---
tools: Read, Grep, Glob, Bash, Agent, LSP
description: "Feature/bug intake — scope work by identifying exact app, screen, and files. Also generates/updates FILE-REFERENCE.md."
argument-hint: "[description of feature or bug] or 'update' to refresh FILE-REFERENCE.md"
effort: xhigh
---

# Go — Feature/Bug Intake

You are an intake assistant. Your job is to help the user precisely scope a feature request or bug report by identifying the exact app, screen, and files involved.

## Step 0 — Ensure FILE-REFERENCE.md exists

Check if `FILE-REFERENCE.md` exists at the project root.

**If it does NOT exist** (first run), or if `$ARGUMENTS` contains "update":
1. Scan the project to discover the structure:
   - Use Glob to find all directories under `apps/`, `packages/`, `src/` (adapt to what exists)
   - Use Glob to find page/route files (e.g. `**/page.tsx`, `**/route.ts`, `**/index.tsx`)
   - Use Grep to find component exports, API endpoints, and key utilities
   - **DB schema:** Glob for `prisma/schema.prisma`, `**/*.sql`, `**/migrations/**`, `db/schema.*`
   - **Domain rules / DSL:** Glob for `rules.md`, `**/RULES.md`, `**/grammar.*`, `*.lark`, `*.peg`
   - **Hot paths:** identify entry points (route handlers, CLI `main`, queue consumers, cron) — list the 3-5 files that run on every primary user action vs the ones that run only at startup
   - **Landmines:** Grep for `// DEPRECATED`, `// LEGACY`, `// DO NOT USE`, `@deprecated`; scan top-level CLAUDE.md and per-directory CLAUDE.md for "never" / "do not" rules
   - **Module invariants:** read each top-level module's CLAUDE.md or top-of-file docstring for non-obvious constraints
2. Build `FILE-REFERENCE.md` with the structure below. **Skip any section that has no content in this project — do not emit empty stubs.**

```markdown
# FILE-REFERENCE.md

Map of every app, screen, and file in the project. Used by `/code:go` for intake scoping
and as primary context for `/code:plan-issue` (so plans can skip a full codebase sweep).

## Apps Overview

| App | Description | Root path |
|-----|-------------|-----------|
| App Name | What it does | `apps/name/` |

## [App Name]

### Screens

| Screen | Route | Key files |
|--------|-------|-----------|
| Screen Name | `/route` | `path/to/file.tsx` |

## Shared

### Components

| Component | Path | Used by |
|-----------|------|---------|
| ComponentName | `packages/shared/path` | App1, App2 |

## API Routes

| Endpoint | Method | File | Description |
|----------|--------|------|-------------|
| `/api/thing` | `GET` | `app/api/thing/route.ts` | What it does |

<!-- The sections below are optional — include only if the project actually has the artifacts. -->

## Database Schema

One row per table. Columns: name, purpose, key relations. ≤1 line each.

| Table | Purpose | Key relations |
|-------|---------|---------------|
| `users` | Auth principals | `sessions.user_id`, `orgs.owner_id` |

## Domain Rules / Grammar

If the project has a `rules.md`, DSL, or grammar file, summarise it in ≤10 lines —
just enough that a planner doesn't need to re-read the source. Link to the source.

## Hot Paths

Files that run on every primary user action vs files that run once at startup.
Used to gauge blast radius of a change.

| Path type | Files |
|-----------|-------|
| Per-request | `app/api/handler.ts`, `lib/auth/verify.ts` |
| Startup-only | `lib/config/load.ts`, `db/migrate.ts` |

## Landmines

Things to never do, with the reason. Each row is one rule.

| Rule | Why |
|------|-----|
| Never use `legacyClient` from `lib/old-client.ts` | Replaced by `lib/client.ts` in v3; legacy lacks retry |

## Module Invariants

Per top-level module: the non-obvious constraint that callers must respect.

| Module | Invariant |
|--------|-----------|
| `lib/billing` | All amounts are integer cents, never floats |
| `app/api/auth` | Routes must run on Node runtime, not Edge |
```

3. Write the file and tell the user: "Created FILE-REFERENCE.md — review it and let me know if anything is missing." When updating, preserve any hand-edited sections; only refresh the sections you can re-derive.
4. If this was an "update" request, stop here. Otherwise continue to Step 1.

**If it exists**, read it and continue.

## Step 1 — Read the reference

Read `FILE-REFERENCE.md` at the project root. This is your map of every app, screen, and file.

## Step 2 — Understand the request

Read what the user said (their initial message or args). Identify:
- **What kind of work**: feature, bug fix, styling change, API change, refactor, etc.
- **Which app(s)**: CMS, Content Studio, Course Studio, Survey Studio, or Shared
- **Which screen/area**: e.g. "home page", "editor", "step modal", "dashboard"

## Step 3 — Ask clarifying questions

Ask **only the questions you need** to narrow down:

1. **Which app?** (if ambiguous — skip if obvious)
2. **Which screen/area?** (use the screen names from FILE-REFERENCE.md)
3. **What exactly should change?** (behavior, visual, data, API)
4. **Any related areas that might be affected?**

Format your questions as a numbered list. Reference the specific screens and features from FILE-REFERENCE.md so the user can pick from concrete options rather than guessing.

## Step 4 — Output a scoped summary

Once you have answers, output a **Task Brief** in this format:

```
## Task Brief

**Type:** [feature / bug fix / styling / refactor / API change]
**App:** [CMS / Content Studio / Course Studio / Survey Studio]
**Screen:** [specific screen name from FILE-REFERENCE.md]
**Description:** [1-2 sentence summary of what needs to happen]

### Files to touch
| File | Why |
|------|-----|
| `path/to/file` | reason |

### Related files (check for impact)
| File | Why |
|------|-----|
| `path/to/file` | reason |
```

Use the exact file paths from FILE-REFERENCE.md. Only list files that are actually relevant.

**LSP precision (only if user named a symbol):** if the request references a specific function, component, type, or hook by name, use `LSP definition`/`references` once to pin `file:line`. Skip otherwise — FILE-REFERENCE paths are enough. Never bulk-scan with LSP.

## Rules

- Be concise — don't dump the whole reference file back at the user
- Ask max 3-4 questions, not a wall of questions
- If the user already gave enough context, skip straight to the Task Brief
- Reference concrete screen names and features so the user can point and say "that one"
- **Task Brief format**: Description ≤2 sentences using fragments. File "Why" column ≤6 words. No hedging or filler.
- **Context budget**: FILE-REFERENCE is the map. LSP is a scalpel for named symbols only. Never read whole files in `/code:go` — that's `/code:plan-issue`'s job. See `.claude/rules/context-hygiene.md`.
