#!/usr/bin/env bash
# Link the handoff skills into every agent runtime found on this machine.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [--check | --uninstall]

Links skills/handoff-plan and skills/handoff-implement into the skill directory of every
runtime that exists here. A runtime whose directory is missing is skipped, never created.
Also creates ~/.config/agent-handoff/agents, with apex as the default implementer, when it
does not exist yet. An existing agents file is never changed.

  (no flag)    create the links and the agents file
  --check      report each link and the agents file; exit 1 when one is missing or wrong
  --uninstall  remove the links this script created, and nothing else; the agents file stays
EOF
}

mode=install
case ${1:-} in
  '') ;;
  --check) mode=check ;;
  --uninstall) mode=uninstall ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "install.sh: unknown option '$1' (see --help)" >&2
    exit 1
    ;;
esac

root=$(cd "$(dirname "$0")" && pwd)
skills=(handoff-plan handoff-implement)
# Claude Code, pi, OpenCode, and the shared directory Codex and others read.
targets=(
  "$HOME/.claude/skills"
  "$HOME/.pi/agent/skills"
  "$HOME/.config/opencode/skills"
  "$HOME/.agents/skills"
)

found=0
bad=0
for dir in "${targets[@]}"; do
  [ -d "$dir" ] || continue
  found=1
  for skill in "${skills[@]}"; do
    src=$root/skills/$skill
    link=$dir/$skill
    case $mode in
      install)
        if [ -e "$link" ] && [ ! -L "$link" ]; then
          echo "skip $link: a real directory is there, not a link; move it first" >&2
          bad=1
          continue
        fi
        ln -sfn "$src" "$link"
        echo "linked $link"
        ;;
      check)
        if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then
          echo "ok      $link"
        else
          echo "missing $link"
          bad=1
        fi
        ;;
      uninstall)
        if [ -L "$link" ] && [ "$(readlink "$link")" = "$src" ]; then
          rm "$link"
          echo "removed $link"
        fi
        ;;
    esac
  done
done

if [ "$found" = 0 ]; then
  echo "no runtime skill directory found; looked in: ${targets[*]}" >&2
  exit 1
fi

# The agents file belongs to the user once it exists: never overwritten, never removed.
agents=${HANDOFF_AGENTS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-handoff/agents}
case $mode in
  install)
    if [ -f "$agents" ]; then
      echo "kept    $agents"
    else
      mkdir -p "$(dirname "$agents")"
      cat >"$agents" <<'EOF'
# Implementer agents for handoff-run, one per line: <name> <runtime> <model>.
# runtime is pi or opencode. model is the id that runtime uses; find it with
# `pi --list-models` or `opencode models`. Run `handoff-run --list` to check them.
# The default line names the agent used when the planner is not told which one.
default apex

apex      pi        callstack/apex
# deepseek  opencode  deepseek/<id from opencode models>
EOF
      echo "created $agents (default: apex)"
    fi
    ;;
  check)
    if [ -f "$agents" ]; then
      echo "ok      $agents"
    else
      echo "missing $agents"
      bad=1
    fi
    ;;
  uninstall)
    [ ! -f "$agents" ] || echo "kept    $agents (your agents; delete it yourself if you want)"
    ;;
esac

if [ "$mode" = install ]; then
  echo
  echo "To call handoff-run from anywhere, put $root/bin on your PATH."
fi

exit "$bad"
