# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents.
`AGENTS.md` is the canonical global instruction source, global agent config
files symlink to it, and branch-ref dispatch remains a policy pattern rather
than a tracked helper-script implementation in this repo.

## Active Human Prompts - chatgit web UI
Desired state: typing `chatgit` in any Git repo starts the Codex Git Chat web UI
for that repository. Keep the implementation small and plain: single-page JS is
acceptable for now, but the web UI must have reliable branching behavior before
larger UI redesign work.

## Active Goals
- [x] Keep global agent instructions centralized in `~/learnings/AGENTS.md`.
- [x] Maintain project-agnostic learnings and workflow guardrails.
- [x] Support branch-ref dispatch where each branch is worked in its own
  worktree.
- [x] Use `STATUS.md` as the single coordination file instead of splitting state
  and communication across a whiteboard.

## TODO Plan
- [x] Add a `chatgit` launcher that starts `codex_web.py` for the current repo.
- [x] Document the lightweight install path in `README.md`.
- [x] Establish explicit parent-branch metadata for web-created branches:
  `branch.<name>.chatgit-parent` and
  `branch.<name>.chatgit-parent-commit`.
- [x] Specify expected web branching behavior in `scripts/test_codex_web/`.
- [x] Fix the web UI's branch creation behavior against a
  mock repo.
- [x] Display parent-branch metadata in the UI so conversations can become a
  branch tree instead of relying on worktree directory layout.
- [x] Make repeated tab branch requests allocate distinct branches and web log
  files.
- [x] Revise the three-pane UI after branching works: branch/conversation list,
  selected conversation, and selected commit detail.
- [x] Add hash-copy controls and first-line commit-message expansion to full
  `git show --format=fuller --patch` output.
- [x] Show queued/active message state without adding a scheduler to the web UI.
- [x] Queue web-submitted messages behind active runs for the same worktree.
- [x] Test recursive web branch creation from a child branch to a grandchild
  branch.
- [x] Verify the revised three-pane UI with browser automation at desktop and
  narrow widths.

## Blockers
- None.

## Recent Results
- Created the `dev` worktree at `/home/name/learnings.worktrees/dev` and
  started a second `chatgit` web UI from that tree in tmux session
  `chatgit-dev` on `127.0.0.1:6175`.
- Deleted remote feature branches `origin/dev` and
  `origin/codex-web-9246530-20260429-183606`; `origin/main` is now the only
  remote branch after pruning.
- Merged the `dev` and `codex-web-9246530-20260429-183606` worktrees into
  `main`, preserving both the parallel-tab collision fix and the three-pane web
  UI work.
- Removed both local feature worktrees and their local branch refs after
  verifying they were merged into `HEAD`.
- Revised `scripts/codex_web.py` into a three-pane layout: branch/worktree list,
  selected conversation, and selected commit detail.
- Added hash-copy controls, `/api/status`, queued/active run display, and
  `git show --format=fuller --patch` commit detail output without a timer loop.
- Added server-side per-worktree message queueing to `scripts/codex_web.py`;
  queued messages now drain in order after the active web-started process exits,
  and `/api/status` exposes active plus queued state.
- Extended `scripts/test_codex_web/test_codex_web.sh` to prove recursive
  child-to-grandchild branch creation and queued follow-up execution.
- Extended the web behavior contract and shell/browser test to cover fuller
  commit detail output plus desktop and narrow Chrome screenshots.
- Added initial `chatgit` launcher, documented PATH-based install, and gave
  web-created branches explicit parent-branch Git config metadata.
- Added a web behavior contract and shell/browser integration test scaffold for
  `chatgit` branch creation.
- Verified `chatgit` against a mock repo: it serves the caller repository,
  creates branch worktrees at the selected base commit, exposes parent metadata
  through `/api/worktrees`, and renders the parent marker in headless Chrome.
- Added a parallel-tab behavior contract: repeated branch submissions get
  distinct branch/worktree names and distinct web log files, avoiding
  same-second collisions.
- Fixed the shell wrapper's interactive job-control `setsid` PID tracking bug
  with a regression test; committed as `11c5765`.
- Replaced the shell implementation with a Python engine behind the same
  `codex_commit`/`codex_resume`/`codex_abort`/`codex_new_message` functions;
  the fake-Codex wrapper suite and `py_compile` pass.
- Corrected Python marker folding to keep newest agent text first and prior
  text as plain body content only; regression tests now reject `previous
  [codex]` and embedded old `[codex]` subjects.
- Tightened `[codex]` folding again: exact-shape tests now compare the whole
  commit body, and amend paths keep existing `session-id`/`run-start` metadata.
- Split branch/worktree execution back out of Codex: `codex_wrap` no longer
  handles `@`, `scripts/branch_commands.sh` provides `do_at_branch`,
  `do_at_commit`, and `codex_in_branch`, and it delegates worktree primitives to
  `scripts/parallel-worktrees/worktrees.sh`.
- Replaced ordinary `agent/<tool>/<branch>` dispatch semantics with
  branch-owned worktree dispatch.
- Removed `HUMAN_AGENTS_WHITEBOARD.md`; active coordination now belongs in
  `STATUS.md`.
- Removed tracked dispatcher/logging helper scripts from `scripts/` and cleaned
  stale documentation references to them.
- Updated coordination policy back to one file: `STATUS.md` contains state,
  active prompts, open questions, agent notes, and TODO plans.

## Agent Notes
- Tracked dispatcher/logging helper scripts are no longer present in this repo;
  keep future docs at the policy level unless a replacement implementation is
  added.
- `git branch -r` currently shows only `origin/main`.
- `git worktree list` currently shows `/home/name/learnings` on `main` and
  `/home/name/learnings.worktrees/dev` on `dev`.
- Active web UI instances: existing main copy on `127.0.0.1:6174`, dev copy in
  tmux session `chatgit-dev` on `127.0.0.1:6175`; dev log path is
  `/tmp/chatgit-dev-6175.log`.
- Current verification for the chatgit UI is `python3 -m py_compile
  scripts/codex_web.py` and `bash scripts/test_codex_web/test_codex_web.sh
  scripts/codex_web.py`; the web test uses headless Chrome when available.
- Stable repo instructions still belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic learnings.
