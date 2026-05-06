#!/usr/bin/env bash
# audit.sh — local mirror of the v3.9.0 CI audit gate.
#
# Usage: audit.sh [--fast | --stage <n>] [--review] [target-dir]
#   --fast      runs only stages 1-2 (fmt + clippy)
#   --stage <n> runs only the n-th stage (1-indexed) from the parsed yaml
#   --review    chains the engineering plugin's code-review skill against
#               `git diff <merge-base>..HEAD`; missing plugin → exit non-zero
#   target-dir defaults to the current working directory.
#
# Exits 0 with "not a Rust workspace, skipping" on stderr if no Cargo.toml
# is found at target or its git root. Otherwise parses the workflow yaml
# and runs every stage in order; missing tools (cargo-machete/audit/deny,
# cargo-nextest, layer-deps script) emit a WARNING and are recorded as
# LOW-severity findings. Always writes <target>/.claude/audit-<UTC>.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGES_SCRIPT="$SCRIPT_DIR/audit-stages.sh"
REPORT_SCRIPT="$SCRIPT_DIR/audit-report.sh"

MODE="all"
STAGE_NUM=""
REVIEW=0
POSITIONAL=()

print_usage() {
  local stages
  stages="$(bash "$STAGES_SCRIPT")" || return 1
  echo "Usage: audit.sh [--fast | --stage <n>] [--review] [target-dir]" >&2
  echo "" >&2
  echo "Valid stages:" >&2
  local i=0
  while IFS='|' read -r name _cmd; do
    [ -z "$name" ] && continue
    i=$((i + 1))
    echo "  $i) $name" >&2
  done <<< "$stages"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --fast)
      if [ "$MODE" = "stage" ]; then
        echo "audit.sh: --fast and --stage are mutually exclusive" >&2
        print_usage
        exit 2
      fi
      MODE="fast"
      shift
      ;;
    --stage)
      if [ "$MODE" = "fast" ]; then
        echo "audit.sh: --fast and --stage are mutually exclusive" >&2
        print_usage
        exit 2
      fi
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        echo "audit.sh: --stage requires a numeric argument" >&2
        print_usage
        exit 2
      fi
      MODE="stage"
      STAGE_NUM="$2"
      shift 2
      ;;
    --review)
      REVIEW=1
      shift
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do POSITIONAL+=("$1"); shift; done
      ;;
    -*)
      echo "audit.sh: unknown flag: $1" >&2
      print_usage
      exit 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

TARGET_RAW="${POSITIONAL[0]:-$PWD}"
TARGET="$(cd "$TARGET_RAW" 2>/dev/null && pwd)" || {
  echo "audit.sh: target dir not found: $TARGET_RAW" >&2
  exit 2
}

STAGES="$(bash "$STAGES_SCRIPT")"
STAGE_COUNT="$(printf '%s\n' "$STAGES" | grep -c '|' || true)"

# --stage <n> validation runs before the workspace guard so bad input always
# exits non-zero, regardless of whether the target is a Rust workspace.
if [ "$MODE" = "stage" ]; then
  if ! [[ "$STAGE_NUM" =~ ^[1-9][0-9]*$ ]] || [ "$STAGE_NUM" -gt "$STAGE_COUNT" ]; then
    echo "audit.sh: invalid stage '$STAGE_NUM' (valid: 1..$STAGE_COUNT)" >&2
    print_usage
    exit 2
  fi
fi

# Target dir checked first (fixture is a Rust workspace nested inside a
# non-Rust outer repo); git root fallback only if target itself has no Cargo.toml.
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

stage_runnable() {
  local cmd="$1" first sub path
  first="$(echo "$cmd" | awk '{print $1}')"
  case "$first" in
    cargo)
      sub="$(echo "$cmd" | awk '{print $2}')"
      # `cargo fmt`/`cargo clippy` ship with the toolchain via rustup — they
      # are dispatched by `cargo` itself, not by separate `cargo-fmt` binaries.
      if [ "$sub" = "fmt" ] || [ "$sub" = "clippy" ]; then
        command -v cargo >/dev/null
        return $?
      fi
      command -v "cargo-$sub" >/dev/null
      ;;
    bash)
      path="$(echo "$cmd" | awk '{print $2}')"
      [ -f "$WORKSPACE/$path" ]
      ;;
    *)
      command -v "$first" >/dev/null
      ;;
  esac
}

# Describe the missing artifact when a stage is not runnable.
# Emits "<artifact>|<install_hint>" — the artifact is the canonical binary or
# script name (used as the finding's `path` slot), and the hint is a short
# remediation string with no pipe characters.
missing_artifact_for() {
  local cmd="$1"
  local first sub path
  first="$(echo "$cmd" | awk '{print $1}')"
  case "$first" in
    cargo)
      sub="$(echo "$cmd" | awk '{print $2}')"
      printf 'cargo-%s|tool not installed; skipping. Install with: cargo install cargo-%s\n' "$sub" "$sub"
      ;;
    bash)
      path="$(echo "$cmd" | awk '{print $2}')"
      printf '%s|script not present in workspace; skipping. Add %s to your workspace.\n' "$path" "$path"
      ;;
    *)
      printf '%s|tool not installed; skipping. Install %s and re-run.\n' "$first" "$first"
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
# SKILL.md path on stdout; 1 if absent.
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

# Capture diff against merge-base, falling through origin/main → main → HEAD~1
# so a branch with no upstream still gets something reviewable. Writes to $1.
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

case "$MODE" in
  fast)  STAGES="$(printf '%s\n' "$STAGES" | sed -n '1,2p')" ;;
  stage) STAGES="$(printf '%s\n' "$STAGES" | sed -n "${STAGE_NUM}p")" ;;
  all) ;;
esac

while IFS='|' read -r name cmd; do
  [ -z "$name" ] && continue
  severity="$(severity_for "$name")"

  if ! stage_runnable "$cmd"; then
    artifact_hint="$(missing_artifact_for "$cmd")"
    artifact="${artifact_hint%%|*}"
    hint="${artifact_hint#*|}"
    echo "audit: WARNING: $name — $hint" >&2
    # Record as LOW finding; exit code stays 0 unless another stage fails.
    msg="${hint//|/\\|}"
    printf '%s|%s|%s|%s|%s\n' \
      "LOW" "$name" "$artifact" "1" "$msg" \
      >> "$FINDINGS_TMP"
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

SUMMARY_LINE="$(bash "$REPORT_SCRIPT" "${REPORT_ARGS[@]}" < "$FINDINGS_TMP")"
echo "audit: report written to $REPORT_PATH" >&2

# AC-12.2: on failure, surface the writer's summary line on stderr so the user
# sees the highest-severity finding without opening the report.
if [ "$OVERALL_FAIL" -ne 0 ] && [ -n "$SUMMARY_LINE" ]; then
  echo "$SUMMARY_LINE" >&2
fi

exit "$OVERALL_FAIL"
