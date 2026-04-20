#!/usr/bin/env bats

setup() {
  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q
  git config user.email "t@t"
  git config user.name "t"
  git commit --allow-empty -q -m init
  git checkout -q -b main 2>/dev/null || true
  mkdir -p plans
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/session-start-prd.sh"
}

teardown() { rm -rf "$REPO"; }

@test "no PRD: emits empty JSON, exits 0" {
  git checkout -q -b feature/no-prd
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == "{}" ]]
}

@test "PRD found: emits context JSON with path and open stories" {
  cat > plans/2026-04-20-dark-mode.md <<'EOF'
# Dark Mode

- [ ] US-1: toggle component
- [x] US-2: persist preference
- [ ] US-3: system theme detection
EOF
  git checkout -q -b feature/dark-mode
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Active PRD:"* ]]
  [[ "$output" == *"plans/2026-04-20-dark-mode.md"* ]]
  [[ "$output" == *"US-1"* ]]
  [[ "$output" == *"US-3"* ]]
}

@test "PRD with no open stories: still emits context with (none)" {
  cat > plans/2026-04-20-done.md <<'EOF'
# Done

- [x] US-1: thing
EOF
  git checkout -q -b feature/done
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Active PRD:"* ]]
  [[ "$output" == *"(none)"* ]]
}
