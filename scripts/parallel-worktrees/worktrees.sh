# Shell functions for parallel worktree management
# Part of the parallel-worktrees Claude Code skill
#
# Installation: Copy the parallel-worktrees folder to ~/.claude/skills/
# Claude will source this file automatically when using the skill.
#
# Assumes no directory ending with .worktrees exists in your git repo
# (except for the ones managed by these functions)

# Functions for parallel worktree operations

# worktree_create <new_branch_name> creates a new worktree with the given branch, cd's into it, and runs pnpm install if package.json is present
# the new worktree is at the <current_path>.worktrees/<branch_name> path. This permits a recursive structure of worktrees,
# which correspond to tasks/agents and subagents. merge_to_parent and merge_from parent are made to keep these in sync,
# if you  want to merge from the main branch directly, just use git merge main as usual.

# We try to set up the env as much as possible, so if package.json is present, we run pnpm install.
# pnpm install is better than npm because it uses the pnpm store and hard links to save space and time

# the commands cds into the new worktree and we can start vibing immediately: `worktree_create <branch_name>; claude`` # or `code .`` for vscode, droid, codex, gemini...
# For `code .` on Mac, you might need to install the 'code' command in PATH from the Command Palette: Shift + Command + P, type 'shell command' to find the option.
worktree_create() {
    # check if argument is given
    if [ -z "$1" ]; then
      echo "Usage: worktree_create <new_branch_name>"
      return 1
    fi
  local NEWBRANCH="$1"
  local NEWWORKTREE="$(git rev-parse --show-toplevel).worktrees/$NEWBRANCH"
  git worktree add "$NEWWORKTREE" # this automatically creates a branch if it doesn't exist, take note LLMs!
  cd "$NEWWORKTREE"
  if [[ -f package.json ]]; then
    pnpm install
  fi
}

worktree_find_for_branch() {
  if [ -z "$1" ]; then
    echo "Usage: worktree_find_for_branch <branch>"
    return 1
  fi
  git worktree list --porcelain | awk -v branch="refs/heads/$1" '
    $1 == "worktree" { path=$2 }
    $1 == "branch" && $2 == branch { print path; found=1; exit }
    END { exit found ? 0 : 1 }
  '
}

worktree_create_from_commit() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: worktree_create_from_commit <new_branch_name> <commit>"
    return 1
  fi
  local NEWBRANCH="$1"
  local COMMIT="$2"
  local NEWWORKTREE="$(git rev-parse --show-toplevel).worktrees/$NEWBRANCH"
  git worktree add -b "$NEWBRANCH" "$NEWWORKTREE" "$COMMIT"
  cd "$NEWWORKTREE"
  if [[ -f package.json ]]; then
    pnpm install
  fi
}

# worktree_cd_to_parent cds to the "parent worktree" of the current worktree, returns path of the child worktree
worktree_cd_to_parent() {
  CHILD_PATH="$PWD"
  cd "${PWD%.worktrees/*}"
}

# worktree_merge_to_parent merges the current state of the branch in the current worktree into the "parent worktree" and goes back to the working branch
worktree_merge_to_parent() {
  local BRANCHTOMERGE="$(git rev-parse --abbrev-ref HEAD)" # first get current branch

  worktree_cd_to_parent # set CHILD_PATH as side effect
  git merge --no-edit "$BRANCHTOMERGE"
  cd $CHILD_PATH
}

# worktree_merge_from_parent merges the parent worktree's current branch into the current worktree, if the parent has updated
worktree_merge_from_parent() {
  worktree_cd_to_parent # set CHILD_PATH as side effect
  local BRANCHTOMERGE="$(git rev-parse --abbrev-ref HEAD)" # now we get the parent's branch
  cd "$CHILD_PATH"
  git merge --no-edit $BRANCHTOMERGE
}

# worktree_abort "aborts" the worktree at the current path: deletes branch and worktree, and ends up in the "parent" worktree.
# Ignores uncommitted changes and unmerged commits!
worktree_abort() {
  local BRANCHTOMERGE="$(git rev-parse --abbrev-ref HEAD)"
  local WORKTREE_ROOT="$(git rev-parse --show-toplevel)"  # get root even if in subdirectory
  worktree_cd_to_parent #set CHILD_PATH as side effect
  git worktree remove --force "$WORKTREE_ROOT"
  git branch -D "$BRANCHTOMERGE"
}

# worktree_finish is a simple wrapper to merge to parent and then abort branch
# still, uncommitted changes will be lost!
worktree_finish() {
  worktree_merge_to_parent
  worktree_abort
}
