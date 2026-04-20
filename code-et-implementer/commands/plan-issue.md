---
tools: Read, Grep, Glob, Bash, LSP, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Skill
description: "Plan: detect PRD, delegate to /ultraplan when present, fall back to LSP-only."
argument-hint: "[feature-description] [@spec-file]"
effort: high
---

Plan implementation tasks. Two paths:

## Path A — PRD present (feature lane)

1. Resolve active PRD via `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh")`.
2. If a path is returned, Read the PRD.
3. **Invoke `/ultraplan`** with the PRD. Try `Skill("ultraplan", args=prd_path)` first; if that fails, pass the PRD contents inline. On any failure (skill unavailable, network error, malformed output), announce exactly once:
   > `/ultraplan unreachable — using local LSP decomposition. Plan may be less thorough for large PRDs.`
   …and fall through to Path B using the PRD as the spec.
4. **Post-process `/ultraplan` output:**
   - For each proposed task, assign a `user_story` tag:
     - If the task implements a specific AC, tag as `AC-N.M`.
     - Else if it serves a US, tag as `US-N`.
     - Else tag as `chore:<one-sentence reason>` (build config, cross-cutting refactors required to enable a story).
   - Reject any task that cannot be tagged — ask for clarification or split the task.
5. **LSP-enrich** each task: use `documentSymbol` / `findReferences` to add `file:line` anchors to `metadata.files`.
6. Create tasks via `TaskCreate` with metadata:
   ```
   {
     "verification": "<cmd>",
     "files": ["path:line", ...],
     "expected_outcome": "<observable success>",
     "user_story": "US-N" | "AC-N.M" | "chore:<reason>"
   }
   ```
7. Set dependencies with `TaskUpdate(addBlockedBy)`. Independent tasks stay parallel.
8. Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

## Path B — No PRD (bug lane, unchanged)

1. If `$ARGUMENTS` has `@<path>`, read that spec. Also check `.claude/rules/*.md` for constraints.
2. Use LSP (`documentSymbol`, `findReferences`) to get exact line numbers. Grep/Glob to find files, LSP for precision. For 3+ independent areas, spawn parallel Explore agents.
3. Break into tasks. Reason about dependencies — use `blocked_by` to build a dependency graph.
4. Create tasks via `TaskCreate` with metadata:
   ```
   {
     "verification": "<cmd>",
     "files": ["path:line", ...],
     "expected_outcome": "<what success looks like>"
   }
   ```
   (No `user_story` required — bug lane.)
5. Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

## Output

`"Plan complete: N tasks created. Run /code:implement to start."`

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Plan Complete' --subtitle 'N tasks created' || true")
```
