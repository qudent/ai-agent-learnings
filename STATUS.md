# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch,
`chatgit`/`codex_web.py` for the local web UI, `codex_sync_push` for explicit
fetch/rebase/push cleanup, `codex_agents` for live local wrapper-agent listing,
and optional `jj_project.sh` helpers.

Today's audit target: make the May 1 prompt/history lessons concrete in the
flow: preserve current active-agent transcript artifacts in Git, classify
dispatch requests before spawning, and keep a timestamped report of what the
user asked for versus what happened.

## Active Goals
- [x] Commit and process the human-authored `STATUS.md` prompts from today.
- [x] Implement Git-backed dispatch helpers rather than relying on internal
  model subagents for substantial work.
- [x] Make `chatgit` graceful when port 6174 is already serving this UI and
  print path-style URLs containing the real `/home/name/repos/...` path.
- [x] Add TDD/docs coverage for dispatch, branch naming, branch-parent metadata,
  active-run display, queueing, and URL behavior.
- [x] Add `codex_agents`, `codex_status`, `codex_sync_push`, and `codex_spawn`.
- [x] Resolve the current `main...origin/main` divergence without hiding it.
- [x] Add tracked `active-agents/<run>.md` artifacts while wrapper runs are
  live, with stop/abort commits deleting them from the current checkout while
  preserving them in Git history.
- [x] Tighten dispatch prompting so requests are classified as status-only,
  trivial-chat, direct-implementation, parallel-dispatch, cleanup, or blocked
  before any child agent is spawned.
- [x] Write a timestamped history report that itemizes user prompt commits and
  follow-through evidence.
- [ ] Reconcile the current `main...origin/main` marker/autosave divergence
  and push after validation.

## TODO Plan
- [x] Commit this status audit.
- [x] Reconcile `main` with `origin/main`: fetched state was `ahead 5, behind
  1`; `origin/main` had `a8fd2da`, an empty marker sibling of local `9865801`,
  while local kept the later `STATUS.md` note. Resolved with a normal merge
  commit, not a live-run rebase.
- [x] Push the reconciled branch to `origin/main`.
- [x] Add a failing active-agent artifact contract commit, then implement the
  lifecycle and make the wrapper suite pass.
- [x] Update dispatch prompt tests and implementation for classification and
  post-spawn verification.
- [ ] Run the web suite because wrapper marker history now includes
  `[active-agent]` commits.
- [ ] Reconcile/push `main` only after tests pass; avoid rebasing active marker
  history unless no local wrapper run is active.

## Blockers
- Current branch still reports `main...origin/main [ahead 5, behind 1]` after
  the new local commits. The behind side is the older remote autosave/marker
  pattern; reconcile only after validation.

## Recent Results
- Implemented `called-by: user|<commit>` marker metadata, `codex_dispatch`,
  `codex_checkpoint`, manual `codex_status`, branch-parent metadata, clearer
  branch names, collapsed run history, active-run indicators, file uploads, and
  path-style web URLs.
- Removed stale worktrees/branches after preserving useful content; the earlier
  `dev` cleanup is complete in the current checkout.
- Added `codex_sync_push` plus a regression for duplicate-patch
  `ahead 1, behind 1` reconciliation, then added an active-run guard after a
  rebase during a live run made process evidence unstable.
- Added `codex_agents` for live wrapper-agent listing and `codex_spawn` so
  dispatchers can launch child `codex_*` commands detached from dispatcher
  process lifetime while keeping normal wrapper metadata and web visibility.
- Tightened dispatch context compaction so old dispatcher prompts, branch
  subjects, and process command lines are elided instead of recursively copied
  into new prompt commits.
- Added a red test commit `51273ae` for the active-agent artifact contract,
  then implemented the lifecycle in `scripts/codex_wrap.py`: live runs now add
  and update `active-agents/<run-start-short>.md`; stop/abort removes it from
  `HEAD` while Git history keeps the artifact.
- Added dispatch classification rules in `scripts/branch_commands.sh` and a
  timestamped audit in `history-prompt-flow-report.md`.

## Agent Notes
- Current handoff: wrapper validation is green after the active-agent change:
  `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile scripts/codex_wrap.py` and
  `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`.
  The web suite still needs to run before pushing.
