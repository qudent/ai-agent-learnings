# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents.
`AGENTS.md` is the canonical global instruction source, global agent config
files symlink to it, and branch-ref dispatch remains a policy pattern rather
than a tracked helper-script implementation in this repo.

## Active Human Prompts - codex-web-interface dev pass
Desired state: improve the dev worktree copy of the Git-backed Codex web UI so
it is less confusing and more discoverable. The running dev server is
`http://127.0.0.1:6175/` from `/home/name/learnings.worktrees/dev`; do this work
on local branch `dev`.

## Active Goals
- [x] Keep global agent instructions centralized in `~/learnings/AGENTS.md`.
- [x] Maintain project-agnostic learnings and workflow guardrails.
- [x] Support branch-ref dispatch where each branch is worked in its own
  worktree.
- [x] Use `STATUS.md` as the single coordination file instead of splitting state
  and communication across a whiteboard.

## TODO Plan
- [x] Rename visible UI wording away from ambiguous `codex-web` toward
  `codex-web-interface` / Git-backed Codex interface language.
- [x] Review command/API/UI names for context drift: distinguish `chatgit`
  launcher, `codex-web-interface` UI, `codex_wrap` runner functions, and
  worktree helper commands.
- [x] Replace UI branch ancestry metadata keys with generic
  `branch.<name>.parent-branch` and `branch.<name>.parent-commit`, matching the
  parallel-worktrees skill.
- [x] Auto-refresh repo data when the repository path input changes, without
  requiring the Refresh button.
- [x] Make process/status rows clickable so the full run transcript/log can be
  shown in the detail pane.
- [x] Color or otherwise mark branch/worktree rows that currently have an
  active agent run, instead of only showing active state below the branch list.
- [x] Check how easy branch-name editing is; implement a low-risk rename flow if
  the Git/worktree mechanics are straightforward, otherwise document the
  blocker in the UI/status.
- [x] Add pasted/dropped file upload to the chat composer and pass uploaded
  file paths along with prompts.
- [x] Add discoverability hints, including that clicking/copying hashes copies
  them.
- [x] Queue web-submitted messages behind active runs for the same worktree.
- [x] Test recursive web branch creation from a child branch to a grandchild
  branch.
- [x] Preserve browser text selection during passive auto-refresh.
- [x] Change the detail-pane copy action from hash-copying to copying the
  displayed patch/transcript/message text.
- [x] Make conversation commit rows clickable so clicking the row opens the
  patch, while hash/buttons keep their specific actions.
- [x] Drive the work TDD-style through `scripts/test_codex_web/` and then smoke
  the running dev server.

## Blockers
- None.

## Recent Results
- Finished child worktree
  `codex-web-interface-645442f-20260429-225724-691746016`: its patch content
  was already present in `dev`, `worktree_finish` merged the branch history into
  `dev`, removed the child worktree, and deleted the child branch.
- Fixed the Continue-button false active-run block: idle `/api/status` now
  returns `active: null` instead of `{}`, and the browser active-run guard only
  treats statuses with a real `hash` or `pid` as active. Regression coverage was
  added to the web behavior contract and shell suite.
- Moved the active-run stop control out of the header and into the composer as
  `Pause run`, beside Continue/Fresh/Branch/Queue; `Queue` is now the only
  composer action that intentionally queues behind an active run, while
  Continue/Fresh/Branch prompt the user to use Queue or pause first.
- Reworded the Detail pane to describe the actual selection model: commits show
  patches, runs show transcripts, and the detail action now says `Copy detail`.
- In child branch `codex-web-interface-645442f-20260429-225724-691746016`,
  reduced the visible button factory by replacing per-run Transcript/Patch/Copy
  rows with a compact run action menu while keeping row-click transcripts,
  shortened the header repo display behind a Change path disclosure, simplified
  composer/detail copy, and added a calmer neutral/accent visual hierarchy.
- Run timeline spacing was tightened up from the screenshot feedback: run rows
  now reserve a wider gutter for the timeline marker, align the marker to the
  rail, and add more spacing around the Transcript/Patch/Copy message action
  buttons.
- Commit-row click handling now opens the selected commit patch from the
  conversation row, and run-row clicks open transcripts; both skip when the
  user is selecting text or clicking an explicit button.
- Commit `a07ec73` from child branch
  `codex-web-interface-b37b388-20260429-223907-346838682` revised the left
  pane run rows into a nested timeline: prompt-first rows, hash/status metadata
  underneath, state nodes, compact branch rename ellipsis, and copy-message
  controls for conversation commits and run-start commits. It also changed
  ambiguous `Send / queue` wording to `Continue`, clarified `Abort run`, and
  documented that web queues are in server memory. The child branch was merged
  into `dev`, removed, and `chatgit-dev` was restarted on `127.0.0.1:6175`.
- Added the pending row-click affordance from the live dev worktree: clicking a
  conversation row opens its patch, clicking a run row opens its transcript, and
  text selection/buttons do not trigger row clicks.
- Commit `0aec54d` changes the detail action to `Copy message`, copying the
  displayed detail pane text instead of the selected hash.
- Passive 2-second refresh now skips while text is selected, including the
  case where selection starts while an overview request is in flight; explicit
  actions still force refreshes.
- Verification passed: `python3 -m py_compile scripts/codex_web.py`,
  `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`, and
  headless Chrome screenshots against temporary servers on ports 6186, 6187,
  and 6188.
- Earlier dev commits in this pass added the overview endpoint/config embed,
  compact active-worktree UI, closed-worktree run grouping, parent metadata,
  path auto-load, process transcripts, branch rename, queueing, and file
  uploads.

## Agent Notes
- Tracked dispatcher/logging helper scripts are no longer present in this repo;
  keep future docs at the policy level unless a replacement implementation is
  added.
- `git branch -r` currently shows only `origin/main`.
- `git worktree list` currently shows `/home/name/learnings` on `main` and
  `/home/name/learnings.worktrees/dev` on `dev`; the
  `codex-web-interface-645442f-20260429-225724-691746016` child worktree has
  been removed.
- Active web UI instances: existing main copy on `127.0.0.1:6174`, dev copy in
  tmux session `chatgit-dev` on `127.0.0.1:6175`; dev log path is
  `/tmp/chatgit-dev-6175.log`.
- Current verification for the codex-web-interface is `python3 -m py_compile
  scripts/codex_web.py` and `bash scripts/test_codex_web/test_codex_web.sh
  scripts/codex_web.py`; the web test uses headless Chrome when available.
- Latest dev verification passed both commands above; the web behavior contract
  now covers idle `active: null`, queue wording, copy-message controls, raw
  run-start commit messages, and browser rendering. `chatgit-dev` was restarted
  on `127.0.0.1:6175` after the fix.
- Current wrapper/backend verification is
  `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`.
- `codex_commit @ ...` remains plain prompt text. Branch/commit placement is
  `codex_in_branch @ <branch-or-commit> <prompt...>` via `do_at_branch` /
  `do_at_commit`; tracked dispatcher scripts are still retired, and the live
  reference-transaction hook silently does nothing if its external sample script
  is absent.
- Stable repo instructions still belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic learnings.
