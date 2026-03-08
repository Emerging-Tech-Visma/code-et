#!/bin/bash
# PreToolUse hook — injects .claude/rules/*.md as additionalContext before Write/Edit
# This ensures subagents see project conventions even without loading rules/ directly.

# Read hook input from stdin
HOOK_INPUT=$(cat)

RULES_DIR=".claude/rules"

if [ ! -d "$RULES_DIR" ]; then
  exit 0
fi

# Collect all rule files
RULES=""
for f in "$RULES_DIR"/*.md; do
  [ -f "$f" ] || continue
  CONTENT=$(cat "$f")
  if [ -n "$CONTENT" ]; then
    RULES="${RULES}--- ${f} ---
${CONTENT}

"
  fi
done

if [ -z "$RULES" ]; then
  exit 0
fi

# Return as additionalContext (JSON output for PreToolUse hooks)
# Escape for JSON: backslashes, quotes, newlines, tabs
ESCAPED=$(printf '%s' "$RULES" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | awk '{printf "%s\\n", $0}')

echo "{\"additionalContext\": \"Project rules:\\n${ESCAPED}\"}"
exit 0
