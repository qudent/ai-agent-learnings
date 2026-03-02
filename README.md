# AI Agent Learnings

Project-agnostic operating guidance for local AI coding agents.

## Setup
- Directory: `~/Dropbox/learnings`
- Keep content reusable across projects
- Project-specific commands belong in each project's `STATUS.md` or docs

## Maintenance Workflow
- Rewrite files when policy changes (avoid append-only drift).
- When workflow changes materially, update `README.md` and `STATUS.md` in the same session.
- Commit and push learnings changes in the same session.

## STATUS.md -- every project gets one

Each non-trivial project must have a `STATUS.md` at its root (~50-100 lines max). This is the coordination point for all agents working on that project.

- **Read it before starting work** on a project.
- **Rewrite it when state changes meaningfully** -- goal completed, blocker found, direction changed.
- **Rewrite, don't append** -- it's current state, not a log. Keep it under 100 lines.
- **Always update STATUS.md immediately after each meaningful state change** -- don't ask, just do it.
- See `agent-coordination.md` for the template and rules.

## Vast Policy Summary
- Hard goals:
  - no long-idle paid instances,
  - autonomous crash detection and recovery,
  - efficient training with complexity-appropriate optimization risk.
- Use a dedicated LLM babysitter agent (Codex) for monitoring/recovery.
- Adaptive check cadence (dense early, sparse stable, dense on alerts).
- Explicit teardown enforcement.

## Files
- `antipatterns.md`
- `ml-experiments.md`
- `vast-ai.md`
- `vast-preestimate.md`
- `agent-coordination.md`
- `modal-inference.md`
