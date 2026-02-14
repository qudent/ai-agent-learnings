# ai-agent-learnings - Status

## Current State
This repo is the project-agnostic operating manual for local AI agents. Monitoring guidance for long Vast runs is now clarified: detached watcher tmux sessions do not wake agents; default workflow is milestone checks or one blocking local wait command.

## Active Goals
- [x] Keep learnings project-agnostic
- [x] Clarify Vast monitoring model and anti-patterns
- [x] Encode learnings maintenance workflow in docs and global instructions
- [ ] Gather predicted-vs-actual runtime deltas from future runs to calibrate estimates

## Blockers
- None

## Recent Results
- `vast-ai.md` now defines:
  - monitoring model limitations (no push wake-up by default),
  - monitoring modes (interactive, unattended blocking wait, milestone),
  - overnight default workflow.
- `antipatterns.md` now includes: `Detached watcher with no consumer`.
- `README.md` now includes maintenance workflow:
  - update `README.md`/`STATUS.md` when workflow changes,
  - commit+push learnings updates in the same session.
- Global `/home/name/CLAUDE.md` now mirrors this rule.

## Next Steps
1. During next long Vast run, record estimate vs actual completion time and checkpoint timings.
2. Tighten estimator defaults if systematic bias appears across multiple runs.
