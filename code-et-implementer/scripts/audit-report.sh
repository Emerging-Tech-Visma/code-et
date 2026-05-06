#!/usr/bin/env bash
# audit-report.sh — write a markdown audit report from findings on stdin.
#
# Findings format (one per line, pipe-delimited):
#   <severity>|<stage>|<path>|<line>|<message>
#
# severity ∈ { CRITICAL, HIGH, MEDIUM, LOW }.
#
# Usage: audit-report.sh <report-path>
# stdin: zero or more finding lines.
# Writes <report-path> with findings grouped by severity (CRITICAL > HIGH >
# MEDIUM > LOW); within a group, original input order is preserved.
#
# Empty input → a "no findings" report; the caller still gets a written file
# (AC-7.1: every audit run writes a report).

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: audit-report.sh <report-path>" >&2
  exit 2
fi

REPORT_PATH="$1"
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
    printf '- **%s** (%s) — %s — `%s:%s`\n' "$severity" "$stage" "$message" "$path" "$line"
  done <<< "$lines"
  printf '\n'
}

{
  printf '# code-et audit report\n\n'
  printf '_Generated: %s UTC_\n\n' "$(date -u '+%Y-%m-%d %H:%M:%S')"

  if [ -z "$INPUT" ]; then
    printf 'All stages passed — no findings.\n'
  else
    emit_group "CRITICAL" "CRITICAL"
    emit_group "HIGH"     "HIGH"
    emit_group "MEDIUM"   "MEDIUM"
    emit_group "LOW"      "LOW"
  fi
} > "$REPORT_PATH"
