#!/usr/bin/env bash
# PreToolUse(TaskCreate) hook: enforce user_story tag (and layer on Rust)
# on branches with an active PRD. Runs *before* the task is created so we
# reject the call instead of orphaning a malformed task.
#
# Pre-v4.2.3 this ran on the `TaskCreated` lifecycle event, which delivers
# a flat post-hoc payload (task_id, task_subject, task_description) with
# no `metadata` field — so well-formed calls were uniformly rejected. The
# `tool_input.metadata` payload only exists on the tool-call envelope
# (PermissionRequest / PreToolUse), not the lifecycle event.
#
# Exit 0 = allow, exit 2 = block (per Claude Code hook contract).

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
payload="$(cat)"

prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"

# Metadata location is harness-dependent. We try, in order:
#   1. tool_input.metadata  (object or JSON-encoded string)
#   2. tool_input           (fields may be flattened at top level of tool_input)
#   3. .metadata            (no tool_input wrapper)
#   4. whole payload as string → parse → recurse
#   5. deep search for user_story / layer keys anywhere in the tree
# Whatever shape arrives, well-formed metadata gets extracted.
extract() {
  # $1 = jq expr that produces the candidate metadata node
  printf '%s' "$payload" | jq -c "
    def norm(\$x): if (\$x|type)==\"string\" then (\$x|fromjson? // {}) elif (\$x|type)==\"object\" then \$x else {} end;
    norm($1)
  " 2>/dev/null
}

read_field() {
  # $1 = field name; tries each candidate metadata location in turn.
  local field="$1" val=""
  for expr in \
    '.tool_input.metadata' \
    '.tool_input' \
    '.metadata' \
    '(. | if type=="string" then (fromjson? // {}) else {} end)' \
    '(.tool_input | if type=="string" then (fromjson? // {}) else {} end)'
  do
    val="$(extract "$expr" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null || echo '')"
    [ -n "$val" ] && [ "$val" != "null" ] && { printf '%s' "$val"; return; }
  done
  # Last resort: deep search anywhere in the JSON tree.
  val="$(printf '%s' "$payload" | jq -r --arg f "$field" '
    [.. | objects | select(has($f)) | .[$f]]
    | map(select(type=="string" and length > 0))
    | first // empty
  ' 2>/dev/null || echo '')"
  [ "$val" = "null" ] && val=""
  printf '%s' "$val"
}

tag="$(read_field user_story)"
layer="$(read_field layer)"

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

# Diagnostic: dump the raw payload + what we extracted, so the failure mode is
# legible without needing to wrap the hook. Newest dump wins; previous is kept
# as .prev.json for one cycle.
debug_dir="${TMPDIR:-/tmp}/code-et-task-hook"
mkdir -p "$debug_dir" 2>/dev/null || true
if [ -f "$debug_dir/last-rejected.json" ]; then
  mv -f "$debug_dir/last-rejected.json" "$debug_dir/last-rejected.prev.json" 2>/dev/null || true
fi
payload_json="$(printf '%s' "$payload" | jq -c . 2>/dev/null || printf '%s' "$payload" | jq -Rs .)"
{
  printf '{"ts":"%s","extracted":{"user_story":%s,"layer":%s},"payload":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$(printf '%s' "$tag" | jq -Rs .)" \
    "$(printf '%s' "$layer" | jq -Rs .)" \
    "$payload_json"
} > "$debug_dir/last-rejected.json" 2>/dev/null || true

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
cat >&2 <<EOF

Raw payload + extraction trace: $debug_dir/last-rejected.json
EOF
exit 2
