#!/bin/bash
# Pre-compact hook — re-inject critical context before compaction

HOOK_INPUT=$(cat)
DATE=$(date +"%Y-%m-%d %H:%M")
BRANCH=$(echo "$HOOK_INPUT" | jq -r '.worktree.branch // empty' 2>/dev/null)
if [ -z "$BRANCH" ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
fi

# Re-inject manifest summary if it exists
MANIFEST=".claude/${CLAUDE_CODE_TASK_LIST_ID:-code-et-tasks}.json"
MANIFEST_SUMMARY=""
if [ -f "$MANIFEST" ] && command -v jq &>/dev/null; then
  MANIFEST_SUMMARY=$(jq -r '
    (.tasks | length) as $total |
    ([.tasks[] | select(.status == "completed")] | length) as $done |
    ([.tasks[] | select(.status == "in_progress")] | length) as $wip |
    ([.tasks[] | select(.status == "pending")] | length) as $pend |
    "Tasks: \($done)/\($total) done, \($wip) in-flight, \($pend) pending"
  ' "$MANIFEST" 2>/dev/null || echo "")
fi

# Re-inject checkpoint if it exists
CHECKPOINT=$(cat .claude/orchestrator-checkpoint.json 2>/dev/null || echo "null")

echo "{\"pre_compact\": \"Context compacting — restore state from manifest and checkpoint\", \"branch\": \"$BRANCH\", \"timestamp\": \"$DATE\", \"manifest_summary\": \"$MANIFEST_SUMMARY\", \"checkpoint\": $CHECKPOINT}"

exit 0
