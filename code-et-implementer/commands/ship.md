---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Edit, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: "Execute pending tasks in parallel worktrees, then audit. Auto-retries 1 fix-pass on CRITICAL/HIGH findings."
argument-hint: "[task-id]"
effort: xhigh
---

# Ship — Execute + Audit

Loads pending tasks from `TaskList` (or `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`), dispatches them as parallel worktree-isolated subagents, then runs the local audit gate. On CRITICAL or HIGH findings, dispatches one fix-pass subagent and re-audits. After 1 retry the chain halts and surfaces findings.

If the current branch is `main` or `master`, create `feature/<slug-from-prd-or-tasks>` first.

## Dispatch

Every task runs as a forked subagent in its own worktree. Use `Agent` with `isolation: "worktree"`, `subagent_type: "general-purpose"`, and `model: "sonnet"` (Sonnet 4.6 — routine coding tier). **Do not** shell out to `git worktree add` — `isolation: "worktree"` handles it (requires `CLAUDE_CODE_FORK_SUBAGENT=1` on external builds; default-on inside this harness).

**Model assignments across the swarm:**

| Role | Model | Why |
|---|---|---|
| Orchestrator (this skill) | inherits (Opus 4.7) | Multi-step coordination + decisions on partial failures. |
| Per-task implementer | `sonnet` (4.6) | Routine vertical-slice coding from a complete brief. |
| Per-task reviewer fork | `opus` (4.7) | Catching bugs the implementer missed is high-leverage — an 8-pt SWE-bench gap on the reviewer pays for itself. Reviewer errors fail silently; implementer errors get caught downstream. |
| Per-task review fix-pass | `opus` (4.7) | Applies reviewer findings — same model as the reviewer to keep judgment consistent across the find/fix pair. |
| Post-merge audit fix-pass | `opus` (4.7) | Judgment call on the audit gate — layer slips, dependency advisories. |
| Explore (when delegated for breadth) | `haiku` (4.5) | Cheap breadth searches for cold areas. Implementer/reviewer prompt may request this. |

Dependency graph drives order. Independent tasks **must** dispatch in a single message with multiple `Agent` calls so they run concurrently — never serialize what could fan out.

### Dispatch prompt template

Each subagent starts cold. Send one comprehensive first turn — intent, constraints, acceptance criteria, `file:line` anchors, verification, and rationale — so it operates autonomously without back-and-forth. Use this template verbatim (fill `<…>` from task metadata + active PRD):

```
# Task <id>: <title>

## Tag
<metadata.user_story — one of: US-N | AC-N.M | chore:<reason> | none>

## PRD context (if US-N or AC-N.M)
<Paste the matching US-N / AC-N.M block from the active PRD, resolved via ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh. Include the parent User Story and all its ACs so the agent sees full intent.>

## Rationale
<metadata.rationale — verbatim from plan. The why, not the what.>

## Files to touch
<metadata.files — exact file:line anchors. Read these before editing.>

## Layer
<metadata.layer — domain | application | infrastructure | interface | chore. Imports point inward; `cargo build` enforces this.>

## Expected outcome
<metadata.expected_outcome — observable success criterion.>

## Verification
Run `<metadata.verification>`. Must exit 0. All existing tests must still pass.

## Constraints
- Follow rules in `code-et-implementer/CLAUDE.md` (Brevity, Context Hygiene, Clean Architecture controlling rules, ≤600 lines/file).
- Layer rules: `code-et-implementer/docs/architecture.md`. Anti-slop hard rules: `code-et-implementer/docs/anti-slop.md`. Test matrix: `code-et-implementer/docs/testing.md`.
- Read in slices: `Read(offset, limit)` for files >200 lines; never re-read the same file twice for different blocks.
- Delegate breadth to `Agent(subagent_type: "Explore")` if the fix path is unclear — do not Grep-and-Read your way through unknown territory.
- Every acceptance criterion must have a corresponding test.
- No scope expansion — implement exactly what the task specifies; flag adjacent issues instead of fixing inline.
- If the slice supersedes existing code, delete the superseded code in the same commit. No parallel utilities, no `// TODO: remove old X`. New code obsoletes old.
- All SQL via `sqlx::query!` / `query_as!` (compile-time-checked). Raw `sqlx::query` is forbidden.
- Commit format: `<prefix>: <subject>` where prefix is US-N | AC-N.M | chore (or no prefix if tag is `none`).

## Deliverables (subagent reports back)
1. Code changes committed in the isolated worktree.
2. `metadata.verification` exits 0.
3. Single commit with correct prefix.
4. PRD checkbox ticked (if `US-N`) — flip `- [ ] US-N` to `- [x] US-N` and stage with the commit.
5. Final report: commit SHA, branch name, worktree path (returned in the `Agent` tool result).

Do not merge back to the parent feature branch — the orchestrator handles that. Do not ask clarifying questions. If blocked, flag in the final report with a specific file:line reference.
```

### Per-subagent contract

1. Implement the task. Every acceptance criterion has a corresponding test.
2. Run `metadata.verification`. Must compile, tests must pass.
3. Commit with the right prefix:
   - `US-N: <subject>` when tag is `US-N`
   - `AC-N.M: <subject>` when tag is `AC-N.M`
   - `chore: <subject>` when tag starts with `chore:`
   - No prefix when tag is `none` or absent.
4. **Tick the PRD checkbox.** If `metadata.user_story` is `US-N`, resolve the PRD via `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh` and `Edit` to flip `- [ ] US-N` → `- [x] US-N`. Stage with the commit.

The subagent stops after step 4 and returns. It must **not** merge or remove its own worktree — it has no view of the parent feature branch.

## Per-task review (before merge)

Code review happens twice in v4.1+: once per task before merge (this section, shift-left), and once across the full feature branch at `/code:review` (pre-PR gate). Per-task review catches logic bugs at the smallest possible diff — task 1's bug never gets to pollute task 2's foundation.

### Step 1 — Capture the diff

After the implementer subagent returns successfully:

```
diff="$(git -C <worktree_path> diff $(git merge-base HEAD <subagent_branch>)..<subagent_branch>)"
```

Empty diff = implementer didn't write code. Halt that task and surface to the user; do not dispatch a reviewer.

### Step 2 — Dispatch the reviewer (Opus 4.7)

Reviewer is a fork — `Agent(model: "opus")` with no `subagent_type` and no `isolation`. It works against the diff payload, not the worktree.

If the diff exceeds **1500 lines**, halt this task and surface a "task too large — split or escalate to `/code:review` only" warning instead of dispatching. A vertical slice that big is almost always two slices in disguise.

Reviewer prompt:

```
# Per-task review for <task-id>: <title>

## Diff (against parent feature branch)
<diff content — full payload, ≤1500 lines>

## Rationale (why this task exists)
<metadata.rationale>

## Expected outcome
<metadata.expected_outcome>

## Layer
<metadata.layer>

Review the diff against the rationale + expected outcome.

**Step A — Try the engineering plugin's code-review skill:**
```
Skill("code-review")
```
If it returns findings, use them. If the skill is not installed (the call errors with "skill not found"), fall back to Step B.

**Step B — Inline 5-area review** (mirror of `/code:review` Step 2):
1. **Layer compliance** — does any new file violate the inward dependency rule? (`code-et-implementer/docs/architecture.md` §"The Dependency Rule")
2. **Anti-slop** — Rule of Three duplicates, mirror tests, defensive validation, dead re-exports. (`code-et-implementer/docs/anti-slop.md` §"Hard rules")
3. **Test coverage** — every acceptance criterion has a corresponding test. (`code-et-implementer/docs/testing.md` §"Per-layer test matrix")
4. **Security** — secrets in `secrecy::Secret<T>`; auth at every interface entry point. (`code-et-implementer/docs/architecture.md` §"Rust security checklist")
5. **Slice integrity** — coherent vertical slice; superseded code deleted in same commit; no `// TODO: remove old X`.

**Output format — strict.** Output ONLY the JSON array as your final message. No preamble, no code fences, no explanation. If no CRITICAL or HIGH findings, output exactly: `[]`

Schema:
[{"severity": "CRITICAL|HIGH", "file": "path:line", "issue": "<one sentence>"}]

Drop MEDIUM and LOW findings — those are for `/code:review` to catch later. Do not modify code. You are a reviewer, not a fixer.
```

### Step 3 — On CRITICAL/HIGH findings, dispatch ONE review fix-pass

Spawn `Agent(subagent_type: "general-purpose", model: "opus")` with no isolation. Prompt directs it to operate via `git -C <worktree_path>` and explicit file paths inside `<worktree_path>`:

```
# Review fix-pass for <task-id>

The per-task reviewer flagged the following CRITICAL/HIGH findings on the diff in worktree <worktree_path>:

<findings JSON>

Fix each finding. Use absolute paths or `git -C <worktree_path>` for git operations. After fixing, re-run `<metadata.verification>` from inside `<worktree_path>` (must exit 0). Commit the fix-up with subject "fix-up: <task tag>". Return the new HEAD SHA.

Constraints: same as the implementer (Brevity, Context Hygiene, Clean Architecture rules). No scope expansion — fix the findings only.
```

After the review fix-pass returns, **do not re-review**. One cycle max — same retry budget as the post-merge audit. If the fix-pass returns without a new commit or `verification` fails, halt that task and surface findings to the user (leave the worktree in place for inspection).

## Orchestrator (this skill)

After each `Agent` call returns:
1. Read the returned worktree path and branch from the tool result.
2. Run **Per-task review** (above). On CRITICAL/HIGH, dispatch one review fix-pass and continue.
3. From the parent feature branch: `git merge --no-ff <subagent-branch>`.
4. `git worktree remove <path>` (the harness auto-cleans empty worktrees, but populated ones need explicit removal).
5. Mark the task completed via `TaskUpdate` only after the merge lands.

If a subagent reports failure, or the review fix-pass cannot resolve findings, leave the worktree in place for inspection — do not auto-discard.

## After all tasks land — audit

Run `Skill("simplify")` first (changed-code refactor pass). Then run the local audit:

```
Bash('bash "${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh" "$PWD"')
```

The audit mirrors the v4.0 CI gate: `cargo fmt --check`, `cargo clippy -D warnings`, `scripts/layer-deps-validator.sh`, `cargo machete`, `cargo audit`, `cargo deny check`, `cargo nextest run --workspace`. Report at `.claude/audit-<UTC>.md`.

### Auto-retry on CRITICAL/HIGH (max 1 pass)

If audit exits non-zero with CRITICAL or HIGH findings (the typical: layer violation, dependency advisory, clippy lint, test failure):

1. Read `.claude/audit-<UTC>.md` — extract the highest-severity finding's `path:line` + message.
2. Dispatch **one** fix-pass subagent via `Agent(subagent_type: "general-purpose", model: "opus")` (no worktree isolation — work directly on the feature branch since the task swarm already merged; Opus 4.7 here because audit-gate findings often require judgment — layer slips, dependency advisories, real test failures vs flakes):
   ```
   # Audit fix-pass
   The post-implement audit returned <severity> at <path:line>: <message>.
   Read the report at .claude/audit-<UTC>.md for full context.
   Fix the finding(s). Then re-run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/audit.sh" "$PWD"`.
   Constraints: same as task subagents (see ship.md). No scope expansion — fix the audit findings, nothing else.
   ```
3. Wait for the fix-pass to return.
4. Re-run audit once. If still failing, **stop the chain** and surface:
   ```
   Audit still failing after 1 fix-pass. Latest report: .claude/audit-<UTC>.md
   Highest finding: <severity> <path:line> — <message>
   Inspect, fix manually, then re-run /code:ship to retry the audit step only.
   ```

Never loop more than once — repeated AI fix-passes on a stuck audit waste tokens and hide the real issue.

### On clean audit

```
✓ All tasks landed. Audit clean.
Next: /code:review (or /commit-push-pr to ship).
```

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Ship done' --subtitle 'Audit clean' || true")
```

## Notes

- The `SubagentStop` hook (`scripts/verify-gate.sh`) runs `cargo test` + `audit --fast` after each subagent — that's the inner loop. The full audit at the end is the outer gate.
- `--fast` runs only fmt + clippy. The post-tasks pass runs the full seven stages.
- The audit is **the** anti-slop enforcement. Never tweak its findings to make it pass — fix the code, or accept a `LOW` finding when a tool is genuinely missing on the host.
