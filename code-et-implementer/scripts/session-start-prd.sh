#!/usr/bin/env bash
# SessionStart hook: inject 3-line PRD pointer when a PRD matches current branch.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"

if [ -z "$prd" ]; then
  echo '{}'
  exit 0
fi

open_stories="$(grep -oE '^\- \[ \] US-[0-9]+' "$prd" 2>/dev/null | sed -E 's/^- \[ \] //' | paste -sd, - | sed 's/,/, /g' || true)"
[ -z "$open_stories" ] && open_stories="(none)"

payload="Active PRD: $prd
Open: $open_stories
Read the PRD before planning or implementing."

body_json="$(printf '%s' "$payload" | jq -Rs .)"
printf '{"context": %s}\n' "$body_json"
