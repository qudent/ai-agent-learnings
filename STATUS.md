# ai-agent-learnings - Status

## Current State
Learnings now encode a clearer Vast workflow: run first, analyze in parallel, optimize based on live telemetry, and kill fast when signal is poor.
`vast-ai.md` and `vast-preestimate.md` were updated to remove heavy upfront-analysis bias.

## Active Goals
- [x] Keep learnings project-agnostic
- [x] Clarify Vast monitoring model and anti-patterns
- [x] Encode run-first Vast workflow in learnings docs
- [ ] Collect estimate-vs-actual deltas from multiple runs to calibrate scenario multipliers

## Blockers
- None

## Recent Results
- `vast-ai.md` now emphasizes:
  - quick instance bring-up,
  - probe-first execution,
  - analysis during runtime,
  - explicit kill-fast rules.
- `vast-preestimate.md` now emphasizes:
  - probe-calibrated ETA/$ estimates,
  - first estimate within 10-15 minutes of a live run,
  - contradiction triggers and immediate corrective actions.
- `README.md` now documents the run-first Vast policy and file roles.

## Next Steps
1. During upcoming Vast runs, log observed step/s and final wall time for calibration.
2. Tighten optimistic/base/pessimistic multipliers after 3+ recorded runs.
