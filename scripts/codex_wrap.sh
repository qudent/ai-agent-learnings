# Source this file from bash:  . ./codex_wrap.sh

_codex_dir() {
  local gd
  gd=$(git rev-parse --git-dir) || return
  mkdir -p "$gd/codex-wrap/logs"
  printf '%s\n' "$gd/codex-wrap"
}

_codex_oneline() {
  printf '%s' "$*" | tr '\n\r\t' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | cut -c1-180
}

_codex_commit_marker() {
  local msg=$1 dir
  dir=$(_codex_dir) || return
  (
    command -v flock >/dev/null 2>&1 && flock 9
    if git log -1 --pretty=%s 2>/dev/null | grep -q '^\[autosave\]'; then
      git commit --allow-empty --amend --only -m "$msg" >/dev/null
    else
      git commit --allow-empty --only -m "$msg" >/dev/null
    fi
  ) 9>"$dir/git.lock"
}

_codex_last_session_id() {
  git log --all --format=%B --grep='^\[codex' -n 500 2>/dev/null |
    grep -Eio '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' |
    head -n1
}

_codex_banner() {
  local errlog=$1 sid=$2 banner ver
  banner=$(awk '/^user$/ { exit } { print }' "$errlog" 2>/dev/null | sed '/^[[:space:]]*$/d')
  if [ -n "$banner" ]; then
    printf '%s\n' "$banner"
  else
    ver=$(codex --version 2>/dev/null || true)
    [ -n "$ver" ] || ver='OpenAI Codex'
    printf '%s\n--------\nworkdir: %s\nsession id: %s\n--------\n' "$ver" "$PWD" "$sid"
  fi
}

_codex_write_state() {
  local dir=$1 runid=$2 pid=$3 pgid=$4 sid=${5:-}
  {
    printf 'runid=%q\n' "$runid"
    printf 'pid=%q\n' "$pid"
    printf 'pgid=%q\n' "$pgid"
    printf 'session_id=%q\n' "$sid"
  } >"$dir/current"
}

_codex_clear_state() {
  local dir=$1 my_runid=$2 runid pid pgid session_id
  [ -f "$dir/current" ] || return 0
  # shellcheck disable=SC1090
  . "$dir/current"
  [ "${runid:-}" = "$my_runid" ] && rm -f "$dir/current"
}

_codex_kill() {
  local pid=$1 pgid=${2:-0}
  if [ "$pgid" = 1 ]; then
    kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
  else
    kill "$pid" 2>/dev/null || true
  fi
}

_codex_run() {
  command -v jq >/dev/null 2>&1 || { echo 'codex_wrap: jq is required for codex exec --json parsing' >&2; return 127; }

  local mode=$1; shift
  local dir runid fifo jsonlog errlog pid pgid=0 session_id='' instruction='' started=0 rc=0
  local line typ sid itype text itemid seen_ids='' banner subject
  local -a cmd

  dir=$(_codex_dir) || return
  runid="$(date +%Y%m%d-%H%M%S)-$$-$RANDOM"
  fifo="$dir/$runid.fifo"
  jsonlog="$dir/logs/$runid.jsonl"
  errlog="$dir/logs/$runid.stderr"
  mkfifo "$fifo" || return

  case "$mode" in
    start)
      instruction="$*"
      cmd=(codex exec --json "$@")
      ;;
    resume)
      session_id=$1; shift
      instruction="$*"
      _codex_commit_marker "[codex_resume] $session_id"$'\n\n'"user"$'\n'"$instruction"
      cmd=(codex exec --json resume "$session_id" "$@")
      ;;
  esac

  if command -v setsid >/dev/null 2>&1; then
    setsid "${cmd[@]}" >"$fifo" 2> >(tee -a "$errlog" >&2) & pid=$!; pgid=1
  else
    "${cmd[@]}" >"$fifo" 2> >(tee -a "$errlog" >&2) & pid=$!; pgid=0
  fi
  _codex_write_state "$dir" "$runid" "$pid" "$pgid" "$session_id"

  trap '_codex_kill "$pid" "$pgid"' INT TERM

  while IFS= read -r line; do
    printf '%s\n' "$line" >>"$jsonlog"
    typ=$(jq -r '.type // empty' <<<"$line" 2>/dev/null) || continue

    if [ "$typ" = thread.started ]; then
      sid=$(jq -r '.thread_id // .session_id // empty' <<<"$line")
      if [ -n "$sid" ]; then
        session_id=$sid
        _codex_write_state "$dir" "$runid" "$pid" "$pgid" "$session_id"
      fi
      if [ "$mode" = start ] && [ "$started" = 0 ]; then
        banner=$(_codex_banner "$errlog" "$session_id")
        subject=$(_codex_oneline "$instruction")
        _codex_commit_marker "[codex_start_user] $subject"$'\n\n'"$banner"$'\n'"user"$'\n'"$instruction"
        started=1
      fi
      continue
    fi

    [ "$typ" = item.completed ] || continue
    itype=$(jq -r '.item.type // empty' <<<"$line")
    [ "$itype" = agent_message ] || continue
    text=$(jq -r '.item.text // empty' <<<"$line")
    [ -n "$text" ] || continue
    itemid=$(jq -r '.item.id // empty' <<<"$line")
    case " $seen_ids " in *" $itemid "*) continue ;; esac
    seen_ids="$seen_ids $itemid"

    printf '\ncodex\n%s\n' "$text" >&2
    subject=$(_codex_oneline "$text")
    _codex_commit_marker "[codex] $subject"$'\n\n'"$text"$'\n\n'"$session_id"
  done <"$fifo"

  wait "$pid"; rc=$?
  trap - INT TERM
  rm -f "$fifo"
  _codex_clear_state "$dir" "$runid"

  if [ -f "$dir/abort.$runid" ]; then
    rm -f "$dir/abort.$runid"
  elif [ -f "$dir/suppress_stop.$runid" ]; then
    rm -f "$dir/suppress_stop.$runid"
  else
    [ -n "$session_id" ] || session_id=$(_codex_last_session_id)
    [ -n "$session_id" ] || session_id=unknown
    _codex_commit_marker "[codex_stop] $session_id"$'\n\n'"exit status: $rc"
  fi

  return "$rc"
}

codex_commit() {
  _codex_run start "$@"
}

codex_resume() {
  local sid
  if [[ ${1:-} =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    sid=$1; shift
  else
    sid=$(_codex_last_session_id)
  fi
  [ -n "$sid" ] || { echo 'codex_wrap: no Codex session id found in git history' >&2; return 1; }
  _codex_run resume "$sid" "$@"
}

codex_abort() {
  local dir runid pid pgid session_id
  dir=$(_codex_dir) || return
  [ -f "$dir/current" ] || { echo 'codex_wrap: no running Codex process recorded' >&2; return 1; }
  # shellcheck disable=SC1090
  . "$dir/current"
  : "${session_id:=unknown}"
  : "${pgid:=0}"
  : "${runid:=unknown}"
  printf '%s\n' "$session_id" >"$dir/abort.$runid"
  _codex_kill "$pid" "$pgid"
  _codex_commit_marker "[codex_abort] $session_id"
}

codex_new_message() {
  local dir runid pid pgid session_id sid
  dir=$(_codex_dir) || return
  sid=$(_codex_last_session_id)
  if [ -f "$dir/current" ]; then
    # shellcheck disable=SC1090
    . "$dir/current"
    [ -n "${session_id:-}" ] && sid=$session_id
    : "${pgid:=0}"
    printf '%s\n' "${session_id:-unknown}" >"$dir/suppress_stop.$runid"
    _codex_commit_marker "[codex_stop] ${session_id:-unknown}"$'\n\n'"restart with new user message"
    _codex_kill "$pid" "$pgid"
  fi
  [ -n "$sid" ] || { echo 'codex_wrap: no Codex session id found in git history' >&2; return 1; }
  codex_resume "$sid" "$@"
}

codex_commit_push() {
  git pull --rebase
  codex_commit "$@"
  git push
}
