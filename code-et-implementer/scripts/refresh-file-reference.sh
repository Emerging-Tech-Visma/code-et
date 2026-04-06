#!/bin/bash
# FileChanged hook — flag FILE-REFERENCE.md as stale when project structure changes
# Triggered on changes to route/page files, new directories under apps/packages/src

HOOK_INPUT=""
if [ ! -t 0 ]; then
  HOOK_INPUT=$(cat)
fi

FILE_PATH=""
if [ -n "$HOOK_INPUT" ] && command -v jq &>/dev/null; then
  FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.file_path // empty' 2>/dev/null)
fi

[ -z "$FILE_PATH" ] && exit 0

# Only care about structural changes (new pages, routes, directories)
case "$FILE_PATH" in
  */page.tsx|*/page.ts|*/route.tsx|*/route.ts|*/index.tsx|*/index.ts|*/layout.tsx|*/layout.ts)
    ;;
  *)
    exit 0
    ;;
esac

# Check if FILE-REFERENCE.md exists in the project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REF_FILE="$PROJECT_ROOT/FILE-REFERENCE.md"

[ ! -f "$REF_FILE" ] && exit 0

# Notify that FILE-REFERENCE.md may be stale
if command -v cmux &>/dev/null && [ -n "$CMUX_SOCKET_PATH" ]; then
  cmux notify --title "FILE-REFERENCE.md" --subtitle "May be stale" --body "Run /code:go update to refresh" 2>/dev/null || true
fi

echo "{\"info\": \"FILE-REFERENCE.md may be stale after change to $FILE_PATH. Run /code:go update to refresh.\"}"
exit 0
