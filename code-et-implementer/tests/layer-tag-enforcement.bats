#!/usr/bin/env bats

# task-created-tag-check.sh extension: metadata.layer is required on Rust
# projects (Cargo.toml at repo root). Non-Rust projects unchanged.

setup() {
  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q
  git config user.email "t@t"
  git config user.name "t"
  git commit --allow-empty -q -m init
  git checkout -q -b main 2>/dev/null || true
  mkdir -p plans
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/task-created-tag-check.sh"
}

teardown() { rm -rf "$REPO"; }

# --- Rust project (Cargo.toml at root) ---

@test "rust project: allows valid user_story + valid layer" {
  echo '[workspace]' > Cargo.toml
  touch plans/2026-05-06-feature.md
  git checkout -q -b feature/feature
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"US-1\",\"layer\":\"domain\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "rust project: blocks missing layer" {
  echo '[workspace]' > Cargo.toml
  touch plans/2026-05-06-feature.md
  git checkout -q -b feature/feature
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"US-1\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "rust project: blocks invalid layer" {
  echo '[workspace]' > Cargo.toml
  touch plans/2026-05-06-feature.md
  git checkout -q -b feature/feature
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"US-1\",\"layer\":\"god\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "rust project: blocks missing user_story even with valid layer" {
  echo '[workspace]' > Cargo.toml
  touch plans/2026-05-06-feature.md
  git checkout -q -b feature/feature
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"layer\":\"domain\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "rust project: chore layer accepted" {
  echo '[workspace]' > Cargo.toml
  touch plans/2026-05-06-feature.md
  git checkout -q -b feature/feature
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"chore:bump deps\",\"layer\":\"chore\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "rust project: all four production layers accepted" {
  echo '[workspace]' > Cargo.toml
  touch plans/2026-05-06-feature.md
  git checkout -q -b feature/feature
  for layer in domain application infrastructure interface; do
    run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"US-1\",\"layer\":\"'"$layer"'\"}}}" | "$0"' "$SCRIPT"
    [ "$status" -eq 0 ]
  done
}

# --- Non-Rust project (no Cargo.toml) ---

@test "non-rust project: layer is optional" {
  touch plans/2026-05-06-feature.md
  git checkout -q -b feature/feature
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"US-1\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "non-rust project: bug lane still permits anything" {
  git checkout -q -b fix/login-crash
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}
