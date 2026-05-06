#!/usr/bin/env bash
# implement-chain-halts-on-audit-failure.sh — assert /code:implement chains
# `--fast` audit after simplify and that a fast audit failure halts the loop
# with the audit report path surfaced (US-2 / AC-2.1, AC-2.2).
#
# We can't drive the full Claude orchestrator from a bash test, so the chain
# assertion is split into two empirical phases:
#
#   Phase A — wiring (AC-2.1): grep implement.md to confirm the line
#     containing `Skill("simplify")` is followed by an `audit` invocation
#     in `--fast` mode. This mirrors the verification in the task manifest.
#
#   Phase B — regression fixture (AC-2.2): build a tiny Rust workspace whose
#     `cargo clippy ... -D warnings` fails (unused variable). Drive
#     `audit.sh --fast` directly, assert non-zero exit, that a report file
#     was written under `<workspace>/.claude/`, and that the runner echoes
#     `audit: report written to <path>` on stderr — the surfacing mechanism
#     a Skill chain inherits via the harness. Skip phase B if `cargo` is
#     missing so the structural check still runs on stripped CI images.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMPLEMENT_MD="$SCRIPT_DIR/../commands/implement.md"
AUDIT="$SCRIPT_DIR/../scripts/audit.sh"

# ----------------------------------------------------------------------------
# Phase A — structural wiring (AC-2.1).
# ----------------------------------------------------------------------------

if [ ! -f "$IMPLEMENT_MD" ]; then
  echo "FAIL (phase A): implement.md not found at $IMPLEMENT_MD" >&2
  exit 1
fi

# The line carrying Skill("simplify") must be followed (within `grep -A1`) by
# an `audit … --fast` reference. Same predicate the task manifest uses.
if ! grep -A1 'Skill("simplify")' "$IMPLEMENT_MD" | grep -q 'audit.*--fast'; then
  echo "FAIL (phase A): implement.md does not chain audit --fast after Skill(\"simplify\")" >&2
  echo "  expected: a line matching 'audit.*--fast' immediately after the simplify call" >&2
  echo "  --- relevant slice ---" >&2
  grep -n -A2 'Skill("simplify")' "$IMPLEMENT_MD" >&2 || true
  exit 1
fi

# ----------------------------------------------------------------------------
# Phase B — regression fixture (AC-2.2).
# Skip cleanly if cargo is not on PATH; phase A still proves the wiring.
# ----------------------------------------------------------------------------

if ! command -v cargo >/dev/null 2>&1; then
  echo "PASS: implement-chain-halts-on-audit-failure (phase A only — cargo missing)"
  exit 0
fi

TMPROOT="$(mktemp -d -t code-et-implement-chain.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

WS="$TMPROOT/ws"
mkdir -p "$WS/src"

# Standalone Cargo package — `audit.sh` accepts a target dir and runs the
# stages with that dir as the working directory.
cat > "$WS/Cargo.toml" <<'EOF'
[package]
name = "implement-chain-fixture"
version = "0.0.1"
edition = "2021"

[[bin]]
name = "implement-chain-fixture"
path = "src/main.rs"
EOF

# Source: well-formatted (so `cargo fmt --check` passes) but carries an
# unused variable — `cargo clippy ... -D warnings` promotes the rustc
# `unused_variables` lint to an error and stage 2 fails. That is the
# "known clippy regression" the chain must catch.
cat > "$WS/src/main.rs" <<'EOF'
fn main() {
    let x = 1;
}
EOF

stderr_log="$TMPROOT/audit.stderr"
stdout_log="$TMPROOT/audit.stdout"

set +e
bash "$AUDIT" --fast "$WS" > "$stdout_log" 2> "$stderr_log"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "FAIL (phase B): audit.sh --fast exited 0 on a workspace with a clippy regression" >&2
  echo "  --- stderr ---" >&2
  cat "$stderr_log" >&2
  exit 1
fi

# Locate the report file the runner wrote.
report="$(ls "$WS/.claude/audit-"*.md 2>/dev/null | head -n1 || true)"
if [ -z "$report" ] || [ ! -f "$report" ]; then
  echo "FAIL (phase B): no audit report written under $WS/.claude/" >&2
  cat "$stderr_log" >&2
  exit 1
fi

if [ ! -s "$report" ]; then
  echo "FAIL (phase B): audit report is empty: $report" >&2
  exit 1
fi

# AC-2.2 surfacing: the runner echoes the report path on stderr. That is the
# string the implement chain (or any caller) sees and can forward to chat.
if ! grep -Fq "audit: report written to $report" "$stderr_log"; then
  echo "FAIL (phase B): report path not surfaced on stderr" >&2
  echo "  expected: audit: report written to $report" >&2
  echo "  --- stderr ---" >&2
  cat "$stderr_log" >&2
  exit 1
fi

# Sanity: `--fast` must run only stages 1-2. Stage 3+ names should never
# appear in the runner's stderr trace. If they do, the chain hook would be
# slower than the PRD allows.
for forbidden in "layer-deps validator" "cargo-machete" "cargo-audit" "cargo-deny" "tests"; do
  if grep -Fq "$forbidden — running" "$stderr_log"; then
    echo "FAIL (phase B): --fast invoked a stage outside 1-2: '$forbidden'" >&2
    cat "$stderr_log" >&2
    exit 1
  fi
done

echo "PASS: implement-chain-halts-on-audit-failure"
