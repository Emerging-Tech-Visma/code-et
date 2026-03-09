#!/bin/bash
# TaskCompleted hook — cmux notification with agent attribution

HOOK_INPUT=""
if [ ! -t 0 ]; then
  HOOK_INPUT=$(cat)
fi

TASK_ID=""
AGENT_ID=""
AGENT_TYPE=""
if [ -n "$HOOK_INPUT" ] && command -v jq &>/dev/null; then
  TASK_ID=$(echo "$HOOK_INPUT" | jq -r '.task_id // empty' 2>/dev/null)
  AGENT_ID=$(echo "$HOOK_INPUT" | jq -r '.agent_id // empty' 2>/dev/null)
  AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // empty' 2>/dev/null)
fi

LABEL="Task ${TASK_ID:-unknown}"
[ -n "$AGENT_ID" ] && LABEL="$LABEL (agent: $AGENT_ID)"

# cmux notification
if command -v cmux &>/dev/null && [ -n "$CMUX_SOCKET_PATH" ]; then
  cmux notify --title "Task Completed" --subtitle "${AGENT_TYPE:-agent}" --body "$LABEL" 2>/dev/null || true
fi

echo "{\"info\": \"$LABEL completed\"}"
exit 0
