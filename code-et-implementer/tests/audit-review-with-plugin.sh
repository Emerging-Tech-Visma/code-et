#!/usr/bin/env bash
# audit-review-with-plugin.sh — assert audit.sh --review writes a Review
# section into the report when the engineering plugin is detectable
# (AC-5.1, AC-5.2).
#
# Strategy: stub plugin presence by creating a fake SKILL.md under a sandboxed
# HOME, build a minimal Rust workspace in a tempdir (Cargo.toml only), seed it
# as a git repo with two commits so a diff exists, then invoke audit --review
# and assert exit 0 and the report contains "## Review".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/../scripts/audit.sh"

TMPROOT="$(mktemp -d -t code-et-audit-rev.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

# Stub plugin presence under a sandboxed HOME.
FAKE_HOME="$TMPROOT/home"
SKILL_DIR="$FAKE_HOME/.claude/plugins/cache/knowledge-work-plugins/engineering/skills/code-review"
mkdir -p "$SKILL_DIR"
cat > "$SKILL_DIR/SKILL.md" <<'EOF'
---
name: code-review
---
stub
EOF

# Minimal Rust workspace + git history so the merge-base diff is non-empty.
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
echo '// edit' >> "$WS/src/main.rs"
git -C "$WS" -c user.email=test@test -c user.name=test commit -q -am "edit"

# Sandbox PATH to a minimal toolset so cargo/clippy are absent and every
# stage skips cleanly. We need git, awk, grep, mktemp, date, sed, cat, head,
# bash, and core POSIX tools — symlink them in.
SANDBOX_BIN="$TMPROOT/bin"
mkdir -p "$SANDBOX_BIN"
for t in bash sh awk grep sed cat head tail mktemp date dirname basename ls cd rm cp mv mkdir tr cut wc sort uniq printf id git env which command find chmod test pwd; do
  if cmd_path="$(command -v "$t" 2>/dev/null)"; then
    ln -sf "$cmd_path" "$SANDBOX_BIN/$t"
  fi
done

STDERR_LOG="$TMPROOT/stderr.log"
set +e
HOME="$FAKE_HOME" CLAUDE_PLUGIN_ROOT="" PATH="$SANDBOX_BIN" \
  bash "$AUDIT" --review "$WS" 2> "$STDERR_LOG"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "FAIL: audit --review exited $rc; expected 0" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

REPORT="$(ls "$WS"/.claude/audit-*.md 2>/dev/null | head -n1 || true)"
if [ -z "$REPORT" ]; then
  echo "FAIL: no report file written" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

if ! grep -q '^## Review' "$REPORT"; then
  echo "FAIL: report missing '## Review' section" >&2
  cat "$REPORT" >&2
  exit 1
fi

if ! grep -q "code-review skill" "$REPORT"; then
  echo "FAIL: review section missing skill-consumption note" >&2
  cat "$REPORT" >&2
  exit 1
fi

if ! grep -q '```diff' "$REPORT"; then
  echo "FAIL: review section missing fenced diff block" >&2
  cat "$REPORT" >&2
  exit 1
fi

echo "PASS: audit-review-with-plugin"
