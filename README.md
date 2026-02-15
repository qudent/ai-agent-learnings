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

## Vast Policy Summary
- Run-first execution after minimal fit gate.
- Canonical architecture: remote supervisor + local adaptive watcher.
- Bounded retries with cheap auto-fixes.
- Adaptive monitoring cadence:
  - early dense checks,
  - stable sparse checks,
  - alert-driven escalation.
- Explicit teardown policy on terminal states.

## Files
- `antipatterns.md`
- `ml-experiments.md`
- `vast-ai.md`
- `vast-preestimate.md`
- `agent-coordination.md`
