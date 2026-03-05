#!/bin/bash
# Pre-compact hook - log state before context compaction
# Called on PreCompact hook

HOOK_INPUT=$(cat)
DATE=$(date +"%Y-%m-%d %H:%M")
BRANCH=$(echo "$HOOK_INPUT" | jq -r '.worktree.branch // empty' 2>/dev/null)
if [ -z "$BRANCH" ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
fi

echo "{\"pre_compact\": \"Context compacting\", \"branch\": \"$BRANCH\", \"timestamp\": \"$DATE\"}"

exit 0
