#!/bin/bash
# PreToolUse hook — injects .claude/rules/*.md as additionalContext before Write/Edit
# This ensures subagents see project conventions even without loading rules/ directly.

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Parse agent identity for traceability
AGENT_ID=""
AGENT_TYPE=""
if [ -n "$HOOK_INPUT" ] && command -v jq &>/dev/null; then
  AGENT_ID=$(echo "$HOOK_INPUT" | jq -r '.agent_id // empty' 2>/dev/null)
  AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
fi

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

AGENT_LABEL=""
[ -n "$AGENT_ID" ] && AGENT_LABEL="[agent:${AGENT_ID}${AGENT_TYPE:+/$AGENT_TYPE}] "

echo "{\"additionalContext\": \"${AGENT_LABEL}Project rules:\\n${ESCAPED}\"}"
exit 0
