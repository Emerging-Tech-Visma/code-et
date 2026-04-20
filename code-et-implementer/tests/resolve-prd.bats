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
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/resolve-prd.sh"
}

teardown() { rm -rf "$REPO"; }

@test "returns matching PRD for feature/<slug>" {
  touch "plans/2026-04-20-dark-mode.md"
  git checkout -q -b feature/dark-mode
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plans/2026-04-20-dark-mode.md" ]]
}

@test "strips fix/ prefix" {
  touch "plans/2026-04-20-login-bug.md"
  git checkout -q -b fix/login-bug
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plans/2026-04-20-login-bug.md" ]]
}

@test "strips chore/ prefix" {
  touch "plans/2026-04-20-deps-bump.md"
  git checkout -q -b chore/deps-bump
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plans/2026-04-20-deps-bump.md" ]]
}

@test "picks most recent when multiple dates exist" {
  touch "plans/2026-01-01-dark-mode.md"
  touch "plans/2026-04-20-dark-mode.md"
  git checkout -q -b feature/dark-mode
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-04-20-dark-mode.md" ]]
}

@test "exits 1 with empty output when no PRD matches" {
  git checkout -q -b feature/unknown
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "accepts branch name as arg 1" {
  touch "plans/2026-04-20-dark-mode.md"
  run "$SCRIPT" "feature/dark-mode"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-04-20-dark-mode.md" ]]
}

@test "ignores non-dated plan files (legacy)" {
  touch "plans/cheeky-wibbling-puddle.md"
  git checkout -q -b feature/cheeky-wibbling-puddle
  run "$SCRIPT"
  [ "$status" -eq 1 ]
}
