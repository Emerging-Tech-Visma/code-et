#!/usr/bin/env bash
# audit.sh — local mirror of the v3.9.0 CI audit gate.
#
# Usage: audit.sh [target-dir]
#   target-dir defaults to the current working directory.
#
# Behaviour:
#   - If no Cargo.toml is found at the target dir or its git root, exits 0
#     with "not a Rust workspace, skipping" on stderr (AC-6.1). No report.
#   - Otherwise parses the workflow yaml via audit-stages.sh and runs every
#     stage in declared order. Stages whose binary (or referenced script) is
#     not on PATH emit a WARNING and are skipped, recorded as LOW-severity
#     findings; the exit code stays 0 if no other stage fails (US-9).
#   - Genuine stage failures collect a finding and cause a non-zero exit.
#   - Always writes <target>/.claude/audit-<YYYYMMDD-HHMMSS>.md (UTC).
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

TARGET_RAW="${1:-$PWD}"
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

REPORT_DIR="$WORKSPACE/.claude"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
REPORT_PATH="$REPORT_DIR/audit-$TIMESTAMP.md"
mkdir -p "$REPORT_DIR"

FINDINGS_TMP="$(mktemp -t code-et-audit.XXXXXX)"
trap 'rm -f "$FINDINGS_TMP"' EXIT

OVERALL_FAIL=0

# Read the stage list once. Each line is `name|command`.
STAGES="$(bash "$STAGES_SCRIPT")"

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

bash "$REPORT_SCRIPT" "$REPORT_PATH" < "$FINDINGS_TMP"
echo "audit: report written to $REPORT_PATH" >&2

exit "$OVERALL_FAIL"
