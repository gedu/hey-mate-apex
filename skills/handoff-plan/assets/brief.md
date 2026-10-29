# Brief: <task-id> <short title>

Repository: <absolute path to the repository root>
Branch: <branch the implementer works on>
Base commit: <sha the implementer starts from>
Report: <path to report.md next to this brief>

## Goal

<One or two sentences: what changes for a user or a caller when this task is done.>

## Specs

<Number every requirement. Quote the issue or the user word for word: messages, flags, examples.
Never summarize a quoted string. Mark anything you inferred as "Assumption:".>

- S1: <requirement>
- S2: <requirement>

## Allowed edit surfaces

<One repository-relative path or narrow glob per line. Nothing outside this list may change.>

src/modules/<feature>/<file>.ts
src/modules/<feature>/__tests__/<file>.test.ts

## Test first

<The test or tests to write before any production code, and what each one asserts.
Name the file, the public entry point it goes through, and the expected failure message
or reason when it runs RED.>

## Context

<What the implementer would otherwise spend time finding: the existing helpers to reuse,
the pattern a sibling module already follows, a gotcha you hit while exploring.
Use path:line references. Leave this out when there is nothing to add.>

## Verification

<Exact commands, in order, with what passing looks like. The implementer pastes the real
output of each one into the report.>

1. `<focused test command>`: the new tests pass.
2. `<full check command>`: exits 0.

## Mutation testing

<Optional. The command and the minimum score for the changed files, or "Not required".>

## Do not

- Commit, push or open a pull request unless this section says otherwise.
- Change files outside the allowed edit surfaces, including lockfiles and generated files.
- <anything specific to this task>

## When blocked

Stop after two attempts that make no progress. Write the report with `Status: blocked`,
say what you tried, and ask one question. Do not guess on a product decision.
