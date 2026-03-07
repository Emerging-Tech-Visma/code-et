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
  TOTAL=$(jq '.tasks | length' "$MANIFEST" 2>/dev/null || echo "?")
  COMPLETED=$(jq '[.tasks[] | select(.status == "completed")] | length' "$MANIFEST" 2>/dev/null || echo "?")
  PENDING=$(jq '[.tasks[] | select(.status == "pending")] | length' "$MANIFEST" 2>/dev/null || echo "?")
  IN_PROGRESS=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "$MANIFEST" 2>/dev/null || echo "?")
  MANIFEST_SUMMARY="Tasks: ${COMPLETED}/${TOTAL} done, ${IN_PROGRESS} in-flight, ${PENDING} pending"
fi

# Re-inject checkpoint if it exists
CHECKPOINT="null"
if [ -f ".claude/orchestrator-checkpoint.json" ]; then
  CHECKPOINT=$(cat .claude/orchestrator-checkpoint.json)
fi

echo "{\"pre_compact\": \"Context compacting — restore state from manifest and checkpoint\", \"branch\": \"$BRANCH\", \"timestamp\": \"$DATE\", \"manifest_summary\": \"$MANIFEST_SUMMARY\", \"checkpoint\": $CHECKPOINT}"

exit 0
