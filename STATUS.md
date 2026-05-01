# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch, and
`chatgit`/`codex_web.py` for the small local web UI.

## Active Goals
- [x] Commit the human-updated `STATUS.md` before taking new work.
- [x] Add `codex_dispatch` for one-round Codex delegation with concise context,
  citations, checkpoint guidance, and `called-by` propagation.
- [x] Add `called-by: user|<commit>` metadata to new run-start marker commits.
- [x] Improve the web UI branch-base/composer behavior and document that the
  current frontend is a legacy plain-JS surface with known AI rough edges.
- [x] Clean stale `STATUS.md` entries and inspect local/upstream branch state.
- [x] Add an optional Jujutsu project-management helper experiment.
- [ ] Decide whether to merge, preserve, or delete the unmerged `dev` branch and
  `origin/dev`.
- [ ] Install `jj` before trying the Jujutsu helper on a real task.

## TODO Plan
- [ ] Restart the `chatgit-main` tmux server so `127.0.0.1:6174` serves the
  patched UI.
- [ ] Run a final status check, commit this compact `STATUS.md`, and push
  `main`.
- [ ] Defer deleting `dev`: it is checked out in a worktree and contains
  unmerged commits/files, so it is not safe to remove as unused.

## Blockers
- `jj` is not installed on this machine, no Rust toolchain is present, and the
  root filesystem has only about 4.8 GB free. The Jujutsu experiment is
  scaffolded but not live-tested with `jj`.

## Recent Results
- Created `Record active coordination prompts` for the human `STATUS.md` edit
  and a checkpoint commit before dispatch/UI work.
- Implemented `called-by` marker metadata, `codex_dispatch`, `codex_checkpoint`,
  compact `/api/overview` polling, mobile composer reachability, visible branch
  base state, clearer branch labels, mobile run actions, and docs/tests.
- Added `scripts/jj_project.sh` as an optional Jujutsu task-DAG experiment; it
  fails clearly when `jj` is missing.
- Verification passed:
  `python3 -m py_compile scripts/codex_web.py scripts/codex_wrap.py`,
  `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`, and
  `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- `git fetch --prune origin` found no stale remote refs. Local `dev` is still
  checked out at `/home/name/repos/ai-agent-learnings.worktrees/dev`, is ahead
  of `origin/dev`, and is not merged into `main`.

## Agent Notes
- This run used internal read-only subagents for UI critique and wrapper tracing,
  not background `codex_commit` workers. The new human correction is now policy
  for larger future dispatch: use Git-backed `codex_dispatch`/`codex_*` calls
  when delegating substantial work.
- `codex_dispatch` lives in `scripts/branch_commands.sh`, not `codex_wrap.py`,
  so branch/worktree orchestration stays outside the low-level wrapper.
- `scripts/.chatgit.swp` was removed in the checkpoint commit.
- Stable repo instructions belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic
  learnings.
