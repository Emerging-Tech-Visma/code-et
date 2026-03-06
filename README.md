# code-et

Team development workflow powered by Claude Code + plugins.

Bun + Next.js project using task-driven development — no GitHub issues, pure Claude Code task workflow.

> **When to use code-et:** Complex features with 3+ tasks, dependencies, or parallel execution. For simple 1-2 file changes, vanilla Claude Code (plan mode or direct prompting) works great on its own.

## Workflow

```
+------------------------------------------------------------------+
|                    CLAUDE CODE + PLUGINS FLOW                     |
+------------------------------------------------------------------+

  1. PLAN + CREATE TASKS
  +-----------------------------------+
  | /code:plan-issue                  |  <-- code-et plugin
  | - Detects stack (TS/Py/Rust)      |
  | - LSP: go-to-def, refs, hover    |
  | - Explores approaches (user pick) |
  | - Creates tasks with file:line    |
  +-----------------------------------+
  |
  OR (manual)
  +---------------------------+
  | Shift+Tab (Plan Mode)     |  <-- Claude Code native
  | + TaskCreate (native)     |
  +---------------------------+
            |
  2. IMPLEMENT
  +-----------------------------------+
  | /code:implement                   |  <-- code-et plugin
  |                                   |
  | Subagent mode (default):          |
  |   Orchestrator (bg)               |
  |   +-- Implementer 1 (wt)         |
  |   +-- Implementer 2 (wt)         |
  |   +-- Implementer N (wt)         |
  |                                   |
  | Team mode (--team):               |
  |   Lead → Teammate 1..N            |
  |   Each claims + implements tasks  |
  |                                   |
  |   Each implementer/teammate:      |
  |   - Hard verification             |
  |   - Auto-commit on pass           |
  |                                   |
  |   /simplify (auto, end)           |  <-- Official plugin
  +-----------------------------------+

  wt = git worktree (always-on)    bg = background agent
```

### Git Branch Flow

```
  main ---------.---------------*---
                 \             /
                  feature/x -*--*
                              ^  ^
                            task commits
```

### Plugin Stack

```
  +----------------------------------------------+
  | Claude Code (native)                         |
  | - Plan Mode, TaskCreate, gh CLI, worktrees   |
  +----------------------------------------------+
  | Official Plugins                             |
  | - commit-commands  (commit, push, PR)        |
  | - code-review      (PR review)               |
  | - code-simplifier  (/simplify)               |
  | - typescript-lsp   (LSP navigation)          |
  +----------------------------------------------+
  | code-et plugin (execution engine)            |
  | - /code:plan-issue (LSP research → tasks)    |
  | - /code:implement  (orchestrator+subagents)  |
  | - /code:setup      (stack detection)         |
  | - /code:cleanup    (CLAUDE.md organization)  |
  | - /code:bun-init   (project scaffolding)     |
  +----------------------------------------------+
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
├── code-et-implementer/                    ← plugin subdirectory
│   ├── .claude-plugin/
│   │   ├── plugin.json               ← plugin identity (name, version)
│   │   └── settings.json             ← permissions, env vars, spinner tips
│   ├── CLAUDE.md                     ← instructions loaded when plugin is active
│   ├── agents/                       ← subagent definitions
│   │   ├── orchestrator.md
│   │   └── implementer.md
│   ├── commands/                     ← slash commands (skills)
│   │   ├── implement.md
│   │   ├── setup.md
│   │   └── cleanup.md
│   ├── hooks/
│   │   └── hooks.json                ← lifecycle hooks
│   └── scripts/                      ← shell scripts invoked by hooks
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
mkdir -p code-et-implementer/{agents,commands,hooks,scripts}
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
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "70"
  },
  "permissions": {
    "allow": ["Bash(git:*)", "Bash(gh:*)", "Bash"]
  }
}
```

### Step 6: Add Commands (Skills)

Each `.md` file in `code-et-implementer/commands/` becomes a skill callable as `/code:<filename>`.

| File           | Skill             |
| -------------- | ----------------- |
| `implement.md` | `/code:implement` |
| `setup.md`     | `/code:setup`     |
| `cleanup.md`   | `/code:cleanup`   |
| `pr.md`        | `/code:pr`        |
| `bun-init.md`  | `/code:bun-init`  |

Commands are markdown files with instructions that Claude follows when the skill is invoked.

### Step 7: Add Agents

Each `.md` file in `code-et-implementer/agents/` becomes a subagent type callable as `code:<filename>`.

| File              | Subagent type       |
| ----------------- | ------------------- |
| `orchestrator.md` | `code:orchestrator` |
| `implementer.md`  | `code:implementer`  |

Agents are spawned via the `Agent` tool with `subagent_type: "code:orchestrator"`.

### Step 8: Add Hooks and Scripts

`code-et-implementer/hooks/hooks.json` defines lifecycle hooks. Scripts go in `code-et-implementer/scripts/` and are referenced via `${CLAUDE_PLUGIN_ROOT}/scripts/`:

```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "code:implementer",
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

### Step 9: Add Plugin CLAUDE.md

`code-et-implementer/CLAUDE.md` contains instructions loaded when the plugin is active. This is where you document workflow rules, conventions, and project standards.

### Step 10: Publish

Commit your plugin files, push to a branch, and create a PR. After merging to main, the marketplace is live.

## How to Install the code-et Plugin

Open Claude Code and run:

```
/plugin marketplace add Emerging-Tech-Visma/code-et
```

Then install the plugin:

```
/plugin install code@code-et
```

> If SSH fails, use the HTTPS workaround: `/plugin` → Marketplaces → Add → paste `Emerging-Tech-Visma/code-et`

After installation, these skills are available:

- `/code:plan-issue` — LSP research → native tasks with file:line refs
- `/code:implement` — orchestrator + parallel implementers in worktrees
- `/code:setup` — detect stack, generate settings
- `/code:cleanup` — refactor CLAUDE.md
- `/code:bun-init` — scaffold Bun + Next.js project

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

After installation, verify skills are available by typing `/code:` — you should see implement, setup, cleanup, and bun-init.

## Local Development

Test plugin changes instantly without the install/update/restart cycle:

```bash
claude --plugin-dir /path/to/code-et/code-et-implementer
```

This loads all commands, agents, and hooks directly from disk. Works from any project folder — hook scripts resolve via `${CLAUDE_PLUGIN_ROOT}`.

Verify: type `/code:` and confirm all skills appear.

## Prerequisites

- **Claude Code** — `npm install -g @anthropic-ai/claude-code`
- **Bun** — `curl -fsSL https://bun.sh/install | bash`
- **GitHub CLI (`gh`)** — used by plugins for PRs, issues, and code review ([install](https://cli.github.com/))

## Getting Started

```bash
git clone https://github.com/Emerging-Tech-Visma/code-et.git
cd code-et
bun install
bun dev
```

## Plugin Installation

**Official plugins (Claude Code):**

```
/plugin install commit-commands@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
/plugin install rust-analyzer-lsp@claude-plugins-official
/plugin install pyright-lsp@claude-plugins-official
/plugin install frontend-design@claude-plugins-official
```

**code-et plugin** (add marketplace, then install):

```
/plugin marketplace add Emerging-Tech-Visma/code-et
/plugin install code@code-et
```

## Skills Reference

### code-et plugin

| Skill              | Description                                                                                                                                                     |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/code:plan-issue` | Research codebase with LSP, plan feature, create native tasks with file:line refs and dependencies                                                              |
| `/code:setup`      | Detects project stack and generates `.claude/settings.json` with permissions                                                                                    |
| `/code:implement`  | Picks up native tasks. Subagent mode (default): orchestrator + parallel implementers in worktrees. Team mode (`--team`): Agent Swarm with distributed teammates |
| `/code:cleanup`    | Refactors CLAUDE.md — keeps root lean, moves details to `.claude/rules/`                                                                                        |
| `/code:bun-init`   | Scaffolds new Bun + Next.js + Shadcn/UI project with Docker and GCP Cloud Run setup                                                                             |

### Official plugins

| Skill              | Plugin          | Description                                                                                                                                                     |
| ------------------ | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/commit`          | commit-commands | Creates a git commit with auto-generated message                                                                                                                |
| `/commit-push-pr`  | commit-commands | Creates branch, commits, pushes, and opens a PR in one step                                                                                                     |
| `/clean_gone`      | commit-commands | Removes local branches marked as `[gone]` (deleted on remote), including associated worktrees                                                                   |
| `/code-review`     | code-review     | Multi-agent PR review — 5 parallel agents check CLAUDE.md compliance, bugs, git history, past PR comments, and code comments. Scores each finding by confidence |
| `/frontend-design` | frontend-design | Creates distinctive, production-grade UI components with bold design direction. Avoids generic AI aesthetics                                                    |
| `/simplify`        | code-review     | Reviews changed code for reuse, quality, and efficiency, then fixes issues found                                                                                |

## Project Setup

After plugins are installed, run inside the project:

```bash
claude
# then inside Claude Code:
/code:setup
```

This auto-detects the stack and configures `.claude/settings.json` permissions.

## Configuration

### Settings (`~/.claude/settings.json`)

All environment variables go in the `env` block of your settings file:

```json
{
  "env": {
    "ENABLE_LSP_TOOL": "1",
    "CLAUDE_CODE_TASK_LIST_ID": "my-project-tasks",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "70"
  }
}
```

| Variable                               | Purpose                                              |
| -------------------------------------- | ---------------------------------------------------- |
| `ENABLE_LSP_TOOL`                      | Set to `"1"` to enable LSP (required for LSP plugins) |
| `CLAUDE_CODE_TASK_LIST_ID`             | Scoped task list name for persistence across sessions |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Set to `"1"` to enable Agent Swarm team mode          |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`      | Context auto-compact threshold (default: 70)          |

Task persistence lets `/code:implement` resume interrupted work across sessions via a manifest file at `.claude/<id>.json`.

### Execution Modes

`/code:implement` runs in subagent mode by default (orchestrator + parallel implementers in worktrees). Pass `--team` to use Agent Swarm team mode instead.

### LSP Setup (optional, recommended)

LSP powers `/code:plan-issue` deep research (goToDefinition, findReferences, hover). Three things needed:

1. **Enable LSP tool** — add `ENABLE_LSP_TOOL: "1"` to env in `~/.claude/settings.json` (must be `"1"`, not `"true"`)
2. **Install LSP plugins:**
   - `typescript-lsp` — for TS/JS (detects tsconfig.json)
   - `pyright-lsp` — for Python (detects pyproject.toml)
   - `rust-analyzer-lsp` — for Rust (detects Cargo.toml)
3. **Language server binaries in $PATH:**
   - `typescript-language-server` — `npm i -g typescript-language-server`
   - `pyright` / `pyright-langserver` — `npm i -g pyright`

The env var gates the feature; plugins configure the connection; binaries do the work. Without LSP, `/code:plan-issue` falls back to Grep/Read (works but less precise).

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
