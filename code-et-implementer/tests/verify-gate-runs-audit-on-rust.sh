#!/usr/bin/env bash
# verify-gate-runs-audit-on-rust.sh — assert verify-gate.sh invokes
# audit.sh --fast when a Cargo.toml is present at the repo root (AC-3.1).
#
# Strategy: stage a copy of verify-gate.sh in a fresh scripts dir alongside
# stub run-tests.sh and audit.sh shims that drop sentinel files when called.
# Run a Rust workspace fixture (just a Cargo.toml) through the gate; assert
# both stubs were called and the gate exits 0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_SRC="$SCRIPT_DIR/../scripts/verify-gate.sh"

TMPDIR_TEST="$(mktemp -d -t code-et-gate-rust.XXXXXX)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

WORKSPACE="$TMPDIR_TEST/workspace"
SCRIPTS="$TMPDIR_TEST/scripts"
mkdir -p "$WORKSPACE" "$SCRIPTS"

# Minimal Rust workspace — Cargo.toml at root is the only signal verify-gate
# uses to gate the audit step.
cat > "$WORKSPACE/Cargo.toml" <<'EOF'
[workspace]
members = []
resolver = "2"
EOF

SENTINEL_TESTS="$TMPDIR_TEST/run-tests-was-called"
SENTINEL_AUDIT="$TMPDIR_TEST/audit-was-called"

# Stub run-tests.sh — drops sentinel, exits 0.
cat > "$SCRIPTS/run-tests.sh" <<EOF
#!/usr/bin/env bash
touch "$SENTINEL_TESTS"
exit 0
EOF
chmod +x "$SCRIPTS/run-tests.sh"

# Stub audit.sh — drops sentinel with the args it received, exits 0.
cat > "$SCRIPTS/audit.sh" <<EOF
#!/usr/bin/env bash
echo "\$*" > "$SENTINEL_AUDIT"
exit 0
EOF
chmod +x "$SCRIPTS/audit.sh"

cp "$GATE_SRC" "$SCRIPTS/verify-gate.sh"
chmod +x "$SCRIPTS/verify-gate.sh"

# Run from inside the workspace so the git/pwd fallback resolves there.
# Outside any git tree -> falls back to PWD; PWD has Cargo.toml -> audit runs.
set +e
(cd "$WORKSPACE" && bash "$SCRIPTS/verify-gate.sh" </dev/null)
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "FAIL: verify-gate.sh exited $rc on Rust workspace; expected 0" >&2
  exit 1
fi

if [ ! -f "$SENTINEL_TESTS" ]; then
  echo "FAIL: run-tests.sh stub was not invoked" >&2
  exit 1
fi

if [ ! -f "$SENTINEL_AUDIT" ]; then
  echo "FAIL: audit.sh stub was not invoked on Rust workspace" >&2
  exit 1
fi

# Sanity: the audit was called with --fast and the workspace path.
if ! grep -q -- "--fast" "$SENTINEL_AUDIT"; then
  echo "FAIL: audit invocation missing --fast flag" >&2
  cat "$SENTINEL_AUDIT" >&2
  exit 1
fi
if ! grep -qF "$WORKSPACE" "$SENTINEL_AUDIT"; then
  echo "FAIL: audit invocation missing workspace path" >&2
  cat "$SENTINEL_AUDIT" >&2
  exit 1
fi

echo "PASS: verify-gate-runs-audit-on-rust"
