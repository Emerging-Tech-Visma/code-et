#!/usr/bin/env bash
# audit-summary-line-on-failure.sh — assert the highest-severity finding is
# surfaced as a one-line summary at the top of the report and echoed to stderr
# on failure (US-12 / AC-12.1, AC-12.2).
#
# Two phases:
#   1. Writer-only: pipe synthetic findings into audit-report.sh and inspect
#      the produced file. No cargo / rust toolchain needed.
#   2. Runner: drive audit.sh against a tiny tmp Cargo workspace whose source
#      has a deterministic `cargo fmt --check` violation. Asserts the same
#      summary line surfaces on stderr and matches the report's first line.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRITER="$SCRIPT_DIR/../scripts/audit-report.sh"
AUDIT="$SCRIPT_DIR/../scripts/audit.sh"

# AC-12.1 pattern: literal `[<SEV>]` prefix where SEV is non-LOW, then space,
# then arbitrary content, then ` — fix:` (em-dash, U+2014).
SUMMARY_RE='^\[(CRITICAL|HIGH|MEDIUM)\] .* — fix:'

TMPROOT="$(mktemp -d -t code-et-audit-summary.XXXXXX)"
trap 'rm -rf "$TMPROOT"' EXIT

# ----------------------------------------------------------------------------
# Phase 1: writer — synthetic findings.
# ----------------------------------------------------------------------------

# Case A: HIGH finding present → first line matches the summary pattern.
report_a="$TMPROOT/case-a.md"
printf 'MEDIUM|fmt|src/foo.rs|1|formatting drift\nHIGH|clippy (deny warnings)|src/bar.rs|42|unused variable `x`\n' \
  | bash "$WRITER" "$report_a"

first_a="$(head -n 1 "$report_a")"
if ! [[ "$first_a" =~ $SUMMARY_RE ]]; then
  echo "FAIL (case A): first line did not match summary regex" >&2
  echo "  got: $first_a" >&2
  exit 1
fi
# Should pick HIGH (not MEDIUM): the prefix tag must be HIGH.
if [[ "$first_a" != \[HIGH\]* ]]; then
  echo "FAIL (case A): expected [HIGH] prefix, got: $first_a" >&2
  exit 1
fi

# Case B: LOW-only findings → no summary prefix; report starts with heading.
report_b="$TMPROOT/case-b.md"
printf 'LOW|cargo-machete (unused deps)|Cargo.toml|1|tool not installed\n' \
  | bash "$WRITER" "$report_b"

first_b="$(head -n 1 "$report_b")"
if [[ "$first_b" =~ $SUMMARY_RE ]]; then
  echo "FAIL (case B): LOW-only run produced a summary prefix" >&2
  echo "  got: $first_b" >&2
  exit 1
fi
if [[ "$first_b" != "# code-et audit report" ]]; then
  echo "FAIL (case B): expected '# code-et audit report' as first line, got: $first_b" >&2
  exit 1
fi

# Case C: no findings → no summary prefix; report starts with heading.
report_c="$TMPROOT/case-c.md"
: | bash "$WRITER" "$report_c"
first_c="$(head -n 1 "$report_c")"
if [[ "$first_c" =~ $SUMMARY_RE ]]; then
  echo "FAIL (case C): empty input produced a summary prefix" >&2
  echo "  got: $first_c" >&2
  exit 1
fi
if [[ "$first_c" != "# code-et audit report" ]]; then
  echo "FAIL (case C): expected '# code-et audit report' as first line, got: $first_c" >&2
  exit 1
fi

# Case D: CRITICAL beats HIGH beats MEDIUM in the summary tag.
report_d="$TMPROOT/case-d.md"
printf 'MEDIUM|fmt|src/a.rs|1|m\nHIGH|tests|src/b.rs|2|h\nCRITICAL|cargo-audit (advisories)|Cargo.lock|1|RUSTSEC-XXXX\n' \
  | bash "$WRITER" "$report_d"
first_d="$(head -n 1 "$report_d")"
if [[ "$first_d" != \[CRITICAL\]* ]]; then
  echo "FAIL (case D): expected [CRITICAL] prefix, got: $first_d" >&2
  exit 1
fi

# ----------------------------------------------------------------------------
# Phase 2: runner — drive audit.sh against a tmp workspace with a deterministic
# fmt violation. Skip if `cargo` is not on PATH (keeps the writer phase usable
# on stripped CI images).
# ----------------------------------------------------------------------------

if ! command -v cargo >/dev/null 2>&1; then
  echo "PASS: audit-summary-line-on-failure (writer phase only — cargo missing)"
  exit 0
fi

WS="$TMPROOT/ws"
mkdir -p "$WS/src"
cat > "$WS/Cargo.toml" <<'EOF'
[package]
name = "audit-summary-fixture"
version = "0.0.1"
edition = "2021"

[[bin]]
name = "audit-summary-fixture"
path = "src/main.rs"
EOF
# Single line, no trailing newline guarantees `cargo fmt --check` will flag it.
printf 'fn main(){let x=1;let _=x;}' > "$WS/src/main.rs"

stderr_log="$TMPROOT/audit.stderr"
set +e
bash "$AUDIT" "$WS" 2> "$stderr_log" >/dev/null
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "FAIL (runner): audit.sh exited 0 on a workspace with fmt violation" >&2
  cat "$stderr_log" >&2
  exit 1
fi

# Locate the report file the runner wrote.
report="$(ls "$WS/.claude/audit-"*.md 2>/dev/null | head -n1 || true)"
if [ -z "$report" ] || [ ! -f "$report" ]; then
  echo "FAIL (runner): no audit report written under $WS/.claude/" >&2
  cat "$stderr_log" >&2
  exit 1
fi

first_line="$(head -n 1 "$report")"
if ! [[ "$first_line" =~ $SUMMARY_RE ]]; then
  echo "FAIL (runner): report first line missing summary prefix" >&2
  echo "  got: $first_line" >&2
  exit 1
fi

# AC-12.2: the same summary line must appear on the runner's stderr.
if ! grep -Fq -- "$first_line" "$stderr_log"; then
  echo "FAIL (runner): summary line not echoed to stderr" >&2
  echo "  expected: $first_line" >&2
  echo "  --- stderr ---" >&2
  cat "$stderr_log" >&2
  exit 1
fi

echo "PASS: audit-summary-line-on-failure"
