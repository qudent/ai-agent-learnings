# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch,
`chatgit`/`codex_web.py` for the local web UI, `codex_sync_push` for explicit
fetch/rebase/push cleanup, `codex_agents` for live local wrapper-agent listing,
and optional `jj_project.sh` helpers.

New direction: migrate away from giant transcript bodies in commit messages and
toward version-controlled `transcripts/` plus `agents/<name>/inbox.md` files,
with short pointer commit messages, explicit commit authors for user/agent/orch
roles, readable agent slugs, branch-local instruction stacks in `STATUS.md`, and
optional `jj` task mirroring after the Git-backed transcript model is stable.
The current marker-orchestration state is preserved at branch
`archive/marker-orchestration-before-transcript-inbox`.

## Active Goals
- [x] Preserve the current marker orchestration state before planning the
  replacement.
- [x] Inspect pre/current orchestration history for useful ideas to keep or drop.
- [x] Write a critique and implementation plan for transcript/inbox
  orchestration.
- [ ] Review/execute `docs/plans/2026-05-02-transcript-inbox-orchestration.md`.
- [ ] If executing, start with a red behavior contract before changing wrapper
  behavior.

## TODO Plan
- [ ] Use the plan to implement transcript/inbox files in small commits:
  behavior contract, naming/path helpers, transcript writers, author metadata,
  inbox follow-ups, dispatcher docs, optional `jj` mirrors, then migration docs.
- [ ] Keep `jj` optional until smoke tests cover colocated `.jj` with Git
  worktrees and transcript files.
- [ ] Push each coherent learnings update in-session.

## Blockers
- None for planning. Implementation should not begin by deleting the old marker
  model; preserve compatibility until wrapper and web tests are green.

## Recent Results
- Created and pushed `archive/marker-orchestration-before-transcript-inbox` at
  `d291d83` so the current marker-heavy orchestration state remains recoverable.
- Reviewed commits `110096f`, `e88cda1`/`d5b3e57`, `1b86658`, `7f9a5fa`,
  `077c34c`, and current wrapper/dispatch files to extract the reusable parts:
  durable human input, branch/worktree isolation, active state visibility,
  dispatch classification, and optional `jj` task DAGs.
- Added `docs/plans/2026-05-02-transcript-inbox-orchestration.md` and linked it
  from `README.md`.

## Agent Notes
- Current handoff: the plan recommends `transcripts/archive/` as canonical
  transcript storage, `transcripts/active/` as live pointer files only,
  `agents/<slug>/inbox.md` for routing messages, and short Git commit messages
  with deliberate `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL` metadata.
- The plan explicitly criticizes a single global user-message file as a conflict
  hotspot; use an index plus per-agent inboxes instead.
