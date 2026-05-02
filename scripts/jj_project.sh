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

_jjp_active_status_items() {
  local file=${1:-STATUS.md}
  [ -f "$file" ] || return 0
  python3 - "$file" <<'PY'
from pathlib import Path
import sys
for line in Path(sys.argv[1]).read_text(errors='replace').splitlines():
    s=line.strip()
    if s.startswith('- [ ]'):
        print(s[5:].strip())
PY
}

jj_task_plan_from_status() {
  local file=${1:-STATUS.md} item
  _jjp_require || return
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    jj_task_new "$item" "Source status: $file"
  done < <(_jjp_active_status_items "$file")
}

jj_task_from_inbox() {
  if [ $# -lt 1 ]; then
    echo "Usage: jj_task_from_inbox <agents/<slug>/inbox.md>" >&2
    return 1
  fi
  _jjp_require || return
  local inbox=$1 body
  [ -f "$inbox" ] || { echo "jj_project: inbox not found: $inbox" >&2; return 1; }
  body=$(python3 - "$inbox" <<'PY'
from pathlib import Path
import sys
text=Path(sys.argv[1]).read_text(errors='replace')
pending=text.split('## pending',1)[1].split('## consumed',1)[0] if '## pending' in text else text
print(pending.strip()[:1200])
PY
)
  jj_task_new "inbox $inbox" "Source inbox: $inbox

$body"
}

jj_task_done_from_transcript() {
  if [ $# -lt 2 ]; then
    echo "Usage: jj_task_done_from_transcript <summary> <transcript-path>" >&2
    return 1
  fi
  _jjp_require || return
  local summary=$1 transcript=$2
  [ -f "$transcript" ] || { echo "jj_project: transcript not found: $transcript" >&2; return 1; }
  jj describe -m "done: $summary

Transcript: $transcript"
}
