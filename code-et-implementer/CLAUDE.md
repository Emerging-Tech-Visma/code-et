# code-et v5.x

Lightweight TypeScript workflow built on **deep modules**. Stack: `Bun + Hono + Drizzle + Biome`. Architecture vocabulary — *module / interface / seam / adapter / depth / leverage / locality* — is standard software-engineering terminology drawn from Ousterhout's *A Philosophy of Software Design* and Feathers' *Working Effectively with Legacy Code*.

## Git Rules

- **Never push directly to main** — always create a feature branch and PR.
- **Branch naming:** `feature/<name>`, `fix/<name>`, `chore/<name>`.
- **Never force push** — rebase locally, push normally.

## Commands

| Task | Command |
|------|---------|
| Scaffold a new project | `/code:start <name>` |
| Add CI to existing repo | `/code:install-ci` |
| Single bug fix | `/code:fix` (intake → Task Brief; you implement) |
| Feature, end-to-end | `/code:plan` (idea → PRD → tasks) → `/code:ship` (parallel agents + audit) |
| Pre-merge gate | `/code:review` (audit + diff review) |

For commits and PRs use the `commit-commands` plugin (`/commit`, `/commit-push-pr`).

## Workflow — two lanes

**Bug lane.** `/code:fix` produces a Task Brief and stops. Most bugs are 1–3 file edits — no orchestration needed. If the work spans multiple coherent vertical slices (HTTP seam + module + DB for a real feature), it's a feature in disguise — write a PRD instead.

**Feature lane.** `/code:plan` (refined brief → PRD on disk → vertical-slice tasks) → `/code:ship` (parallel worktree agents + audit + 1 auto-retry on CRITICAL/HIGH) → `/code:review` (pre-merge gate) → `/commit-push-pr`.

Each task is a **vertical slice**: HTTP route → module → DB (or whatever path the slice actually traverses), end-to-end testable. When a slice supersedes existing code, deletion of the old code is part of the same commit — no parallel utilities, no `// TODO: remove old X`.

## Vocabulary — use these terms exactly

- **Module** — anything with an interface and an implementation. Function, file, folder, package.
- **Interface** — everything a caller must know: types, invariants, error modes, ordering. Not just the type signature.
- **Implementation** — the body of code inside.
- **Depth** — leverage at the interface; a lot of behaviour behind a small interface.
- **Seam** — where an interface lives.
- **Adapter** — a concrete thing satisfying an interface at a seam.

**Three principles:**

1. **Deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across callers, the module earned its keep.
2. **Interface is the test surface.** Tests cross the same seam callers do.
3. **One adapter = hypothetical seam. Two adapters = real seam.**

Don't drift into "component", "service", "API", or "boundary".

## Task Metadata Convention

Tasks created with `TaskCreate` carry:

```
metadata: {
  verification: "bun test && bun run typecheck",
  files: [
    {"path": "src/modules/<m>/index.ts", "symbol": "Orders.place", "line": 42, "op": "modify"},
    {"path": "src/http/routes/orders.ts", "symbol": "placeOrder", "op": "add"},
    {"path": "src/modules/<m>/legacy.ts", "symbol": "oldPlace", "line": 89, "op": "delete"}
  ],
  expected_outcome: "what success looks like",
  rationale: "why this slice exists — the constraint driving it",
  user_story: "US-N" | "AC-N.M" | "chore:<reason>",
  module: "orders"
}
```

`files[]` entries: `path` + `op` always required; `symbol` required for `modify|replace|delete`; `line` is a drift-tolerant hint — `symbol` is the contract. Full schema in `commands/plan.md` §"TaskCreate metadata".

`rationale` is mandatory — implementer subagents in `/code:ship` start cold.

`module` is free-form lowercase (`orders`, `payments`, `auth`, `chore`) — no enforced taxonomy. Matches the folder name in `src/modules/`.

## Model Assignments

| Role | Model | Where |
|---|---|---|
| Orchestrator (`/code:plan`, `/code:ship`) | `opus` (4.7) | Inherited; multi-step coordination + judgment. |
| Per-task implementer | `sonnet` (4.6) | `/code:ship` — routine vertical-slice coding from a complete brief. |
| Per-task reviewer | `opus` (4.7) | `/code:ship` — diff review via engineering plugin's `code-review` (falls back to inline 5-area checklist). Bugs the reviewer misses fail silently. |
| Per-task review fix-pass | `opus` (4.7) | `/code:ship` — applies reviewer findings; same model for find/fix consistency. |
| Audit fix-pass | `opus` (4.7) | `/code:ship` — judgment on type errors, dep advisories, test failures. |
| Explore (breadth searches) | `haiku` (4.5) | `/code:plan`, `/code:fix` — cheap parallel discovery. |

Heavy lifting (planning, judgment, review) on Opus; routine coding from a complete brief on Sonnet; breadth gathering on Haiku.

## Code Standards

- TypeScript strict (`strict: true`, `noUncheckedIndexedAccess: true`).
- `biome check .` clean, `tsc --noEmit` clean.
- Max ~400 lines per file (soft guidance — split when adding behaviour, not by line count alone).
- Compose at `src/main.ts` (the composition root); no module instantiates another module's concrete implementation.
- All HTTP input parsed with Zod at the route seam. Modules trust their callers within the process boundary.
- All DB access through Drizzle — no raw SQL string-concatenation.
- Forward-only migrations under `src/db/migrations/`. Each rollback is its own forward migration.

## Deep Modules — controlling rules

Apply the doctrine in [`docs/architecture.md`](docs/architecture.md). Each new or modified file belongs to a named module (`metadata.module` in tasks). Modules grow organically; no fixed taxonomy.

UI: optional Vite + React frontend in `web/`. Drop it if API-only.
DB: SQLite for local + dev, Postgres for prod. Same Drizzle schema; the migrator emits dialect-aware SQL.

**Delegation map for human-judgment passes** (engineering plugin: `knowledge-work-plugins/engineering`):
- security / code review → `code-review` skill
- testing strategy → `testing-strategy` skill
- tech-debt triage → `tech-debt` skill
- ADR / system design → `system-design` skill
- architecture refactors → engineering plugin's `improve-codebase-architecture` skill (if installed)

**Anti-slop hard rules:** see [`docs/anti-slop.md`](docs/anti-slop.md). Deletion test before extraction. Rule of Three. No mirror tests. No defensive validation at trusted seams.

## Brevity

Drop filler ("just", "simply", "really"), hedging ("perhaps", "maybe"), pleasantries ("Sure!", "Happy to help"). Fragments over sentences when meaning is clear. Pattern: `[thing] [action] [reason]. [next].`

Task subjects: `<verb> <object>` ≤50 chars. ✗ "I will implement the auth middleware". ✓ "add auth middleware in src/http/routes/auth.ts".

Never compress: code, file paths, URLs, error messages, security warnings.

## Context Hygiene

Token waste = worse plans + worse code.

1. **Trim attachments.** Quote back only the slice you act on. Duplicate blocks count once.
2. **Read in slices.** Files >200 lines: Grep first, then `Read(offset, limit)` for a window. Re-reading the same file twice = first read should have been a slice.
3. **Delegate breadth.** 3+ independent areas → `Agent(subagent_type: "Explore", model: "haiku")`. Parallel queries → one message, multiple Agent calls.
4. **Stop at sufficient.** `file:line` + rationale per task is enough. 5 sharp tasks > 15 vague ones.

## Always-latest dependencies

The template's `package.json` pins to caret (`^4.6.0`) so patches and compatible minors flow through `bun install`. Major bumps need a manual `bun update` plus a `bun run audit` smoke. The CI gate's `bun audit` step catches yanked or vulnerable pins on every PR.
