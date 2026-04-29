# Context Hygiene

Token waste = worse plans + worse code.

1. **Trim attachments.** Quote back only the slice you act on. Ignore siblings the harness attached. Duplicate blocks count once.
2. **Read in slices.** Files >200 lines: Grep first, then `Read(offset, limit)` for a window. Re-reading the same file twice = first read should have been a slice.
3. **Delegate breadth.** 3+ independent areas, or fix in an unknown file → `Agent(subagent_type: "Explore")`. Parallel queries → one message, multiple Agent calls. Don't delegate AND search. Specify thoroughness: `quick` | `medium` | `very thorough`.
4. **Stop at sufficient.** `file:line` + rationale per task is enough. 5 sharp tasks > 15 vague ones.
