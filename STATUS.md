# ai-agent-learnings - Status

## Current State
This repository stores project-agnostic learnings for AI agents. Vast.ai guidance now includes a dedicated rules-first pre-estimation playbook for one-off manual calculations before expensive runs.

## Active Goals
- [x] Build a pre-estimation workflow for GPU training on Vast.ai
  - [x] Add a dedicated pre-estimate file that can be loaded only when needed
  - [x] Document manual one-off calculations before launch
  - [x] Link from `vast-ai.md` and keep `vast-ai.md` concise
- [x] Incorporate evidence from recent Codex/Claude transcripts into recommendations
- [x] Keep content project-agnostic (no one-off project runbooks)

## Blockers
- None

## Recent Results
- Added `vast-preestimate.md` with manual formulas/checks for:
  - memory fit (GPU VRAM + CPU RAM),
  - throughput prediction using `total_flops` and `gpu_mem_bw`,
  - time/cost ranges with setup-debug tax,
  - 10-minute runtime validation and contradiction triggers.
- Updated `vast-ai.md` to make pre-estimation mandatory before long runs.
- Updated `README.md` file index to include the new playbook.

## Next Steps
1. Use this playbook in the next real Vast.ai run and capture predicted vs actual deltas.
2. If repeated deltas show bias, tighten default efficiency factors and thresholds.
