# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch,
`chatgit`/`codex_web.py` for the local web UI, `codex_sync_push` for explicit
fetch/rebase/push cleanup, `codex_agents` for live local wrapper-agent listing,
and optional `jj_project.sh` helpers.

Today's audit target is implemented locally: preserve current active-agent
transcript artifacts in Git, classify dispatch requests before spawning, and
keep a timestamped report of what the user asked for versus what happened.

## Active Goals
- [x] Commit and process the human-authored `STATUS.md` prompts from today.
- [x] Implement Git-backed dispatch helpers rather than relying on internal
  model subagents for substantial work.
- [x] Make `chatgit` graceful when port 6174 is already serving this UI and
  print path-style URLs containing the real `/home/name/repos/...` path.
- [x] Add TDD/docs coverage for dispatch, branch naming, branch-parent metadata,
  active-run display, queueing, and URL behavior.
- [x] Add `codex_agents`, `codex_status`, `codex_sync_push`, and `codex_spawn`.
- [x] Add tracked `active-agents/<run>.md` artifacts while wrapper runs are
  live, with stop/abort commits deleting them from the current checkout while
  preserving them in Git history.
- [x] Tighten dispatch prompting so requests are classified as status-only,
  trivial-chat, direct-implementation, parallel-dispatch, cleanup, or blocked
  before any child agent is spawned.
- [x] Write a timestamped history report that itemizes user prompt commits and
  follow-through evidence.
- [ ] Push the just-merged local history to `origin/main`.

## TODO Plan
- [x] Add a failing active-agent artifact contract commit, then implement the
  lifecycle and make the wrapper suite pass.
- [x] Update dispatch prompt tests and implementation for classification and
  post-spawn verification.
- [x] Run the web suite because wrapper marker history now includes
  `[active-agent]` commits.
- [x] Reconcile the remote autosave/marker divergence with a normal merge,
  preserving the deliberately red contract commit hash.
- [ ] Push `main` after the merge commit is completed.

## Blockers
- None. No live wrapper agents were reported before the merge.

## Recent Results
- Added a red test commit `51273ae` for the active-agent artifact contract,
  then implemented the lifecycle in `scripts/codex_wrap.py`: live runs now add
  and update `active-agents/<run-start-short>.md`; stop/abort removes it from
  `HEAD` while Git history keeps the artifact.
- Added dispatch classification rules in `scripts/branch_commands.sh` and a
  timestamped audit in `history-prompt-flow-report.md`.
- Validation passed:
  `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile scripts/codex_wrap.py scripts/codex_web.py`,
  `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`,
  and `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.

## Agent Notes
- Current handoff: `STATUS.md` conflict from merging `origin/main` was resolved
  as current state. Finish the merge commit, then push.
