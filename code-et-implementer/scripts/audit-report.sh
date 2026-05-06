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
# When any non-LOW finding is present, the report is prepended with a single
# summary line of the form (US-12 / AC-12.1):
#   [<SEVERITY>] <stage>: <message-head> — fix: <hint>
# LOW-only and empty inputs do NOT trigger a summary prefix.
#
# Note: the upstream message field may contain escaped pipes (`\|`) since
# audit.sh strips literal `|` before emission. We truncate the message to keep
# the summary line short, so this is cosmetic.
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
    printf -- '- **%s** (%s) — %s — `%s:%s`\n' "$severity" "$stage" "$message" "$path" "$line"
  done <<< "$lines"
  printf '\n'
}

# Stage-specific remediation hint. Closed set per the v3.9.0 gate; unknown
# stages fall back to a generic pointer.
remediation_for() {
  case "$1" in
    "fmt") echo "run \`cargo fmt --all\`" ;;
    "clippy (deny warnings)") echo "address the warning or allow it explicitly" ;;
    "layer-deps validator") echo "remove the disallowed cross-layer import" ;;
    "cargo-machete (unused deps)") echo "drop the unused dependency from Cargo.toml" ;;
    "cargo-audit (advisories)") echo "upgrade the affected crate or pin an advisory exception" ;;
    "cargo-deny (license + bans + sources + advisories)") echo "review deny.toml and update the offending dependency" ;;
    "tests") echo "fix the failing test(s) shown above" ;;
    *) echo "see report for details" ;;
  esac
}

# Compose the one-line summary from the highest-severity finding present.
# Echoes the line on stdout; emits nothing when only LOW (or no) findings.
summary_line() {
  local sev stage path line message hint head
  for sev in CRITICAL HIGH MEDIUM; do
    IFS='|' read -r _severity stage path line message \
      < <(filter_severity "$sev" | head -n 1) || true
    if [ -n "${stage:-}" ]; then
      hint="$(remediation_for "$stage")"
      # Trim the message to its first 80 chars so the summary stays compact.
      head="$message"
      if [ "${#head}" -gt 80 ]; then
        head="${head:0:77}..."
      fi
      printf '[%s] %s: %s — fix: %s\n' "$sev" "$stage" "$head" "$hint"
      return 0
    fi
  done
  return 0
}

SUMMARY="$(summary_line)"

{
  if [ -n "$SUMMARY" ]; then
    printf '%s\n\n' "$SUMMARY"
  fi

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
