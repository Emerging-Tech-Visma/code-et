#!/usr/bin/env bash
# TaskCreated hook: enforce user_story tag on branches with an active PRD.
# Exit 0 = allow, exit 2 = block (per Claude Code hook contract).

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
payload="$(cat)"

prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"

# metadata may arrive as an object OR as a JSON-encoded string (harness quirk).
md="$(printf '%s' "$payload" | jq -c '(.tool_input.metadata // {}) | if type=="string" then (fromjson? // {}) else . end' 2>/dev/null || echo '{}')"
tag="$(printf '%s' "$md" | jq -r '.user_story // ""' 2>/dev/null || echo '')"
layer="$(printf '%s' "$md" | jq -r '.layer // ""' 2>/dev/null || echo '')"

if [ -z "$prd" ]; then
  # Bug lane — anything goes
  exit 0
fi

tag_ok=0
if [[ "$tag" =~ ^US-[0-9]+$ ]] \
   || [[ "$tag" =~ ^AC-[0-9]+\.[0-9]+$ ]] \
   || [[ "$tag" =~ ^chore:.+ ]]; then
  tag_ok=1
fi

# layer is required only when the project is Rust (Cargo.toml at repo root).
layer_required=0
if git rev-parse --show-toplevel &>/dev/null; then
  root="$(git rev-parse --show-toplevel)"
  [ -f "$root/Cargo.toml" ] && layer_required=1
fi

layer_ok=1
if [ "$layer_required" -eq 1 ]; then
  case "$layer" in
    domain|application|infrastructure|interface|chore) layer_ok=1 ;;
    *) layer_ok=0 ;;
  esac
fi

if [ "$tag_ok" -eq 1 ] && [ "$layer_ok" -eq 1 ]; then
  exit 0
fi

cat >&2 <<EOF
Task rejected: required metadata is missing or invalid.

Active PRD: $prd

metadata.user_story — required: "US-<N>" | "AC-<N>.<M>" | "chore:<reason>"
EOF
if [ "$layer_required" -eq 1 ]; then
  cat >&2 <<EOF
metadata.layer — required on Rust projects: "domain" | "application" | "infrastructure" | "interface" | "chore"
                See code-et-implementer/docs/architecture.md §"Layer model".
EOF
fi
exit 2
