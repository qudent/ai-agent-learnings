# ai-agent-learnings - Status

## Current State
Vast learnings now enforce adaptive monitoring: dense checks during early risk, sparse checks during stable cruise, and alert-driven escalation.
The policy explicitly avoids token-heavy fixed polling over long healthy runs.

## Active Goals
- [x] Keep learnings project-agnostic
- [x] Encode run-first, probe-calibrated Vast workflow
- [x] Encode adaptive check-in strategy with alert escalation
- [ ] Calibrate default thresholds from additional completed runs

## Blockers
- None

## Recent Results
- Rewrote `vast-ai.md` with a concrete adaptive check-in framework.
- Rewrote `vast-preestimate.md` to pair forecasting cadence with run stability.
- Rewrote `antipatterns.md` to include over-polling as a first-class anti-pattern.
- Updated `README.md` with the new Vast policy summary.

## Next Steps
1. Collect 3+ completed run traces and tune alert thresholds.
2. Keep the one-line check output contract (`ts step rate eta gpu mem eval status`) consistent across projects.
