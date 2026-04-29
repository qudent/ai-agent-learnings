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

## Parent Branch Metadata

- Given the server creates a branch from `main`,
- then Git config records:
  - `branch.<new-branch>.chatgit-parent = main`
  - `branch.<new-branch>.chatgit-parent-commit = <base commit>`
- and `/api/worktrees` returns both fields for the new branch.

The UI may later render this as a proper tree. Until then, parent metadata must
not be inferred from worktree directory names.

## Browser Smoke

- Given the server is running,
- when a browser opens the root page,
- then the page renders without an HTTP error and includes the current repo in
  the worktree selector after JavaScript loads.
