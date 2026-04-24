# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents. `AGENTS.md` is the canonical global instruction source, global agent config files symlink to it, and branch-ref dispatched `@codex`/`@claude` helpers live under `scripts/`. `STATUS.md` is now compact project state only; active human-agent communication belongs in `HUMAN_AGENTS_WHITEBOARD.md`.

## Active Goals
- [x] Keep global agent instructions centralized in `~/learnings/AGENTS.md`.
- [x] Maintain project-agnostic learnings and workflow guardrails.
- [x] Support branch-ref dispatch where each branch is worked in its own worktree.
- [x] Split project state from active human-agent communication.

## Blockers
- None.

## Recent Results
- Merged the old `agent/codex/main` result into `main`, then removed the stale local and remote `agent/codex/main` branch/worktree.
- Replaced ordinary `agent/<tool>/<branch>` dispatch semantics with branch-owned worktree dispatch.
- Added `scripts/reference-transaction-dispatch.sample` so committed `refs/heads/<branch>` pointer updates trigger dispatch when the new tip commit message contains `@codex` or `@claude`.
- Installed local `.git/hooks/reference-transaction` wrappers in `~/learnings` and `~/repos/endepromotion`.
- Updated coordination policy so `STATUS.md` is state only and `HUMAN_AGENTS_WHITEBOARD.md` holds active prompts, open questions, agent notes, and latest agent-to-human communication.

## Next Steps
- Watch the first real branch-update dispatch log under `/home/name/agent-dispatch-logs` and tighten hook behavior if Git reports an unexpected ref-update edge case.
