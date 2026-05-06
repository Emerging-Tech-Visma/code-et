#!/usr/bin/env bash
# layer-deps-validator.sh — code-et Clean Architecture defence-in-depth check.
# The cargo build is the primary gate; this script makes the violation message
# explicit when a [dependencies] section drifts in CI.
#
# Layer rules (inward dependency only):
#   domain         → (no workspace deps)
#   application    → domain
#   infrastructure → application, domain
#   interface      → application, domain   (NOT infrastructure)
#   apps/*         → may depend on any crate (composition root)
#
# Usage: bash scripts/layer-deps-validator.sh
# Exits 0 on clean, 1 on violations. Prints offending crate + dep on stderr.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

declare -A ALLOWED
ALLOWED[domain]=""
ALLOWED[application]="domain"
ALLOWED[infrastructure]="application domain"
ALLOWED[interface]="application domain"

violations=0

check_crate() {
  local layer="$1" cargo="$2"
  local allowed="${ALLOWED[$layer]:-}"
  # Extract workspace-member dep names from [dependencies] / [dev-dependencies] only.
  # A workspace dep looks like:  name = { path = "../other" }   or   name.workspace = true
  while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    # accept the layer's own crate name (rare; sub-modules)
    [ "$dep" = "$layer" ] && continue
    if ! echo " $allowed " | grep -q " $dep "; then
      # Only flag if the dep is itself a workspace crate (lives under crates/)
      if [ -d "crates/$dep" ]; then
        echo "::error file=$cargo::layer violation: crates/$layer must not depend on crates/$dep" >&2
        violations=$((violations + 1))
      fi
    fi
  done < <(awk '
    /^\[dependencies\]|^\[dev-dependencies\]/ { in_deps=1; next }
    /^\[/ { in_deps=0; next }
    in_deps && /^[a-zA-Z0-9_-]+[[:space:]]*=/ {
      sub(/[[:space:]]*=.*/, "", $0); print
    }' "$cargo")
}

for layer in domain application infrastructure interface; do
  cargo="crates/$layer/Cargo.toml"
  [ -f "$cargo" ] || continue
  check_crate "$layer" "$cargo"
done

if [ "$violations" -gt 0 ]; then
  echo "layer-deps-validator: $violations violation(s)" >&2
  exit 1
fi

echo "layer-deps-validator: clean"
