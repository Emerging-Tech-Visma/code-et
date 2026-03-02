---
allowed-tools: Bash(gh:*), Bash(git:*), Write
description: Create GitHub PR with auto-generated description
---

# Create Pull Request

Create a PR with auto-generated description from branch commits.

## Step 1: Check Branch State

```bash
git branch --show-current
git status --short
```

If on main/master → Warn user to create feature branch.

**If uncommitted changes exist:**

1. Stage all changes: `git add -A`
2. Auto-commit with: `Skill("commit-commands:commit")`
3. Continue to Step 2

## Step 2: Get Branch Diff

```bash
git log main..HEAD --oneline
git diff main...HEAD --stat
```

Identify:

- All commits on this branch
- Files changed
- Purpose of the changes

## Step 3: Generate PR Description

Format:

```markdown
## Summary

[1-2 sentences describing what this PR does]

## Changes

- [Bullet points of key changes]

## Testing

- [ ] Tests pass
- [ ] Manual testing done

---

Created with `/code:pr`
```

## Step 4: Write Description to File

### CRITICAL: No Heredocs

Heredocs fail silently in sandbox → empty PR body. **Use Write tool only.**

Write description to `.claude-pr-body.md` using Write tool.

## Step 5: Validate & Create PR

### Validation (REQUIRED)

Before creating PR, verify file exists:

```bash
if [ ! -s .claude-pr-body.md ]; then
  echo "ERROR: .claude-pr-body.md missing or empty."
  echo "Use Write tool to create it first."
  exit 1
fi
echo "PR body validated ($(wc -l < .claude-pr-body.md) lines)"
```

### Create PR

```bash
gh pr create --title "<type>: <summary>" --body-file .claude-pr-body.md
```

Title format matches commit convention:

- `feat: add user authentication`
- `fix: resolve login redirect loop`

## Step 6: Output Result

Show:

- PR URL
- Title
- Target branch (usually main)

## Rules

- **No heredocs** - Always use `--body-file`
- **Auto-commit uncommitted changes** - Never create PR with dirty working tree
- **Don't force push** - Let user handle that manually
