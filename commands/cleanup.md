---
allowed-tools: Read, Write, Glob, Grep, Edit, AskUserQuestion, Bash(mkdir:*)
description: Refactor CLAUDE.md and auto-memory for progressive disclosure
---

# Cleanup Context Files

Refactor CLAUDE.md and auto-memory using progressive disclosure. Keep root files lean, move detailed rules to `.claude/rules/`.

## Step 1: Find Context Files

```
Glob: **/CLAUDE.md
```

Read each file found.

## Step 2: Detect Contradictions

Scan for conflicting instructions (e.g., "Always use X" vs "Never use X", different values for same setting).

For each contradiction: `AskUserQuestion` with options [Keep first, Keep second, Keep both (clarify context), Delete both].

## Step 3: Categorize Instructions

| Category   | Destination                   |
| ---------- | ----------------------------- |
| Essential  | Root CLAUDE.md                |
| Workflow   | Root CLAUDE.md (always keep)  |
| TypeScript | `.claude/rules/typescript.md` |
| Testing    | `.claude/rules/testing.md`    |
| Git        | `.claude/rules/git.md`        |
| API        | `.claude/rules/api.md`        |
| Delete     | (removed)                     |

## Step 4: Flag Items for Deletion

Identify redundant, stale, or obvious items. For each: `AskUserQuestion` with options [Delete, Keep in root, Move to rules].

## Step 5: Create Rules Structure

```bash
mkdir -p .claude/rules
```

Each rule file: `# [Category] Rules` → `_Loaded when working on [category] files_` → sections with specific rules.

## Step 6: Write Minimal Root CLAUDE.md

Target: **Under 50 lines.** Must include: project name (1-2 lines), architecture (5-10 lines), critical rules (10-15 lines), Plugin Usage table, reference to `.claude/rules/`.

## Step 7: Organize Auto-Memory

Review `~/.claude/projects/*/memory/`: deduplicate, remove stale entries (>30 days unless recurring), ensure MEMORY.md under 200 lines. Confirm with user before cleanup.

## Step 8: Report Summary

Output before/after line counts, rules files created, items deleted, auto-memory changes, and user decisions made.

## Rules

- **Never delete without asking** - Always get user confirmation
- **Progressive disclosure** - Root file is entry point, details in rules/
- **Keep it lean** - Root CLAUDE.md under 50 lines
- **Auto-memory hygiene** - MEMORY.md under 200 lines
