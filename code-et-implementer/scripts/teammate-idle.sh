#!/bin/bash
# TeammateIdle hook — guide idle teammate to pick up next task or exit
# Exit code 2 = send feedback to teammate

if command -v cmux &>/dev/null && [ -n "$CMUX_SOCKET_PATH" ]; then
  cmux notify --title "Teammate Idle" --subtitle "Stalled" --body "An implementer appears stuck — may need intervention" 2>/dev/null || true
fi

echo "Check TaskList for pending tasks with completed blockers. If a pending task exists, claim and implement it. If NO pending tasks remain (all tasks are completed or blocked), exit your session immediately with /exit."
exit 2
