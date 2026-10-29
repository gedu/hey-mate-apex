# Report: <task-id>

Status: <done | partial | blocked>
Commit: <sha, or "none" when the brief did not ask for a commit>

## Specs covered

- S1: <yes | no | partial>, <test name that proves it>
- S2: <yes | no | partial>, <test name that proves it>

## Files changed

```
<paste the output of: git diff --stat <base commit>>
```

## RED evidence

```
<paste the failing output of the new tests, run before the production change>
```

## Verification

<One block per command in the brief, in the same order. Paste the real output, trimmed to the
summary lines and any failure. Never write "passed" without the output.>

### `<command>`

```
<output>
```

## Mutation testing

<Command, score, and the surviving mutants you did not kill, or "Not required".>

## Deviations and assumptions

<Anything you did that the brief did not say, and why. Write "None" when there is nothing.>

## Questions for the planner

<Only when Status is partial or blocked. One question, with the options you see.>
