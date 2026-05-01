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

_codex_dispatch_context() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf '(unknown)')
  printf 'Current branch: %s\n' "$branch"
  printf 'Current HEAD: %s\n\n' "$(git rev-parse --short HEAD 2>/dev/null || printf unknown)"
  printf 'Active run on this branch:\n'
  codex_active 2>/dev/null || printf 'none\n'
  printf '\nRecent commits:\n'
  git log --oneline --decorate --max-count=18 2>/dev/null || true
  printf '\nWorktrees:\n'
  git worktree list --porcelain 2>/dev/null | sed -n '1,80p' || true
  printf '\nLocal branches:\n'
  git branch -vv 2>/dev/null | sed -n '1,40p' || true
  printf '\nRecent run-start markers with pid metadata:\n'
  git log --grep='^\[codex_start' --format='%h %s%n%b%x1e' --max-count=20 2>/dev/null \
    | awk 'BEGIN{RS="\036"} /pid: /{split($0, lines, "\n"); pid=""; cwd=""; host=""; head=lines[1]; for (i in lines) { if (lines[i] ~ /^pid: /) pid=lines[i]; if (lines[i] ~ /^cwd: /) cwd=lines[i]; if (lines[i] ~ /^host: /) host=lines[i]; } print head " | " pid " | " host " | " cwd }' \
    | sed -n '1,20p' || true
  printf '\nLive Codex-related processes for PID cross-check:\n'
  ps -eo pid,pgid,stat,cmd 2>/dev/null \
    | grep -E 'codex(_wrap)?|codex_web.py|branch_commands.sh' \
    | grep -v grep \
    | sed -n '1,40p' || printf 'none\n'
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
- Split the instruction into independent, reviewable tasks.
- Inspect currently running sessions before dispatching: compare recent run-start marker pid/cwd metadata with the live process table above, then decide whether to call codex_commit, codex_new_message/codex_continue-style followup, codex_abort, or explicitly report blocked-by.
- End with a single round of new codex_* calls, such as codex_in_branch, codex_commit, codex_new_message, or codex_abort, then stop.
- Leave the actual work and followup to the called agents.
- Prefix every codex_* call that starts or resumes an agent with CODEX_WRAP_CALLED_BY=\$(codex_active) so start commits cite this dispatcher as their caller.
- Include concise citations in dispatched prompts and your final status: cite commit hashes, branch names, STATUS.md sections, and file paths that justify each task.
- For long work, create periodic empty [status] commits that summarize the last interval and cite the commit hashes that matter for the next agent context.
- Use one-line empty checkpoint commits before disruptive work, for example: git commit --allow-empty -m "checkpoint: last save state before <work>".
- Finish with a quick status update saying what kind of work was dispatched and where.
EOF
)
  codex_commit "$prompt"
}
