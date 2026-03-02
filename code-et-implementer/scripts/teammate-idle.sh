#!/bin/bash
# TeammateIdle hook — guide idle teammate to pick up next task or exit
# Exit code 2 = send feedback to teammate
echo "Check TaskList for pending tasks with completed blockers. If a pending task exists, claim and implement it. If NO pending tasks remain (all tasks are completed or blocked), exit your session immediately with /exit."
exit 2
