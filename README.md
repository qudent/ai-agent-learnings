# AI Agent Learnings

This repository tracks project-agnostic lessons for local AI coding agents.

## Setup
- Directory: `~/Dropbox/learnings`
- Purpose: reusable operating guidance, not project-specific commands
- Project-specific commands belong in each project's `STATUS.md` or docs

## Maintenance Workflow
- Keep content project-agnostic.
- When workflow policy changes, update `README.md` and `STATUS.md` in the same session.
- Commit and push learnings updates before ending the task.

## Vast Policy Summary
- Vast execution is run-first and probe-calibrated.
- Monitoring is adaptive, not fixed-interval:
  - dense checks early
  - sparse milestone checks once stable
  - immediate escalation on alert triggers
- Prefer one canonical blocking watcher for unattended runs.

## Files
- `antipatterns.md`
- `ml-experiments.md`
- `vast-ai.md`
- `vast-preestimate.md`
- `agent-coordination.md`
