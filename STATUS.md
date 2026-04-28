# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents.
`AGENTS.md` is the canonical global instruction source, global agent config
files symlink to it, and branch-ref dispatched `@codex`/`@claude` helpers live
under `scripts/`.

`STATUS.md` is now the single coordination source of truth for project state,
active human prompts, agent replies, handoff notes, open questions, and TODO
plans. The separate human-agent whiteboard pattern is retired.

## Active Human Prompts
- Remove human-agent whiteboards and integrate active coordination into
  `STATUS.md` as the source of truth.
- Keep coordination plain and simple: the human writes what they want, the agent
  replies with what they need to reply, and the current coordination file is
  committed and pushed whenever there is meaningful new information.

## Active Goals
- [x] Keep global agent instructions centralized in `~/learnings/AGENTS.md`.
- [x] Maintain project-agnostic learnings and workflow guardrails.
- [x] Support branch-ref dispatch where each branch is worked in its own
  worktree.
- [x] Use `STATUS.md` as the single coordination file instead of splitting state
  and communication across a whiteboard.

## TODO Plan
- [ ] Watch the next real branch-update dispatch log under
  `/home/name/agent-dispatch-logs` and tighten hook behavior if Git reports an
  unexpected ref-update edge case.
- [ ] When touching existing project repos, remove stale whiteboard files only
  when the active context has been preserved in `STATUS.md`.

## Blockers
- None.

## Recent Results
- Replaced ordinary `agent/<tool>/<branch>` dispatch semantics with
  branch-owned worktree dispatch.
- Added `scripts/reference-transaction-dispatch.sample` so committed
  `refs/heads/<branch>` pointer updates trigger dispatch when the new tip commit
  message contains `@codex` or `@claude`.
- Updated coordination policy back to one file: `STATUS.md` contains state,
  active prompts, open questions, agent notes, and TODO plans.

## Agent Notes
- `scripts/log-human-input.sh` writes human notes into `STATUS.md` and commits
  with `[no-dispatch] usr: log human input`.
- Stable repo instructions still belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic learnings.
