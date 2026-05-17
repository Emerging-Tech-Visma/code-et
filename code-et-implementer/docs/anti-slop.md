---
name: anti-slop
description: Anti-slop framework for TS deep-modules — 4 elements, 5 categories, 4-stage verification, hard rules. The CI gate enforces the deterministic stages; the engineering plugin's code-review skill catches the rest.
applies_to: typescript
---

# Anti-Slop (code-et v5)

AI-generated code accumulates structural debt that file-local linters miss: shallow modules extracted "for testability", duplicate utilities, defensive over-programming, mirror tests, drift away from the deep-module shape. This doctrine names the patterns and the gates.

## The 4 elements

### 1. Shallow modules

**Slop:** Modules whose interface is nearly as complex as their implementation. Most often a pure function extracted for "testability" while the real bugs live in how it's called.

**How to detect.** Apply the **deletion test** from [`architecture.md`](architecture.md): imagine deleting the module. If complexity vanishes, it was a pass-through — fold it back into the caller. If complexity reappears across N callers, the module earns its keep.

**How to fix.** Merge the shallow module into the caller. If it shouldn't go away, deepen it — move more behaviour behind the same interface so callers get **leverage**.

### 2. Duplication

**Slop:** One bug must be fixed in many places. Exact clones, semantic clones, "I'll copy this helper into the new module".

**Rule of Three.** Two duplicates is a coincidence; three is a pattern. **The third occurrence triggers a refactor in the same PR.** Extract into the module whose interface naturally owns the concept.

**How to detect.** Biome catches some patterns. For cross-file copy-paste: `npx jscpd src --min-tokens 50` (run on demand, not in CI by default).

### 3. Defensive over-programming

**Slop:** Excessive `Optional`/`Result` plumbing for inputs already validated upstream. Re-validating in `application` what `interface` already parsed with Zod. `if (!x) throw new Error("x is required")` on a non-null parameter.

**How to fix.** Validate at the seam (HTTP route, queue handler, file parser). Trust internal calls. Pre-conditions in types: if `Order` exists in memory, its fields are valid — don't re-check them on every method.

### 4. Drift from the deep-module shape

**Slop:** Modules acquiring "convenience" exports that paper over a missing abstraction. Implementation details leaking through the interface (returning the Drizzle row instead of the domain DTO). Routes reaching past a module to its private files.

**How to detect.** `eslint-plugin-import` or Biome import rules can enforce "no relative imports past `index.ts`". Code review on PRs that touch `index.ts` of multiple modules — when one module's interface grows, ask: does the caller need the new export, or is the module the wrong shape?

**How to fix.** Move the leaked behaviour behind the existing interface. If the interface can't absorb it cleanly, the module is mis-named — rename to what it actually does, *then* see whether the leakage was inevitable.

## The 5 slop categories — spotting it in review

When CI is green but something still feels wrong, look for these. The engineering plugin's `code-review` skill catches most; reviewers catch the rest.

| Category | Looks like | Fix |
|---|---|---|
| **Superficial Competence** | Code follows common patterns but ignores the specific business rule. Example: a `validateOrder` that checks for null and length but not the actual domain invariant. | Re-read the use case. Validation belongs at the seam, framed as "what makes this operation valid in *this* domain". |
| **Unnecessary Complexity** | Hand-rolled loops, hand-rolled state machines where stdlib or a small lib exists. 12-line `for` loop building an array that's `.map(...)` + `.filter(...)`. | Use the language. If stdlib doesn't fit, a named helper, not inline. |
| **Defensive Over-Programming** | Internal modules re-validating fields the seam already parsed with Zod. | Validate at the seam, not between trusted modules. Types carry the post-condition. |
| **Mirror Tests** | Tests replay the implementation. `expect(add(2, 3)).toBe(2 + 3)`. The test asserts what the implementation will compute, not what callers expect. | Tests assert observable behaviour through the public interface. A test that passes for two different correct implementations is a real test. |
| **Inconsistent Styling** | Mixed quote styles, mixed `===` / `==`, naming drift (`userId` here, `user_id` there), comments restating the obvious. | `biome check --apply`. Project-wide naming enforced in review. |

## The 4-stage verification loop — what CI runs

The `.github/workflows/code-et-audit.yml` shipped by `/code:start` and `/code:install-ci` runs these stages on every PR. The same pipeline runs locally via `bun run audit` and as the tail step of `/code:ship`.

| Stage | What | Tool |
|---|---|---|
| 1 — Static validation | Format, lint, dead exports | `biome check .` |
| 2 — Type safety | TypeScript checks across the workspace | `tsc --noEmit` |
| 3 — Dependency audit | Vulnerable + unused deps | `bun audit`. Optional: `npx knip` for unused exports/files. |
| 4 — Tests | Unit + integration | `bun test` |

A finding is **CRITICAL** if it falls into one of:
- Type error (stage 2)
- Known security advisory in a dependency (stage 3 — `bun audit`)
- Test failure (stage 4)

CI exits non-zero on any CRITICAL finding. **HIGH** findings (Biome errors, type warnings escalated to errors) also block merge. MEDIUM/LOW (Biome warnings, unused exports from `knip`) are reviewed but don't block.

## Hard rules

These are non-negotiable — they live in `code-et-implementer/CLAUDE.md` so they apply to every plan, every implementation, every review.

1. **Deletion test before extraction.** Before extracting a helper into its own module, mentally delete it. If complexity vanishes, don't extract — inline it. Extract only when the deletion test says complexity would reappear across N callers.
2. **Rule of Three.** Third duplicate triggers a refactor in the same PR.
3. **No mirror tests.** Tests assert observable behaviour, not implementation calls. See [`testing.md`](testing.md) §"Mirror-test ban".
4. **No defensive validation at trusted seams.** Validate at HTTP/queue/file seams (with Zod). Trust internal calls.
5. **No `// TODO: remove old X`.** When a new module supersedes existing code, deletion is part of the same commit. New code obsoletes old in one step.
6. **No re-exports for convenience.** A re-export is documentation that a type belongs to two modules. If that's not what you meant, refactor.
7. **One adapter = hypothetical seam. Two adapters = real seam.** Don't introduce a port unless something actually varies across it.
8. **Trust the types.** Don't sprinkle runtime `if (!foo) throw` for fields the type system already proves non-null. Validate at the seam, then trust.

## See also

- [`architecture.md`](architecture.md) — deep-modules architecture; dependency categories; the seam vocabulary anti-slop defends.
- [`testing.md`](testing.md) — interface-as-test-surface; mirror-test ban examples.
- Engineering plugin's `tech-debt` skill — prioritising slop fixes via Impact × Risk × Effort.
- Engineering plugin's `code-review` skill — the human-judgment pass after CI.
