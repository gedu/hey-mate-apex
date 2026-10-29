# agent-handoff

One agent plans and reviews. Another agent writes the code. They pass work to each other
through two Markdown files in the repository, so any pair of tools can play either role:
Claude Code planning with Apex implementing in pi, OpenCode on both sides, or a person
copying files between two chat windows.

This is version 0.1. The scripts are tested; the flow itself has not yet been run end to end
on a real task.

## Why files

Every agent runtime can read and write a file in the repository. Few of them can talk to
each other, and the ones that can do it in different ways that change between releases. A
file contract keeps working when someone swaps the runtime, the model or the editor.

It also leaves a record. When a task goes wrong, the brief shows what was asked and the
report shows what the implementer claimed. You can compare both with the diff.

## How a task flows

1. You open the planner (for example Claude Code) and give it an issue.
2. The planner explores the code, splits the work into tasks and writes one brief per task
   to `.handoff/<task-id>/brief.md`.
3. The implementer (for example Apex in pi) reads the brief, writes the failing tests, makes
   them pass, runs the checks and writes `.handoff/<task-id>/report.md`.
4. The planner reviews: it re-runs the checks itself, compares the diff against the allowed
   files and reads the tests against the specs.
5. The planner accepts the task or appends a correction to the brief. One correction round
   per task. If that still fails, it asks you.

`.handoff/` goes into `.git/info/exclude`, which is local to your clone. The project's
`.gitignore` and history stay untouched.

## Install

```sh
git clone <this repository> ~/agent-handoff
cd ~/agent-handoff
./install.sh
```

`install.sh` links the two skills into the skill directory of every runtime it finds:
`~/.claude/skills`, `~/.pi/agent/skills`, `~/.config/opencode/skills` and `~/.agents/skills`.
It skips a runtime whose directory does not exist, and it never overwrites a directory that
is not its own link. `./install.sh --check` reports the links, and `./install.sh --uninstall`
removes them.

It also creates `~/.config/agent-handoff/agents`, which lists the agents that can implement,
with Apex as the default. An existing file is never touched, and uninstall leaves it in place.

To call `handoff-run` from any directory, add `~/agent-handoff/bin` to your `PATH`.

## Who plans and who codes

The planner is whichever agent you talk to. Open Claude Code and Claude plans; open OpenCode
and that model plans. Nothing configures it.

The implementer comes from the agents file:

```
# <name>  <runtime>  <model>
default apex

apex      pi        callstack/apex
deepseek  opencode  deepseek/deepseek-chat
```

To add a model, add one line. To change who codes when you name nobody, edit the `default`
line. The model id is whatever the runtime calls it: `pi --list-models` and `opencode models`
print them.

agent-handoff never sees an API key. Each runtime keeps its own credentials: log in once in
pi (`/login`, or the provider's API key variable, plus `~/.pi/agent/models.json` for custom
providers) or in OpenCode (`opencode auth login`).

`handoff-run --list` shows every agent, marks the default with `*`, and checks each one:

```
agents file: /Users/you/.config/agent-handoff/agents
* apex       pi        callstack/apex                 ok
  deepseek   opencode  deepseek/deepseek-chat         not available
```

If you ask for an agent that is not set up, nothing runs. `handoff-run` stops before
launching, exits 3, and says what to do, for example
`deepseek/deepseek-chat is not available in opencode: log in with: opencode auth login, ...`.
The planner shows you that message and asks which agent to use instead.

## Use it

Start the planner in the project and tell it what you want, for example:

> Take issue #42. Plan it with the handoff-plan skill, and hand each task to deepseek.

Name an agent from the agents file, or name none to get the default.

From there, the dispatch step depends on how the implementer runs.

### The planner runs the implementer for you

When the planner can run shell commands and the implementer has a headless mode, the planner
calls:

```sh
handoff-run .handoff/T1/brief.md --agent deepseek
```

`handoff-run` prints which implementer it started, runs it non-interactively, waits for it,
and prints the report's `Status:` line. The agent's full output goes to `.handoff/T1/run.log`.
Claude Code can run this in the background and pick up the result when it exits, so you keep
talking to the planner in the meantime.

Supported runtimes are `pi` (`pi -p`) and `opencode` (`opencode run`). You can still skip the
agents file and pass `--runtime pi --model callstack/apex`, or set `HANDOFF_RUNTIME` and
`HANDOFF_MODEL` in your shell profile; those win over the file's default. `--no-check` skips
the pre-launch check, for a runtime whose model list misses a model it can still run.
`handoff-run --help` has the full order.

### You run the implementer yourself

Open the implementer in a second terminal, in the same repository, and paste:

```
Load the handoff-implement skill and execute .handoff/T1/brief.md.
```

When it finishes, tell the planner the report is ready.

### A chat without tools

A web chat (ChatGPT, Claude.ai) cannot edit your files or run your tests. You can still use
the brief as a prompt and apply the answer by hand, but you then run every command and paste
the output into the report yourself. Most of the value comes from the implementer running
the checks, so prefer a runtime that has tool access.

## The brief and the report

The templates live in `skills/handoff-plan/assets/brief.md` and
`skills/handoff-implement/assets/report.md`.

A brief is ready when it has four things: numbered specs quoted from the issue, the list of
files that may change, the test to write first, and the exact commands that prove the work.
The implementer is told to change nothing outside that list and to stop and ask when a spec
needs a product decision.

A report carries the real output of every command. The implementer is told never to write
"passed" without it. That rule is what makes a quick review possible.

## Reviewing

The planner follows `skills/handoff-plan/references/review.md`. In short, it never trusts a
report on its word:

- `git diff --stat` against the base commit must list only allowed files;
- the planner re-runs the main check command itself and compares the result;
- each spec needs a test that goes through the public entry point and asserts what a caller
  sees;
- for risky changes, the new tests are run against the base commit to prove they fail there.

## What this does not do

- It does not commit, push or open pull requests. The brief can allow a commit; delivery
  stays with you.
- It does not retry on its own. One correction round, then a question for you.
- It does not sandbox the implementer. The allowed edit surfaces are an instruction, checked
  at review time, not a permission the runtime enforces.

## Layout

```
skills/handoff-plan/        planner skill: brief template, review checklist
skills/handoff-implement/   implementer skill: report template
bin/handoff-run             runs the implementer headless on one brief
install.sh                  links the skills into each runtime
test/run.sh                 tests for both scripts
```

## Tests

```sh
bash test/run.sh
```

The tests use a temporary `HOME` and a fake `pi`, so they touch nothing on your machine.
