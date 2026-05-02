# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch,
`chatgit`/`codex_web.py` for the local web UI, `codex_sync_push` for explicit
fetch/rebase/push cleanup, `codex_agents` for live local wrapper-agent listing,
and optional `jj_project.sh` helpers.

Transcript/inbox implementation is in progress on branch
`transcript-inbox-implementation`. New wrapper runs now create
`agents/<slug>/profile.md`, `agents/<slug>/inbox.md`,
`transcripts/archive/<date>-<slug>.md`, and `transcripts/active/<slug>.md`;
commit authors identify `user`, `codex:<slug>`, or `orchestrator:<slug>`;
`codex_new_message` appends user follow-ups to the target inbox/transcript before
resuming. The archive branch
`archive/marker-orchestration-before-transcript-inbox` preserves the previous
marker-orchestration state.

## Active Goals
- [x] Preserve the current marker orchestration state before planning the
  replacement.
- [x] Inspect pre/current orchestration history for useful ideas to keep or drop.
- [x] Write a critique and implementation plan for transcript/inbox
  orchestration.
- [x] Review/execute the earliest safe slice from
  `docs/plans/2026-05-02-transcript-inbox-orchestration.md`.
- [x] Start with a red behavior contract before changing wrapper
  behavior.
- [ ] Finish compacting start/assistant marker commit bodies into short pointers
  while preserving old marker-history compatibility.
- [ ] Evaluate optional `jj` task mirror helpers after Git-backed transcript
  behavior remains stable.

## TODO Plan
- [x] Land behavior contract, naming/path helpers, transcript writers, author
  metadata, inbox follow-ups, and dispatcher docs in small commits.
- [ ] Add a focused contract for concise pointer commit bodies, then move new
  start/assistant marker bodies out of commit messages and into transcript
  files.
- [ ] Add optional `jj` mirror helpers with absent-`jj` failure tests.
- [ ] Do migration cleanup/deprecation docs for `active-agents/` after pointer
  commit behavior is stable.
- [ ] Keep `jj` optional until smoke tests cover colocated `.jj` with Git
  worktrees and transcript files.
- [ ] Push the review branch after final validation.

## Blockers
- None for the completed foundation. Remaining work is deliberately deferred:
  new wrapper commits still keep legacy `[codex_start_user]` / `[codex]` bodies
  for compatibility, so the concise-pointer migration is not complete yet.

## Recent Results
- Added `scripts/test_codex_wrap/TRANSCRIPT_INBOX_BEHAVIOR.md` and a red shell
  contract for `agents/` plus `transcripts/` artifacts before changing wrapper
  behavior.
- Implemented transcript/inbox files, readable slugs, per-role Git author
  metadata, active-pointer cleanup, and user follow-up inbox/transcript commits.
- Updated dispatcher context/docs to list transcript/inbox files and avoid
  dumping full transcripts into dispatch prompts. Validation passed:
  `py_compile`, `test_codex_wrap`, and `test_codex_web`.

## Agent Notes
- `transcripts/index.md` is intentionally stable layout documentation for now;
  dispatch context lists `transcripts/active` and `agents` directly. A dynamic
  shared index caused add/add conflicts in parallel web branch tests.
- Preserve old marker parsing until the concise-pointer commit-body contract is
  added and compatibility tests cover existing `[codex]` history.
