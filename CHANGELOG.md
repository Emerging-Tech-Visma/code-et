# Changelog

All notable changes to the code-et plugin will be documented in this file.

## [1.11.0] - 2026-03-03

### Changed

- Remove default worktree isolation from implementer agent — was causing file write failures
- Worktree isolation is now opt-in via `--worktree` flag on `/code:implement`
- Orchestrator checks `metadata.files` overlap between concurrent tasks before using worktrees
- Tasks with overlapping files or missing file metadata always run in the main working tree

## [1.10.0] - 2026-03-03

### Added

- `/code:plan-issue` command — research codebase with LSP precision (TypeScript/Python/Rust), explore approaches with user selection, and create native tasks with `file:line` references and dependencies
- Multi-language LSP detection: auto-selects `typescript-lsp`, `pyright-lsp`, or `rust-analyzer-lsp` based on project files
- Quality gate phase ensuring every task has file:line refs, verification command, and success criteria
- `expected_outcome` field in task metadata (backwards compatible with `/code:implement`)

## [1.0.0] - 2026-03-02

### Added

- `/code:implement` — orchestrator + parallel implementers in worktrees
- `/code:setup` — stack detection and settings generation
- `/code:pr` — GitHub PR creation
- `/code:cleanup` — CLAUDE.md refactoring
- `/code:bun-init` — Bun + Next.js project scaffolding
- Team mode (`--team`) with Agent Swarm support
- Verification gate hooks for implementer subagents
