# Source from bash: . ~/repos/ai-agent-learnings/scripts/branch_commands.sh
# Generic branch/worktree command helpers. Codex-specific wrappers belong at the edge.

_BC_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=./parallel-worktrees/worktrees.sh
. "$_BC_SCRIPT_DIR/parallel-worktrees/worktrees.sh"

: "${DO_AT_BRANCH_PREFIX:=work}"

_do_at_unique_branch() {
  local commit=$1 short branch i=0
  short=$(git rev-parse --short --verify --quiet --end-of-options "$commit^{commit}") || return
  while :; do
    branch="$DO_AT_BRANCH_PREFIX-$short-$(date +%Y%m%d-%H%M%S)${i:+-$i}"
    git show-ref --verify --quiet "refs/heads/$branch" || { printf '%s\n' "$branch"; return 0; }
    i=$((i + 1))
    sleep 1
  done
}

do_at_branch() {
  if [ $# -lt 2 ]; then
    echo "Usage: do_at_branch <branch> <command...>" >&2
    return 1
  fi
  local branch=$1 wt
  shift
  wt=$(worktree_find_for_branch "$branch" 2>/dev/null || true)
  if [ -n "$wt" ]; then
    ( cd "$wt" && "$@" )
    return
  fi
  ( worktree_create "$branch" && "$@" )
}

do_at_commit() {
  if [ $# -lt 2 ]; then
    echo "Usage: do_at_commit <commit> <command...>" >&2
    return 1
  fi
  local commit=$1 branch
  shift
  branch=$(_do_at_unique_branch "$commit") || return
  ( worktree_create_from_commit "$branch" "$commit" && "$@" )
}

codex_in_branch() {
  if [ "${1:-}" != @ ] || [ $# -lt 3 ]; then
    echo "Usage: codex_in_branch @ <branch-or-commit> <prompt...>" >&2
    return 1
  fi
  shift
  local target=$1
  shift
  if git show-ref --verify --quiet "refs/heads/$target"; then
    do_at_branch "$target" codex_commit "$@"
  else
    do_at_commit "$target" codex_commit "$@"
  fi
}

_codex_spawn_log() {
  local common logdir
  common=$(git rev-parse --path-format=absolute --git-common-dir) || return
  logdir="$common/codex-wrap/dispatch"
  mkdir -p "$logdir"
  printf '%s/%s-%s.log\n' "$logdir" "$(date +%Y%m%d-%H%M%S)" "$$"
}

codex_spawn() {
  if [ $# -lt 2 ]; then
    echo "Usage: codex_spawn <codex_commit|codex_resume|codex_new_message|codex_in_branch> <args...>" >&2
    return 1
  fi
  local fn=$1 caller log pid
  shift
  case "$fn" in
    codex_commit|codex_resume|codex_new_message|codex_in_branch) ;;
    *)
      echo "codex_spawn: unsupported command: $fn" >&2
      return 2
      ;;
  esac
  caller=${CODEX_WRAP_CALLED_BY:-}
  if [ -z "$caller" ]; then
    caller=$(codex_active 2>/dev/null || printf 'user')
  fi
  log=$(_codex_spawn_log) || return
  CODEX_WRAP_CALLED_BY=$caller setsid bash -lc '
    source "$1"
    source "$2"
    shift 2
    fn=$1
    shift
    "$fn" "$@"
  ' bash "$_BC_SCRIPT_DIR/codex_wrap.sh" "$_BC_SCRIPT_DIR/branch_commands.sh" "$fn" "$@" </dev/null >>"$log" 2>&1 &
  pid=$!
  disown "$pid" 2>/dev/null || true
  printf 'codex_spawn: pid=%s log=%s command=%s called-by=%s\n' "$pid" "$log" "$fn" "$caller"
}

codex_checkpoint() {
  local msg=${*:-last save state}
  git commit --allow-empty -m "checkpoint: $msg"
}

codex_status() {
  if [ $# -lt 1 ]; then
    echo "Usage: codex_status <one-line-summary>" >&2
    return 1
  fi
  git commit --allow-empty -m "[status] $*"
}

_codex_compact_subjects() {
  awk -F '\t' '
    {
      refs=$2
      subj=$3
      if (subj ~ /^\[codex_start_user\] You are a Codex dispatch\/orchestration agent\./) {
        subj="[codex_start_user] <dispatch prompt elided>"
      } else if (subj ~ /^\[codex\] You are a Codex dispatch\/orchestration agent\./) {
        subj="[codex] <dispatch transcript elided>"
      }
      if (length(subj) > 120) subj=substr(subj, 1, 117) "..."
      if (refs != "") print $1 " (" refs ") " subj
      else print $1 " " subj
    }
  '
}

_codex_dispatch_context() {
  if [ -x "$_BC_SCRIPT_DIR/agent_context.sh" ]; then
    "$_BC_SCRIPT_DIR/agent_context.sh" context --limit 80
    return
  fi
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf '(unknown)')
  printf 'Current branch: %s\n' "$branch"
  printf 'Current HEAD: %s\n\n' "$(git rev-parse --short HEAD 2>/dev/null || printf unknown)"
  printf 'Active run on this branch:\n'
  codex_active 2>/dev/null || printf 'none\n'
  printf '\nRecent commits (subjects compacted; dispatch prompts elided):\n'
  git log --format='%h%x09%D%x09%s' --max-count=18 2>/dev/null | _codex_compact_subjects || true
  if [ -f STATUS.md ]; then
    printf '\nCurrent STATUS.md:\n'
    sed -n '1,120p' STATUS.md
  fi
}

codex_dispatch() {
  if [ $# -lt 1 ]; then
    echo "Usage: codex_dispatch <instruction...>" >&2
    return 1
  fi
  local user_instruction context prompt
  user_instruction=$*
  context=$(_codex_dispatch_context)
  prompt=$(cat <<EOF
You are a Codex dispatch/orchestration agent. Do not complete the requested implementation yourself unless it is needed only to decide dispatch.

User instruction:
$user_instruction

Relevant concise context:
$context

Dispatch contract:
- First reconcile state from the Agent Context Pack: branch/worktree, upstream divergence if visible, active local wrapper runs, queued work, current STATUS goals, active transcript pointers, inboxes, recent transcript excerpts, and the audit trail.
- Classify the request as exactly one of: status-only, trivial-chat, direct-implementation, parallel-dispatch, cleanup, or blocked.
- If status-only or trivial-chat, do not spawn; answer directly in the final status.
- If implementation/subagent work is needed, prefer dispatch/delegation: split into independent, reviewable tasks with disjoint write scopes and call child agents through codex_spawn rather than doing broad work in the dispatcher.
- Do direct implementation locally only for the tiny glue needed to decide dispatch, unblock routing, or fix the dispatcher itself; otherwise delegate.
- Inspect currently running sessions before dispatching: compare recent run-start marker pid/cwd metadata with the live process table above, then decide whether to call codex_commit, codex_new_message/codex_continue-style followup, codex_abort, or explicitly report blocked-by.
- Read transcripts/index.md and the relevant agents/*/profile.md before routing follow-ups or spawning related work.
- Send follow-ups through codex_new_message or a target agents/<slug>/inbox.md update; do not embed full transcript bodies into new marker commits.
- Spawn new agents with named task scopes that map cleanly to readable agent slugs and disjoint branch/worktree ownership.
- Source the helpers before calling them: . scripts/codex_wrap.sh && . scripts/branch_commands.sh.
- Use codex_spawn for child implementation agents so they run detached from the dispatcher and survive this dispatcher exiting. The web UI will still show them because codex_spawn runs the normal wrapper, which writes pid/cwd marker commits and transcript files.
- After each codex_spawn call, verify that a child start marker appears with the expected called-by, branch/worktree cwd, pid, and dispatch log path. If a child produces only marker commits and no useful diff, report it as marker-only/no-op.
- Command quick reference:
  - codex_spawn codex_in_branch @ <branch-or-commit> "<prompt>": detached child in a branch/worktree rooted at the target.
  - codex_spawn codex_commit "<prompt>": detached child in the current worktree.
  - codex_spawn codex_new_message "<prompt>": detached followup to the active/latest session.
  - codex_abort [run-start-commit]: stop an active wrapper run.
  - codex_agents: list live local wrapper agents from marker commits and live PIDs.
- End with a single round of codex_spawn calls, or codex_abort only when aborting is the task, then stop.
- Leave the actual work and followup to the called agents.
- codex_spawn sets CODEX_WRAP_CALLED_BY from codex_active by default; set CODEX_WRAP_CALLED_BY explicitly only when you need to override that caller.
- Include concise citations in dispatched prompts and your final status: cite commit hashes, branch names, STATUS.md sections, and file paths that justify each task.
- For long work, create periodic empty [status] commits that summarize the last interval and cite the commit hashes that matter for the next agent context.
- Use one-line empty checkpoint commits before disruptive work, for example: git commit --allow-empty -m "checkpoint: last save state before <work>".
- Finish with a quick status update saying what kind of work was dispatched and where.
EOF
)
  codex_commit "$prompt"
}
