---
context: fork
allowed-tools: Bash(ls:*), Bash(cat:*), Bash(find:*), Bash(grep:*), Bash(mkdir:*), Bash(chmod:*), Read, Write, AskUserQuestion
description: Detect project stack, generate settings.json permissions and deployment scripts
---

# Project Setup

Detect project stack and configure Claude Code settings + deployment scripts.

## Phase 1: Detect Stack

```bash
ls bun.lock 2>/dev/null && echo "Bun detected"
ls package-lock.json 2>/dev/null && echo "npm detected"
ls pnpm-lock.yaml 2>/dev/null && echo "pnpm detected"
ls pyproject.toml 2>/dev/null && echo "Python detected"
ls Cargo.toml 2>/dev/null && echo "Rust detected"
ls go.mod 2>/dev/null && echo "Go detected"
ls next.config.* 2>/dev/null && echo "Next.js detected"
ls vite.config.* 2>/dev/null && echo "Vite detected"
ls firebase.json 2>/dev/null && echo "Firebase detected"
ls Dockerfile 2>/dev/null && echo "Docker detected"
ls tsconfig.json 2>/dev/null && echo "TypeScript detected"
cat .claude/settings.json 2>/dev/null || echo "No settings.json found"
```

## Phase 2: Generate Settings

Based on detected stack, generate `.claude/settings.json`:

| Stack       | Allow                                                     | Deny                         |
| ----------- | --------------------------------------------------------- | ---------------------------- |
| Bun         | `bun:*`, `bunx:*`, `bun test:*`, `bun run:*`              | —                            |
| npm         | `npm:*`, `npx:*`                                          | —                            |
| Python (uv) | `uv:*`, `uv run:*`                                        | —                            |
| Firebase    | `firebase:*`, `firebase deploy:*`, `firebase emulators:*` | `firebase projects:delete:*` |
| Docker      | `docker:*`, `docker compose:*`                            | `docker system prune:*`      |
| GCP         | `gcloud:*`                                                | `gcloud projects delete:*`   |
| General     | `git:*`, `gh:*`, `tsc:*`                                  | `rm -rf:*`                   |

Always include:

```json
{
  "plansDirectory": "plans",
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "70",
    "CLAUDE_CODE_TASK_LIST_ID": "<project-name>-tasks"
  }
}
```

## Phase 3: Deployment Scripts

Use AskUserQuestion: **Generate deployment scripts?** [Yes / No]. If yes, ask deployment target (Firebase Hosting / GCP Cloud Run / Skip).

Create `scripts/` directory with `dev.sh`, `deploy-staging.sh`, `deploy-production.sh`.

### Firebase Hosting Scripts

**dev.sh:** `set -e`, install deps if needed, `bun run dev`
**deploy-staging.sh:** `set -e`, `bun run build`, `firebase deploy --only hosting:staging`
**deploy-production.sh:** `set -e`, require `$1 == "yes"`, `bun run build`, `firebase deploy --only hosting:production`

### GCP Cloud Run Scripts

**dev.sh:** `set -e`, install deps if needed, `bun run dev`
**deploy-staging.sh:** `set -e`, source `.env`, validate `GCP_PROJECT_STAGING`, deploy with `--cpu 1 --memory 512Mi --min-instances 0 --max-instances 3`
**deploy-production.sh:** `set -e`, require `$1 == "yes"`, source `.env`, validate `GCP_PROJECT_PROD`, `bun test`, deploy with `--cpu 2 --memory 1Gi --min-instances 1 --max-instances 10 --cpu-boost`

After generating: `chmod +x scripts/*.sh`

## Phase 4: Update CLAUDE.md & Report

If deployment scripts were generated, append deployment docs to `.claude/CLAUDE.md`.

Output: settings path, deployment script paths, and next steps (review settings, set env vars, run dev.sh).
