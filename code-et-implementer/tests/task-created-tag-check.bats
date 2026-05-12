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
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/task-created-tag-check.sh"
}

teardown() { rm -rf "$REPO"; }

@test "allows US-N tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"US-3\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "allows AC-N.M tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"AC-3.2\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "allows chore:<reason> tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"chore:bump tailwind\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "blocks missing tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "blocks invalid tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"random\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "allows any task when no PRD (bug lane)" {
  git checkout -q -b fix/login-crash
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "allows user_story:none when no PRD" {
  git checkout -q -b fix/login-crash
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"none\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "tolerates stringified metadata when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"tool_input\":{\"metadata\":\"{\\\"user_story\\\":\\\"US-3\\\"}\"}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "tolerates flattened metadata fields on tool_input" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"tool_input\":{\"user_story\":\"US-3\",\"layer\":\"interface\"}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "tolerates metadata at payload root (no tool_input wrapper)" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"metadata\":{\"user_story\":\"AC-1.2\"}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "deep-searches for user_story in nested envelopes" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  run bash -c 'echo "{\"params\":{\"input\":{\"task\":{\"metadata\":{\"user_story\":\"US-7\"}}}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "rejection writes diagnostic dump to debug_dir" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  export TMPDIR="$REPO/tmp"
  mkdir -p "$TMPDIR"
  run bash -c 'echo "{\"tool_input\":{\"metadata\":{\"user_story\":\"bogus\"}}}" | "$0"' "$SCRIPT"
  [ "$status" -eq 2 ]
  [ -f "$TMPDIR/code-et-task-hook/last-rejected.json" ]
  run jq -r '.extracted.user_story' "$TMPDIR/code-et-task-hook/last-rejected.json"
  [ "$output" = "bogus" ]
}
