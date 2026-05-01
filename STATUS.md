# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch,
`chatgit`/`codex_web.py` for the local web UI, `codex_sync_push` for explicit
fetch/rebase/push cleanup, `codex_agents` for live local wrapper-agent listing,
and optional `jj_project.sh` helpers.

Today's audit target: reconcile the actual May 1 prompt/history state with the
file, especially the recurring local/remote divergence, dispatch behavior, and
web UI process/queue observations.

## Active Goals
- [x] Commit and process the human-authored `STATUS.md` prompts from today.
- [x] Implement Git-backed dispatch helpers rather than relying on internal
  model subagents for substantial work.
- [x] Make `chatgit` graceful when port 6174 is already serving this UI and
  print path-style URLs containing the real `/home/name/repos/...` path.
- [x] Add TDD/docs coverage for dispatch, branch naming, branch-parent metadata,
  active-run display, queueing, and URL behavior.
- [x] Add `codex_agents`, `codex_status`, `codex_sync_push`, and `codex_spawn`.
- [ ] Resolve the current `main...origin/main` divergence without hiding it.
- [ ] Verify the latest web UI report: a Codex process disappeared from the
  active-process list and a child-branch action appeared as "queued".
- [ ] Decide whether automatic periodic state commits are actually desired and,
  if so, implement them. Only manual `codex_status "<summary>"` exists now.

## TODO Plan
- [ ] Commit this status audit.
- [ ] Reconcile `main` with `origin/main`: current fetch-verified state is
  `ahead 4, behind 1`; `origin/main` has `a8fd2da`, an empty marker sibling of
  local `9865801`, while local keeps the later `STATUS.md` note.
- [ ] Reproduce or dismiss the "queued branch" report against the live
  port-6174 UI/API. The current regression says child branch creation should
  start immediately while the parent worktree is active.
- [ ] If automatic periodic state commits are requested, add an explicit test
  and implementation instead of relying on dispatch prompt wording.

## Blockers
- `codex_sync_push` refuses to rebase while this Codex run is active. A normal
  merge or fetch-verified direct push may still be appropriate, but do not claim
  the branch is clean until `git status --short --branch` confirms no
  ahead/behind after the run's own marker commits are accounted for.

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

## Agent Notes
- Current live check: `/api/status?repo=/home/name/repos/ai-agent-learnings`
  reports this run active at `9ee3fcb` with queue depth `0`.
- Current divergence is real and current: `main...origin/main` is `ahead 4,
  behind 1` after fetch. The previous `STATUS.md` claim that main was only
  ahead is stale.
- The latest unprocessed human note was pasted into `STATUS.md` but not turned
  into checklist state. It asks why the Codex process vanished from active
  processes and why creating a child branch showed "queued" when the intended
  model is parallel work in the child branch.
- Existing validation from today's implementation:
  `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile scripts/codex_wrap.py scripts/codex_web.py`,
  `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`,
  and `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
