# ai-agent-learnings - Status

## Current State
Vast learnings now encode explicit operational goals:
- prevent idle spend,
- autonomous crash recovery,
- efficient training with proportional optimization complexity/risk.

The canonical method is now agent-driven babysitting (LLM agent), not shell-heavy automation.

## Active Goals
- [x] Keep learnings project-agnostic
- [x] Encode user hard goals as non-negotiable constraints
- [x] Encode LLM babysitter monitoring/recovery workflow
- [x] Encode teardown enforcement rule
- [ ] Calibrate alert thresholds from additional completed runs

## Blockers
- None

## Recent Results
- Rewrote `vast-ai.md` around hard goals + agent babysitter algorithm.
- Updated `README.md` Vast summary to match these goals.
- Rewrote `STATUS.md` to reflect current policy and remaining calibration work.

## Next Steps
1. Collect additional unattended run traces and tune alert thresholds.
2. Keep one-line milestone reporting to minimize token burn.
