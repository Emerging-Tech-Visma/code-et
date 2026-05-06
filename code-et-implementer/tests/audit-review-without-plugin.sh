#!/usr/bin/env bash
# audit-review-without-plugin.sh — assert audit.sh --review exits non-zero
# with the install hint when the engineering plugin is not detectable
# (AC-5.3).
#
# Strategy: sandbox HOME to an empty tempdir so no plugin SKILL.md is reachable,
# point CLAUDE_PLUGIN_ROOT at a stub with no engineering sibling, build a
# minimal Rust workspace with a git history, and invoke audit --review.
# Assert non-zero exit and the hint string on stderr.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/../scripts/audit.sh"

TMPROOT="$(mktemp -d -t code-et-audit-norev.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

# Sandboxed HOME with no plugins. CLAUDE_PLUGIN_ROOT points at a stub dir
# whose ../engineering/skills/code-review/SKILL.md does NOT exist.
FAKE_HOME="$TMPROOT/home"
mkdir -p "$FAKE_HOME"
STUB_PLUGIN_ROOT="$TMPROOT/code-et-implementer"
mkdir -p "$STUB_PLUGIN_ROOT"

# Minimal Rust workspace + git history.
WS="$TMPROOT/ws"
mkdir -p "$WS/src"
cat > "$WS/Cargo.toml" <<'EOF'
[package]
name = "stub"
version = "0.1.0"
edition = "2021"
EOF
echo 'fn main() {}' > "$WS/src/main.rs"

git -C "$WS" init -q -b main
git -C "$WS" -c user.email=test@test -c user.name=test add -A
git -C "$WS" -c user.email=test@test -c user.name=test commit -q -m "init"

# Sandbox PATH so cargo/clippy don't surface real failures unrelated to the
# plugin-detection branch we're testing.
SANDBOX_BIN="$TMPROOT/bin"
mkdir -p "$SANDBOX_BIN"
for t in bash sh awk grep sed cat head tail mktemp date dirname basename ls cd rm cp mv mkdir tr cut wc sort uniq printf id git env which command find chmod test pwd; do
  if cmd_path="$(command -v "$t" 2>/dev/null)"; then
    ln -sf "$cmd_path" "$SANDBOX_BIN/$t"
  fi
done

STDERR_LOG="$TMPROOT/stderr.log"
set +e
HOME="$FAKE_HOME" CLAUDE_PLUGIN_ROOT="$STUB_PLUGIN_ROOT" PATH="$SANDBOX_BIN" \
  bash "$AUDIT" --review "$WS" 2> "$STDERR_LOG"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "FAIL: audit --review exited 0; expected non-zero (no plugin)" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

if ! grep -q "engineering plugin not installed" "$STDERR_LOG"; then
  echo "FAIL: missing install-hint string on stderr" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

if ! grep -q "/plugin install engineering" "$STDERR_LOG"; then
  echo "FAIL: hint missing install command" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

echo "PASS: audit-review-without-plugin"
