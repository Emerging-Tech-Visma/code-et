#!/usr/bin/env bash
# audit-skips-non-rust.sh — assert audit.sh exits 0 with no report when the
# target dir is not a Rust workspace (AC-6.1).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/../scripts/audit.sh"

TMPDIR_TEST="$(mktemp -d -t code-et-audit-test.XXXXXX)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# A bare temp dir with no Cargo.toml and no enclosing git tree.
STDERR_LOG="$(mktemp -t code-et-audit-stderr.XXXXXX)"
set +e
bash "$AUDIT" "$TMPDIR_TEST" 2> "$STDERR_LOG"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "FAIL: audit.sh exited $rc on non-Rust dir; expected 0" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

if ! grep -q "not a Rust workspace, skipping" "$STDERR_LOG"; then
  echo "FAIL: missing skip message on stderr" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

if ls "$TMPDIR_TEST/.claude/audit-"*.md >/dev/null 2>&1; then
  echo "FAIL: report file written despite skip" >&2
  exit 1
fi

rm -f "$STDERR_LOG"
echo "PASS: audit-skips-non-rust"
