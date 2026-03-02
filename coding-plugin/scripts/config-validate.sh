#!/bin/bash
# ConfigChange hook — validate settings.json has required fields
# Warns if critical plugin settings are missing after user edits

SETTINGS_FILE=".claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{"warning": "No .claude/settings.json found — plugin settings may not apply"}'
  exit 0
fi

WARNINGS=""

# Check plansDirectory
if ! grep -q '"plansDirectory"' "$SETTINGS_FILE"; then
  WARNINGS="${WARNINGS}Missing plansDirectory (plans won't be saved to plans/ folder). "
fi

# Check CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
if ! grep -q 'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE' "$SETTINGS_FILE"; then
  WARNINGS="${WARNINGS}Missing CLAUDE_AUTOCOMPACT_PCT_OVERRIDE (long sessions may hit context limits). "
fi

if [ -n "$WARNINGS" ]; then
  echo "{\"warning\": \"Settings validation: ${WARNINGS}These ship with the plugin defaults but may have been removed.\"}"
fi

exit 0
