#!/bin/bash
# Shared verification gate — detects and runs project test command
# Usage: run-tests.sh <caller-label> <failure-exit-code>
# Args:
#   $1 = caller label ("Implementer" or "Teammate") for log messages
#   $2 = exit code on test failure (1 for SubagentStop, 2 for TaskCompleted)

CALLER="${1:-Agent}"
FAIL_EXIT="${2:-1}"

# Read hook input from stdin (JSON with last_assistant_message)
HOOK_INPUT=""
if [ ! -t 0 ]; then
  HOOK_INPUT=$(cat)
fi

# Parse last_assistant_message (jq preferred, grep fallback)
LAST_MSG=""
if [ -n "$HOOK_INPUT" ]; then
  if command -v jq &> /dev/null; then
    LAST_MSG=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
  else
    LAST_MSG=$(echo "$HOOK_INPUT" | grep -o '"last_assistant_message":"[^"]*"' | head -1 | sed 's/"last_assistant_message":"//;s/"$//')
  fi
fi

# Check agent's final status
if [ -n "$LAST_MSG" ]; then
  if echo "$LAST_MSG" | grep -qi "BLOCKED:"; then
    CLAIM=$(echo "$LAST_MSG" | head -c 200)
    echo "{\"info\": \"$CALLER reported BLOCKED — skipping verification\", \"claim\": \"$CLAIM\"}"
    exit 0
  fi
  if ! echo "$LAST_MSG" | grep -qi "COMPLETE"; then
    echo "{\"warning\": \"$CALLER exited without COMPLETE or BLOCKED — running verification anyway\"}"
  fi
fi

# Detect quality gates (tests + lint + typecheck)
detect_quality_gates() {
  local gates=""

  if [ -f "package.json" ]; then
    if grep -q '"test"' package.json; then
      if command -v bun &> /dev/null; then
        gates="bun test"
      else
        gates="npm test"
      fi
    fi
    if grep -q '"lint"' package.json; then
      if command -v bun &> /dev/null; then
        gates="${gates:+$gates && }bun run lint"
      else
        gates="${gates:+$gates && }npm run lint"
      fi
    fi
    if grep -q '"typecheck"' package.json; then
      if command -v bun &> /dev/null; then
        gates="${gates:+$gates && }bun run typecheck"
      else
        gates="${gates:+$gates && }npm run typecheck"
      fi
    fi
    if [ -n "$gates" ]; then
      echo "$gates"
      return
    fi
  fi

  if [ -f "Makefile" ] && grep -q "^test:" Makefile; then
    echo "make test"
    return
  fi

  if [ -f "pyproject.toml" ]; then
    if command -v uv &> /dev/null; then
      echo "uv run pytest"
    else
      echo "pytest"
    fi
    return
  fi

  if [ -f "Cargo.toml" ]; then
    echo "cargo test"
    return
  fi

  echo ""
}

TEST_CMD=$(detect_quality_gates)

if [ -z "$TEST_CMD" ]; then
  echo "{\"info\": \"No test command detected — verification skipped\"}"
  exit 0
fi

echo "{\"verification\": \"Running: $TEST_CMD\"}"

# Run tests with 120s timeout
if command -v timeout &> /dev/null; then
  timeout 120 $TEST_CMD
else
  # macOS fallback: use perl for timeout
  perl -e "alarm 120; exec @ARGV" $TEST_CMD
fi

EXIT_CODE=$?

# cmux notification helper
_cmux_notify() {
  if command -v cmux &>/dev/null && [ -n "$CMUX_SOCKET_PATH" ]; then
    cmux notify --title "$1" --subtitle "$2" --body "$3" 2>/dev/null || true
  fi
}

if [ $EXIT_CODE -eq 124 ]; then
  echo "{\"error\": \"Tests timed out after 120 seconds\"}"
  _cmux_notify "$CALLER" "Timeout" "Tests timed out after 120 seconds"
  exit $FAIL_EXIT
elif [ $EXIT_CODE -ne 0 ]; then
  echo "{\"error\": \"Tests failed (exit $EXIT_CODE)\"}"
  _cmux_notify "$CALLER" "Tests Failed" "Verification failed (exit $EXIT_CODE)"
  exit $FAIL_EXIT
fi

echo '{"verification": "Tests passed"}'
_cmux_notify "$CALLER" "Tests Passed" "Verification gate passed"
exit 0
