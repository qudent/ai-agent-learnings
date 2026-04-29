# Source from bash: . ~/learnings/scripts/codex_wrap.sh
# Thin shell interface for the Python Codex wrapper engine.

: "${CODEX_WRAP_CODEX_FLAGS:=--dangerously-bypass-approvals-and-sandbox}"
: "${CODEX_WRAP_BRANCH_PREFIX:=codex}"
: "${CODEX_WRAP_BRANCH_CONTEXT:=fresh}"
: "${CODEX_WRAP_PNPM_INSTALL:=1}"
: "${CODEX_WRAP_STDIN_NEW_MESSAGE:=1}"
: "${CODEX_WRAP_POLL_SECONDS:=0.05}"
: "${CODEX_WRAP_ACTIVE_SCAN:=120}"
: "${CODEX_WRAP_KILL_GRACE:=0.2}"
export CODEX_WRAP_CODEX_FLAGS CODEX_WRAP_BRANCH_PREFIX CODEX_WRAP_BRANCH_CONTEXT
export CODEX_WRAP_PNPM_INSTALL CODEX_WRAP_STDIN_NEW_MESSAGE CODEX_WRAP_POLL_SECONDS
export CODEX_WRAP_ACTIVE_SCAN CODEX_WRAP_KILL_GRACE

_CW_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
_CW_PY="$_CW_SCRIPT_DIR/codex_wrap.py"
_CW_UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

_cw_py() { python3 "$_CW_PY" "$@"; }

_cw_parse_at() {
  _cw_at_commit=''
  if [ "${1:-}" = @ ]; then
    shift
    _cw_at_commit=${1:-}
    shift || true
  elif [[ ${1:-} == @* ]]; then
    _cw_at_commit=${1#@}
    shift
  fi
  _cw_at_rest=("$@")
}

_cw_cd_worktree() {
  local wt
  wt=$(_cw_py worktree "$1") || return
  cd "$wt" || return
}

codex_commit() {
  local sid
  _cw_parse_at "$@"
  set -- "${_cw_at_rest[@]}"
  if [ -n "$_cw_at_commit" ]; then
    _cw_cd_worktree "$_cw_at_commit" || return
    if [ "$CODEX_WRAP_BRANCH_CONTEXT" = resume ]; then
      sid=$(_cw_py last-sid HEAD || true)
      [ -n "$sid" ] && { _cw_py run resume "$sid" "$@"; return; }
    fi
  fi
  _cw_py run start "$@"
}

codex_resume() {
  local sid
  _cw_parse_at "$@"
  set -- "${_cw_at_rest[@]}"
  if [ -n "$_cw_at_commit" ]; then
    _cw_cd_worktree "$_cw_at_commit" || return
    [ "$CODEX_WRAP_BRANCH_CONTEXT" = resume ] && sid=$(_cw_py last-sid HEAD || true) || sid=''
    [ -n "$sid" ] && _cw_py run resume "$sid" "$@" || _cw_py run start "$@"
    return
  fi
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
  _cw_parse_at "$@"
  set -- "${_cw_at_rest[@]}"
  if [ -n "$_cw_at_commit" ]; then
    codex_commit @ "$_cw_at_commit" "$@"
    return
  fi
  _cw_py new-message "$@"
}

codex_branch() { codex_commit @ "$@"; }
codex_at() { codex_commit @ "$@"; }
codex_active() { _cw_py active; }
codex_active_run() { _cw_py active; }
codex_commit_push() { git pull --rebase && codex_commit "$@" && git push; }
