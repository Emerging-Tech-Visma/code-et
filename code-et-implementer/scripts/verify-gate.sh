#!/bin/bash
# SubagentStop hook — verification gate after implementer
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/run-tests.sh" "Implementer" 1
