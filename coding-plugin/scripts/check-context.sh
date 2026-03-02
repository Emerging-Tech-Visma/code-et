#!/bin/bash
# Estimates context usage and outputs warnings
# Called on Stop hook

# Heuristic reminder - Claude Code doesn't expose exact context usage
echo '{"reminder": "Long conversation? Consider /clear and resuming with /code:implement"}'

exit 0
