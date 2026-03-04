---
allowed-tools: Bash(cmux:*), Bash(git:*), AskUserQuestion
description: Set up a cmux workspace for the current feature branch. Use when the user wants to create a cmux workspace, set up their terminal layout for a feature, or prepare a multi-pane coding environment.
---

# Set up cmux workspace

Create a cmux workspace named after the current git branch with optional browser pane.

## Step 1: Verify cmux

```bash
cmux ping
```

If this fails, tell the user to start cmux first and stop here.

## Step 2: Get branch name

```bash
git branch --show-current
```

If detached HEAD or not a git repo, warn user and use directory name as fallback.

## Step 3: Create and name workspace

```bash
cmux new-workspace --cwd "$(pwd)"
cmux rename-workspace -- "<branch-name>"
```

## Step 4: Browser pane (optional)

Ask the user if they want a browser pane for dev server preview.

If yes:

```bash
cmux new-pane --type browser --direction right
cmux browser open http://localhost:3000
```

## Step 5: Confirm

Show `cmux tree` output and report workspace is ready.
