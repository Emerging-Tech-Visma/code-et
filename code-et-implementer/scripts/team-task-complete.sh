#!/bin/bash
# TaskCompleted hook — verification gate for team mode
# Exit code 2 = reject completion (tests failed, task stays in_progress)
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/run-tests.sh" "Teammate" 2
