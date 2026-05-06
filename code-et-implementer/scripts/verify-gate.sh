#!/bin/bash
# SubagentStop hook — verification gate after background agent
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/run-tests.sh" "Agent" 1 || exit $?

# US-3: Run audit --fast on Rust workspaces. Detect repo root via git, fall
# back to cwd. Skip silently when no Cargo.toml — keeps the hook safe to wire
# into shared SubagentStop on non-Rust repos.
ROOT=""
if command -v git >/dev/null 2>&1; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$ROOT" ] && ROOT="$PWD"
if [ -f "$ROOT/Cargo.toml" ]; then
  "$DIR/audit.sh" --fast "$ROOT" </dev/null
fi
