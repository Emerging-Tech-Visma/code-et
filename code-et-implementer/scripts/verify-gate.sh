#!/bin/bash
# SubagentStop hook — verification gate after background agent
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/run-tests.sh" "Agent" 1
