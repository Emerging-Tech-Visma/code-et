---
allowed-tools: Read, Write, Glob, Grep, Edit, AskUserQuestion, Bash(mkdir:*)
description: Refactor CLAUDE.md and auto-memory for progressive disclosure
---

Refactor CLAUDE.md: move detailed rules to `.claude/rules/`, keep root under 50 lines. Detect contradictions — ask user to resolve. Organize auto-memory (target < 200 lines). Never delete without asking.
