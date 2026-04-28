---
name: parallel-worktrees
description: Manage git worktrees for parallel development. Use when creating worktrees, merging between parent/child worktrees, or cleaning up worktrees. Triggers on phrases like "create worktree", "merge to parent", "finish worktree", "abort worktree".
allowed-tools: Bash, Read
---

# Parallel Worktrees

Manage hierarchical git worktrees for parallel agent workflows.

## Running Commands

Source the script then run the command:

```bash
source ~/.claude/skills/parallel-worktrees/worktrees.sh && <command>
```

## Commands

| Command | Purpose |
|---------|---------|
| `worktree_create <branch>` | Create branch (if <branch> doesn't exist) and worktree at `<repo>.worktrees/<branch>`, cd into it, run pnpm install if needed |
| `worktree_cd_to_parent` | Navigate to parent worktree (sets `$CHILD_PATH` as side effect) |
| `worktree_merge_to_parent` | Merge current branch into parent's branch |
| `worktree_merge_from_parent` | Pull parent's changes into current worktree |
| `worktree_abort` | Delete worktree and branch, return to parent |
| `worktree_finish` | Merge to parent then abort |

## Examples

```bash
# Create worktree for a feature
source ~/.claude/skills/parallel-worktrees/worktrees.sh && worktree_create fix-login-bug

# Merge work up to parent and clean up
source ~/.claude/skills/parallel-worktrees/worktrees.sh && worktree_finish

# Abandon without merging
source ~/.claude/skills/parallel-worktrees/worktrees.sh && worktree_abort
```

## Key Concepts

- Worktrees nest recursively: `repo.worktrees/a.worktrees/b`
- Parent-child merges follow the directory hierarchy
- For main branch, use regular `git merge main`
