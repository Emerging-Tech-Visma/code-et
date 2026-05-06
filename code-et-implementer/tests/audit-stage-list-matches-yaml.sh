#!/usr/bin/env bash
# audit-stage-list-matches-yaml.sh — assert audit-stages.sh's parsed list
# matches the workflow yaml step-for-step (AC-8.2).
#
# We re-parse the yaml here using a deliberately different extraction (grep on
# `name:` and `run:` / `uses:` lines) so the comparison has signal, not a
# tautology — a typo in audit-stages.sh's mapping would still be caught.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGES="$SCRIPT_DIR/../scripts/audit-stages.sh"
YAML="$SCRIPT_DIR/../templates/shared/.github/workflows/code-et-audit.yml"

# Setup-only steps to ignore. Match by `uses:` action prefix (no @ref).
SETUP_USES_RE='^(actions/checkout|dtolnay/rust-toolchain|Swatinem/rust-cache|taiki-e/install-action)'

# Action-to-command map for `uses:` gate steps. Mirrored in audit-stages.sh —
# the test's job is to fail loudly if the two ever diverge.
map_uses_to_cmd() {
  case "$1" in
    bnjbvr/cargo-machete)             echo "cargo machete" ;;
    rustsec/audit-check)              echo "cargo audit" ;;
    EmbarkStudios/cargo-deny-action)  echo "cargo deny check" ;;
    *) echo "UNKNOWN" ;;
  esac
}

# Walk the yaml. For each step, capture `name:` and `run:` / `uses:`.
# Emit `name|command` for non-setup steps. Use Python for indent-aware parsing
# only if available; otherwise a portable awk pass.
expected="$(awk '
  function flush(  cmd, action) {
    if (name == "") return
    if (run != "") {
      cmd = run
    } else if (uses != "") {
      action = uses
      sub(/@.*/, "", action)
      if (action ~ /^actions\/checkout$/ ||
          action ~ /^dtolnay\/rust-toolchain$/ ||
          action ~ /^Swatinem\/rust-cache$/ ||
          action ~ /^taiki-e\/install-action$/) {
        reset(); return
      }
      if (action == "bnjbvr/cargo-machete") cmd = "cargo machete"
      else if (action == "rustsec/audit-check") cmd = "cargo audit"
      else if (action == "EmbarkStudios/cargo-deny-action") cmd = "cargo deny check"
      else { printf "test: unmapped uses %s\n", action > "/dev/stderr"; exit 5 }
    } else { reset(); return }
    printf "%s|%s\n", name, cmd
    reset()
  }
  function reset() { name=""; run=""; uses="" }
  BEGIN { in_steps = 0; reset() }
  /^    steps:[[:space:]]*$/ { in_steps = 1; next }
  in_steps == 1 && /^[a-zA-Z]/ { in_steps = 0 }
  in_steps == 1 && /^      - / {
    flush()
    line = $0; sub(/^      - /, "", line)
    if (line ~ /^uses:[[:space:]]/)      { sub(/^uses:[[:space:]]+/, "", line); uses = line }
    else if (line ~ /^name:[[:space:]]/) { sub(/^name:[[:space:]]+/, "", line); name = line }
    next
  }
  in_steps == 1 && /^        name:[[:space:]]/ { line = $0; sub(/^        name:[[:space:]]+/, "", line); name = line; next }
  in_steps == 1 && /^        uses:[[:space:]]/ { line = $0; sub(/^        uses:[[:space:]]+/, "", line); uses = line; next }
  in_steps == 1 && /^        run:[[:space:]]/  { line = $0; sub(/^        run:[[:space:]]+/, "", line); run = line; next }
  END { flush() }
' "$YAML")"

actual="$(bash "$STAGES" "$YAML")"

if [ "$expected" != "$actual" ]; then
  echo "FAIL: audit-stages.sh output diverges from yaml" >&2
  diff <(echo "$expected") <(echo "$actual") >&2 || true
  exit 1
fi

# Sanity: exactly seven gate stages.
count="$(echo "$actual" | grep -c '|')"
if [ "$count" -ne 7 ]; then
  echo "FAIL: expected 7 stages, got $count" >&2
  echo "$actual" >&2
  exit 1
fi

# Suppress unused-var warning for SETUP_USES_RE (kept for documentation).
: "$SETUP_USES_RE"

echo "PASS: audit-stage-list-matches-yaml ($count stages)"
