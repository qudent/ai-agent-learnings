# Source from bash: . ~/repos/ai-agent-learnings/scripts/jj_project.sh
# Experimental Jujutsu-backed project-management helpers.

_JJP_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

_jjp_require() {
  command -v jj >/dev/null 2>&1 || {
    echo "jj_project: jj is not installed; install Jujutsu before using these helpers" >&2
    return 127
  }
  git rev-parse --show-toplevel >/dev/null 2>&1 || {
    echo "jj_project: run inside a Git repository" >&2
    return 1
  }
}

jj_project_init() {
  _jjp_require || return
  if [ -d .jj ]; then
    echo "jj_project: .jj already exists"
    return 0
  fi
  jj git init --colocate
}

jj_task_new() {
  if [ $# -lt 1 ]; then
    echo "Usage: jj_task_new <title> [details...]" >&2
    return 1
  fi
  _jjp_require || return
  local title=$1
  shift
  local details=${*:-}
  if [ -n "$details" ]; then
    jj new -m "todo: $title

$details"
  else
    jj new -m "todo: $title"
  fi
}

jj_task_note() {
  if [ $# -lt 1 ]; then
    echo "Usage: jj_task_note <message...>" >&2
    return 1
  fi
  _jjp_require || return
  jj describe -m "$*"
}

jj_task_done() {
  if [ $# -lt 1 ]; then
    echo "Usage: jj_task_done <summary...>" >&2
    return 1
  fi
  _jjp_require || return
  jj describe -m "done: $*"
}

jj_task_log() {
  _jjp_require || return
  jj log -r 'mutable()' --template 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
}
