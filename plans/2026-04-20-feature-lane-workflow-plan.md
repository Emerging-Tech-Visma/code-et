# Feature Lane Workflow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship code-et v3.6.0 with a feature lane (`/code:grill` → `/code:prd` → `/code:plan-issue` → `/code:implement`) alongside the existing bug lane, backed by three new hooks (`SessionStart`, `TaskCreated`, `PreCompact`) and branch-matched PRDs in `plans/YYYY-MM-DD-<slug>.md`.

**Architecture:** Markdown slash-command files define command behaviour (model-executed); shell scripts in `code-et-implementer/scripts/` implement hooks; a shared `resolve-prd.sh` helper derives `plans/<date>-<slug>.md` from `git branch --show-current`. `/code:plan-issue` becomes a thin wrapper around `/ultraplan` (Anthropic cloud plan skill) with fallback to the existing LSP-only path; `/code:implement` tags every commit with `US-N:` prefix and ticks the PRD checklist.

**Tech Stack:** Claude Code plugin system (slash commands in markdown, hooks in `hooks.json`), POSIX shell for hook scripts, `bats-core` for shell tests (new dev dependency), git for branch/state resolution, `jq` for JSON parsing in hook scripts, Anthropic-hosted `/ultraplan` skill.

**Spec reference:** `plans/2026-04-20-feature-lane-workflow.md` (21 user stories US-1..US-21).

---

## File Structure

**New files:**

| Path | Purpose | US coverage |
|------|---------|-------------|
| `code-et-implementer/commands/grill.md` | `/code:grill` command definition | US-1..US-4 |
| `code-et-implementer/commands/prd.md` | `/code:prd` command definition | US-5..US-8 |
| `code-et-implementer/scripts/resolve-prd.sh` | Branch → PRD path resolver (shared helper) | US-16 |
| `code-et-implementer/scripts/session-start-prd.sh` | `SessionStart` hook: inject PRD pointer | US-15 |
| `code-et-implementer/scripts/task-created-tag-check.sh` | `TaskCreated` hook: enforce `user_story` tag | US-17 |
| `code-et-implementer/scripts/pre-compact-prd.sh` | `PreCompact` hook: inject open-stories summary | US-18 |
| `code-et-implementer/scripts/pr-created-suggest-review.sh` | `PostToolUse` hook on `gh pr create`: suggest `/ultrareview` | US-19 |
| `code-et-implementer/tests/resolve-prd.bats` | Tests for PRD resolver | — |
| `code-et-implementer/tests/session-start-prd.bats` | Tests for `SessionStart` hook | — |
| `code-et-implementer/tests/task-created-tag-check.bats` | Tests for `TaskCreated` hook | — |
| `code-et-implementer/tests/pre-compact-prd.bats` | Tests for `PreCompact` hook | — |
| `code-et-implementer/tests/fixtures/plans/…` | Fixture PRDs for tests | — |

**Modified files:**

| Path | Change | US coverage |
|------|--------|-------------|
| `code-et-implementer/commands/plan-issue.md` | Add PRD detection + `/ultraplan` wrapper + US-N tagging + LSP fallback | US-9..US-12, US-20 |
| `code-et-implementer/commands/implement.md` | Add US-N commit prefix + PRD checkbox tick | US-13, US-14 |
| `code-et-implementer/hooks/hooks.json` | Wire 4 new hooks | US-15, US-17, US-18, US-19 |
| `code-et-implementer/.claude-plugin/plugin.json` | Bump to `3.6.0` | US-21 |
| `.claude-plugin/marketplace.json` | Bump to `3.6.0` | US-21 |
| `CHANGELOG.md` | Add `## [3.6.0] - 2026-04-20` entry | US-21 |
| `README.md` | Replace single-lane diagram with two-lane; add Feature lane section | US-21 |

---

## Task 0: Setup — bats test runner

**Files:**
- Create: `code-et-implementer/tests/run-tests.sh`
- Create: `code-et-implementer/tests/README.md`

- [ ] **Step 1: Verify `bats` is available**

Run: `command -v bats || brew install bats-core`
Expected: prints path to bats, or installs it.

- [ ] **Step 2: Create test runner**

Write `code-et-implementer/tests/run-tests.sh`:

```sh
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
bats --tap *.bats
```

Then: `chmod +x code-et-implementer/tests/run-tests.sh`

- [ ] **Step 3: Create tests README**

Write `code-et-implementer/tests/README.md`:

```markdown
# Hook script tests

Run all: `./run-tests.sh`
Run one: `bats resolve-prd.bats`

Requires: `bats-core` (`brew install bats-core` or `npm i -g bats`).

Fixtures live under `fixtures/`. Each test creates a temp repo via
`mktemp -d` and exports `CLAUDE_PLUGIN_ROOT` so scripts resolve correctly.
```

- [ ] **Step 4: Sanity check**

Run: `code-et-implementer/tests/run-tests.sh`
Expected: `bats: no tests found` (exits 0 or non-zero — either is fine; the harness works).

- [ ] **Step 5: Commit**

```bash
git checkout -b feature/feature-lane-workflow
git add code-et-implementer/tests/run-tests.sh code-et-implementer/tests/README.md
git commit -m "chore: add bats test runner for hook scripts"
```

---

## Task 1: `resolve-prd.sh` — branch → PRD path helper

**Files:**
- Create: `code-et-implementer/scripts/resolve-prd.sh`
- Create: `code-et-implementer/tests/resolve-prd.bats`
- Create: `code-et-implementer/tests/fixtures/plans/.keep`

**Contract:** Given a branch name on stdin or `$1`, prints the absolute path to the matching PRD file (most recent if multiple dates exist) and exits `0`. If no PRD matches, exits `1` with empty stdout. Strips prefixes `feature/`, `fix/`, `chore/`.

- [ ] **Step 1: Write failing tests**

Create `code-et-implementer/tests/resolve-prd.bats`:

```bash
#!/usr/bin/env bats

setup() {
  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q
  git checkout -q -b main
  mkdir -p plans
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/resolve-prd.sh"
}

teardown() { rm -rf "$REPO"; }

@test "returns matching PRD for feature/<slug>" {
  touch "plans/2026-04-20-dark-mode.md"
  git checkout -q -b feature/dark-mode
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plans/2026-04-20-dark-mode.md" ]]
}

@test "strips fix/ prefix" {
  touch "plans/2026-04-20-login-bug.md"
  git checkout -q -b fix/login-bug
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plans/2026-04-20-login-bug.md" ]]
}

@test "strips chore/ prefix" {
  touch "plans/2026-04-20-deps-bump.md"
  git checkout -q -b chore/deps-bump
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plans/2026-04-20-deps-bump.md" ]]
}

@test "picks most recent when multiple dates exist" {
  touch "plans/2026-01-01-dark-mode.md"
  touch "plans/2026-04-20-dark-mode.md"
  git checkout -q -b feature/dark-mode
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-04-20-dark-mode.md" ]]
}

@test "exits 1 with empty output when no PRD matches" {
  git checkout -q -b feature/unknown
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "accepts branch name as arg 1" {
  touch "plans/2026-04-20-dark-mode.md"
  run "$SCRIPT" "feature/dark-mode"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026-04-20-dark-mode.md" ]]
}

@test "ignores non-dated plan files (legacy)" {
  touch "plans/cheeky-wibbling-puddle.md"
  git checkout -q -b feature/cheeky-wibbling-puddle
  run "$SCRIPT"
  [ "$status" -eq 1 ]
}
```

Also: `touch code-et-implementer/tests/fixtures/plans/.keep`

- [ ] **Step 2: Run tests, verify they fail**

Run: `code-et-implementer/tests/run-tests.sh`
Expected: All 7 tests fail (script does not exist yet).

- [ ] **Step 3: Implement `resolve-prd.sh`**

Create `code-et-implementer/scripts/resolve-prd.sh`:

```sh
#!/usr/bin/env bash
# Resolve active PRD for current branch.
# Usage: resolve-prd.sh [branch-name]
# Prints absolute path to plans/YYYY-MM-DD-<slug>.md (most recent) on success.
# Exits 1 with empty stdout when no match.

set -euo pipefail

branch="${1:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')}"
[ -z "$branch" ] && exit 1

# Strip standard prefixes
slug="${branch#feature/}"
slug="${slug#fix/}"
slug="${slug#chore/}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
plans_dir="$repo_root/plans"
[ -d "$plans_dir" ] || exit 1

# Match YYYY-MM-DD-<slug>.md, newest first
match="$(ls -1 "$plans_dir"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-"$slug".md 2>/dev/null | sort -r | head -n1 || true)"

[ -z "$match" ] && exit 1
echo "$match"
```

Then: `chmod +x code-et-implementer/scripts/resolve-prd.sh`

- [ ] **Step 4: Run tests, verify they pass**

Run: `code-et-implementer/tests/run-tests.sh`
Expected: 7/7 pass.

- [ ] **Step 5: Commit**

```bash
git add code-et-implementer/scripts/resolve-prd.sh \
        code-et-implementer/tests/resolve-prd.bats \
        code-et-implementer/tests/fixtures/plans/.keep
git commit -m "US-16: add resolve-prd.sh branch→PRD helper"
```

---

## Task 2: `session-start-prd.sh` — inject 3-line PRD pointer

**Files:**
- Create: `code-et-implementer/scripts/session-start-prd.sh`
- Create: `code-et-implementer/tests/session-start-prd.bats`

**Contract:** On `SessionStart`, if `resolve-prd.sh` returns a path, print a 3-line JSON context block: `{ "context": "Active PRD: <path>\nOpen: US-1, US-3, US-7\nRead the PRD before planning or implementing." }` for injection. If no PRD, print `{}` and exit 0 (no-op).

- [ ] **Step 1: Write failing tests**

Create `code-et-implementer/tests/session-start-prd.bats`:

```bash
#!/usr/bin/env bats

setup() {
  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q
  git checkout -q -b main
  mkdir -p plans
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/session-start-prd.sh"
  export RESOLVER="${BATS_TEST_DIRNAME}/../scripts/resolve-prd.sh"
}

teardown() { rm -rf "$REPO"; }

@test "no PRD: emits empty JSON, exits 0" {
  git checkout -q -b feature/no-prd
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == "{}" ]]
}

@test "PRD found: emits context JSON with path" {
  cat > plans/2026-04-20-dark-mode.md <<'EOF'
# Dark Mode

- [ ] US-1: toggle component
- [x] US-2: persist preference
- [ ] US-3: system theme detection
EOF
  git checkout -q -b feature/dark-mode
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Active PRD:"* ]]
  [[ "$output" == *"plans/2026-04-20-dark-mode.md"* ]]
  [[ "$output" == *"US-1"* ]]
  [[ "$output" == *"US-3"* ]]
  # US-2 is checked, should not appear in open list
  [[ "$output" != *"US-2"* ]]
}

@test "PRD with no open stories: still emits context" {
  cat > plans/2026-04-20-done.md <<'EOF'
# Done

- [x] US-1: thing
EOF
  git checkout -q -b feature/done
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Active PRD:"* ]]
  [[ "$output" == *"Open: (none)"* ]]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats code-et-implementer/tests/session-start-prd.bats`
Expected: 3 fail.

- [ ] **Step 3: Implement `session-start-prd.sh`**

Create `code-et-implementer/scripts/session-start-prd.sh`:

```sh
#!/usr/bin/env bash
# SessionStart hook: inject 3-line PRD pointer when a PRD matches current branch.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"

if [ -z "$prd" ]; then
  echo '{}'
  exit 0
fi

# Extract unchecked US-N identifiers from the PRD
open_stories="$(grep -oE '^\- \[ \] US-[0-9]+' "$prd" 2>/dev/null | awk '{print $3}' | paste -sd, - | sed 's/,/, /g' || true)"
[ -z "$open_stories" ] && open_stories="(none)"

# Emit JSON with context field (Claude Code SessionStart hook contract)
payload="Active PRD: $prd\nOpen: $open_stories\nRead the PRD before planning or implementing."
printf '{"context": "%s"}\n' "$payload"
```

Then: `chmod +x code-et-implementer/scripts/session-start-prd.sh`

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats code-et-implementer/tests/session-start-prd.bats`
Expected: 3/3 pass.

- [ ] **Step 5: Commit**

```bash
git add code-et-implementer/scripts/session-start-prd.sh \
        code-et-implementer/tests/session-start-prd.bats
git commit -m "US-15: add SessionStart hook injecting PRD pointer"
```

---

## Task 3: `task-created-tag-check.sh` — enforce `user_story` tag

**Files:**
- Create: `code-et-implementer/scripts/task-created-tag-check.sh`
- Create: `code-et-implementer/tests/task-created-tag-check.bats`

**Contract:** Reads a `TaskCreated` hook JSON payload from stdin (Claude Code passes `{"tool_input": {"metadata": {...}}}`). Exits `0` (allow) when:
- `metadata.user_story` matches `^US-\d+$` or `^AC-\d+\.\d+$` or `^chore:.+`, OR
- No PRD exists for the current branch and value is `none` (bug lane), OR
- No PRD exists and no tag provided (bug lane).

Exits `2` (block, per Claude Code hook contract) with an error message to stderr when a PRD exists and the tag is missing/invalid.

- [ ] **Step 1: Write failing tests**

Create `code-et-implementer/tests/task-created-tag-check.bats`:

```bash
#!/usr/bin/env bats

setup() {
  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q
  git checkout -q -b main
  mkdir -p plans
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/task-created-tag-check.sh"
}

teardown() { rm -rf "$REPO"; }

@test "allows US-N tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  echo '{"tool_input":{"metadata":{"user_story":"US-3"}}}' | run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "allows AC-N.M tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  echo '{"tool_input":{"metadata":{"user_story":"AC-3.2"}}}' | run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "allows chore:<reason> tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  echo '{"tool_input":{"metadata":{"user_story":"chore:bump tailwind"}}}' | run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "blocks missing tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  echo '{"tool_input":{"metadata":{}}}' | run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"user_story"* ]] || [[ "$output" == *"user_story"* ]]
}

@test "blocks invalid tag when PRD exists" {
  touch plans/2026-04-20-dark-mode.md
  git checkout -q -b feature/dark-mode
  echo '{"tool_input":{"metadata":{"user_story":"random"}}}' | run "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "allows any task when no PRD (bug lane)" {
  git checkout -q -b fix/login-crash
  echo '{"tool_input":{"metadata":{}}}' | run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "allows user_story:none when no PRD (bug lane explicit)" {
  git checkout -q -b fix/login-crash
  echo '{"tool_input":{"metadata":{"user_story":"none"}}}' | run "$SCRIPT"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats code-et-implementer/tests/task-created-tag-check.bats`
Expected: 7 fail.

- [ ] **Step 3: Implement `task-created-tag-check.sh`**

Create `code-et-implementer/scripts/task-created-tag-check.sh`:

```sh
#!/usr/bin/env bash
# TaskCreated hook: enforce user_story tag on branches that have an active PRD.
# Exit 0 = allow, exit 2 = block (per Claude Code hook contract).

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
payload="$(cat)"

prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"

# Extract tag via jq
tag="$(printf '%s' "$payload" | jq -r '.tool_input.metadata.user_story // ""' 2>/dev/null || echo '')"

if [ -z "$prd" ]; then
  # Bug lane — anything goes
  exit 0
fi

# Feature lane — validate tag
if [[ "$tag" =~ ^US-[0-9]+$ ]] \
   || [[ "$tag" =~ ^AC-[0-9]+\.[0-9]+$ ]] \
   || [[ "$tag" =~ ^chore:.+ ]]; then
  exit 0
fi

# Block with remediation hint
cat >&2 <<EOF
Task rejected: metadata.user_story is missing or invalid.

Active PRD: $prd
Required format: "US-<N>" | "AC-<N>.<M>" | "chore:<reason>"

Open the PRD, pick the story this task serves, and add it to metadata.user_story.
EOF
exit 2
```

Then: `chmod +x code-et-implementer/scripts/task-created-tag-check.sh`

- [ ] **Step 4: Verify `jq` available**

Run: `command -v jq || brew install jq`
Expected: path to jq or install.

- [ ] **Step 5: Run tests, verify they pass**

Run: `bats code-et-implementer/tests/task-created-tag-check.bats`
Expected: 7/7 pass.

- [ ] **Step 6: Commit**

```bash
git add code-et-implementer/scripts/task-created-tag-check.sh \
        code-et-implementer/tests/task-created-tag-check.bats
git commit -m "US-17: add TaskCreated hook enforcing user_story tag"
```

---

## Task 4: `pre-compact-prd.sh` — inject open-stories before compaction

**Files:**
- Create: `code-et-implementer/scripts/pre-compact-prd.sh`
- Create: `code-et-implementer/tests/pre-compact-prd.bats`

**Contract:** On `PreCompact`, if a PRD matches the current branch, emit a JSON context block containing up to 20 open US-N lines from the PRD. If more than 20, emit a summary line. If no PRD, emit `{}`.

- [ ] **Step 1: Write failing tests**

Create `code-et-implementer/tests/pre-compact-prd.bats`:

```bash
#!/usr/bin/env bats

setup() {
  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q
  git checkout -q -b main
  mkdir -p plans
  export SCRIPT="${BATS_TEST_DIRNAME}/../scripts/pre-compact-prd.sh"
}

teardown() { rm -rf "$REPO"; }

@test "no PRD: emits empty JSON" {
  git checkout -q -b feature/nothing
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "PRD with <=20 open stories: includes all" {
  {
    echo "# Plan"
    for i in 1 2 3; do echo "- [ ] US-$i: thing $i"; done
    echo "- [x] US-99: done"
  } > plans/2026-04-20-x.md
  git checkout -q -b feature/x
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"US-1"* ]]
  [[ "$output" == *"US-2"* ]]
  [[ "$output" == *"US-3"* ]]
  [[ "$output" != *"US-99"* ]]
}

@test "PRD with >20 open stories: emits summary" {
  {
    echo "# Plan"
    for i in $(seq 1 25); do echo "- [ ] US-$i: thing $i"; done
  } > plans/2026-04-20-big.md
  git checkout -q -b feature/big
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"25 open stories"* ]]
  [[ "$output" == *"plans/2026-04-20-big.md"* ]]
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `bats code-et-implementer/tests/pre-compact-prd.bats`
Expected: 3 fail.

- [ ] **Step 3: Implement `pre-compact-prd.sh`**

Create `code-et-implementer/scripts/pre-compact-prd.sh`:

```sh
#!/usr/bin/env bash
# PreCompact hook: inject PRD open-stories summary before Claude compacts.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"

if [ -z "$prd" ]; then
  echo '{}'
  exit 0
fi

open_count="$(grep -cE '^\- \[ \] US-' "$prd" 2>/dev/null || echo 0)"

if [ "$open_count" -gt 20 ]; then
  body="Active PRD: $prd\n${open_count} open stories. Read the PRD for full list."
else
  lines="$(grep -E '^\- \[ \] US-' "$prd" 2>/dev/null || true)"
  body="Active PRD: $prd\nOpen stories:\n${lines}"
fi

# Escape newlines for JSON
body_json="$(printf '%s' "$body" | jq -Rs .)"
printf '{"context": %s}\n' "$body_json"
```

Then: `chmod +x code-et-implementer/scripts/pre-compact-prd.sh`

- [ ] **Step 4: Run tests, verify they pass**

Run: `bats code-et-implementer/tests/pre-compact-prd.bats`
Expected: 3/3 pass.

- [ ] **Step 5: Commit**

```bash
git add code-et-implementer/scripts/pre-compact-prd.sh \
        code-et-implementer/tests/pre-compact-prd.bats
git commit -m "US-18: add PreCompact hook injecting open-stories summary"
```

---

## Task 5: `pr-created-suggest-review.sh` — suggest `/ultrareview` on PR

**Files:**
- Create: `code-et-implementer/scripts/pr-created-suggest-review.sh`

**Contract:** Fires as `PostToolUse` matcher on `Bash` when the command contains `gh pr create`. Reads the tool result JSON, extracts the PR URL, derives the PR number, and if a PRD exists for the current branch prints a one-line suggestion to stdout (user-facing).

- [ ] **Step 1: Create script**

Create `code-et-implementer/scripts/pr-created-suggest-review.sh`:

```sh
#!/usr/bin/env bash
# PostToolUse hook fired after `gh pr create`. Suggests /ultrareview when a PRD exists.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
payload="$(cat)"

command="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || echo '')"
case "$command" in
  *"gh pr create"*) ;;
  *) echo '{}'; exit 0 ;;
esac

prd="$("$here/resolve-prd.sh" 2>/dev/null || true)"
[ -z "$prd" ] && { echo '{}'; exit 0; }

# Extract PR URL from tool output
pr_url="$(printf '%s' "$payload" | jq -r '.tool_response.output // .tool_response.stdout // ""' 2>/dev/null | grep -oE 'https://github\.com/[^ ]+/pull/[0-9]+' | head -n1 || true)"
pr_num="${pr_url##*/}"

repo_root="$(git rev-parse --show-toplevel)"
prd_rel="${prd#$repo_root/}"

msg="PRD detected for this branch. Optional: run \`/ultrareview ${pr_num:-<PR#>} --context ${prd_rel}\` to review the PR against acceptance criteria."
msg_json="$(printf '%s' "$msg" | jq -Rs .)"
printf '{"context": %s}\n' "$msg_json"
```

Then: `chmod +x code-et-implementer/scripts/pr-created-suggest-review.sh`

- [ ] **Step 2: Smoke-test manually**

Run:

```bash
printf '{"tool_input":{"command":"gh pr create"},"tool_response":{"output":"https://github.com/a/b/pull/42"}}' \
  | code-et-implementer/scripts/pr-created-suggest-review.sh
```

Expected on branch with no PRD: `{}`
Expected on branch with PRD: JSON containing `/ultrareview 42` suggestion.

- [ ] **Step 3: Commit**

```bash
git add code-et-implementer/scripts/pr-created-suggest-review.sh
git commit -m "US-19: add PostToolUse hook suggesting /ultrareview on PR"
```

---

## Task 6: Wire hooks into `hooks.json`

**Files:**
- Modify: `code-et-implementer/hooks/hooks.json`

- [ ] **Step 1: Read current hooks.json**

Run: `cat code-et-implementer/hooks/hooks.json` — confirm current shape (`PreToolUse`, `PermissionRequest`, `SubagentStop`, `TaskCompleted`, `FileChanged`, `InstructionsLoaded`).

- [ ] **Step 2: Add `SessionStart`, `TaskCreated`, `PreCompact`, and `PostToolUse:Bash` entries**

Replace the file with:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/inject-rules.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/pr-created-suggest-review.sh",
            "timeout": 3000
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "matcher": "Read|Grep|Glob|LSP",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/auto-approve-readonly.sh",
            "timeout": 2000
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/verify-gate.sh",
            "timeout": 30000
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/session-start-prd.sh",
            "timeout": 3000
          }
        ]
      }
    ],
    "TaskCreated": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/task-created-tag-check.sh",
            "timeout": 3000
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/task-complete.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/pre-compact-prd.sh",
            "timeout": 3000
          }
        ]
      }
    ],
    "FileChanged": [
      {
        "matcher": "*/page.tsx|*/route.ts|*/route.tsx|*/index.tsx|*/layout.tsx",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/refresh-file-reference.sh",
            "timeout": 3000
          }
        ]
      }
    ],
    "InstructionsLoaded": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/log-instructions.sh",
            "timeout": 2000
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Validate JSON**

Run: `jq . code-et-implementer/hooks/hooks.json > /dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add code-et-implementer/hooks/hooks.json
git commit -m "US-15 US-17 US-18 US-19: wire SessionStart TaskCreated PreCompact PostToolUse hooks"
```

---

## Task 7: `/code:grill` command

**Files:**
- Create: `code-et-implementer/commands/grill.md`

- [ ] **Step 1: Write the command file**

Create `code-et-implementer/commands/grill.md`:

```markdown
---
tools: Read, Grep, Glob, Bash, Agent
description: "Grill an idea into a refined brief — one question at a time, codebase-first, converges automatically."
argument-hint: "[rough idea or @brief-file]"
effort: high
---

# Grill — Idea Refinement

Turn a rough idea into a refined brief you can hand to `/code:prd`. Ask one question at a time with a recommended answer. Stop when every open decision is resolved.

## Rules

1. **If a question can be answered from the codebase, answer it yourself.** Use Read/Grep/Glob/Bash (git log). Do not ask the user.
2. **Ask one question per message.** Number it. Include a recommended answer and 1-sentence rationale.
3. **Accept "you decide" as a final answer.** Record the recommendation as the decision. Do not re-ask.
4. **Accept "defer: <reason>"** — mark deferred, move on.
5. **Stop rule:** when every item in the decisions ledger is resolved (`answered` | `recommended-accepted` | `deferred`), announce completion and print the refined brief.

## Decisions Ledger

Maintain an in-session ledger. Each entry:
- `id` (D-1, D-2, …)
- `question`
- `recommendation`
- `state`: `pending` | `answered` | `recommended-accepted` | `deferred`
- `final_answer`

Present the ledger summary after every 3 answered questions so the user can see progress.

## Process

1. **Parse input.** `$ARGUMENTS` is either the rough idea as text or `@path/to/brief.md`. If `@path`, read the file.
2. **Explore context.** Run `Glob` on `**/*.md` for existing plans, `git log --oneline -20`, and scan key config files. Build a project-state snapshot.
3. **Seed the ledger.** From the input and context, draft 5-10 open decisions. Common axes: scope, actor, data model, UI surface, integration points, non-goals, success criteria.
4. **Interrogate.** One question at a time. Resolve codebase-answerable items yourself before asking.
5. **Converge.** When ledger is fully resolved, print:

```
## Refined Brief

**Idea:** <1-sentence>
**Actors:** <list>
**Scope:** <in / out>
**Key decisions:**
- D-1: <question> → <final_answer>
- D-2: …

**Suggested slug:** <kebab-case>

Next: run /code:prd to convert this brief into a PRD file.
```

## Brevity

Drop filler. Questions ≤2 sentences. Recommendations ≤1 sentence.
```

- [ ] **Step 2: Lint markdown frontmatter**

Run: `head -10 code-et-implementer/commands/grill.md`
Expected: valid YAML frontmatter with `tools`, `description`, `argument-hint`, `effort`.

- [ ] **Step 3: Commit**

```bash
git add code-et-implementer/commands/grill.md
git commit -m "US-1 US-2 US-3 US-4: add /code:grill idea-refinement command"
```

---

## Task 8: `/code:prd` command

**Files:**
- Create: `code-et-implementer/commands/prd.md`

- [ ] **Step 1: Write the command file**

Create `code-et-implementer/commands/prd.md`:

```markdown
---
tools: Read, Write, Bash, Grep, Glob
description: "Synthesise current conversation into a PRD file at plans/YYYY-MM-DD-<slug>.md. Sets session title. Local only — no GitHub issue."
argument-hint: "[optional slug override]"
effort: high
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

5. **Set session title** by printing to Claude Code's `UserPromptSubmit` output-channel format:

```
{"sessionTitle": "feat:<slug>"}
```

6. **Announce completion** and the path.

## Rules

- **No file paths in the PRD.** Implementation Decisions stay module-level.
- **User stories get unique `US-N` ids.** Acceptance criteria get `AC-<story>.<M>` ids.
- **Long user-story list** — aim for 10+ stories covering all aspects of the feature.
- **Story Checklist must match the US-N ids exactly** — `/code:implement` tick them.
```

- [ ] **Step 2: Commit**

```bash
git add code-et-implementer/commands/prd.md
git commit -m "US-5 US-6 US-7 US-8: add /code:prd command writing plans/<date>-<slug>.md"
```

---

## Task 9: Modify `/code:plan-issue` — `/ultraplan` wrapper + US-N tagging

**Files:**
- Modify: `code-et-implementer/commands/plan-issue.md`

- [ ] **Step 1: Replace file with updated version**

Replace `code-et-implementer/commands/plan-issue.md` with:

```markdown
---
tools: Read, Grep, Glob, Bash, LSP, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Skill
description: "Plan: detect PRD, delegate to /ultraplan when present, fall back to LSP-only."
argument-hint: "[feature-description] [@spec-file]"
effort: high
---

Plan implementation tasks. Two paths:

## Path A — PRD present (feature lane)

1. Resolve active PRD via `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh")`.
2. If a path is returned, Read the PRD.
3. **Invoke `/ultraplan`** with the PRD. Try `Skill("ultraplan", args=prd_path)` first; if that fails, try passing the PRD contents inline. On any failure (skill unavailable, network error, malformed output), announce exactly once:
   > `/ultraplan unreachable — using local LSP decomposition. Plan may be less thorough for large PRDs.`
   …and fall through to Path B using the PRD as the spec.
4. **Post-process `/ultraplan` output:**
   - For each proposed task, assign a `user_story` tag:
     - If the task implements a specific AC, tag as `AC-N.M`.
     - Else if it serves a US, tag as `US-N`.
     - Else tag as `chore:<one-sentence reason>` (build config, cross-cutting refactors required to enable a story).
   - Reject any task that cannot be tagged — ask for clarification or split the task.
5. **LSP-enrich** each task: use `documentSymbol` / `findReferences` to add `file:line` anchors to `metadata.files`.
6. Create tasks via `TaskCreate` with metadata:
   ```
   {
     "verification": "<cmd>",
     "files": ["path:line", ...],
     "expected_outcome": "<observable success>",
     "user_story": "US-N" | "AC-N.M" | "chore:<reason>"
   }
   ```
7. Set dependencies with `TaskUpdate(addBlockedBy)`. Independent tasks stay parallel.
8. Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

## Path B — No PRD (bug lane, unchanged)

1. If `$ARGUMENTS` has `@<path>`, read that spec. Also check `.claude/rules/*.md` for constraints.
2. Use LSP (`documentSymbol`, `findReferences`) to get exact line numbers. Grep/Glob to find files, LSP for precision. For 3+ independent areas, spawn parallel Explore agents.
3. Break into tasks. Reason about dependencies — use `blocked_by` to build a dependency graph.
4. Create tasks via `TaskCreate` with metadata:
   ```
   {
     "verification": "<cmd>",
     "files": ["path:line", ...],
     "expected_outcome": "<what success looks like>"
   }
   ```
   (No `user_story` required — bug lane.)
5. Save manifest to `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`.

## Output

`"Plan complete: N tasks created. Run /code:implement to start."`

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Plan Complete' --subtitle 'N tasks created' || true")
```
```

- [ ] **Step 2: Commit**

```bash
git add code-et-implementer/commands/plan-issue.md
git commit -m "US-9 US-10 US-11 US-12 US-20: plan-issue wraps /ultraplan with LSP fallback"
```

---

## Task 10: Modify `/code:implement` — US-N commit prefix + PRD checkbox

**Files:**
- Modify: `code-et-implementer/commands/implement.md`

- [ ] **Step 1: Replace file with updated version**

Replace `code-et-implementer/commands/implement.md` with:

```markdown
---
background: true
tools: Bash, Bash(gh:*), Bash(git:*), Read, Edit, Grep, Glob, Agent, Skill, TaskCreate, TaskList, TaskGet, TaskUpdate
description: Implement pending tasks with parallel agents. Tags commits with US-N. Ticks PRD checklist.
argument-hint: [task-id]
effort: medium
---

Load pending tasks from `TaskList` or `.claude/${CLAUDE_CODE_TASK_LIST_ID}.json`. If on main, create a feature branch.

Every task runs as a subagent in its own worktree. Use the dependency graph to run independent tasks in parallel.

## Each agent must:

1. Implement the task. Ensure every acceptance criterion has a corresponding test.
2. Run `metadata.verification` — code must compile, all tests must pass.
3. **Commit with US-N prefix.** If `metadata.user_story` is set, format the commit message as:
   - `US-N: <subject>` when tag is `US-N`
   - `AC-N.M: <subject>` when tag is `AC-N.M`
   - `chore: <subject>` when tag starts with `chore:`
   - No prefix when tag is `none` or absent (bug lane).
4. **Tick the PRD checkbox.** If `metadata.user_story` is `US-N`, resolve the PRD via `${CLAUDE_PLUGIN_ROOT}/scripts/resolve-prd.sh` and use `Edit` to flip `- [ ] US-N` to `- [x] US-N` on that exact line. Stage the PRD change with the agent's commit.
5. Merge back to the feature branch and remove the worktree.

Only mark the task completed after the commit lands and the PRD checkbox is ticked (if applicable).

When done, run `Skill("simplify")` and report summary.

```
Bash("command -v cmux &>/dev/null && [ -n \"$CMUX_SOCKET_PATH\" ] && cmux notify --title 'Implement Done' --subtitle 'All tasks complete' || true")
```
```

- [ ] **Step 2: Commit**

```bash
git add code-et-implementer/commands/implement.md
git commit -m "US-13 US-14: implement tags commits with US-N, ticks PRD checklist"
```

---

## Task 11: Version bump — plugin.json + marketplace.json

**Files:**
- Modify: `code-et-implementer/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump plugin.json**

Edit `code-et-implementer/.claude-plugin/plugin.json`:

- Change `"version": "3.5.1"` → `"version": "3.6.0"`
- Update `description` from `"Plan with LSP, implement with parallel agents. Pairs with commit-commands and code-review plugins."` to `"Feature + bug lanes. Grill ideas into PRDs, plan with /ultraplan, implement with parallel agents."`

- [ ] **Step 2: Bump marketplace.json**

Edit `.claude-plugin/marketplace.json`:

- Change `"version": "3.5.1"` → `"version": "3.6.0"` in `metadata`.
- Update `metadata.description` to match the new plugin.json description.

- [ ] **Step 3: Validate JSON**

Run:

```bash
jq . code-et-implementer/.claude-plugin/plugin.json > /dev/null
jq . .claude-plugin/marketplace.json > /dev/null
echo OK
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add code-et-implementer/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "US-21: bump version to 3.6.0 and update description"
```

---

## Task 12: CHANGELOG entry

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Read current CHANGELOG format**

Run: `head -30 CHANGELOG.md`
Expected: observe the `## [X.Y.Z] - YYYY-MM-DD` pattern used in 3.5.1.

- [ ] **Step 2: Insert new entry**

Insert at the top (below the `# Changelog` header, above `## [3.5.1]`):

```markdown
## [3.6.0] - 2026-04-20

### Added
- `/code:grill` — interrogates a rough idea into a refined brief (one question at a time, codebase-first, "you decide" converges).
- `/code:prd` — synthesises the brief into `plans/YYYY-MM-DD-<slug>.md` with user stories (US-N) and acceptance criteria (AC-N.M). Sets session title `feat:<slug>`.
- `SessionStart` hook injecting a 3-line PRD pointer on branches with a matching PRD.
- `TaskCreated` hook enforcing `user_story: US-N | AC-N.M | chore:<reason>` tag on feature-lane tasks.
- `PreCompact` hook injecting open-stories summary before compaction.
- `PostToolUse` hook suggesting `/ultrareview <PR#> --context plans/<slug>.md` after `gh pr create` when a PRD exists.
- `resolve-prd.sh` shared helper — branch → `plans/YYYY-MM-DD-<slug>.md`.
- Bats test suite for hook scripts under `code-et-implementer/tests/`.

### Changed
- `/code:plan-issue` now detects an active PRD, delegates decomposition to `/ultraplan`, tags every task with `user_story`, and LSP-enriches with `file:line`. Falls back to LSP-only path with a one-line announcement when `/ultraplan` is unreachable.
- `/code:implement` prefixes commits with `US-N:` / `AC-N.M:` / `chore:` and ticks the PRD checklist when a story completes.
- README documents the two-lane workflow.

### Notes
- Requires Claude Code ≥ 2.1.94 for `UserPromptSubmit.sessionTitle`.
- `/ultraplan` and `/ultrareview` are cloud skills — feature lane degrades gracefully when offline.
- Bug lane (`/code:go` → `/code:plan-issue` → `/code:implement`) is unchanged when no PRD exists.
```

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "US-21: add v3.6.0 CHANGELOG entry"
```

---

## Task 13: README update — two-lane workflow

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read current README**

Run: `cat README.md | head -80` to locate the bug-lane diagram and plugin ecosystem table.

- [ ] **Step 2: Replace single-lane diagram with two-lane diagram**

Find the existing workflow diagram (the `/code:go → /code:plan-issue → /code:implement → /commit-push-pr` block). Replace with:

````markdown
## Workflows

code-et ships two lanes. Both share the midpoint (`/code:plan-issue` → `/code:implement` → `/commit-push-pr`); only the front end differs.

### Bug lane — small, scoped work

```
/code:go  →  /code:plan-issue  →  /code:implement  →  /commit-push-pr
 intake       LSP decomposition     parallel agents      PR
```

Use when scope is already clear. No PRD, no user stories.

### Feature lane — larger work across multiple sessions

```
/code:grill  →  /code:prd  →  /code:plan-issue  →  /code:implement  →  /commit-push-pr
 interview       PRD file       /ultraplan + LSP      US-N commits       PR (+ /ultrareview hint)
```

- `/code:grill` interrogates the idea, one question at a time, stopping when all decisions are resolved.
- `/code:prd` writes `plans/YYYY-MM-DD-<slug>.md` with numbered user stories (US-N) and acceptance criteria.
- `/code:plan-issue` detects the PRD, delegates to `/ultraplan`, tags every task with its `user_story`, and enriches with LSP `file:line` refs.
- `/code:implement` prefixes commits with `US-N:` and ticks the PRD checklist as tasks land.
- Hooks re-inject the PRD pointer on `SessionStart` and before `PreCompact`, so multi-session work stays coherent.

### PRD file convention

PRDs live at `plans/YYYY-MM-DD-<branch-slug>.md`. The slug is derived from `feature/`, `fix/`, or `chore/` branch names by stripping the prefix. Switching branches auto-resolves the matching PRD.

### Dependencies

- `/ultraplan` and `/ultrareview` are cloud-hosted Anthropic skills. Requires network access. `/code:plan-issue` falls back to a local LSP-only path with a one-line announcement when `/ultraplan` is unreachable.
- Requires Claude Code ≥ 2.1.94.
````

- [ ] **Step 3: Ensure bug-lane section from earlier still documents `/code:go`**

If the README had a separate "workflow" bullet list elsewhere, keep it consistent with the two-lane framing above. Remove any duplicate single-lane description.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "US-21: README documents bug + feature two-lane workflow"
```

---

## Task 14: Integration smoke test

**Files:** (no code changes, verification only)

- [ ] **Step 1: Run the full bats suite**

Run: `code-et-implementer/tests/run-tests.sh`
Expected: all `.bats` files pass.

- [ ] **Step 2: Validate every JSON config**

Run:

```bash
for f in code-et-implementer/hooks/hooks.json \
         code-et-implementer/.claude-plugin/plugin.json \
         .claude-plugin/marketplace.json; do
  jq . "$f" > /dev/null && echo "OK: $f"
done
```

Expected: `OK:` line for each.

- [ ] **Step 3: Check script permissions**

Run: `ls -l code-et-implementer/scripts/*.sh | awk '{print $1, $NF}'`
Expected: every `.sh` under `scripts/` is `-rwxr-xr-x` (executable).

- [ ] **Step 4: Dry-run `resolve-prd.sh` against this repo's own branch**

Run:

```bash
git checkout -q -b feature/feature-lane-workflow-test 2>/dev/null || git checkout feature/feature-lane-workflow-test
touch plans/$(date +%Y-%m-%d)-feature-lane-workflow-test.md
code-et-implementer/scripts/resolve-prd.sh
rm plans/$(date +%Y-%m-%d)-feature-lane-workflow-test.md
git checkout - 2>/dev/null
git branch -D feature/feature-lane-workflow-test 2>/dev/null || true
```

Expected: prints the temp PRD path, exits 0.

- [ ] **Step 5: Verify `SessionStart` hook JSON shape**

Run: `code-et-implementer/scripts/session-start-prd.sh | jq .`
Expected: valid JSON (either `{}` or `{"context": "..."}`).

- [ ] **Step 6: Commit any fixes**

If previous steps required fixes, commit them separately. Otherwise proceed.

```bash
git status  # confirm clean
```

---

## Task 15: PR

**Files:** (no file changes)

- [ ] **Step 1: Push branch**

```bash
git push -u origin feature/feature-lane-workflow
```

- [ ] **Step 2: Open PR**

Run:

```bash
gh pr create --title "feat: feature lane workflow (v3.6.0)" --body "$(cat <<'EOF'
## Summary
- Add feature lane (`/code:grill` → `/code:prd` → `/code:plan-issue` → `/code:implement`) alongside unchanged bug lane
- Wire `SessionStart`, `TaskCreated`, `PreCompact`, `PostToolUse` hooks for PRD-aware sessions
- `/code:plan-issue` now wraps `/ultraplan` with LSP fallback
- Bump to v3.6.0, update README + CHANGELOG

See `plans/2026-04-20-feature-lane-workflow.md` for the design spec (21 user stories).

## Test plan
- [ ] `code-et-implementer/tests/run-tests.sh` passes
- [ ] Install plugin locally, run `/code:grill <idea>` → converges
- [ ] `/code:prd` writes `plans/YYYY-MM-DD-<slug>.md`
- [ ] `/code:plan-issue` on a branch with PRD invokes `/ultraplan` (or announces fallback)
- [ ] `/code:implement` commits use `US-N:` prefix and PRD checkboxes tick
- [ ] `SessionStart` on a branch with PRD injects the 3-line pointer
- [ ] `TaskCreate` without `user_story` on a PRD branch is rejected
- [ ] Bug lane: `/code:go` → `/code:plan-issue` → `/code:implement` unchanged when no PRD exists

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Return PR URL to user**

---

## Self-Review (completed by plan author)

**Spec coverage:**

| US | Task(s) |
|----|---------|
| US-1..US-4 (grill) | Task 7 |
| US-5..US-8 (prd) | Task 8 |
| US-9 (plan-issue detects PRD) | Task 9 |
| US-10 (ultraplan fallback) | Task 9 |
| US-11 (US-N tagging) | Task 9 |
| US-12 (LSP enrichment) | Task 9 |
| US-13 (US-N commit prefix) | Task 10 |
| US-14 (PRD checkbox tick) | Task 10 |
| US-15 (SessionStart hook) | Task 2 + Task 6 |
| US-16 (branch-match resolver) | Task 1 |
| US-17 (TaskCreated hook) | Task 3 + Task 6 |
| US-18 (PreCompact hook) | Task 4 + Task 6 |
| US-19 (ultrareview suggestion) | Task 5 + Task 6 |
| US-20 (bug lane unchanged) | Task 9 (Path B) |
| US-21 (version + docs) | Tasks 11, 12, 13 |

All 21 stories covered.

**Placeholder scan:** No `TBD`, no "implement later", no "handle edge cases" without code. All shell scripts show complete implementations; all templates contain exact code.

**Type consistency:** Script names consistent across `hooks.json`, script files, and test files. `resolve-prd.sh` contract identical in every caller (stdout = path or empty, exit 0 or 1). `user_story` tag format identical in spec, `/code:plan-issue`, `task-created-tag-check.sh`, and `/code:implement`.

**Known residual risks** (from the spec — acknowledged, handled by fallback):
- `/ultraplan` invocation contract: wrapper tries `Skill("ultraplan", args=...)` then inline; falls back to LSP. Announced once.
- `SessionStart` / `PreCompact` / `TaskCreated` hook event names assume Claude Code ≥ 2.1.94 — documented in CHANGELOG Notes.
- Legacy auto-named plan files (e.g. `cheeky-wibbling-puddle.md`) ignored by `resolve-prd.sh` (must match `YYYY-MM-DD-` prefix). Confirmed by Task 1 test "ignores non-dated plan files (legacy)".

---

## Execution Handoff

Two options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session via `executing-plans`, batched checkpoints.
