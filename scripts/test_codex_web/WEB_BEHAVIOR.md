# Codex Web Behavior Contract

These tests describe the minimum behavior `scripts/codex_web.py` and
`scripts/chatgit` must preserve while the UI remains a small plain-JS app.

## Launching

- Given a user is inside any Git repository,
- when they run `chatgit`,
- then the web server starts for that repository, not for `~/learnings`.

## Branching

- Given the selected repository is on branch `main`,
- and the user chooses a commit as the branch base,
- when they submit a prompt in `branch` mode,
- then the server creates a new worktree branch at that exact base commit.
- Given the selected repository is already a web-created child branch,
- when they submit another prompt in `branch` mode,
- then the server creates a grandchild worktree and records the selected child
  branch as its parent.

## Parent Branch Metadata

- Given the server creates a branch from `main`,
- then Git config records:
  - `branch.<new-branch>.chatgit-parent = main`
  - `branch.<new-branch>.chatgit-parent-commit = <base commit>`
- and `/api/worktrees` returns both fields for the new branch.

The UI may later render this as a proper tree. Until then, parent metadata must
not be inferred from worktree directory names.

## Parallel Tabs

- Given two browser tabs are pointed at different branches or worktrees,
- when both tabs submit commands,
- then each command runs in the repo path sent by that tab.
- Branch creation requests must receive distinct branch/worktree names.
- Spawned wrapper processes must receive distinct web log files, even when they
  start within the same second.

## Message Queueing

- Given a web-started Codex process is still active for a repository,
- when the user submits another message for that same repository,
- then the server queues the new message instead of interrupting the active
  process.
- Queued messages run in submission order after the active process exits.
- `/api/status` exposes the active process and queued messages so the UI can
  render both states without relying on browser-local state.

## Browser Smoke

- Given the server is running,
- when a browser opens the root page,
- then the page renders without an HTTP error at desktop and narrow widths,
- and includes the current repo in the branch/conversation list after JavaScript
  loads.

## Commit Detail

- Given a user selects a commit,
- then the detail pane shows `git show --format=fuller --patch` output,
- and visible hash-copy controls are available for the selected commit.
