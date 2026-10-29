#!/usr/bin/env bash
# Tests for install.sh and bin/handoff-run. Every test runs in its own temporary HOME and repo,
# with a fake pi on PATH, so nothing on this machine is touched.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
passed=0
failed=0

check() {
  local name=$1
  shift
  if "$@"; then
    passed=$((passed + 1))
    echo "ok   $name"
  else
    failed=$((failed + 1))
    echo "FAIL $name"
  fi
}

# A scratch HOME with the given runtime dirs, and a repo holding one brief.
setup() {
  scratch=$(mktemp -d)
  export HOME=$scratch/home
  mkdir -p "$HOME"
  for dir in "$@"; do mkdir -p "$HOME/$dir"; done
  repo=$scratch/repo
  mkdir -p "$repo/.handoff/T1"
  git -C "$repo" init -q
  echo "# Brief: T1" >"$repo/.handoff/T1/brief.md"
  mkdir -p "$scratch/bin"
  PATH=$scratch/bin:$ORIGINAL_PATH
  unset XDG_CONFIG_HOME HANDOFF_AGENT HANDOFF_AGENTS_FILE HANDOFF_MODEL HANDOFF_RUNTIME HANDOFF_NO_CHECK
  agents=$HOME/.config/agent-handoff/agents
}

# An agents file holding the given lines.
agents_file() {
  mkdir -p "$(dirname "$agents")"
  printf '%s\n' "$@" >"$agents"
}

# A fake pi: lists FAKE_MODELS for --list-models; otherwise records its arguments and writes a
# report unless FAKE_NO_REPORT is set.
fake_pi() {
  cat >"$scratch/bin/pi" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = --list-models ]; then
  echo "provider   model  context"
  printf '%s\n' "${FAKE_MODELS-callstack  apex  200K
x          m      8K}"
  exit 0
fi
printf '%s\n' "$@" >"$FAKE_ARGS"
pwd >>"$FAKE_ARGS"
if [ -z "${FAKE_NO_REPORT:-}" ]; then
  report=$(printf '%s' "${@: -1}" | sed 's/.*Write the report to //; s/\.$//')
  printf 'Status: done\n' >"$report"
fi
exit "${FAKE_EXIT:-0}"
EOF
  chmod +x "$scratch/bin/pi"
  export FAKE_ARGS=$scratch/args
}

ORIGINAL_PATH=$PATH

# install.sh

test_install_links_only_existing_runtimes() {
  setup .claude/skills .pi/agent/skills
  "$root/install.sh" >/dev/null &&
    [ "$(readlink "$HOME/.claude/skills/handoff-plan")" = "$root/skills/handoff-plan" ] &&
    [ "$(readlink "$HOME/.pi/agent/skills/handoff-implement")" = "$root/skills/handoff-implement" ] &&
    [ ! -e "$HOME/.config/opencode" ]
}

test_check_fails_before_install_and_passes_after() {
  setup .claude/skills
  ! "$root/install.sh" --check >/dev/null &&
    "$root/install.sh" >/dev/null &&
    "$root/install.sh" --check >/dev/null
}

test_install_refuses_to_replace_a_real_directory() {
  setup .claude/skills
  mkdir "$HOME/.claude/skills/handoff-plan"
  touch "$HOME/.claude/skills/handoff-plan/mine"
  ! "$root/install.sh" >/dev/null 2>&1 &&
    [ -f "$HOME/.claude/skills/handoff-plan/mine" ]
}

test_uninstall_removes_only_its_own_links() {
  setup .claude/skills
  ln -s /elsewhere "$HOME/.claude/skills/handoff-implement"
  "$root/install.sh" >/dev/null
  ln -sfn /elsewhere "$HOME/.claude/skills/handoff-implement"
  "$root/install.sh" --uninstall >/dev/null &&
    [ ! -e "$HOME/.claude/skills/handoff-plan" ] &&
    [ "$(readlink "$HOME/.claude/skills/handoff-implement")" = /elsewhere ]
}

test_install_creates_an_agents_file_with_apex_as_default() {
  setup .claude/skills
  "$root/install.sh" >/dev/null &&
    grep -qx 'default apex' "$agents" &&
    grep -Eq '^apex +pi +callstack/apex$' "$agents"
}

test_install_keeps_an_existing_agents_file() {
  setup .claude/skills
  agents_file 'default mine' 'mine opencode a/b'
  "$root/install.sh" >/dev/null &&
    [ "$(cat "$agents")" = "$(printf 'default mine\nmine opencode a/b')" ]
}

test_check_fails_without_an_agents_file() {
  setup .claude/skills
  "$root/install.sh" >/dev/null
  mv "$agents" "$agents.gone"
  ! "$root/install.sh" --check >/dev/null
}

test_install_fails_with_no_runtime() {
  setup
  ! "$root/install.sh" >/dev/null 2>&1
}

# handoff-run

test_run_needs_a_model() {
  setup
  fake_pi
  local out
  out=$(HANDOFF_MODEL='' "$root/bin/handoff-run" "$repo/.handoff/T1/brief.md" 2>&1)
  [ $? -eq 1 ] && [[ $out == *"no model or agent"* ]] && [ ! -f "$FAKE_ARGS" ]
}

test_run_rejects_a_missing_brief() {
  setup
  out=$("$root/bin/handoff-run" --model m "$repo/nope.md" 2>&1)
  [ $? -eq 1 ] && [[ $out == *"brief not found"* ]]
}

test_run_passes_model_skill_and_brief_to_pi_from_the_repo_root() {
  setup
  fake_pi
  (cd "$scratch" && "$root/bin/handoff-run" --model callstack/apex repo/.handoff/T1/brief.md) >/dev/null &&
    grep -qx -- '--model' "$FAKE_ARGS" &&
    grep -qx 'callstack/apex' "$FAKE_ARGS" &&
    grep -qx "$root/skills/handoff-implement" "$FAKE_ARGS" &&
    grep -q "execute the brief at $repo/.handoff/T1/brief.md" "$FAKE_ARGS" &&
    [ "$(tail -1 "$FAKE_ARGS")" = "$(cd "$repo" && pwd -P)" ]
}

test_run_prints_the_report_status() {
  setup
  fake_pi
  out=$("$root/bin/handoff-run" --model m "$repo/.handoff/T1/brief.md")
  [[ $out == *"Status: done"* ]]
}

test_run_exits_2_when_no_report_is_written() {
  setup
  fake_pi
  FAKE_NO_REPORT=1 "$root/bin/handoff-run" --model m "$repo/.handoff/T1/brief.md" >/dev/null 2>&1
  [ $? -eq 2 ]
}

test_run_moves_an_old_report_aside() {
  setup
  fake_pi
  echo "Status: blocked" >"$repo/.handoff/T1/report.md"
  FAKE_NO_REPORT=1 "$root/bin/handoff-run" --model m "$repo/.handoff/T1/brief.md" >/dev/null 2>&1
  [ $? -eq 2 ] && grep -q blocked "$repo/.handoff/T1/report.prev.md"
}

test_run_keeps_the_agent_exit_code() {
  setup
  fake_pi
  FAKE_EXIT=7 "$root/bin/handoff-run" --model m "$repo/.handoff/T1/brief.md" >/dev/null 2>&1
  [ $? -eq 7 ]
}

test_run_splits_extra_pi_args() {
  setup
  fake_pi
  HANDOFF_PI_ARGS='--thinking high' "$root/bin/handoff-run" --model m "$repo/.handoff/T1/brief.md" >/dev/null &&
    grep -qx -- '--thinking' "$FAKE_ARGS" && grep -qx 'high' "$FAKE_ARGS"
}

test_run_rejects_an_unknown_runtime() {
  setup
  out=$("$root/bin/handoff-run" --runtime cursor --model m "$repo/.handoff/T1/brief.md" 2>&1)
  [ $? -eq 1 ] && [[ $out == *"unknown runtime 'cursor'"* ]]
}

test_run_uses_the_named_agent() {
  setup
  fake_pi
  agents_file 'default other' 'other pi x/m' 'apex pi callstack/apex'
  out=$("$root/bin/handoff-run" --agent apex "$repo/.handoff/T1/brief.md") &&
    grep -qx 'callstack/apex' "$FAKE_ARGS" &&
    [[ $out == *"implementer: apex (pi, callstack/apex)"* ]]
}

test_run_uses_the_default_agent_when_none_is_named() {
  setup
  fake_pi
  agents_file '# comment' '' 'default apex' 'apex  pi  callstack/apex'
  "$root/bin/handoff-run" "$repo/.handoff/T1/brief.md" >/dev/null &&
    grep -qx 'callstack/apex' "$FAKE_ARGS"
}

test_run_prefers_handoff_model_over_the_default_agent() {
  setup
  fake_pi
  agents_file 'default apex' 'apex pi callstack/apex'
  HANDOFF_MODEL=m "$root/bin/handoff-run" "$repo/.handoff/T1/brief.md" >/dev/null &&
    grep -qx 'm' "$FAKE_ARGS" && ! grep -qx 'callstack/apex' "$FAKE_ARGS"
}

test_run_rejects_an_unknown_agent_and_lists_the_known_ones() {
  setup
  fake_pi
  agents_file 'default apex' 'apex pi callstack/apex'
  out=$("$root/bin/handoff-run" --agent deepseek "$repo/.handoff/T1/brief.md" 2>&1)
  [ $? -eq 1 ] && [[ $out == *"no agent named 'deepseek'"* ]] && [[ $out == *"known: apex"* ]] &&
    [ ! -f "$FAKE_ARGS" ]
}

test_run_rejects_agent_together_with_model() {
  setup
  fake_pi
  agents_file 'apex pi callstack/apex'
  out=$("$root/bin/handoff-run" --agent apex --model m "$repo/.handoff/T1/brief.md" 2>&1)
  [ $? -eq 1 ] && [[ $out == *"not both"* ]] && [ ! -f "$FAKE_ARGS" ]
}

test_run_rejects_a_malformed_agents_line() {
  setup
  fake_pi
  agents_file 'apex pi'
  out=$("$root/bin/handoff-run" --agent apex "$repo/.handoff/T1/brief.md" 2>&1)
  [ $? -eq 1 ] && [[ $out == *"line 1"* ]] && [ ! -f "$FAKE_ARGS" ]
}

test_run_stops_before_launch_when_the_runtime_lacks_the_model() {
  setup
  fake_pi
  out=$(FAKE_MODELS='' "$root/bin/handoff-run" --model deepseek/chat "$repo/.handoff/T1/brief.md" 2>&1)
  [ $? -eq 3 ] && [[ $out == *"deepseek/chat is not available in pi"* ]] &&
    [[ $out == *"pi --list-models"* ]] && [ ! -f "$FAKE_ARGS" ]
}

test_run_accepts_a_pi_thinking_suffix() {
  setup
  fake_pi
  "$root/bin/handoff-run" --model callstack/apex:high "$repo/.handoff/T1/brief.md" >/dev/null &&
    grep -qx 'callstack/apex:high' "$FAKE_ARGS"
}

test_run_explains_how_to_set_up_opencode() {
  setup
  printf '#!/usr/bin/env bash\necho opencode/free-model\n' >"$scratch/bin/opencode"
  chmod +x "$scratch/bin/opencode"
  out=$("$root/bin/handoff-run" --runtime opencode --model deepseek/chat "$repo/.handoff/T1/brief.md" 2>&1)
  [ $? -eq 3 ] && [[ $out == *"opencode auth login"* ]]
}

test_run_fails_when_the_runtime_is_not_installed() {
  setup
  out=$(PATH=$scratch/bin:/usr/bin:/bin "$root/bin/handoff-run" --model m "$repo/.handoff/T1/brief.md" 2>&1)
  [ $? -eq 3 ] && [[ $out == *"pi is not installed"* ]]
}

test_run_skips_the_check_with_no_check() {
  setup
  fake_pi
  FAKE_MODELS='' "$root/bin/handoff-run" --no-check --model deepseek/chat "$repo/.handoff/T1/brief.md" >/dev/null &&
    grep -qx 'deepseek/chat' "$FAKE_ARGS"
}

test_list_shows_agents_default_and_availability() {
  setup
  fake_pi
  agents_file 'default apex' 'apex pi callstack/apex' 'deepseek pi deepseek/chat'
  out=$("$root/bin/handoff-run" --list) &&
    echo "$out" | grep -Eq '^\* apex +pi +callstack/apex +ok$' &&
    echo "$out" | grep -Eq '^  deepseek +pi +deepseek/chat +not available$'
}

test_list_explains_a_missing_agents_file() {
  setup
  out=$("$root/bin/handoff-run" --list 2>&1)
  [ $? -eq 1 ] && [[ $out == *"install.sh"* ]]
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  check "$t" "$t"
  [ -n "${scratch:-}" ] && rm -rf "$scratch"
  scratch=
done

echo
echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
