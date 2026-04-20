#!/usr/bin/env bash
# PreCompact hook: inject PRD open-stories summary before Claude compacts.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"

if [ -z "$prd" ]; then
  echo '{}'
  exit 0
fi

open_count="$(grep -cE '^\- \[ \] US-' "$prd" 2>/dev/null || true)"
open_count="${open_count:-0}"

if [ "$open_count" -gt 20 ]; then
  body="Active PRD: $prd
${open_count} open stories. Read the PRD for full list."
else
  lines="$(grep -E '^\- \[ \] US-' "$prd" 2>/dev/null || true)"
  body="Active PRD: $prd
Open stories:
${lines}"
fi

body_json="$(printf '%s' "$body" | jq -Rs .)"
printf '{"context": %s}\n' "$body_json"
