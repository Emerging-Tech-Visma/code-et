---
tools: Read, Write, Bash, Grep, Glob
description: "Synthesise current conversation into a PRD file at plans/YYYY-MM-DD-<slug>.md. Sets session title. Local only — no GitHub issue."
argument-hint: "[optional slug override]"
effort: xhigh
---

# PRD — Product Requirements Document

Synthesise the current conversation (ideally a `/code:grill` output) into a PRD file. Local only.

## Process

1. **Derive the slug.**
   - If `$ARGUMENTS` is non-empty, use it (lowercased, kebab-cased).
   - Else derive from the refined brief's "Idea" line (kebab-case, ≤40 chars).

2. **Create the feature branch if not on one.**

```bash
branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  git checkout -b "feature/<slug>"
fi
```

3. **Compute the PRD path.**

```bash
date="$(date +%Y-%m-%d)"
prd_path="plans/${date}-<slug>.md"
```

4. **Write the PRD** at `$prd_path` using this template (replace `<…>` placeholders — do NOT leave TBDs):

```markdown
# <Feature Title>

**Date:** <YYYY-MM-DD>
**Slug:** <slug>
**Status:** Draft

## Problem Statement

<From the user's perspective. 2-4 sentences.>

## Solution

<From the user's perspective. 2-4 sentences.>

## User Stories

1. US-1: As a <actor>, I want <feature>, so that <benefit>.
2. US-2: As a <actor>, I want <feature>, so that <benefit>.
…

## Acceptance Criteria

### US-1
- AC-1.1: <specific observable behaviour>
- AC-1.2: …

### US-2
- AC-2.1: …

## Implementation Decisions

<Module-level. NO file paths. NO code snippets. Cover: modules affected, interfaces, data shape, integration points.>

## Testing Decisions

<What to test. Reference similar tests in the codebase by module name, not path. External behaviour only.>

## Out of Scope

<Bullet list.>

## Further Notes

<Anything else.>

## Story Checklist

- [ ] US-1
- [ ] US-2
…
```

5. **Set session title** by emitting Claude Code's `UserPromptSubmit` output JSON:

```
{"sessionTitle": "feat:<slug>"}
```

6. **Announce completion** and the path.

## Rules

- **No file paths in the PRD.** Implementation Decisions stay module-level.
- **User stories get unique `US-N` ids.** Acceptance criteria get `AC-<story>.<M>` ids.
- **Long user-story list** — aim for 10+ stories covering all aspects of the feature.
- **Story Checklist must match the US-N ids exactly** — `/code:implement` ticks them.
