#!/usr/bin/env bash
# audit-report.sh — write a markdown audit report from findings on stdin.
#
# Findings format (one per line, pipe-delimited):
#   <severity>|<stage>|<path>|<line>|<message>
#
# severity ∈ { CRITICAL, HIGH, MEDIUM, LOW }.
#
# Usage: audit-report.sh <report-path> [--review-file <diff-path>]
# stdin: zero or more finding lines.
# Writes <report-path> with findings grouped by severity (CRITICAL > HIGH >
# MEDIUM > LOW); within a group, original input order is preserved.
#
# When --review-file is supplied (US-5), appends a "## Review" section under
# the static findings. The file's contents (a captured `git diff`) are queued
# for consumption by the engineering plugin's code-review skill — this writer
# does not invoke the skill itself.
#
# Empty input → a "no findings" report; the caller still gets a written file
# (AC-7.1: every audit run writes a report).

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: audit-report.sh <report-path> [--review-file <diff-path>]" >&2
  exit 2
fi

REPORT_PATH="$1"
shift
REVIEW_FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --review-file)
      shift
      REVIEW_FILE="${1:-}"
      [ -z "$REVIEW_FILE" ] && { echo "audit-report.sh: --review-file requires a path" >&2; exit 2; }
      shift
      ;;
    *)
      echo "audit-report.sh: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

mkdir -p "$(dirname "$REPORT_PATH")"

INPUT="$(cat)"

# Group lines by severity, preserving input order within each group.
filter_severity() {
  local sev="$1"
  printf '%s\n' "$INPUT" | awk -F'|' -v sev="$sev" '$1 == sev { print }'
}

emit_group() {
  local sev="$1" header="$2" lines
  lines="$(filter_severity "$sev")"
  if [ -z "$lines" ]; then return; fi
  printf '## %s\n\n' "$header"
  while IFS='|' read -r severity stage path line message; do
    [ -z "$severity" ] && continue
    printf -- '- **%s** (%s) — %s — `%s:%s`\n' "$severity" "$stage" "$message" "$path" "$line"
  done <<< "$lines"
  printf '\n'
}

emit_review() {
  [ -z "$REVIEW_FILE" ] && return
  printf '## Review\n\n'
  printf '_Diff queued for the engineering plugin'\''s code-review skill._\n\n'
  if [ -s "$REVIEW_FILE" ]; then
    printf '```diff\n'
    cat "$REVIEW_FILE"
    printf '\n```\n\n'
  else
    printf '_No diff captured — branch matches its merge base._\n\n'
  fi
}

{
  printf '# code-et audit report\n\n'
  printf '_Generated: %s UTC_\n\n' "$(date -u '+%Y-%m-%d %H:%M:%S')"

  if [ -z "$INPUT" ]; then
    printf 'All stages passed — no findings.\n\n'
  else
    emit_group "CRITICAL" "CRITICAL"
    emit_group "HIGH"     "HIGH"
    emit_group "MEDIUM"   "MEDIUM"
    emit_group "LOW"      "LOW"
  fi

  emit_review
} > "$REPORT_PATH"
