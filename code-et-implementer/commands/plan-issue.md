---
tools: Read, Grep, Glob, Bash, LSP, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Skill
description: "Plan a PRD-driven feature into vertical-slice tasks anchored at file:line."
argument-hint: "[feature-description]"
effort: xhigh
---

Decompose a PRD into vertical-slice tasks. **PRD-only** — if there's no PRD, route the user to `/code:prd` first (or `/code:go` for a single bug).

## Context Budget

Quality of plan = quality of context. Bad context = bad tasks.

Follow Context Hygiene rules in `code-et-implementer/CLAUDE.md` (slice reads, parallel Explore, trim attachments). Plus, plan-issue specifics:

1. **FILE-REFERENCE.md = constraints + orientation.** Apps overview, hot paths, landmines, invariants. File inventories are NOT in here — Glob the filesystem for routes/components/schemas when you need them.
2. **Order of ops:** Read FILE-REFERENCE first (cheap, has the rules) → Glob for files in the affected area → LSP to pin symbols.
3. **LSP for symbols, not sweeps.** Use `documentSymbol`/`findReferences`/`definition` to anchor `file:line`. Never use LSP to enumerate a whole project.
4. **Tip for token-tight sessions:** scope to one user story or AC per `/code:plan-issue` invocation. Smaller batches keep the context window cool and let `/code:implement` finish before the next plan.

Better: 5 tasks with sharp `file:line` + real rationale. Worse: 15 tasks with vague paths.

## Decomposition Rules (apply to every task)

### Vertical slicing — non-negotiable

Each task implements **one full vertical slice**: UI ↔ logic ↔ API ↔ database, end-to-end and testable. A task that touches only one layer is wrong — split or merge until each task ships a working slice.

- ✗ "Add API endpoint" + "Wire UI button" + "Migrate schema" — three half-tasks
- ✓ "Submit-feedback flow: form → API → `feedback` row → email confirmation" — one slice

`metadata.verification` must exercise the full slice end-to-end, not a single layer.

### Replace, don't accumulate

If a slice supersedes existing logic, the task scope **includes deletion of the superseded code**. No duplicate utilities, no dead branches, no `// TODO: remove old X`. New code obsoletes old in the same commit. State the path:line of what's being replaced in `metadata.rationale`.

## Procedure

1. Resolve active PRD via `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh")`. If no PRD is returned, stop and tell the user: "No PRD found. Run `/code:prd` to create one, or `/code:go` if this is a single bug."
2. Read the PRD; treat it as the authoritative spec.
3. Use LSP (`documentSymbol`, `findReferences`, `definition`) to anchor each US/AC to `file:line`. Grep/Glob for discovery, LSP for precision. For 3+ independent areas, spawn parallel Explore agents.
4. Decompose into **vertical slices** (see Decomposition Rules above). For each task assign a `user_story` tag:
   - Implements a specific AC → `AC-N.M`
   - Serves a US → `US-N`
   - Cross-cutting plumbing required to enable a story → `chore:<one-sentence reason>`
   - Reject any task that can't be tagged — split or ask for clarification.
5. Create tasks via `TaskCreate` with metadata:
   ```
   {
     "verification": "<cmd that exercises the slice end-to-end>",
     "files": ["path:line", ...],
     "expected_outcome": "<observable end-to-end behaviour>",
     "rationale": "<1-2 sentences: why this slice exists, the constraint driving it; if replacing existing code, name the path:line being deleted>",
     "user_story": "US-N" | "AC-N.M" | "chore:<reason>"
   }
   ```
   `rationale` is mandatory — the subagent starts cold and needs the *why*, not the *what*. Reject "because the PRD says so" — restate the underlying constraint.
6. Set dependencies with `TaskUpdate(addBlockedBy)`. Independent slices stay parallel.
7. Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

> Tip: for richer upstream planning, run `/ultraplan` manually before `/code:plan-issue` and commit the refined plan to `plans/` so this command picks it up.

## Output

`"Plan complete: N tasks created. Run /code:implement to start."`

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Plan Complete' --subtitle 'N tasks created' || true")
```
