#!/usr/bin/env bats

# layer-deps-validator.sh — defence-in-depth layer-direction check.

setup() {
  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q
  git config user.email "t@t"
  git config user.name "t"
  git commit --allow-empty -q -m init
  cp "${BATS_TEST_DIRNAME}/../templates/shared/scripts/layer-deps-validator.sh" "$REPO/validator.sh"
  chmod +x "$REPO/validator.sh"
}

teardown() { rm -rf "$REPO"; }

# Helper: write a minimal Cargo.toml under crates/<layer>/ with a dependency block.
# Args: layer, deps...
make_crate() {
  local layer="$1"; shift
  mkdir -p "crates/$layer"
  {
    echo "[package]"
    echo "name = \"$layer\""
    echo "version = \"0.1.0\""
    echo "edition = \"2024\""
    echo
    echo "[dependencies]"
    for dep in "$@"; do
      if [ -d "crates/$dep" ]; then
        echo "$dep = { path = \"../$dep\" }"
      else
        echo "$dep = \"1\""
      fi
    done
  } > "crates/$layer/Cargo.toml"
}

@test "clean: domain has no workspace deps" {
  make_crate domain serde
  make_crate application domain async-trait
  make_crate infrastructure application domain sqlx
  make_crate interface application domain dioxus
  run bash validator.sh
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "clean"
}

@test "violation: domain depends on infrastructure" {
  make_crate infrastructure
  make_crate domain infrastructure serde
  make_crate application domain
  make_crate interface application domain
  run bash validator.sh
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "layer violation"
}

@test "violation: application depends on infrastructure" {
  make_crate domain serde
  make_crate infrastructure
  make_crate application domain infrastructure async-trait
  make_crate interface application domain
  run bash validator.sh
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "layer violation"
}

@test "violation: interface depends on infrastructure" {
  make_crate domain serde
  make_crate application domain
  make_crate infrastructure application domain
  make_crate interface application domain infrastructure dioxus
  run bash validator.sh
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "layer violation"
}

@test "no-op: project without crates/ directory" {
  # Simulating a non-clean-architecture Rust project (e.g. a single-crate cargo new)
  echo '[workspace]' > Cargo.toml
  run bash validator.sh
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "clean"
}

@test "third-party deps don't count as layer violations" {
  make_crate domain serde uuid time thiserror
  run bash validator.sh
  [ "$status" -eq 0 ]
}
