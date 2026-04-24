# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents. `AGENTS.md` is the canonical global instruction source, global agent config files symlink to it, and one-shot `@codex`/`@claude` dispatch helpers now live under `scripts/`. Dispatch runs in the worktree associated with the triggering branch, not in `agent/<tool>/<branch>` child branches.

## Human Prompts
- None active.

## Active Goals
- [x] Move canonical global instructions into `~/learnings/AGENTS.md`.
- [x] Fold agent coordination guidance into `AGENTS.md`.
- [x] Replace global `AGENTS.md`/`CLAUDE.md` files with symlinks to `~/learnings/AGENTS.md`.
- [x] Commit and push the learnings repo update.
- [x] Add durable human-input conventions around commit messages and `USER_IO.md`.
- [x] Add one-shot branch-worktree dispatcher and local human-input logging helper.
- [x] Add a first-pass main-branch dispatcher for `@codex` and `@claude` commits.
- [x] Clarify dispatcher prompt semantics and align new-worktree initialization with `parallel-worktrees`.
- [x] Merge `agent/codex/main` into `main` and correct dispatch semantics to branch-owned worktrees.
- [x] Install guarded local branch-update hooks for `~/learnings` and `~/repos/endepromotion`.

## Blockers
- None.

## Recent Results
- Added git-dispatched worktree workflow guidance.
- Removed separate `agent-coordination.md` from the intended policy surface.
- Replaced `/home/name/AGENTS.md`, `/home/name/.codex/AGENTS.md`, and `/home/name/.claude/CLAUDE.md` with symlinks to `/home/name/learnings/AGENTS.md`.
- Added `scripts/dispatch-agent.sh` and guarded local hook samples for triggering dispatch on `theserver`.
- Added `[no-dispatch]` / `@no-dispatch` suppression and clarified that only commit messages trigger dispatch.
- Removed the cron-based watcher; dispatch is trigger-based, not polling-based.
- Added `USER_IO.md` convention: human-owned durable prompts are distinct from agent-owned `STATUS.md` output.
- Clarified that the whole trigger commit message and human-authored patch are durable prompt input; post-tag text is extra prompt content, not the only prompt.
- Merged the old `agent/codex/main` result into `main`.
- Corrected dispatcher behavior: it receives the source branch, finds or creates that branch's worktree, runs the agent there, commits to the same branch, and queues concurrent trigger commits with a blocking lock.
- Added `scripts/reference-transaction-dispatch.sample`, which watches committed `refs/heads/<branch>` pointer updates and triggers only when the new tip commit message contains `@codex` or `@claude`.
- Installed local `.git/hooks/reference-transaction` wrappers in `~/learnings` and `~/repos/endepromotion`; the hook exits cleanly off `theserver` or when the dispatcher script is absent, starts dispatch inside persistent `tmux`, and logs under `/home/name/agent-dispatch-logs`.

## Agent Output
- Resolved the active correction: dispatch is now keyed by branch ref updates, not by guessing from a commit after the fact. The branch itself owns the worktree where the agent runs; extra instructions during a run should arrive as another `@codex`/`@claude` commit, which waits on the dispatcher lock.

## Next Steps
- Remove the stale `agent/codex/main` branch/worktree after the merged result is pushed.
