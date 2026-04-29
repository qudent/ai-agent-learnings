# Source from bash: . ./codex_wrap_parallel.sh
# Codex wrapper: branch-local parallel runs, same-tree marker commits, and @ worktree branching.

: "${CODEX_WRAP_CODEX_FLAGS:=--dangerously-bypass-approvals-and-sandbox}"
: "${CODEX_WRAP_BRANCH_PREFIX:=codex}"
: "${CODEX_WRAP_BRANCH_CONTEXT:=fresh}"
: "${CODEX_WRAP_PNPM_INSTALL:=1}"
: "${CODEX_WRAP_STDIN_NEW_MESSAGE:=1}"
: "${CODEX_WRAP_POLL_SECONDS:=0.05}"
: "${CODEX_WRAP_ACTIVE_SCAN:=120}"
: "${CODEX_WRAP_KILL_GRACE:=0.2}"

_CW_UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
_CW_HASH='[0-9a-fA-F]{7,40}'

_cw_host() { hostname -f 2>/dev/null || hostname; }
_cw_now() { date -Iseconds 2>/dev/null || date; }
_cw_dir() { local gd; gd=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git rev-parse --absolute-git-dir) || return; mkdir -p "$gd/codex-wrap/logs"; printf '%s\n' "$gd/codex-wrap"; }
_cw_head() { git rev-parse -q --verify HEAD 2>/dev/null || true; }
_cw_subject() { git cat-file commit "${1:-HEAD}" 2>/dev/null | sed -n '/^$/ { n; p; q; }' || true; }
_cw_body() { git cat-file commit "$1" 2>/dev/null | sed '1,/^$/d' || true; }
_cw_oneline() { printf '%s' "$*" | tr '\n\r\t' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | cut -c1-180; }
_cw_field() { git cat-file commit "$1" 2>/dev/null | sed '1,/^$/d' | sed -n "s/^$2:[[:space:]]*//p" | head -n1; }

_cw_update() {
  local msg=$1 tree_src=$2 mode=$3 parent_src=$4 expected=$5 tmp tree new p
  local -a parents=()
  tmp=$(mktemp) || return
  printf '%s\n' "$msg" >"$tmp"
  tree=$(git rev-parse "$tree_src^{tree}") || { rm -f "$tmp"; return 1; }
  if [ "$mode" = normal ]; then
    parents=(-p "$expected")
  else
    set -- $(git rev-list --parents -n1 "$parent_src"); shift || true
    for p in "$@"; do parents+=(-p "$p"); done
  fi
  new=$(git commit-tree "$tree" "${parents[@]}" -F "$tmp") || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
  git update-ref -m codex-wrap HEAD "$new" "$expected" 2>/dev/null || return 1
  printf '%s\n' "$new"
}

_cw_marker() {
  local msg=$1 old subj mode i new
  for i in 1 2 3 4 5 6 7; do
    old=$(_cw_head); [ -n "$old" ] || return 1
    subj=$(_cw_subject "$old"); mode=normal
    [ "${subj#\[autosave\]}" != "$subj" ] && mode=amend
    new=$(_cw_update "$msg" "$old" "$mode" "$old" "$old") && { printf '%s\n' "$new"; return 0; }
    sleep 0.05
  done
  return 1
}

_cw_agent() {
  local text=$1 sid=$2 run_start=$3 old subj prev body msg mode parent i new
  for i in 1 2 3 4 5 6 7; do
    old=$(_cw_head); [ -n "$old" ] || return 1
    subj=$(_cw_subject "$old")
    msg="[codex] $(_cw_oneline "$text")"$'\n\n'"$text"$'\n\n'"session-id: ${sid:-unknown}"$'\n'"run-start-commit-hash: $run_start"
    mode=normal; parent=$old
    if [ "${subj#\[codex\]}" != "$subj" ]; then
      body=$(_cw_body "$old"); msg="$msg"$'\n\nprevious [codex]\n\n'"$body"; mode=amend; parent=$old
    elif [ "${subj#\[autosave\]}" != "$subj" ]; then
      mode=amend; parent=$old
      if git rev-parse -q --verify "$old^" >/dev/null 2>&1; then
        prev=$(_cw_subject "$old^")
        if [ "${prev#\[codex\]}" != "$prev" ]; then body=$(_cw_body "$old^"); msg="$msg"$'\n\nprevious [codex]\n\n'"$body"; parent="$old^"; fi
      fi
    fi
    new=$(_cw_update "$msg" "$old" "$mode" "$parent" "$old") && { printf '%s\n' "$new"; return 0; }
    sleep 0.05
  done
  return 1
}

_cw_last_sid() { git log --format=%B --grep='^\[codex' -n 500 2>/dev/null | grep -Eio "$_CW_UUID" | head -n1; }
_cw_last_sid_at() { git log --format=%B -n 200 "$1" 2>/dev/null | grep -Eio "$_CW_UUID" | head -n1; }
_cw_banner() { local err=$1 sid=$2 b; b=$(awk '/^user$/ { exit } { print }' "$err" 2>/dev/null | sed '/^[[:space:]]*$/d'); [ -n "$b" ] && printf '%s\n' "$b" || printf 'OpenAI Codex\n--------\nworkdir: %s\nsession id: %s\n--------\n' "$PWD" "${sid:-unknown}"; }
_cw_base() { printf '%s\0' codex exec --json $CODEX_WRAP_CODEX_FLAGS; }
_cw_proc_alive() { local pid=$1; [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && ! ps -o stat= -p "$pid" 2>/dev/null | grep -q Z; }
_cw_kill() { local pid=$1 pgid=${2:-}; if [ -n "$pgid" ] && [ "$pgid" != 0 ]; then kill -TERM -- -"$pgid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true; else kill -TERM "$pid" 2>/dev/null || true; fi; sleep "$CODEX_WRAP_KILL_GRACE" 2>/dev/null || true; }
_cw_setsid_wait() { command -v setsid >/dev/null 2>&1 && setsid --help 2>&1 | grep -q -- ' --wait'; }
_cw_wait_pidfile() { local f=$1 i; for i in 1 2 3 4 5 6 7 8 9 10; do [ -s "$f" ] && return 0; sleep 0.01; done; return 1; }

_cw_start_msg() {
  local kind=$1 prompt=$2 sid=$3 pid=$4 pgid=$5 err=${6:-}
  if [ "$kind" = start ]; then printf '[codex_start_user] %s\n\n' "$(_cw_oneline "$prompt")"; _cw_banner "$err" "$sid"; printf 'user\n%s\n\n' "$prompt"; else printf '[codex_resume_user] %s\n\nuser\n%s\n\n' "$(_cw_oneline "$prompt")" "$prompt"; fi
  printf 'session-id: %s\npid: %s\npgid: %s\nhost: %s\ncwd: %s\nstarted-at: %s\n' "${sid:-unknown}" "$pid" "${pgid:-$pid}" "$(_cw_host)" "$PWD" "$(_cw_now)"
}
_cw_stop_msg() { local label=$1 sid=$2 run_start=$3 detail=$4; printf '%s %s\n\nrun-start-commit-hash: %s\nsession-id: %s\n%s\nat: %s\n' "$label" "${sid:-unknown}" "$run_start" "${sid:-unknown}" "$detail" "$(_cw_now)"; }

_cw_run_closed() {
  local run_start=$1
  git log --format='%B%x1e' "$run_start"..HEAD 2>/dev/null | awk -v RS='\036' -v r="$run_start" '/^\[codex_(stop|abort)\]/ && index($0, "run-start-commit-hash: " r) { found=1 } END { exit found ? 0 : 1 }'
}
_cw_latest_active_run() {
  local h subj host pid
  while IFS=$'\037' read -r h subj; do
    [ -n "$h" ] || continue; _cw_run_closed "$h" && continue
    host=$(_cw_field "$h" host); [ -n "$host" ] && [ "$host" != "$(_cw_host)" ] && continue
    pid=$(_cw_field "$h" pid); _cw_proc_alive "$pid" || continue
    printf '%s\n' "$h"; return 0
  done < <(git log --extended-regexp --format='%H%x1f%s' --grep='^\[codex_(start_user|resume_user)\]' -n "$CODEX_WRAP_ACTIVE_SCAN" 2>/dev/null)
  return 1
}
_cw_rename_logs() { local pending=$1 final=$2 d; d=$(_cw_dir) || return; [ -n "$final" ] || return 0; [ -f "$d/logs/$pending.jsonl" ] && mv "$d/logs/$pending.jsonl" "$d/logs/$final.jsonl"; [ -f "$d/logs/$pending.stderr" ] && mv "$d/logs/$pending.stderr" "$d/logs/$final.stderr"; return 0; }

_cw_run() {
  command -v jq >/dev/null 2>&1 || { echo 'codex_wrap: jq required' >&2; return 127; }
  local mode=$1; shift
  local d tmp fifo json err pid pidfile launcher_pid='' pgid='' sid='' prompt='' run_start='' started=0 line typ itype text itemid seen='' rc=0 restart='' dead_polls=0
  local -a base cmd
  d=$(_cw_dir) || return
  tmp="pending-$(date +%Y%m%d-%H%M%S)-$BASHPID-$RANDOM"; fifo="$d/$tmp.fifo"; pidfile="$d/$tmp.pid"; json="$d/logs/$tmp.jsonl"; err="$d/logs/$tmp.stderr"
  mkfifo "$fifo" || return
  mapfile -d '' -t base < <(_cw_base)
  case "$mode" in start) prompt="$*"; cmd=("${base[@]}" "$@") ;; resume) sid=$1; shift; prompt="$*"; cmd=("${base[@]}" resume "$sid" "$@") ;; *) echo "codex_wrap: bad mode $mode" >&2; rm -f "$fifo"; return 2 ;; esac
  if _cw_setsid_wait; then
    setsid --wait sh -c 'printf "%s\n" "$$" >"$1"; shift; exec "$@"' sh "$pidfile" "${cmd[@]}" >"$fifo" 2> >(tee -a "$err" >&2) & launcher_pid=$!
    pid=$launcher_pid; pgid=$pid
  elif command -v setsid >/dev/null 2>&1; then
    setsid sh -c 'printf "%s\n" "$$" >"$1"; shift; exec "$@"' sh "$pidfile" "${cmd[@]}" >"$fifo" 2> >(tee -a "$err" >&2) & launcher_pid=$!
    pid=$launcher_pid; pgid=$pid
  else
    "${cmd[@]}" >"$fifo" 2> >(tee -a "$err" >&2) & pid=$!; launcher_pid=$pid; pgid=$pid
  fi
  trap '_cw_kill "$pid" "$pgid"' INT TERM
  if [ "$mode" = resume ]; then run_start=$(_cw_marker "$(_cw_start_msg resume "$prompt" "$sid" "$pid" "$pgid" "")") || { _cw_kill "$pid" "$pgid"; rm -f "$fifo" "$pidfile"; return 1; }; _cw_rename_logs "$tmp" "$run_start"; json="$d/logs/$run_start.jsonl"; err="$d/logs/$run_start.stderr"; fi
  exec 3<"$fifo"
  if [ -f "$pidfile" ]; then _cw_wait_pidfile "$pidfile" || true; pid=$(cat "$pidfile" 2>/dev/null || printf '%s\n' "$launcher_pid"); pgid=$pid; fi
  while :; do
    if IFS= read -r -t "$CODEX_WRAP_POLL_SECONDS" line <&3; then
      dead_polls=0
      printf '%s\n' "$line" >>"$json"
      typ=$(jq -r '.type // empty' <<<"$line" 2>/dev/null) || continue
      if [ "$typ" = thread.started ]; then
        sid=$(jq -r '.thread_id // .session_id // empty' <<<"$line")
        if [ "$mode" = start ] && [ "$started" = 0 ]; then run_start=$(_cw_marker "$(_cw_start_msg start "$prompt" "$sid" "$pid" "$pgid" "$err")") || { _cw_kill "$pid" "$pgid"; break; }; _cw_rename_logs "$tmp" "$run_start"; json="$d/logs/$run_start.jsonl"; err="$d/logs/$run_start.stderr"; started=1; fi
        continue
      fi
      [ "$typ" = item.completed ] || continue
      itype=$(jq -r '.item.type // empty' <<<"$line"); [ "$itype" = agent_message ] || continue
      text=$(jq -r '.item.text // .item.message // .item.content // empty' <<<"$line"); [ -n "$text" ] || continue
      [ -n "$run_start" ] || continue; _cw_run_closed "$run_start" && continue
      itemid=$(jq -r '.item.id // empty' <<<"$line"); case " $seen " in *" $itemid "*) continue ;; esac; seen="$seen $itemid"
      printf '\ncodex\n%s\n' "$text" >&2
      _cw_agent "$text" "$sid" "$run_start" >/dev/null || true
    else
      if ! _cw_proc_alive "$pid"; then dead_polls=$((dead_polls + 1)); [ "$dead_polls" -gt 8 ] && break; fi
    fi
    if [ "$CODEX_WRAP_STDIN_NEW_MESSAGE" = 1 ] && [ -n "$run_start" ] && [ -t 0 ] && [ -r /dev/tty ] && read -r -t 0 restart </dev/tty 2>/dev/null; then
      read -r restart </dev/tty || restart=''; [ -n "$restart" ] || continue; [ -n "$sid" ] || sid=$(_cw_last_sid)
      _cw_marker "$(_cw_stop_msg '[codex_stop]' "$sid" "$run_start" 'reason: restart with new user message')" >/dev/null || true
      _cw_kill "$pid" "$pgid"; break
    fi
  done
  exec 3<&-; wait "$launcher_pid"; rc=$?; trap - INT TERM; rm -f "$fifo" "$pidfile"
  if [ -n "$run_start" ] && _cw_run_closed "$run_start"; then :; elif [ -n "$run_start" ]; then [ -n "$sid" ] || sid=$(_cw_last_sid); _cw_marker "$(_cw_stop_msg '[codex_stop]' "$sid" "$run_start" "exit-status: $rc")" >/dev/null || true; fi
  [ -n "$restart" ] && _cw_run resume "$sid" "$restart" || return "$rc"
}

_cw_worktree() {
  local c=$1 short root branch wt i=0
  short=$(git rev-parse --short "$c") || return; root=$(git rev-parse --show-toplevel) || return
  while :; do branch="$CODEX_WRAP_BRANCH_PREFIX-$short-$(date +%Y%m%d-%H%M%S)${i:+-$i}"; wt="$root.worktrees/$branch"; git show-ref --verify --quiet "refs/heads/$branch" || [ -e "$wt" ] || break; i=$((i+1)); sleep 1; done
  git worktree add -b "$branch" "$wt" "$c" || return; echo "codex_wrap: branched $branch at $wt" >&2; cd "$wt" || return
  [ "$CODEX_WRAP_PNPM_INSTALL" = 1 ] && [ -f package.json ] && command -v pnpm >/dev/null 2>&1 && pnpm install
  return 0
}

codex_commit() { local c sid; if [ "${1:-}" = @ ]; then shift; c=${1:-}; shift || true; elif [[ ${1:-} == @* ]]; then c=${1#@}; shift; fi; if [ -n "${c:-}" ]; then _cw_worktree "$c" || return; if [ "$CODEX_WRAP_BRANCH_CONTEXT" = resume ]; then sid=$(_cw_last_sid_at HEAD); [ -n "$sid" ] && { _cw_run resume "$sid" "$@"; return; }; fi; fi; _cw_run start "$@"; }
codex_resume() { local c sid; if [ "${1:-}" = @ ]; then shift; c=${1:-}; shift || true; elif [[ ${1:-} == @* ]]; then c=${1#@}; shift; fi; if [ -n "${c:-}" ]; then _cw_worktree "$c" || return; [ "$CODEX_WRAP_BRANCH_CONTEXT" = resume ] && sid=$(_cw_last_sid_at HEAD) || sid=''; [ -n "$sid" ] && _cw_run resume "$sid" "$@" || _cw_run start "$@"; return; fi; if [[ ${1:-} =~ ^$_CW_UUID$ ]]; then sid=$1; shift; else sid=$(_cw_last_sid); fi; [ -n "$sid" ] || { echo 'codex_wrap: no session id found in current branch history' >&2; return 1; }; _cw_run resume "$sid" "$@"; }
codex_abort() { local run sid pid pgid host cwd; run=${1:-}; [[ $run =~ ^$_CW_HASH$ ]] || run=$(_cw_latest_active_run); [ -n "$run" ] || { echo 'codex_wrap: no active Codex run found in current branch history' >&2; return 1; }; sid=$(_cw_field "$run" session-id); pid=$(_cw_field "$run" pid); pgid=$(_cw_field "$run" pgid); host=$(_cw_field "$run" host); cwd=$(_cw_field "$run" cwd); [ -z "$host" ] || [ "$host" = "$(_cw_host)" ] || { echo "codex_wrap: active run is on host $host" >&2; return 1; }; _cw_proc_alive "$pid" || { echo "codex_wrap: process $pid is not alive" >&2; return 1; }; ( cd "${cwd:-$PWD}" && _cw_marker "$(_cw_stop_msg '[codex_abort]' "$sid" "$run" 'reason: abort')" >/dev/null ) || return; _cw_kill "$pid" "$pgid"; }
codex_new_message() { local c run sid pid pgid host cwd; if [ "${1:-}" = @ ]; then shift; c=${1:-}; shift || true; codex_commit @ "$c" "$@"; return; elif [[ ${1:-} == @* ]]; then c=${1#@}; shift; codex_commit @ "$c" "$@"; return; fi; run=$(_cw_latest_active_run || true); if [ -n "$run" ]; then sid=$(_cw_field "$run" session-id); pid=$(_cw_field "$run" pid); pgid=$(_cw_field "$run" pgid); host=$(_cw_field "$run" host); cwd=$(_cw_field "$run" cwd); [ -z "$host" ] || [ "$host" = "$(_cw_host)" ] || { echo "codex_wrap: active run is on host $host" >&2; return 1; }; ( cd "${cwd:-$PWD}" && _cw_marker "$(_cw_stop_msg '[codex_stop]' "$sid" "$run" 'reason: restart with new user message')" >/dev/null ) || return; _cw_kill "$pid" "$pgid"; ( cd "${cwd:-$PWD}" && _cw_run resume "$sid" "$@" ); else codex_resume "$@"; fi; }
codex_branch() { codex_commit @ "$@"; }
codex_at() { codex_commit @ "$@"; }
codex_active() { _cw_latest_active_run; }
codex_active_run() { _cw_latest_active_run; }
codex_commit_push() { git pull --rebase && codex_commit "$@" && git push; }
