# Reviewing an implementer report

The review is quick, but it is never a read of the report alone. The report says what the
implementer believes happened. The repository says what did. Check the repository.

Run the steps in order and stop at the first failure. That failure goes into the correction.

## 1. The report is complete

- `Status:` is `done`. For `partial` or `blocked`, read the question and answer it first.
- Every spec from the brief has a line under `## Specs covered`.
- Every command from `## Verification` has a block with pasted output.

## 2. Nothing changed outside the brief

```sh
git diff --stat <base commit>
git status --short
```

Every path must match a line in `## Allowed edit surfaces`. An extra file is a defect even
when the change looks harmless. Lockfiles and generated files count.

## 3. The checks pass for you

Re-run the main verification command yourself, usually the full check. Compare the summary
line with the one in the report. A mismatch is a defect, and worth telling the user about:
it means the report was not true.

## 4. The diff does what the specs say

Read the diff with the brief open. For each `S#`:

- find the test that proves it, and check it goes through the public entry point;
- check the test asserts the observable result (output, return value, stored data), not an
  internal call;
- check the production change is the smallest one that makes that test pass.

## 5. The tests were red first

The report has a `## RED evidence` block. When the change is risky, confirm it: copy the new
test files onto the base commit in a scratch worktree and run them there. They must fail.

```sh
scratch=$(mktemp -d)
git worktree add --detach "$scratch" <base commit>
for f in <test files>; do mkdir -p "$scratch/$(dirname "$f")"; cp "$f" "$scratch/$f"; done
(cd "$scratch" && <install command> && <focused test command>)
git worktree remove --force "$scratch"
```

The install step is there because a fresh worktree has no dependencies. Skip it when the
runner needs none.

## 6. Mutation score, when the brief asked for it

Check the score against the threshold. Surviving mutants in the changed lines are a defect
unless the report explains why each one is equivalent.

## Verdict

- All six pass: accepted. Tell the user, then start the next task.
- Any failure: append `## Correction 1` to the brief, one line per defect with the file and
  what is wrong, and dispatch again.
- The correction comes back still failing: stop and ask the user. Do not send a third round.
