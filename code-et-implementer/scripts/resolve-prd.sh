#!/usr/bin/env bash
# Resolve active PRD for current branch.
# Usage: resolve-prd.sh [branch-name]
# Prints absolute path to plans/YYYY-MM-DD-<slug>.md (most recent) on success.
# Exits 1 with empty stdout when no match.

set -euo pipefail

branch="${1:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')}"
[ -z "$branch" ] && exit 1

# Strip standard prefixes
slug="${branch#feature/}"
slug="${slug#fix/}"
slug="${slug#chore/}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
plans_dir="$repo_root/plans"
[ -d "$plans_dir" ] || exit 1

# Match YYYY-MM-DD-<slug>.md, newest first
match="$(ls -1 "$plans_dir"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-"$slug".md 2>/dev/null | sort -r | head -n1 || true)"

[ -z "$match" ] && exit 1
echo "$match"
