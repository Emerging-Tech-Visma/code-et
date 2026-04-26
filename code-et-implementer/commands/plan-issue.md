---
tools: Read, Grep, Glob, Bash, LSP, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Skill
description: "Plan: detect PRD if present, decompose via LSP into tagged tasks."
argument-hint: "[feature-description] [@spec-file]"
effort: xhigh
---

Plan implementation tasks. Two paths:

## Context Budget (applies to both paths)

Quality of plan = quality of context. Bad context = bad tasks.

Follow `.claude/rules/context-hygiene.md` (slice reads, parallel Explore, trim attachments). Plus, plan-issue specifics:

1. **FILE-REFERENCE.md is the map.** Read it once. Don't re-Glob what it already lists.
2. **LSP for symbols, not sweeps.** Use `documentSymbol`/`findReferences`/`definition` to anchor `file:line`. Never use LSP to enumerate a whole project.
3. **Tip for token-tight sessions:** scope to one user story or AC per `/code:plan-issue` invocation. Smaller batches keep the context window cool and let `/code:implement` finish before the next plan.

Better: 5 tasks with sharp `file:line` + real rationale. Worse: 15 tasks with vague paths.

## Path A — PRD present (feature lane)

1. Resolve active PRD via `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh")`.
2. If a path is returned, Read the PRD and treat it as the authoritative spec.
3. Use LSP (`documentSymbol`, `findReferences`) to anchor each US/AC to `file:line`. Grep/Glob for discovery, LSP for precision. For 3+ independent areas, spawn parallel Explore agents.
4. Decompose into tasks. For each task, assign a `user_story` tag:
   - If the task implements a specific AC, tag as `AC-N.M`.
   - Else if it serves a US, tag as `US-N`.
   - Else tag as `chore:<one-sentence reason>` (build config, cross-cutting refactors required to enable a story).
   - Reject any task that cannot be tagged — split it or ask for clarification.
5. Create tasks via `TaskCreate` with metadata:
   ```
   {
     "verification": "<cmd>",
     "files": ["path:line", ...],
     "expected_outcome": "<observable success>",
     "rationale": "<1-2 sentences: why this task exists, the constraint or decision driving it>",
     "user_story": "US-N" | "AC-N.M" | "chore:<reason>"
   }
   ```
   `rationale` is mandatory — the subagent starts cold and needs the *why*, not just the *what*. Reject any task whose rationale would be "because the PRD says so"; restate the underlying constraint.
6. Set dependencies with `TaskUpdate(addBlockedBy)`. Independent tasks stay parallel.
7. Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

> Tip: for richer upstream planning, run `/ultraplan` manually before `/code:plan-issue` and commit the refined plan to `plans/` so this command picks it up.

## Path B — No PRD (bug lane, unchanged)

1. If `$ARGUMENTS` has `@<path>`, read that spec. Also check `.claude/rules/*.md` for constraints.
2. Use LSP (`documentSymbol`, `findReferences`) to get exact line numbers. Grep/Glob to find files, LSP for precision. For 3+ independent areas, spawn parallel Explore agents.
3. Break into tasks. Reason about dependencies — use `blocked_by` to build a dependency graph.
4. Create tasks via `TaskCreate` with metadata:
   ```
   {
     "verification": "<cmd>",
     "files": ["path:line", ...],
     "expected_outcome": "<what success looks like>",
     "rationale": "<1-2 sentences: why this task exists, the constraint or decision driving it>"
   }
   ```
   (No `user_story` required — bug lane. `rationale` still mandatory.)
5. Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

## Output

`"Plan complete: N tasks created. Run /code:implement to start."`

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Plan Complete' --subtitle 'N tasks created' || true")
```
