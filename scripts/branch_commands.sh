# Source from bash: . ~/learnings/scripts/branch_commands.sh
# Generic branch/worktree command helpers. Codex-specific wrappers belong at the edge.

_BC_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=./parallel-worktrees/worktrees.sh
. "$_BC_SCRIPT_DIR/parallel-worktrees/worktrees.sh"

: "${DO_AT_BRANCH_PREFIX:=work}"

_do_at_unique_branch() {
  local commit=$1 short branch i=0
  short=$(git rev-parse --short "$commit") || return
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
