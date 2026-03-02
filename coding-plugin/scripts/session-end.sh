#!/bin/bash
# Clean up session - warn about uncommitted changes
# Called on SessionEnd hook

# Check for uncommitted changes
if git status --porcelain 2>/dev/null | grep -q .; then
  echo '{"warning": "Uncommitted changes detected - consider committing before ending"}'
fi

exit 0
