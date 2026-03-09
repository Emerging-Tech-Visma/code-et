#!/bin/bash
# InstructionsLoaded hook — log which instruction file was loaded

HOOK_INPUT=""
if [ ! -t 0 ]; then
  HOOK_INPUT=$(cat)
fi

FILE_PATH=""
if [ -n "$HOOK_INPUT" ] && command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.file // empty' 2>/dev/null)
fi

echo "{\"info\": \"Instructions loaded: ${FILE_PATH:-unknown}\"}"
exit 0
