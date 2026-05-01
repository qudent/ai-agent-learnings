# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch,
`chatgit`/`codex_web.py` for the local web UI, `codex_sync_push` for explicit
fetch/rebase/push cleanup, and optional `jj_project.sh` helpers.

Active human context: the user asked to commit the edited `STATUS.md`, then
finish/delegate the new work. The live follow-up concern was that the UI looked
like it had zero running agents; direct checks now show an active Codex run on
this repo and the port-6174 API reports it.

## Active Goals
- [x] Commit the user-authored `STATUS.md` update.
- [x] Reconcile the recurring `origin/main ahead 1, local ahead N` duplicate
  patch state without losing local work.
- [x] Add a rigorous sync/push path that prevents the duplicate-patch pattern
  from lingering after agent work.
- [x] Clean up the stale delegated cleanup worktree/branch.
- [x] Verify `chatgit` prints real path-style URLs with `/repos`.
- [ ] Push the final synchronized `main` state to `origin/main`.

## TODO Plan
- [ ] Commit this refreshed `STATUS.md`.
- [ ] Run final branch/worktree/process checks.
- [ ] Push `main` with `codex_sync_push` or equivalent fetch/rebase/push.

## Blockers
- None. Note that two Codex-related processes were visible during this handoff:
  the primary active run for this task and a web-launched `codex_new_message`
  follow-up asking whether work had stopped. Current `/api/status` reports the
  primary active run, not zero.

## Recent Results
- `STATUS.md` was already captured in a start marker commit after the user's
  edit; the working tree was clean before follow-up implementation began.
- `origin/main`'s single ahead commit had the same stable patch-id as local
  `91ec203`; `git rebase origin/main` skipped that duplicate and removed the
  behind side of the divergence.
- Removed stale worktree/branch
  `cleanup-inconsistencies-eea7985-20260501-143630`; it contained no useful
  code delta relative to the current mainline.
- Added `codex_sync_push`, rewired `codex_commit_push` to sync before and after
  a run, documented the exact push behavior, and added a regression that starts
  from `ahead 1, behind 1` duplicate patches and ends aligned with `origin/main`.
- Verified `scripts/chatgit` now prints
  `http://127.0.0.1:6174/home/name/repos/ai-agent-learnings` when the existing
  port-6174 server is already running.

## Agent Notes
- Important behavior: `codex_commit` and the web UI still do not push
  automatically. The explicit push path is `codex_sync_push`; `codex_commit_push`
  now runs that sync both before and after the Codex session.
- Validation passed:
  `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile scripts/codex_wrap.py scripts/codex_web.py`,
  `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`,
  and `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- Before final handoff, push `main` and confirm `git status --short --branch`
  no longer reports `ahead` or `behind`.
