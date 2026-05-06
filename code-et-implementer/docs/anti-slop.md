---
name: anti-slop
description: Anti-slop framework + 5 slop categories + 4-stage verification loop. The CI gate enforces the deterministic stages; the engineering plugin's code-review skill catches the rest.
applies_to: rust
---

# Anti-Slop (code-et)

AI-generated code accumulates structural debt that file-local linters miss: re-export cascades, orphaned modules, duplicated logic, defensive over-programming, mirror tests, architecture drift. This doctrine codifies what code-et's CI gate enforces and what reviewers catch by hand.

## The 4 elements

### 1. Global dead code & dependency pruning

**Slop:** Functionally extinct code still reachable by the compiler — re-export cascades, orphaned modules, unused crates in `Cargo.toml`.

**How to detect.**
- Unused dependencies: `cargo machete` (fast, manifest-level). For deeper unused-code-path detection: `cargo +nightly udeps --workspace --all-targets`.
- Dead code in source: `cargo clippy --workspace --all-targets -- -D warnings -W dead_code -W unreachable_pub`.

**How to fix.** Delete the dead code in the same PR. Don't leave `// TODO: remove` markers. If a re-export exists for backwards compatibility, gate it behind a `#[deprecated]` attribute with a target removal version.

**Goal:** code relevance, faster builds, fewer attack surfaces.

### 2. Duplication

**Slop:** "Logic spread" — one bug must be fixed in many places. Exact clones (copy-paste) and semantic clones (same logic, renamed variables).

**How to detect.**
- `clippy` catches some patterns (`clippy::clone_on_ref_ptr`, `clippy::needless_collect`, etc.).
- Optional: `jscpd --languages rust --min-tokens 50 --threshold 0` for cross-file copy-paste.

**Rule of Three.** Two duplicates is a coincidence; three is a pattern. **The third occurrence triggers a refactor in the same PR.** Extract a function, a trait, or a shared module.

**How to fix.** Extract. If the duplication is across layers, the extracted helper goes in the *innermost* layer that all callers can reach — usually `domain` (pure logic) or `application` (orchestration helpers).

### 3. Complexity hotspots

**Slop:** High cognitive load — deeply nested `match`, complex lifetime constraints, functions doing five things.

**How to detect.**
- `clippy::cognitive_complexity` (warn at 15 by default in `clippy.toml`; deny at 25). Cognitive complexity is preferred over cyclomatic — it weights nested logic and control-flow breaks more heavily.
- `clippy::cyclomatic_complexity` as a secondary gate.
- Manual: identify "critical hotspots" — files where high complexity intersects high change frequency (`git log --since=3.months --name-only --pretty=format: | sort | uniq -c | sort -rn`). Refactor those first.

**How to fix.** Split the function. Extract the inner `match` arms into named helpers. If lifetimes are tangled, often the underlying problem is a layer violation (a `domain` type holding a `&'_ infrastructure::Foo`); fix the dependency direction first.

### 4. Architecture drift

**Slop:** Divergence from the layered design — circular dependencies, `domain` reaching into `infrastructure`, "convenience" re-exports that paper over a missing abstraction.

**How to detect.**
- **Compiler:** the workspace `Cargo.toml` `[dependencies]` table is the primary gate. Adding a forbidden dep makes `cargo build` fail.
- **CI validator:** `scripts/layer-deps-validator.sh` (30 lines, ships in every project from `/code:bootstrap`) re-asserts the layer rule explicitly.
- **Circular deps:** `cargo` already forbids them at the crate level. Within a crate, large modules can still cycle; if it gets bad, restructure into sub-crates.

**How to fix.** Move the type to the inner layer. Introduce a port (trait) in `application` and implement it in `infrastructure`. Never collapse layers to "make it compile" — that's the slop.

## The 5 slop categories (spotting it in review)

When the CI gate is green but something still feels wrong, look for these patterns. The engineering plugin's `code-review` skill catches most; reviewers catch the rest.

| Category | Looks like | Fix |
|---|---|---|
| **Superficial Competence** | Code that follows common patterns but ignores the specific business rule. Example: a `validate_order` that checks for null and length but not the actual domain invariant. | Re-read the use case. Validation belongs in `application`, framed as "what makes this domain operation valid". |
| **Unnecessary Complexity** | Manual loops, manual builders, hand-rolled state machines where a stdlib function exists. Example: a 12-line `for` loop building a `Vec<String>` that's just `.iter().map(...).collect()`. | Use the stdlib. If the stdlib doesn't fit, write a clear named helper, not an inline loop. |
| **Defensive Over-Programming** | Excessive `Option`/`Result` plumbing for inputs already validated upstream. Example: an internal `application` use case re-validating fields the `interface` parsed with serde. | Trust internal callers. Validate at boundaries (interface → application), not between trusted modules. Pre-conditions in types: if `User` exists, its fields are valid. |
| **Mirror Tests** | Tests that replay the implementation. Example: `#[test] fn test_add() { assert_eq!(add(2,3), 2 + 3); }`. The test asserts what the implementation will compute, not what callers expect. | Tests assert observable behaviour: inputs at the public API, outputs at the public API. If a test passes for two different correct implementations, it's a real test. |
| **Inconsistent Styling** | Inline styles in dioxus components instead of class names, comments restating the obvious (`// Call stop` before `stop()`), naming that drifts (`user_id` here, `userId` there). | `rustfmt --check`, `clippy::doc_markdown`, project-wide naming convention enforced by review. |

## The 4-stage verification loop (what the CI gate runs)

The `.github/workflows/code-et-audit.yml` workflow shipped by `/code:bootstrap` and `/code:install-ci` runs these stages on every PR. v3.10.0's `/code:audit` will mirror them locally for fast feedback.

| Stage | What | Tool |
|---|---|---|
| 1 — Static validation | Format, dead code, dead exports | `cargo fmt --check`, `cargo clippy -D warnings -W dead_code -W unreachable_pub`. Optional: `cargo +nightly udeps`. |
| 2 — Architectural check | Layer-direction enforcement | `scripts/layer-deps-validator.sh` (defence-in-depth; the `cargo` build is the primary). |
| 3 — Dependency audit | Unused + vulnerable + license/source bans | `cargo machete`, `cargo audit`, `cargo deny check`. |
| 4 — Complexity & duplication | Cognitive complexity, Rule of Three duplication | `cargo clippy` with `clippy.toml` thresholds. Optional: `jscpd` for explicit duplication detection. |

A finding is **CRITICAL** if it falls into one of:
- Layer violation (stage 2)
- Known security advisory in a dependency (stage 3 — `cargo audit`)
- Rule-of-Three duplication group (stage 4)
- Cognitive complexity above the deny threshold (stage 4)

The CI workflow exits non-zero on any CRITICAL finding. Other findings are warnings and don't block merge but are reviewed.

## Hard rules

These are non-negotiable — they end up in `code-et-implementer/CLAUDE.md` so they apply to every plan, every implementation, every review.

1. **Rule of Three.** Third duplicate triggers a refactor in the same PR.
2. **No mirror tests.** Tests assert observable behaviour, not implementation calls.
3. **No defensive validation at trusted boundaries.** Validate at interface→application; trust internal calls.
4. **No `// TODO: remove old X`.** When a slice supersedes existing code, deletion is part of the same commit.
5. **No re-exports for convenience.** A re-export is documentation that a type belongs to two modules; if that's not what you meant, refactor.
6. **Cognitive complexity ceiling: 15.** Override only with `#[allow(clippy::cognitive_complexity)]` + a one-line justification comment.

## See also

- [`docs/architecture.md`](architecture.md) — Rust Clean Architecture (the structural target the anti-slop rules defend).
- [`docs/testing.md`](testing.md) — per-layer test matrix; the mirror-test ban is enforced there.
- Engineering plugin's `tech-debt` skill — for prioritising slop fixes via Impact × Risk × Effort.
- Engineering plugin's `code-review` skill — for the human-judgment pass after the CI gate.
