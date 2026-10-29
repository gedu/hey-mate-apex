---
name: handoff-implement
description: "Trigger: execute this brief, implement the brief, .handoff brief.md, you are the implementer. Implement one planner brief with TDD and write the report."
license: Apache-2.0
metadata:
  author: "callstack"
  version: "0.1"
---

## Activation Contract

Load when you receive a path to a `brief.md`, usually under `.handoff/<task-id>/`, and you
are asked to execute it. You are the implementer: a planner wrote the brief and will review
your work.

## Hard Rules

- Read the whole brief before touching anything. It is the only spec. When it conflicts with
  your own habits, the brief wins. The repository's `AGENTS.md` still applies.
- Change only paths listed under `## Allowed edit surfaces`. Need another file? Stop and ask.
- Write the test first and run it. Keep its failing output for the report.
- Paste real command output into the report. Never write "passed" for a command you did not
  run, and never trim a failure out.
- Do not commit, push or open a pull request unless the brief says so.
- Two attempts without progress: stop and report `Status: blocked` with one question.
- Never edit the brief. Write only to the report path it names.

## Decision Gates

| Situation | Action |
| --- | --- |
| Brief has `## Correction N` | Fix only the listed defects, then rerun every verification command |
| Brief has `## Answers` | Apply the answers and continue from where you stopped |
| A spec is ambiguous but a conservative reading exists | Take it, note it under `## Deviations and assumptions` |
| A spec needs a product decision | Stop, `Status: blocked`, ask one question |
| A verification command fails for a reason outside your change | Report it as is, with output, `Status: partial` |

## Execution Steps

1. Check you are on the brief's branch and the base commit is an ancestor of `HEAD`.
2. Write the tests from `## Test first`. Run them. Confirm they fail for the stated reason.
3. Write the smallest production change that makes them pass.
4. Refactor while the tests stay green.
5. Run every command in `## Verification`, in order. Fix and rerun until they pass, within
   the two-attempt budget.
6. Run mutation testing when the brief asks for it. Kill survivors or explain each one.
7. Copy `assets/report.md` to the report path and fill every section.

## Output Contract

End your final message with the report path and its `Status:` line. Nothing else is needed:
the planner reads the report file.

## References

- `assets/report.md`: the report template.
