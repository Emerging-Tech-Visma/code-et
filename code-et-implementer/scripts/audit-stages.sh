#!/usr/bin/env bash
# audit-stages.sh — yaml parser for the audit pipeline (used by audit.sh and /code:ship).
# Emits one `name|command` line per gate stage on stdout, in declared order.
# Reads the workflow yaml at $1 (default: shared template path).
# The yaml is the single source of truth — no hardcoded stage list.
#
# Mapping for `uses:` steps (GitHub Action → local cargo subcommand):
#   bnjbvr/cargo-machete                  → cargo machete
#   rustsec/audit-check                   → cargo audit
#   EmbarkStudios/cargo-deny-action       → cargo deny check
#
# Setup-only `uses:` steps are skipped (checkout, rust-toolchain, rust-cache,
# install-action). They install tooling, not run audit stages.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_YAML="$SCRIPT_DIR/../templates/shared/.github/workflows/code-et-audit.yml"
YAML_PATH="${1:-$DEFAULT_YAML}"

if [ ! -f "$YAML_PATH" ]; then
  echo "audit-stages.sh: yaml not found: $YAML_PATH" >&2
  exit 2
fi

# Walk the yaml line by line. The workflow is hand-written and stable, so a
# small awk pass is enough — we don't need a real yaml lib.
awk '
  function flush(  cmd) {
    if (name == "") return
    if (run != "") {
      cmd = run
    } else if (uses != "") {
      # Strip @<ref> suffix.
      action = uses
      sub(/@.*/, "", action)
      if (action == "actions/checkout") { reset(); return }
      if (action == "dtolnay/rust-toolchain") { reset(); return }
      if (action == "Swatinem/rust-cache") { reset(); return }
      if (action == "taiki-e/install-action") { reset(); return }
      if (action == "bnjbvr/cargo-machete") { cmd = "cargo machete" }
      else if (action == "rustsec/audit-check") { cmd = "cargo audit" }
      else if (action == "EmbarkStudios/cargo-deny-action") { cmd = "cargo deny check" }
      else {
        printf "audit-stages.sh: unknown uses action: %s\n", action > "/dev/stderr"
        exit 3
      }
    } else {
      reset(); return
    }
    printf "%s|%s\n", name, cmd
    reset()
  }
  function reset() { name=""; run=""; uses="" }

  BEGIN { in_steps = 0; reset() }

  # Detect entering the steps: block. Match exactly two-space indent under
  # jobs.audit, then four-space "steps:".
  /^    steps:[[:space:]]*$/ { in_steps = 1; next }

  # Leaving steps: a top-level key (no leading space) or a sibling at indent <=4
  in_steps == 1 && /^[a-zA-Z]/ { in_steps = 0 }

  in_steps == 1 {
    # A new step starts with "      - " (six spaces, dash, space) at the steps
    # list indent.
    if ($0 ~ /^      - /) {
      flush()
      # The dash-line itself may carry "uses:" or "name:" inline.
      line = $0
      sub(/^      - /, "", line)
      if (line ~ /^uses:[[:space:]]/) {
        sub(/^uses:[[:space:]]+/, "", line)
        uses = line
      } else if (line ~ /^name:[[:space:]]/) {
        sub(/^name:[[:space:]]+/, "", line)
        name = line
      }
      next
    }
    # Continuation keys for the current step: indent eight spaces.
    if ($0 ~ /^        name:[[:space:]]/) {
      line = $0
      sub(/^        name:[[:space:]]+/, "", line)
      name = line
      next
    }
    if ($0 ~ /^        uses:[[:space:]]/) {
      line = $0
      sub(/^        uses:[[:space:]]+/, "", line)
      uses = line
      next
    }
    if ($0 ~ /^        run:[[:space:]]/) {
      line = $0
      sub(/^        run:[[:space:]]+/, "", line)
      run = line
      next
    }
  }

  END { flush() }
' "$YAML_PATH"
