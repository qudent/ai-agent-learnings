# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents. `AGENTS.md` is the canonical global instruction source, global agent config files symlink to it, and branch-scoped one-shot `@codex`/`@claude` dispatch helpers now live under `scripts/`.

## Human Prompts
- None active.

## Active Goals
- [x] Move canonical global instructions into `~/learnings/AGENTS.md`.
- [x] Fold agent coordination guidance into `AGENTS.md`.
- [x] Replace global `AGENTS.md`/`CLAUDE.md` files with symlinks to `~/learnings/AGENTS.md`.
- [x] Commit and push the learnings repo update.
- [x] Add durable human-input conventions around commit messages and `USER_IO.md`.
- [x] Add branch-scoped one-shot dispatcher and local human-input logging helper.
- [x] Add a first-pass main-branch dispatcher for `@codex` and `@claude` commits.

## Blockers
- None.

## Recent Results
- Added git-dispatched worktree workflow guidance.
- Removed separate `agent-coordination.md` from the intended policy surface.
- Replaced `/home/name/AGENTS.md`, `/home/name/.codex/AGENTS.md`, and `/home/name/.claude/CLAUDE.md` with symlinks to `/home/name/learnings/AGENTS.md`.
- Added `scripts/dispatch-agent.sh` and a sample laptop `post-commit` hook for triggering `/home/name/repos/endepromotion`.
- Added `[no-dispatch]` / `@no-dispatch` suppression and clarified that only commit messages trigger dispatch.
- Removed the cron-based watcher; dispatch is trigger-based, not polling-based.
- Added `USER_IO.md` convention: human-owned durable prompts are distinct from agent-owned `STATUS.md` output.
- Changed dispatcher branches from one branch per SHA to one branch per tool/source branch, e.g. `agent/codex/main`.

## Agent Output
- Implemented the prompt-preserving workflow: human input goes in commit messages, human diffs, or `USER_IO.md`; live chat feedback can be logged with `[no-dispatch]`; dispatch is one-shot and branch-scoped so follow-up commits continue the same agent branch.

## Next Steps
- Install the laptop hook or webhook trigger for target repos when ready.
