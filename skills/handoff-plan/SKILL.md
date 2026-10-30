---
name: handoff-plan
description: "Trigger: hand off to another agent or model (Apex, DeepSeek, any name in the agents file), code it with <model>, delegate the coding, write a brief, planner and implementer, review the implementer report. Plan a task and hand it to another agent."
license: MIT
metadata:
  author: "callstack"
  version: "0.1"
---

## Activation Contract

Load when you are the planner: the user wants another agent (the implementer) to write the
code while you explore, plan, brief and review. Also load when a `report.md` from an
implementer is waiting for review.

## Hard Rules

- You write no production code or tests. The implementer does. You may write briefs only.
- One brief per task. A task is one behavior with its tests and docs, small enough to review
  in a few minutes.
- Specs quote the issue or the user word for word. Mark every inference as `Assumption:`.
- Every brief names its allowed edit surfaces, its test-first step and its exact
  verification commands. A brief without them is not ready.
- Never accept a report on its word. Re-run at least the main verification command yourself.
- One correction round per task. If the second report still fails, stop and ask the user.

## Decision Gates

| Situation | Action |
| --- | --- |
| A product decision is open | Ask the user one question before writing the brief |
| `bin/handoff-run` and the implementer CLI exist on this machine | Run it in the background, wait for it to exit |
| The user named the implementer ("code it with deepseek") | Pass `--agent <name>`; never swap in another agent |
| The user named no implementer | Omit `--agent`; `handoff-run` uses the default agent |
| The name is unknown, or `handoff-run` exits 1 or 3 | Nothing ran. Show the user its message and `handoff-run --list`, then ask which agent to use |
| No CLI, or the user prefers to drive the implementer | Give the user the one-line prompt to paste |
| Report `Status: blocked` | Answer the question in the brief under `## Answers`, dispatch again |
| Review finds a defect | Append `## Correction 1` to the brief listing each defect, dispatch again |

## Execution Steps

1. Explore the code and the issue until you can name the files to change.
2. Split the work into tasks. Number them `T1`, `T2`, in the order they must land.
3. Create `.handoff/<task-id>/` at the repository root. Add `.handoff/` to the file
   `git rev-parse --git-path info/exclude` prints, unless it is already there, so it never
   reaches the project's history. That path also works inside a git worktree.
4. Copy `assets/brief.md` to `.handoff/<task-id>/brief.md` and fill every section.
   Record the current commit as the base.
5. Dispatch: `handoff-run .handoff/<task-id>/brief.md [--agent <name>]`, or hand the user
   this prompt: `Load the handoff-implement skill and execute .handoff/<task-id>/brief.md.`
   Tell the user the `implementer:` line `handoff-run` prints, so they know who is coding.
6. When the report exists, review it with `references/review.md`.
7. Accept, or write the correction and dispatch again. Then move to the next task.

## Output Contract

After each review, tell the user: the task id, the implementer that ran it, the verdict (accepted, correction sent, or
needs your decision), the command you re-ran with its result, and the next task.

## References

- `assets/brief.md`: the brief template.
- `references/review.md`: the review checklist.
