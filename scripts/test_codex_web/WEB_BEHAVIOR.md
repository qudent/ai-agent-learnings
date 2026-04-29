# Codex Web Interface Behavior Contract

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
  - `branch.<new-branch>.parent-branch = main`
  - `branch.<new-branch>.parent-commit = <base commit>`
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
- Queued messages live in the web server process memory; restarting the server
  loses them.
- The web UI labels the ordinary follow-up action as continuing the latest
  session and makes clear that active worktree runs are queued server-side.

## Browser Smoke

- Given the server is running,
- when a browser opens the root page,
- then the page renders without an HTTP error at desktop and narrow widths,
- and includes the current repo in the branch/conversation list after JavaScript
  loads.
- The visible product wording should say `codex-web-interface` or otherwise make
  clear that this is the Git-backed Codex interface, not a different Codex
  product.
- Repository path edits should auto-load the new path after input/change without
  requiring the Refresh button.
- The page should periodically refresh branch/message/status data so marker
  commits created outside the browser action appear without manual Sync.
- Browser refresh should use one overview API request for branch, message, and
  status data after initial configuration so SSH-tunneled sessions are not
  penalized by serial roundtrips.
- Hash controls should include a visible hint that clicking a hash copies it.
- Commit rows and run rows should expose a copy-message action for the full Git
  commit message when one is available.
- Worktree rows with an active agent should have a distinct visual state, such
  as color, border, or an `agent active` marker on the row itself.
- The composer should support pasted or dropped arbitrary file uploads, allow
  removing attached files before sending, and include uploaded file paths in
  the prompt sent to Codex.

## Commit Detail

- Given a user selects a commit,
- then the detail pane shows `git show --format=fuller --patch` output,
- and visible hash-copy controls are available for the selected commit.

## Process Transcripts

- Given the server has spawned a wrapper process,
- then `/api/transcript` can return the full web/wrapper log for that process,
- and process/status rows in the UI are clickable to show that transcript in the
  detail pane.
- Long active or queued status text must stay inside the branch pane instead of
  painting across adjacent panes.
- Finished runs are durable run objects in `/api/worktrees`, grouped under
  their owning active worktree when it still exists.
- When a finished branch worktree has been merged and removed, its run remains
  visible under a closed-worktree runs section and can still open its
  transcript. The UI should make clear that these are runs whose recorded cwd no
  longer maps to a currently attached worktree.

## Active Branches

- Given a branch/worktree has a currently running Codex process,
- then `/api/worktrees` marks that worktree with active-run data,
- and the row for that worktree has a visible active-agent indication.
- Once that Codex process exits, `/api/worktrees` must stop marking the
  worktree active.

## Prompt Safety

- Prompts from the web UI are passed to Codex as argv, not interpolated into
  shell source.
- Shell metacharacters in prompt text must remain literal and must not execute
  before reaching Codex.
- Commit detail endpoints validate commit-ish input and reject values shaped
  like Git options.

## File Uploads

- Given the user pastes or drops a file in the composer,
- then the server stores it under the repo's Git common directory,
- returns a filesystem path for the uploaded file,
- and prompts sent with that attachment include the uploaded path.

## Branch Renaming

- Given a worktree owns a checked-out branch,
- when the UI asks to rename that branch,
- then the server validates the new branch name and uses Git's branch rename
  mechanics from the owning worktree.
- Worktree directory paths do not need to be renamed during this pass.
