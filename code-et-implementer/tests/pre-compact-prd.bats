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
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/pre-compact-prd.sh"
}

teardown() { rm -rf "$REPO"; }

@test "no PRD: emits empty JSON" {
  git checkout -q -b feature/nothing
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "PRD with few open stories includes all" {
  {
    echo "# Plan"
    for i in 1 2 3; do echo "- [ ] US-$i: thing $i"; done
    echo "- [x] US-99: done"
  } > plans/2026-04-20-x.md
  git checkout -q -b feature/x
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"US-1"* ]]
  [[ "$output" == *"US-2"* ]]
  [[ "$output" == *"US-3"* ]]
  [[ "$output" != *"US-99"* ]]
}

@test "PRD with many open stories emits summary" {
  {
    echo "# Plan"
    for i in $(seq 1 25); do echo "- [ ] US-$i: thing $i"; done
  } > plans/2026-04-20-big.md
  git checkout -q -b feature/big
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"25 open stories"* ]]
  [[ "$output" == *"plans/2026-04-20-big.md"* ]]
}
