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

# Check if agent reported BLOCKED — skip tests
if [ -n "$HOOK_INPUT" ]; then
  LAST_MSG=$(echo "$HOOK_INPUT" | grep -o '"last_assistant_message":"[^"]*"' | head -1 | sed 's/"last_assistant_message":"//;s/"$//')
  if echo "$LAST_MSG" | grep -qi "BLOCKED:"; then
    echo "{\"info\": \"$CALLER reported BLOCKED — skipping verification\", \"claim\": \"$LAST_MSG\"}"
    exit 0
  fi
fi

# Detect test command
detect_test_cmd() {
  if [ -f "package.json" ]; then
    if grep -q '"test"' package.json; then
      if command -v bun &> /dev/null; then
        echo "bun test"
      else
        echo "npm test"
      fi
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

TEST_CMD=$(detect_test_cmd)

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

if [ $EXIT_CODE -eq 124 ]; then
  echo "{\"error\": \"Tests timed out after 120 seconds\"}"
  exit $FAIL_EXIT
elif [ $EXIT_CODE -ne 0 ]; then
  echo "{\"error\": \"Tests failed (exit $EXIT_CODE)\"}"
  exit $FAIL_EXIT
fi

echo '{"verification": "Tests passed"}'
exit 0
