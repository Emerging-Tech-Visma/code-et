#!/usr/bin/env bats

# Verify the doctrine files exist with expected structure. Smoke test —
# guards against accidental deletion or stripped frontmatter.

DOCS="${BATS_TEST_DIRNAME}/../docs"

@test "architecture.md exists" {
  [ -f "$DOCS/architecture.md" ]
}

@test "architecture.md has frontmatter" {
  head -1 "$DOCS/architecture.md" | grep -q '^---$'
  grep -q '^name: architecture' "$DOCS/architecture.md"
}

@test "architecture.md contains Uncle Bob excerpt" {
  grep -q "The Dependency Rule" "$DOCS/architecture.md"
  grep -q "source code dependencies" "$DOCS/architecture.md"
}

@test "architecture.md describes the four layers" {
  grep -q "domain" "$DOCS/architecture.md"
  grep -q "application" "$DOCS/architecture.md"
  grep -q "infrastructure" "$DOCS/architecture.md"
  grep -q "interface" "$DOCS/architecture.md"
}

@test "architecture.md has Dioxus targets matrix" {
  grep -q "Dioxus" "$DOCS/architecture.md"
  grep -q "web" "$DOCS/architecture.md"
  grep -q "desktop" "$DOCS/architecture.md"
  grep -q "mobile" "$DOCS/architecture.md"
}

@test "architecture.md has database section with GCP and SQLite" {
  grep -q "Cloud SQL" "$DOCS/architecture.md"
  grep -q "SQLite" "$DOCS/architecture.md"
  grep -q "sqlx" "$DOCS/architecture.md"
}

@test "architecture.md has secrets baseline" {
  grep -q "Secret Manager" "$DOCS/architecture.md"
  grep -qi "secrecy" "$DOCS/architecture.md"
}

@test "architecture.md has Rust security checklist" {
  grep -qi "security checklist" "$DOCS/architecture.md"
  grep -q "unsafe" "$DOCS/architecture.md"
  grep -q "cargo audit" "$DOCS/architecture.md"
}

@test "anti-slop.md exists with frontmatter" {
  [ -f "$DOCS/anti-slop.md" ]
  head -1 "$DOCS/anti-slop.md" | grep -q '^---$'
  grep -q '^name: anti-slop' "$DOCS/anti-slop.md"
}

@test "anti-slop.md has the 4 elements" {
  grep -q "dead code" "$DOCS/anti-slop.md"
  grep -q "[Dd]uplication" "$DOCS/anti-slop.md"
  grep -q "[Cc]omplexity" "$DOCS/anti-slop.md"
  grep -q "[Aa]rchitecture drift" "$DOCS/anti-slop.md"
}

@test "anti-slop.md has 5 slop categories" {
  grep -q "Superficial Competence" "$DOCS/anti-slop.md"
  grep -q "Unnecessary Complexity" "$DOCS/anti-slop.md"
  grep -q "Defensive Over-Programming" "$DOCS/anti-slop.md"
  grep -q "Mirror Tests" "$DOCS/anti-slop.md"
  grep -q "Inconsistent Styling" "$DOCS/anti-slop.md"
}

@test "anti-slop.md has the 4-stage CI loop" {
  grep -q "Static validation" "$DOCS/anti-slop.md"
  grep -q "Architectural check" "$DOCS/anti-slop.md"
  grep -q "Dependency audit" "$DOCS/anti-slop.md"
  grep -qi "complexity.*duplication\|complexity & duplication" "$DOCS/anti-slop.md"
}

@test "anti-slop.md has Rule of Three" {
  grep -q "Rule of Three" "$DOCS/anti-slop.md"
}

@test "testing.md exists with frontmatter" {
  [ -f "$DOCS/testing.md" ]
  head -1 "$DOCS/testing.md" | grep -q '^---$'
  grep -q '^name: testing' "$DOCS/testing.md"
}

@test "testing.md has per-layer matrix" {
  grep -q "domain" "$DOCS/testing.md"
  grep -q "application" "$DOCS/testing.md"
  grep -q "infrastructure" "$DOCS/testing.md"
  grep -q "interface" "$DOCS/testing.md"
}

@test "testing.md bans mirror tests" {
  grep -qi "mirror.*test" "$DOCS/testing.md"
  grep -qi "ban\|banned" "$DOCS/testing.md"
}

@test "testing.md uses cargo-nextest" {
  grep -q "cargo.nextest\|cargo-nextest" "$DOCS/testing.md"
}

@test "testing.md cross-links to engineering testing-strategy skill" {
  grep -q "testing-strategy" "$DOCS/testing.md"
}

@test "CLAUDE.md has Clean Architecture (Rust) controlling rules section" {
  grep -q "Clean Architecture (Rust)" "${BATS_TEST_DIRNAME}/../CLAUDE.md"
  grep -q "controlling rules" "${BATS_TEST_DIRNAME}/../CLAUDE.md"
}

@test "CLAUDE.md no longer contains stale bun test example" {
  ! grep -q "bun test && bun run lint" "${BATS_TEST_DIRNAME}/../CLAUDE.md"
}

@test "CLAUDE.md uses Rust verification example" {
  grep -q "cargo nextest run" "${BATS_TEST_DIRNAME}/../CLAUDE.md"
  grep -q "cargo clippy" "${BATS_TEST_DIRNAME}/../CLAUDE.md"
}

@test "CLAUDE.md names the engineering plugin and rust-analyzer-lsp" {
  grep -qi "engineering" "${BATS_TEST_DIRNAME}/../CLAUDE.md"
  grep -q "rust-analyzer-lsp" "${BATS_TEST_DIRNAME}/../CLAUDE.md"
}
