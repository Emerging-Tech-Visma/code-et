#!/usr/bin/env bash
# PostToolUse hook fired after a Bash tool call. Suggests /ultrareview when:
#   - command contains `gh pr create`
#   - a PRD matches the current branch
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
payload="$(cat)"

command="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || echo '')"
case "$command" in
  *"gh pr create"*) ;;
  *) echo '{}'; exit 0 ;;
esac

prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"
[ -z "$prd" ] && { echo '{}'; exit 0; }

pr_url="$(printf '%s' "$payload" | jq -r '.tool_response.output // .tool_response.stdout // ""' 2>/dev/null | grep -oE 'https://github\.com/[^ ]+/pull/[0-9]+' | head -n1 || true)"
pr_num="${pr_url##*/}"
[ -z "$pr_num" ] && pr_num="<PR#>"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo '')"
prd_rel="${prd#"$repo_root"/}"

msg="PRD detected for this branch. Optional: run \`/ultrareview ${pr_num} --context ${prd_rel}\` to review the PR against acceptance criteria."
msg_json="$(printf '%s' "$msg" | jq -Rs .)"
printf '{"context": %s}\n' "$msg_json"
