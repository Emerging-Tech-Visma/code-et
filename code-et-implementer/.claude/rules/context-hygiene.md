# Context Hygiene Rules

Applies to all code-et commands. Token waste = worse plans + worse code.

## 1. Trim attached payloads

When the user uses "select-and-attach" (IDE element-picker, paste-with-context, etc.), the harness may attach surrounding HTML/code/siblings.

- Quote back ONLY the slice you act on. Never echo the full attached block.
- If the attachment includes siblings/parents not part of the question, ignore them silently — do not summarise them, do not acknowledge them.
- If the attachment is duplicated (same block twice), treat it as one.

## 2. Read in slices, not whole files

`Read` defaults to 2000 lines from the top. That is almost always wrong for files >200 lines.

- For files >200 lines: ALWAYS pass `offset` and `limit`. Use `Grep` first to find the line, then `Read(offset=N-20, limit=60)` for the window.
- Whole-file reads only for: cross-cutting refactor, files <200 lines, or when you genuinely need every line.
- Re-reading the same file twice in one session to grab different blocks is a red flag — the first read should have been a slice.

## 3. Delegate broad exploration to a subagent

A subagent burns its own context and returns a synthesis. Your context only sees the summary.

- 3+ independent search areas, OR fix is in a file you do not already know → spawn `Agent(subagent_type: "Explore")`.
- Multiple independent Explore queries → dispatch in ONE message with parallel `Agent` calls.
- Do NOT both delegate and search yourself. Pick one.
- Tell the subagent the thoroughness level: `quick` | `medium` | `very thorough`.

## 4. Stop at sufficient

`file:line` + rationale per task is enough. Do not fish for completeness. 5 sharp tasks > 15 vague ones.
