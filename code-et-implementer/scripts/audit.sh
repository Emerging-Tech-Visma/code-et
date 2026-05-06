#!/usr/bin/env bash
# audit.sh — local mirror of the v3.9.0 CI audit gate.
#
# Usage: audit.sh [--review] [target-dir]
#   target-dir defaults to the current working directory.
#   --review chains the engineering plugin's code-review skill against the
#     working diff (AC-5.1). Requires the engineering plugin to be installed
#     (AC-5.3); the runner detects it via SKILL.md presence.
#
# Behaviour:
#   - If no Cargo.toml is found at the target dir or its git root, exits 0
#     with "not a Rust workspace, skipping" on stderr (AC-6.1). No report.
#   - Otherwise parses the workflow yaml via audit-stages.sh and runs every
#     stage in declared order. Stages whose binary (or referenced script) is
#     not on PATH skip silently with a stderr notice — T7 will refine into
#     formal LOW-severity findings.
#   - Genuine stage failures collect a finding and cause a non-zero exit.
#   - Always writes <target>/.claude/audit-<YYYYMMDD-HHMMSS>.md (UTC).
#   - With --review: after stages, captures `git diff <merge-base>..HEAD` and
#     hands it to audit-report.sh which appends a `## Review` section. If the
#     engineering plugin is not detected, exits non-zero with an install hint.
#
# Severity mapping per stage:
#   fmt                      → MEDIUM
#   clippy (deny warnings)   → HIGH
#   layer-deps validator     → HIGH
#   cargo-machete            → MEDIUM
#   cargo-audit              → CRITICAL
#   cargo-deny               → CRITICAL
#   tests                    → HIGH
#   (default)                → MEDIUM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGES_SCRIPT="$SCRIPT_DIR/audit-stages.sh"
REPORT_SCRIPT="$SCRIPT_DIR/audit-report.sh"

# Argument parsing: support --review as a flag in any position; the lone
# positional is the target dir. Future T3 (--fast, --stage) extends this loop.
REVIEW=0
TARGET_RAW=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --review) REVIEW=1; shift ;;
    --) shift; break ;;
    -*)
      echo "audit.sh: unknown flag: $1" >&2
      exit 2
      ;;
    *)
      if [ -n "$TARGET_RAW" ]; then
        echo "audit.sh: unexpected extra arg: $1" >&2
        exit 2
      fi
      TARGET_RAW="$1"
      shift
      ;;
  esac
done
TARGET_RAW="${TARGET_RAW:-$PWD}"

TARGET="$(cd "$TARGET_RAW" 2>/dev/null && pwd)" || {
  echo "audit.sh: target dir not found: $TARGET_RAW" >&2
  exit 2
}

# Workspace guard. Check the target dir first (the fixture is a Rust workspace
# nested inside a non-Rust outer repo); fall back to the git root if any.
find_workspace_root() {
  local dir="$1"
  if [ -f "$dir/Cargo.toml" ]; then
    echo "$dir"
    return 0
  fi
  local git_root
  if git_root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
    if [ -f "$git_root/Cargo.toml" ]; then
      echo "$git_root"
      return 0
    fi
  fi
  return 1
}

if ! WORKSPACE="$(find_workspace_root "$TARGET")"; then
  echo "audit.sh: not a Rust workspace, skipping" >&2
  exit 0
fi

# Severity mapping per stage name.
severity_for() {
  case "$1" in
    "fmt") echo "MEDIUM" ;;
    "clippy (deny warnings)") echo "HIGH" ;;
    "layer-deps validator") echo "HIGH" ;;
    "cargo-machete (unused deps)") echo "MEDIUM" ;;
    "cargo-audit (advisories)") echo "CRITICAL" ;;
    "cargo-deny (license + bans + sources + advisories)") echo "CRITICAL" ;;
    "tests") echo "HIGH" ;;
    *) echo "MEDIUM" ;;
  esac
}

# Probe whether a stage's executable is available. Returns 0 if runnable.
# For `cargo <sub> ...` forms, checks `cargo-<sub>` on PATH (cargo dispatches
# to it). For `bash <path> ...`, checks the path exists.
stage_runnable() {
  local cmd="$1"
  local first
  first="$(echo "$cmd" | awk '{print $1}')"
  case "$first" in
    cargo)
      local sub
      sub="$(echo "$cmd" | awk '{print $2}')"
      # `cargo fmt`, `cargo clippy` ship with the toolchain — cargo handles them
      # even though `cargo-fmt` / `cargo-clippy` are present via rustup.
      if [ "$sub" = "fmt" ] || [ "$sub" = "clippy" ]; then
        command -v cargo >/dev/null
        return $?
      fi
      command -v "cargo-$sub" >/dev/null
      ;;
    bash)
      local path
      path="$(echo "$cmd" | awk '{print $2}')"
      [ -f "$WORKSPACE/$path" ]
      ;;
    *)
      command -v "$first" >/dev/null
      ;;
  esac
}

# Heuristic: extract a path:line citation from stage stderr/stdout. Falls back
# to <workspace-relative-cargo>:1 so every finding has a citation per AC-7.3.
extract_citation() {
  local log="$1"
  local hit
  # rust diagnostic format: "  --> path/to/file.rs:LINE:COL"
  hit="$(grep -oE '[^[:space:]]+\.rs:[0-9]+:[0-9]+' "$log" 2>/dev/null | head -n1 || true)"
  if [ -n "$hit" ]; then
    # Drop the column; keep path:line.
    echo "$hit" | awk -F: '{print $1 ":" $2}'
    return
  fi
  # generic "path:line:" prefix
  hit="$(grep -oE '[^[:space:]]+:[0-9]+:' "$log" 2>/dev/null | head -n1 || true)"
  if [ -n "$hit" ]; then
    echo "${hit%:}"
    return
  fi
  echo "Cargo.toml:1"
}

# Detect engineering plugin's code-review skill. Returns 0 and prints the
# SKILL.md path on stdout; 1 if absent. Search order:
#   1. ${CLAUDE_PLUGIN_ROOT}/../engineering/skills/code-review/SKILL.md
#   2. ${HOME}/.claude/plugins/cache/*/engineering/skills/code-review/SKILL.md
#   3. <workspace>/.claude/plugins/engineering/skills/code-review/SKILL.md
detect_engineering_plugin() {
  local cand
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    cand="$CLAUDE_PLUGIN_ROOT/../engineering/skills/code-review/SKILL.md"
    if [ -f "$cand" ]; then echo "$cand"; return 0; fi
  fi
  if [ -n "${HOME:-}" ]; then
    for cand in "$HOME"/.claude/plugins/cache/*/engineering/skills/code-review/SKILL.md; do
      [ -f "$cand" ] && { echo "$cand"; return 0; }
    done
  fi
  cand="$WORKSPACE/.claude/plugins/engineering/skills/code-review/SKILL.md"
  if [ -f "$cand" ]; then echo "$cand"; return 0; fi
  return 1
}

# Capture git diff against the merge base of the current branch. Falls back
# through origin/main → main → HEAD~1 → empty. If the merge-base resolves to
# HEAD itself (e.g. on main with no upstream), drops to HEAD~1 so there's
# something to review. Writes the diff to $1.
capture_review_diff() {
  local out="$1" base="" head=""
  head="$(git -C "$WORKSPACE" rev-parse HEAD 2>/dev/null || true)"
  base="$(git -C "$WORKSPACE" merge-base origin/main HEAD 2>/dev/null || true)"
  if [ -z "$base" ] || [ "$base" = "$head" ]; then
    base="$(git -C "$WORKSPACE" merge-base main HEAD 2>/dev/null || true)"
  fi
  if [ -z "$base" ] || [ "$base" = "$head" ]; then
    base="$(git -C "$WORKSPACE" rev-parse HEAD~1 2>/dev/null || true)"
  fi
  if [ -n "$base" ] && [ "$base" != "$head" ]; then
    git -C "$WORKSPACE" diff "$base"..HEAD > "$out" 2>/dev/null || : > "$out"
  else
    : > "$out"
  fi
}

REPORT_DIR="$WORKSPACE/.claude"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
REPORT_PATH="$REPORT_DIR/audit-$TIMESTAMP.md"
mkdir -p "$REPORT_DIR"

FINDINGS_TMP="$(mktemp -t code-et-audit.XXXXXX)"
REVIEW_TMP="$(mktemp -t code-et-audit-review.XXXXXX)"
trap 'rm -f "$FINDINGS_TMP" "$REVIEW_TMP"' EXIT

OVERALL_FAIL=0

# Read the stage list once. Each line is `name|command`.
STAGES="$(bash "$STAGES_SCRIPT")"

while IFS='|' read -r name cmd; do
  [ -z "$name" ] && continue
  severity="$(severity_for "$name")"

  if ! stage_runnable "$cmd"; then
    echo "audit: $name — tool not installed; skipping" >&2
    continue
  fi

  echo "audit: $name — running" >&2
  stage_log="$(mktemp -t code-et-audit-stage.XXXXXX)"
  set +e
  ( cd "$WORKSPACE" && eval "$cmd" ) > "$stage_log" 2>&1
  rc=$?
  set -e
  cat "$stage_log" >&2
  if [ "$rc" -ne 0 ]; then
    OVERALL_FAIL=1
    citation="$(extract_citation "$stage_log")"
    msg="stage '$name' failed (exit $rc): $cmd"
    # Strip pipes from the message so the delimited format survives.
    msg="${msg//|/\\|}"
    printf '%s|%s|%s|%s|%s\n' \
      "$severity" "$name" "${citation%:*}" "${citation##*:}" "$msg" \
      >> "$FINDINGS_TMP"
  fi
  rm -f "$stage_log"
done <<< "$STAGES"

REPORT_ARGS=("$REPORT_PATH")

# Review wiring only attaches when static stages pass — a failing audit is
# already actionable without prose review noise.
if [ "$REVIEW" -eq 1 ] && [ "$OVERALL_FAIL" -eq 0 ]; then
  if ! SKILL_PATH="$(detect_engineering_plugin)"; then
    echo "audit: engineering plugin not installed; run /plugin install engineering to enable --review" >&2
    exit 1
  fi
  echo "audit: --review enabled — capturing diff for $SKILL_PATH" >&2
  capture_review_diff "$REVIEW_TMP"
  REPORT_ARGS+=(--review-file "$REVIEW_TMP")
fi

bash "$REPORT_SCRIPT" "${REPORT_ARGS[@]}" < "$FINDINGS_TMP"
echo "audit: report written to $REPORT_PATH" >&2

exit "$OVERALL_FAIL"
