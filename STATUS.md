# ai-agent-learnings - Status

## Current State
Vast learnings now define a concrete unattended algorithm for long training runs:
- remote supervisor with bounded retries,
- local adaptive watcher,
- alert-driven cadence changes,
- explicit teardown on terminal states.

## Active Goals
- [x] Keep learnings project-agnostic
- [x] Encode sleep-mode run manager algorithm
- [x] Encode adaptive monitoring + stall guardrails
- [x] Encode strict learnings versioning discipline
- [ ] Calibrate thresholds from more completed runs

## Blockers
- None

## Recent Results
- Rewrote `vast-ai.md` with canonical supervisor/watcher architecture and full algorithm.
- Rewrote `vast-preestimate.md` to align ETA/cost updates with adaptive monitoring.
- Rewrote `antipatterns.md` to include:
  - over-polling,
  - false stall detection,
  - early-stop misclassification,
  - learnings versioning failures.
- Updated `README.md` to summarize policy and maintenance rules.

## Next Steps
1. Record 3+ unattended run traces and refine alert thresholds.
2. Keep status output compact and action-oriented (`ts status attempt step gpu mem fix run`).
