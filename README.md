# code-et

Pure-Rust Clean Architecture workflow powered by Claude Code + plugins.

Task-driven development for Rust full-stack projects (`axum + sqlx + Dioxus 0.7+ + tokio`). Bootstraps new projects with the Dependency Rule enforced at the Cargo level. Ships a CI gate (`.github/workflows/code-et-audit.yml`) that fails PRs on slop. Doctrine in [`code-et-implementer/docs/`](code-et-implementer/docs/) covers architecture, anti-slop, and per-layer testing.

> **When to use code-et:** Single bugs benefit from `/code:go`'s scoping (intake → Task Brief, you implement). Complex features with 3+ tasks, dependencies, or parallel execution get the full PRD-driven lane. New projects start with `/code:bootstrap`. For 1-2 file changes you already understand, direct prompting works fine.

## What's new in v3.9.0

- **`/code:bootstrap`** — scaffold a pure-Rust project (4-crate Clean Architecture workspace + Dioxus 0.7+ for web/desktop/mobile + sqlx for SQLite/Postgres + axum for the server).
- **`/code:install-ci`** — drop the audit GitHub workflow + layer validator into an existing Rust repo.
- **CLAUDE.md as control plane** — `code-et-implementer/CLAUDE.md` §"Clean Architecture (Rust)" tells Claude when to invoke the engineering plugin's skills (`code-review`, `tech-debt`, `testing-strategy`, `system-design`) with Clean Architecture context.
- **Doctrine** — [`docs/architecture.md`](code-et-implementer/docs/architecture.md), [`docs/anti-slop.md`](code-et-implementer/docs/anti-slop.md), [`docs/testing.md`](code-et-implementer/docs/testing.md). Loaded on demand by the skills.
- **Companion plugins**: hard-depend on `knowledge-work-plugins/engineering` and `rust-analyzer-lsp` (replaces the old `typescript-lsp` recommendation).
- v3.10.0 preview: `/code:audit` will mirror the CI gate locally for fast feedback.

## Workflows

code-et ships **two distinct lanes**. They share no midpoint — `/code:go` does NOT chain into `/code:plan-issue` or `/code:implement`. The user reads the brief and decides next steps.

### Bug lane — single fix, scope-and-go

```
/code:go  →  (user implements directly)  →  /commit-push-pr
 intake       1-3 file edits, no swarm        PR
```

`/code:go` produces a Task Brief and stops. Most bugs are 1-3 file edits — no orchestration needed. If the work spans multiple coherent vertical slices, it's a feature in disguise — write a PRD instead.

### Feature lane — PRD-driven, vertically sliced

```
/code:grill  →  /code:prd  →  /code:plan-issue  →  /code:implement  →  /commit-push-pr
 interview      PRD file        vertical slices       parallel agents     PR (+ /ultrareview hint)
```

- `/code:grill` runs a one-question-at-a-time interview, refusing to converge until scope, constraints, and success criteria are explicit.
- `/code:prd` writes the PRD to `plans/YYYY-MM-DD-<branch-slug>.md` with `US-N` / `AC-N.M` checkboxes.
- `/code:plan-issue` is **PRD-only**. It decomposes into **vertical slices** — each task implements UI ↔ logic ↔ API ↔ DB end-to-end and is testable as a unit. When a slice supersedes existing code, deletion of the old code is part of the same commit (no parallel utilities, no `// TODO: remove old X`).
- `/code:implement` prefixes each commit with `US-N:` / `AC-N.M:` / `chore:` and ticks the PRD checkbox for that story.

> Tip: for richer upstream planning, run `/ultraplan` (built-in Claude Code command, research preview) before `/code:plan-issue` and commit its output to `plans/`.

### PRD file convention

- Path: `plans/YYYY-MM-DD-<slug>.md` where `<slug>` = current branch with `feature/`, `fix/`, or `chore/` prefix stripped.
- Structure: problem, goals, user stories `US-N`, acceptance criteria `AC-N.M`, open questions, story checklist.
- Most recent date wins when multiple match the branch slug.
- Resolved by `scripts/resolve-prd.sh`; consumed by SessionStart, PreCompact, TaskCreated, and `/code:implement`.

### Dependencies

- `/ultrareview` is suggested (not required) after PR creation.
- `/ultraplan` is optional — a built-in Claude Code command (research preview) you can run manually upstream of `/code:plan-issue`.

### Git Branch Flow

```
  main ---------.---------------*---
                 \             /
                  feature/x -*--*
                              ^  ^
                            task commits
```

### How the Plugins Work Together

**Bug lane** — single fix, no orchestration:

```
  YOU: "fix the broken submit button"
   │
   ▼
  /code:go ─── scopes ────────▶ identifies app, screen, files
   │                             generates/updates FILE-REFERENCE.md
   ▼ Task Brief (stops here)
  (you implement directly — 1-3 file edits)
   │
   ▼ code ready
  /commit-push-pr ─── runs ───▶ git commit + push + gh pr create
```

**Feature lane** — PRD-driven, vertically sliced, parallel execution:

```
  YOU: "add dark mode support"
   │
   ▼
  /code:grill ─── refines ────▶ scope, constraints, success criteria
   │
   ▼ refined brief
  /code:prd ─── writes ───────▶ plans/YYYY-MM-DD-<slug>.md
   │                             US-N stories, AC-N.M checkboxes
   ▼ PRD
  /code:plan-issue ─── uses ──▶ LSP for symbol-level precision
   │                             vertical-slice decomposition
   │                             each task: UI ↔ logic ↔ API ↔ DB
   ▼ tasks
  /code:implement ─── spawns ──▶ parallel agents (worktree isolation)
   │                             each agent: edit, test, commit
   │                             deletes superseded code in same commit
   ▼ code ready
  /commit-push-pr ─── runs ───▶ git commit + push + gh pr create
   │
   ▼ PR open
  /code-review ─── spawns ────▶ 5 review agents in parallel
   │
   ▼ merged
  /revise-claude-md ──────────▶ update CLAUDE.md with learnings
```

**Plugin responsibilities:**

```
  +-------------------+--------------------------------------------+
  | Plugin            | What it does                               |
  +-------------------+--------------------------------------------+
  | code-et           | /go          — single-bug intake → Task Brief |
  |   (this repo)     | /grill       — interview to refine an idea    |
  |                   | /prd         — synthesize PRD from session    |
  |                   | /plan-issue  — PRD → vertical-slice tasks     |
  |                   | /implement   — parallel agents in worktrees   |
  +-------------------+--------------------------------------------+
  | commit-commands   | /commit      — auto-message git commit     |
  |   (official)      | /commit-push-pr — branch + commit + PR     |
  |                   | /clean_gone  — prune merged branches       |
  +-------------------+--------------------------------------------+
  | code-review       | /code-review — multi-agent PR review       |
  |   (official)      | /simplify    — refactor changed code       |
  +-------------------+--------------------------------------------+
  | typescript-lsp    | LSP navigation for /code:plan-issue        |
  |   (official)      | goToDefinition, findReferences, hover      |
  +-------------------+--------------------------------------------+
  | claude-md-mgmt    | /revise-claude-md  — update CLAUDE.md      |
  |   (official)      | /claude-md-improver — audit & improve      |
  +-------------------+--------------------------------------------+
  | frontend-design   | /frontend-design — production-grade UI     |
  |   (official)      | bold design, avoids generic AI aesthetics  |
  +-------------------+--------------------------------------------+
  | feature-dev       | /feature-dev — guided feature development   |
  |   (official)      | codebase analysis + architecture focus      |
  +-------------------+--------------------------------------------+
  | skill-creator     | /skill-creator — create & optimize skills   |
  |   (official)      | build skills, run evals, benchmark          |
  +-------------------+--------------------------------------------+
  | agent-sdk-dev     | Claude Agent SDK development helper         |
  |   (official)      | build custom agents with Agent SDK          |
  +-------------------+--------------------------------------------+
```

**Install all plugins:**

```
# Official plugins (from claude-plugins-official)
/plugin install commit-commands@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official
/plugin install frontend-design@claude-plugins-official
/plugin install feature-dev@claude-plugins-official
/plugin install skill-creator@claude-plugins-official
/plugin install agent-sdk-dev@claude-plugins-official

# code-et (from this repo)
/plugin marketplace add Emerging-Tech-Visma/code-et
/plugin install code@code-et
```

## Building a Plugin from Scratch

This section documents how the code-et plugin was built — use it as a guide for creating your own Claude Code marketplace plugin.

### Step 1: Repository Structure

A marketplace repo has two levels:

- **Root** `.claude-plugin/marketplace.json` — declares which plugins exist and where to find them
- **Subdirectory** (e.g. `code-et-implementer/`) — contains the actual plugin with its own `.claude-plugin/plugin.json`

```
my-repo/                              ← GitHub repo root
├── .claude-plugin/
│   └── marketplace.json              ← marketplace manifest (points to subdirs)
├── code-et-implementer/              ← plugin subdirectory
│   ├── .claude-plugin/
│   │   ├── plugin.json               ← plugin identity (name, version)
│   │   └── settings.json             ← permissions, env vars, spinner tips
│   ├── CLAUDE.md                     ← instructions loaded when plugin is active
│   ├── commands/                     ← slash commands (skills)
│   │   ├── plan-issue.md
│   │   └── implement.md
│   ├── hooks/
│   │   └── hooks.json                ← lifecycle hooks
│   └── scripts/                      ← shell scripts invoked by hooks
│       ├── inject-rules.sh
│       ├── verify-gate.sh
│       └── run-tests.sh
├── README.md                         ← repo docs (not part of plugin)
└── package.json                      ← repo-level config (not part of plugin)
```

> **Key rule:** `marketplace.json` uses `"source": "./code-et-implementer"` — the source must point to a subdirectory, never `"."`.

### Step 2: Create the Directory Structure

```bash
# From your repo root
mkdir -p code-et-implementer/.claude-plugin
mkdir -p code-et-implementer/{commands,hooks,scripts}
mkdir -p .claude-plugin
```

### Step 3: Marketplace Manifest

Create `.claude-plugin/marketplace.json` at the **repo root**:

```json
{
  "name": "code-et",
  "owner": {
    "name": "Your Name"
  },
  "metadata": {
    "description": "Task-driven coding workflow with parallel agents in worktrees",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "code",
      "source": "./code-et-implementer",
      "description": "Task-driven coding workflow with native Task tools."
    }
  ]
}
```

- `name` — marketplace name (matches the repo)
- `plugins[].name` — becomes the skill prefix (`/code:*`)
- `plugins[].source` — relative path to the plugin subdirectory

### Step 4: Plugin Identity

Create `code-et-implementer/.claude-plugin/plugin.json`:

```json
{
  "name": "code",
  "version": "1.0.0",
  "description": "Task-driven coding workflow with native Task tools.",
  "author": {
    "name": "Your Name"
  },
  "license": "MIT",
  "keywords": ["coding", "workflow", "agents"]
}
```

The `name` field here **must match** the `plugins[].name` in `marketplace.json`. This determines the skill prefix — `"code"` means `/code:implement`, `/code:setup`, etc.

### Step 5: Plugin Settings

Create `code-et-implementer/.claude-plugin/settings.json`:

```json
{
  "plansDirectory": "plans",
  "permissions": {
    "allow": ["Bash(git:*)", "Bash(gh:*)", "Bash"]
  }
}
```

### Step 6: Add Commands (Skills)

Each `.md` file in `code-et-implementer/commands/` becomes a skill callable as `/code:<filename>`.

| File             | Skill              |
| ---------------- | ------------------ |
| `plan-issue.md`  | `/code:plan-issue` |
| `implement.md`   | `/code:implement`  |

Commands are markdown files with instructions that Claude follows when the skill is invoked.

### Step 7: Add Hooks and Scripts

`code-et-implementer/hooks/hooks.json` defines lifecycle hooks. Scripts go in `code-et-implementer/scripts/` and are referenced via `${CLAUDE_PLUGIN_ROOT}/scripts/`:

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/verify-gate.sh"
          }
        ]
      }
    ]
  }
}
```

> **Tip:** Use `claude --plugin-dir ./your-plugin-dir` to test locally without installing. Hook scripts resolve via `${CLAUDE_PLUGIN_ROOT}`, and skill `.md` files can reference sibling files via `${CLAUDE_SKILL_DIR}`.

### Step 8: Add Plugin CLAUDE.md

`code-et-implementer/CLAUDE.md` contains instructions loaded when the plugin is active. This is where you document workflow rules, conventions, and project standards.

### Step 9: Publish

Commit your plugin files, push to a branch, and create a PR. After merging to main, the marketplace is live.

## How to Install the code-et Plugin

Open Claude Code and run:

```
/plugin marketplace add Emerging-Tech-Visma/code-et

# Pin to a specific version:
/plugin marketplace add Emerging-Tech-Visma/code-et@v1.18.4
```

Then install the plugin:

```
/plugin install code@code-et
```

> If SSH fails, use the HTTPS workaround: `/plugin` → Marketplaces → Add → paste `Emerging-Tech-Visma/code-et`

After installation, these skills are available:

- `/code:go` — single-bug intake → Task Brief; generates FILE-REFERENCE.md (does not chain into plan-issue/implement)
- `/code:grill` — refine an idea via one-question-at-a-time interview
- `/code:prd` — synthesize a PRD from the current conversation
- `/code:plan-issue` — PRD → vertical-slice tasks anchored at `file:line`
- `/code:implement` — parallel agents in worktree isolation

For CLAUDE.md maintenance, use the `claude-md-management` plugin (`/revise-claude-md`, `/claude-md-improver`).
For commits and PRs, use the companion `commit-commands` plugin (`/commit`, `/commit-push-pr`).

To update after new commits are pushed:

```
/plugin  →  Marketplaces  →  code-et  →  Update
```

## Clone & Install from GitHub

Clone the repo and add it as a marketplace source:

```bash
git clone https://github.com/Emerging-Tech-Visma/code-et.git
```

Then in Claude Code:

```
/plugin marketplace add Emerging-Tech-Visma/code-et
/plugin install code@code-et
```

After installation, verify skills are available by typing `/code:` — you should see go, plan-issue, and implement.

## Local Development

Test plugin changes instantly without the install/update/restart cycle:

```bash
claude --plugin-dir /path/to/code-et/code-et-implementer
```

This loads all commands, agents, and hooks directly from disk. Works from any project folder — hook scripts resolve via `${CLAUDE_PLUGIN_ROOT}`.

Verify: type `/code:` and confirm all skills appear.

## Prerequisites

- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **Rust toolchain** — `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- **GitHub CLI (`gh`)** — used by plugins for PRs, issues, and code review ([install](https://cli.github.com/))
- **Audit tools** — `cargo install --locked cargo-machete cargo-audit cargo-deny cargo-nextest sqlx-cli dioxus-cli`

## Getting Started

```bash
# Existing Rust repo: install the CI gate
/code:install-ci

# Brand new Rust project: bootstrap from scratch
/code:bootstrap myapp --targets web,desktop,mobile --db sqlite
cd myapp
just db-migrate && just run-server
```

## Plugin Installation

**Required companions:**

```
/plugin marketplace add knowledge-work-plugins
/plugin install engineering@knowledge-work-plugins
/plugin install rust-analyzer-lsp@claude-plugins-official
```

The `engineering` plugin provides `code-review`, `tech-debt`, `testing-strategy`, and `system-design` skills that code-et's CLAUDE.md delegates to (see "Clean Architecture (Rust) — controlling rules" §"Delegation map"). `rust-analyzer-lsp` provides symbol-level precision for `/code:plan-issue` and `/code:go`.

**Other official plugins (recommended):**

```
/plugin install commit-commands@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official
/plugin install frontend-design@claude-plugins-official
/plugin install feature-dev@claude-plugins-official
/plugin install skill-creator@claude-plugins-official
/plugin install agent-sdk-dev@claude-plugins-official
```

> Other LSP plugins (`pyright-lsp`, `swift-lsp`) install per language — see [LSP Setup](#lsp-setup-optional-recommended) below.

**code-et plugin** (add marketplace, then install):

```
/plugin marketplace add Emerging-Tech-Visma/code-et
/plugin install code@code-et
```

## Skills Reference

### code-et plugin

| Skill              | Effort | Description                                                                                  |
| ------------------ | ------ | -------------------------------------------------------------------------------------------- |
| `/code:go`         | xhigh  | **Single-bug intake** — scopes app/screen/files → Task Brief (with per-file `Layer` on Rust). Does NOT chain into plan-issue/implement. Generates FILE-REFERENCE.md (non-derivable knowledge only) |
| `/code:grill`      | high   | Feature-lane intake — one-question-at-a-time interview refining scope, constraints, success criteria |
| `/code:prd`        | xhigh  | Writes PRD to `plans/YYYY-MM-DD-<slug>.md` with `US-N`/`AC-N.M` checklist                     |
| `/code:plan-issue` | xhigh  | **PRD-only.** LSP decomposition into vertical slices. Replaces, doesn't accumulate — superseded code deleted in same commit. Tags tasks `US-N`/`AC-N.M`/`chore:` plus `metadata.layer` on Rust projects |
| `/code:implement`  | xhigh  | Parallel agents in worktree isolation. Ships a dispatch template so subagents start cold with full context. Prefixes commits `US-N:`, ticks PRD checklist |
| `/code:bootstrap`  | xhigh  | Scaffold a pure-Rust full-stack project (axum + sqlx + Dioxus 0.7+ + tokio) with the 4-crate Clean Architecture workspace + CI gate |
| `/code:install-ci` | high   | Drop the audit GitHub workflow + layer-deps validator into an existing Rust repo |

### Official plugins

| Skill              | Plugin          | Description                                                                                                                                                     |
| ------------------ | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/commit`          | commit-commands | Creates a git commit with auto-generated message                                                                                                                |
| `/commit-push-pr`  | commit-commands | Creates branch, commits, pushes, and opens a PR in one step                                                                                                     |
| `/clean_gone`      | commit-commands | Removes local branches marked as `[gone]` (deleted on remote), including associated worktrees                                                                   |
| `/code-review`     | code-review     | Multi-agent PR review — 5 parallel agents check CLAUDE.md compliance, bugs, git history, past PR comments, and code comments. Scores each finding by confidence |
| `/frontend-design` | frontend-design | Creates distinctive, production-grade UI components with bold design direction. Avoids generic AI aesthetics                                                    |
| `/simplify`        | code-review     | Reviews changed code for reuse, quality, and efficiency, then fixes issues found                                                                                |
| `/revise-claude-md` | claude-md-management | Update CLAUDE.md with learnings from the current session                                                                                                  |
| `/claude-md-improver` | claude-md-management | Audit and improve CLAUDE.md files — scans, evaluates quality, makes targeted updates                                                                    |
| `/feature-dev`     | feature-dev     | Guided feature development with codebase understanding and architecture focus                                                                                   |
| `/skill-creator`   | skill-creator   | Create new skills, modify existing ones, run evals, benchmark performance                                                                                       |

## Configuration

### Settings (`~/.claude/settings.json`)

All environment variables go in the `env` block of your settings file:

```json
{
  "env": {
    "ENABLE_LSP_TOOL": "1",
    "CLAUDE_CODE_TASK_LIST_ID": "my-project-tasks",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

| Variable                               | Purpose                                              |
| -------------------------------------- | ---------------------------------------------------- |
| `ENABLE_LSP_TOOL`                      | Set to `"1"` to enable LSP (required for LSP plugins) |
| `CLAUDE_CODE_TASK_LIST_ID`             | Scoped task list name for persistence across sessions |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Set to `"1"` to enable Agent Swarm team mode          |

Task persistence lets `/code:implement` resume interrupted work across sessions via a manifest file at `.claude/<id>.json`.

### Execution Modes

`/code:implement` auto-selects the best mode based on task count:

| Mode | When | How |
|------|------|-----|
| Inline | 1 task, or 2 simple tasks | Implements directly in main session |
| Background | 2-5 independent tasks | Spawns agents in worktree isolation |
| Swarm | 5+ tasks or `--team` flag | Agent Swarm (requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) |

### LSP Setup (optional, recommended)

LSP powers symbol-level precision in `/code:plan-issue` (full decomposition) and `/code:go` (narrow — only when the user names a specific function/component/type). Without it, both fall back to Grep/Read — works, but less precise.

Three layers need to line up. Skip any one and LSP stays dark.

#### 1. Env var (gates the feature)

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "ENABLE_LSP_TOOL": "1"
  }
}
```

Must be the string `"1"`, not `"true"`. Restart Claude Code after editing.

#### 2. LSP plugins (configure the connection)

Install one per language you work in:

```
/plugin install typescript-lsp@claude-plugins-official     # TS/JS — detects tsconfig.json
/plugin install pyright-lsp@claude-plugins-official        # Python — detects pyproject.toml
/plugin install rust-analyzer-lsp@claude-plugins-official  # Rust — detects Cargo.toml
/plugin install swift-lsp@claude-plugins-official          # Swift — detects Package.swift
```

#### 3. Language server binaries (do the work)

Each plugin shells out to a binary that must be in `$PATH`:

| Language | Binary | Install |
|----------|--------|---------|
| TS/JS | `typescript-language-server` | `npm i -g typescript-language-server typescript` |
| Python | `pyright-langserver` | `npm i -g pyright` |
| Rust | `rust-analyzer` | `rustup component add rust-analyzer` *or* `brew install rust-analyzer` |
| Swift | `sourcekit-lsp` | Bundled with Xcode / Swift toolchain — no separate install |

#### 4. Verify

In a Claude Code session:

```bash
which typescript-language-server   # or pyright-langserver, rust-analyzer
```

Then ask Claude: *"use LSP to find the definition of `<symbolNameInThisProject>`"* — if it returns a `file:line`, all three layers are wired. If it falls back to grep, check the env var (most common miss) and restart.

> **Why three layers?** Env var is project-wide on/off. Plugins teach Claude *how* to talk to a specific server. Binaries do the actual analysis. Each layer is independent — diagnose by checking from the bottom up: binary in `$PATH` → plugin installed → env var set.

### Recommended Hooks

Auto-format on file writes with Prettier — add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "npx prettier --write \"$CLAUDE_TOOL_INPUT_FILE_PATH\""
          }
        ]
      }
    ]
  }
}
```

## GitHub Workflow: Multiple PRs

You can run several features in parallel, each on its own branch with its own PR.

### How it works

```
main ─────────────────────────────*────────*──── (deploy-ready)
       \                         /        /
        feature/auth ──PR #1────┘        /
       \                                /
        feature/dashboard ──PR #2──────┘
```

1. **Start a bug fix** — run `/code:go "broken submit button"` to scope, then implement the 1-3 file edits directly.
   **Start a feature** — run `/code:grill` (optional) → `/code:prd` to write a PRD → `/code:plan-issue` to create vertical-slice tasks → `/code:implement` for parallel execution. Each feature gets its own branch automatically.
2. **Open a PR** — run `/commit-push-pr`. This pushes the branch and creates a pull request on GitHub.
3. **Start the next piece of work** — switch back to main (`git checkout main`), then repeat step 1. Each PR is independent.

### Multiple PRs at the same time

Each PR is independent. You can have 2, 5, or 10 open PRs — they don't block each other unless they change the same files.

- **No conflicts** — each PR merges into main on its own. Click "Merge" on GitHub when the PR is approved.
- **Conflicts** — if two PRs change the same file, GitHub will flag it. Merge the first PR, then update the second branch (`git merge main`) to resolve.

### When does code reach production?

PRs sit on GitHub until someone merges them. Nothing goes to main (and therefore production) until a PR is explicitly merged. This gives the team time to review and approve.

Typical flow:
1. PR is created → team reviews
2. PR is approved → click "Merge pull request" on GitHub
3. Code is now on main → ready for deploy
