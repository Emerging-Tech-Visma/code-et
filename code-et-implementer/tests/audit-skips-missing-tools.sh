#!/usr/bin/env bash
# audit-skips-missing-tools.sh — assert audit.sh degrades gracefully when
# optional toolchain binaries (and the layer-deps validator script) are
# missing on a fresh dev machine (US-9, AC-9.1, AC-9.2).
#
# Strategy: build a minimal Rust workspace fixture, then invoke audit.sh
# with a sanitised PATH that contains only a stub `cargo` shim and the bare
# Unix utilities. The stub cargo handles `fmt` and `clippy` (noops) but no
# `cargo-machete` / `cargo-audit` / `cargo-deny` / `cargo-nextest` exist on
# PATH, and the workspace ships no `scripts/layer-deps-validator.sh`.
#
# Expected outcome:
#   - exit code 0 (no genuine stage failure)
#   - five LOW findings: machete, audit, deny, layer-deps, nextest
#   - one "WARNING" line per skipped stage on stderr
#   - report contains a `## LOW` section listing each skip

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="$SCRIPT_DIR/../scripts/audit.sh"

TMPDIR_TEST="$(mktemp -d -t code-et-audit-missing.XXXXXX)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

WORKSPACE="$TMPDIR_TEST/workspace"
STUB_BIN="$TMPDIR_TEST/bin"
mkdir -p "$WORKSPACE" "$STUB_BIN"

# Minimal empty Rust workspace — enough for find_workspace_root to accept it.
cat > "$WORKSPACE/Cargo.toml" <<'EOF'
[workspace]
members = []
resolver = "2"
EOF

# Stub `cargo` — handles fmt/clippy as noops, refuses unknown subcommands the
# way real cargo does so audit.sh's stage_runnable probe (which checks for
# `cargo-<sub>` on PATH) still rejects them.
cat > "$STUB_BIN/cargo" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  fmt|clippy) exit 0 ;;
  *)
    echo "error: no such subcommand: \`$1\`" >&2
    exit 101
    ;;
esac
EOF
chmod +x "$STUB_BIN/cargo"

STDERR_LOG="$TMPDIR_TEST/stderr.log"

set +e
PATH="$STUB_BIN:/usr/bin:/bin" bash "$AUDIT" "$WORKSPACE" 2> "$STDERR_LOG"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  echo "FAIL: audit.sh exited $rc with all optional tools missing; expected 0" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

# Locate the freshly-written report. There should be exactly one.
REPORT="$(ls "$WORKSPACE/.claude/audit-"*.md 2>/dev/null | head -n1 || true)"
if [ -z "$REPORT" ]; then
  echo "FAIL: no audit report written" >&2
  cat "$STDERR_LOG" >&2
  exit 1
fi

# AC-9.1: a WARNING line on stderr for each missing tool/script.
expected_warnings=(
  "cargo-machete (unused deps)"
  "cargo-audit (advisories)"
  "cargo-deny (license + bans + sources + advisories)"
  "layer-deps validator"
  "tests"
)
for stage in "${expected_warnings[@]}"; do
  if ! grep -qF "WARNING: $stage" "$STDERR_LOG"; then
    echo "FAIL: missing WARNING line for stage '$stage' on stderr" >&2
    cat "$STDERR_LOG" >&2
    exit 1
  fi
done

# AC-9.2: each skip is recorded in the report under the LOW group.
if ! grep -q '^## LOW' "$REPORT"; then
  echo "FAIL: report has no LOW severity section" >&2
  cat "$REPORT" >&2
  exit 1
fi

expected_paths=(
  "cargo-machete"
  "cargo-audit"
  "cargo-deny"
  "scripts/layer-deps-validator.sh"
  "cargo-nextest"
)
for path in "${expected_paths[@]}"; do
  if ! grep -qF "\`$path:1\`" "$REPORT"; then
    echo "FAIL: report missing LOW finding with path '$path:1'" >&2
    cat "$REPORT" >&2
    exit 1
  fi
done

# Sanity: every LOW finding line carries the install/remediation hint stem.
low_lines="$(awk '/^## LOW/{flag=1; next} /^## /{flag=0} flag && /^- /' "$REPORT")"
low_count="$(printf '%s\n' "$low_lines" | grep -c '^- ' || true)"
if [ "$low_count" -ne 5 ]; then
  echo "FAIL: expected 5 LOW findings, got $low_count" >&2
  cat "$REPORT" >&2
  exit 1
fi

# Bracket: no CRITICAL/HIGH/MEDIUM sections — only skips, no real failures.
for sev in CRITICAL HIGH MEDIUM; do
  if grep -q "^## $sev" "$REPORT"; then
    echo "FAIL: report has unexpected $sev section" >&2
    cat "$REPORT" >&2
    exit 1
  fi
done

echo "PASS: audit-skips-missing-tools ($low_count LOW findings, exit 0)"
