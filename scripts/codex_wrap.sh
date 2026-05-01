# Source from bash: . ~/repos/ai-agent-learnings/scripts/codex_wrap.sh
# Thin shell interface for the Python Codex wrapper engine.

: "${CODEX_WRAP_CODEX_FLAGS:=--dangerously-bypass-approvals-and-sandbox}"
: "${CODEX_WRAP_ACTIVE_SCAN:=120}"
: "${CODEX_WRAP_KILL_GRACE:=0.2}"
export CODEX_WRAP_CODEX_FLAGS CODEX_WRAP_ACTIVE_SCAN CODEX_WRAP_KILL_GRACE

_CW_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
_CW_PY="$_CW_SCRIPT_DIR/codex_wrap.py"
_CW_UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

_cw_py() { python3 "$_CW_PY" "$@"; }

codex_commit() {
  _cw_py run start "$@"
}

codex_resume() {
  local sid
  if [[ ${1:-} =~ ^$_CW_UUID$ ]]; then
    sid=$1
    shift
  else
    sid=$(_cw_py last-sid || true)
  fi
  [ -n "$sid" ] || { echo 'codex_wrap: no session id found in current branch history' >&2; return 1; }
  _cw_py run resume "$sid" "$@"
}

codex_abort() { _cw_py abort "$@"; }

codex_new_message() {
  _cw_py new-message "$@"
}

codex_active() { _cw_py active; }
codex_active_run() { _cw_py active; }
codex_agents() { _cw_py agents; }
codex_commit_push() { git pull --rebase && codex_commit "$@" && git push; }
