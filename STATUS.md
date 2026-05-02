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
resuming. Start/resume and assistant commits for new runs are concise pointers;
full prompts and assistant output live in transcript files. New runs do not
create legacy `active-agents/` artifacts. The archive branch
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
- [x] Compact start/resume and assistant marker commits into short pointers for
  new runs, intentionally dropping backwards compatibility layers per user
  instruction.
- [ ] Evaluate optional `jj` task mirror helpers after Git-backed transcript
  behavior remains stable.

## TODO Plan
- [x] Land behavior contract, naming/path helpers, transcript writers, author
  metadata, inbox follow-ups, and dispatcher docs in small commits.
- [x] Add a focused contract for concise pointer commit bodies, then move new
  start/assistant marker bodies out of commit messages and into transcript
  files.
- [ ] Add optional `jj` mirror helpers with absent-`jj` failure tests.
- [x] Remove new-run `active-agents/` writes and document transcript/inbox files
  as the durable source of truth.
- [ ] Keep `jj` optional until smoke tests cover colocated `.jj` with Git
  worktrees and transcript files.
- [x] Push the review branch after final validation.

## Blockers
- None for the transcript pointer cleanup. Backwards compatibility with old
  marker bodies was intentionally dropped for new wrapper behavior after the
  user's correction to simplify.

## Recent Results
- Added `scripts/test_codex_wrap/TRANSCRIPT_INBOX_BEHAVIOR.md` and a red shell
  contract for `agents/` plus `transcripts/` artifacts before changing wrapper
  behavior.
- Implemented transcript/inbox files, readable slugs, per-role Git author
  metadata, active-pointer cleanup, and user follow-up inbox/transcript commits.
- Updated dispatcher context/docs to list transcript/inbox files and avoid
  dumping full transcripts into dispatch prompts. Validation passed:
  `py_compile`, `test_codex_wrap`, and `test_codex_web`.
- Simplified new wrapper commits: start/resume markers no longer store full
  prompts, assistant commits are `codex: update <slug>` transcript pointers, and
  assistant output is appended to `transcripts/archive/`.
- Full validation passed and branch `transcript-inbox-implementation` was
  pushed to origin.

## Agent Notes
- `transcripts/index.md` is intentionally stable layout documentation for now;
  dispatch context lists `transcripts/active` and `agents` directly. A dynamic
  shared index caused add/add conflicts in parallel web branch tests.
- Per user instruction, do not add a compatibility layer for old marker bodies
  in new wrapper behavior. If old history needs inspection, use the archive
  branch rather than reintroducing legacy writes.
