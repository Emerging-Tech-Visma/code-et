---
tools: Read, Grep, Glob, Bash, Agent
description: "Grill an idea into a refined brief — one question at a time, codebase-first, converges automatically."
argument-hint: "[rough idea or @brief-file]"
effort: high
---

# Grill — Idea Refinement

Turn a rough idea into a refined brief you can hand to `/code:prd`. Ask one question at a time with a recommended answer. Stop when every open decision is resolved.

## Rules

1. **If a question can be answered from the codebase, answer it yourself.** Use Read/Grep/Glob/Bash (git log). Do not ask the user.
2. **Ask one question per message.** Number it. Include a recommended answer and 1-sentence rationale.
3. **Accept "you decide" as a final answer.** Record the recommendation as the decision. Do not re-ask.
4. **Accept "defer: <reason>"** — mark deferred, move on.
5. **Stop rule:** when every item in the decisions ledger is resolved (`answered` | `recommended-accepted` | `deferred`), announce completion and print the refined brief.

## Decisions Ledger

Maintain an in-session ledger. Each entry:
- `id` (D-1, D-2, …)
- `question`
- `recommendation`
- `state`: `pending` | `answered` | `recommended-accepted` | `deferred`
- `final_answer`

Present the ledger summary after every 3 answered questions so the user can see progress.

## Process

1. **Parse input.** `$ARGUMENTS` is either the rough idea as text or `@path/to/brief.md`. If `@path`, read the file.
2. **Explore context.** Run `Glob` on `**/*.md` for existing plans, `git log --oneline -20`, and scan key config files. Build a project-state snapshot.
3. **Seed the ledger.** From the input and context, draft 5-10 open decisions. Common axes: scope, actor, data model, UI surface, integration points, non-goals, success criteria.
4. **Interrogate.** One question at a time. Resolve codebase-answerable items yourself before asking.
5. **Converge.** When ledger is fully resolved, print:

```
## Refined Brief

**Idea:** <1-sentence>
**Actors:** <list>
**Scope:** <in / out>
**Key decisions:**
- D-1: <question> → <final_answer>
- D-2: …

**Suggested slug:** <kebab-case>

Next: run /code:prd to convert this brief into a PRD file.
```

## Brevity

Drop filler. Questions ≤2 sentences. Recommendations ≤1 sentence.
