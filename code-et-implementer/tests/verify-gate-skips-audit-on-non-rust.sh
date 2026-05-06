#!/usr/bin/env bash
# verify-gate-skips-audit-on-non-rust.sh — assert verify-gate.sh skips the
# audit step when no Cargo.toml is present at the repo root (AC-3.2).
#
# Same shim strategy as the rust variant: a sentinel-touching stub for
# audit.sh that must NOT be created when the gate runs on a bare temp dir.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SRC="$SCRIPT_DIR/../scripts/verify-gate.sh"

TMPDIR_TEST="$(mktemp -d -t code-et-gate-norust.XXXXXX)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

WORKSPACE="$TMPDIR_TEST/workspace"
SCRIPTS="$TMPDIR_TEST/scripts"
mkdir -p "$WORKSPACE" "$SCRIPTS"

# Bare workspace — no Cargo.toml, no git tree.

SENTINEL_TESTS="$TMPDIR_TEST/run-tests-was-called"
SENTINEL_AUDIT="$TMPDIR_TEST/audit-was-called"

cat > "$SCRIPTS/run-tests.sh" <<EOF
#!/usr/bin/env bash
touch "$SENTINEL_TESTS"
exit 0
EOF
chmod +x "$SCRIPTS/run-tests.sh"

# Audit shim — if invoked on a non-Rust tree, this is a regression. The
# sentinel must not be created.
cat > "$SCRIPTS/audit.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" > "$SENTINEL_AUDIT"
exit 0
EOF
chmod +x "$SCRIPTS/audit.sh"

cp "$GATE_SRC" "$SCRIPTS/verify-gate.sh"
chmod +x "$SCRIPTS/verify-gate.sh"

STDERR_LOG="$TMPDIR_TEST/stderr.log"

set +e
(cd "$WORKSPACE" && bash "$SCRIPTS/verify-gate.sh" </dev/null) 2> "$STDERR_LOG"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "FAIL: verify-gate.sh exited $rc on non-Rust dir; expected 0" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

if [ ! -f "$SENTINEL_TESTS" ]; then
  echo "FAIL: run-tests.sh stub was not invoked" >&2
  exit 1
fi

if [ -f "$SENTINEL_AUDIT" ]; then
  echo "FAIL: audit.sh was invoked on non-Rust dir; expected silent skip" >&2
  cat "$SENTINEL_AUDIT" >&2
  exit 1
fi

# Silent skip: stderr should not mention the audit or the workspace skip.
if grep -qi "audit\|not a Rust workspace" "$STDERR_LOG"; then
  echo "FAIL: skip path emitted stderr; expected silent" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

echo "PASS: verify-gate-skips-audit-on-non-rust"
