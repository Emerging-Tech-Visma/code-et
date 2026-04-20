#!/usr/bin/env bash
# TaskCreated hook: enforce user_story tag on branches with an active PRD.
# Exit 0 = allow, exit 2 = block (per Claude Code hook contract).

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
payload="$(cat)"

prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"

tag="$(printf '%s' "$payload" | jq -r '.tool_input.metadata.user_story // ""' 2>/dev/null || echo '')"

if [ -z "$prd" ]; then
  # Bug lane — anything goes
  exit 0
fi

if [[ "$tag" =~ ^US-[0-9]+$ ]] \
   || [[ "$tag" =~ ^AC-[0-9]+\.[0-9]+$ ]] \
   || [[ "$tag" =~ ^chore:.+ ]]; then
  exit 0
fi

cat >&2 <<EOF
Task rejected: metadata.user_story is missing or invalid.

Active PRD: $prd
Required format: "US-<N>" | "AC-<N>.<M>" | "chore:<reason>"

Open the PRD, pick the story this task serves, and add it to metadata.user_story.
EOF
exit 2
