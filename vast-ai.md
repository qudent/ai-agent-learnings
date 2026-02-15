# Vast.ai Learnings

## Core Objective
Catch failures early without wasting tokens on noisy long-run polling.

## Operating Principle
Run first, then monitor adaptively.
- Start a real probe quickly.
- Use dense checks only while failure risk is highest.
- Switch to sparse milestone checks once stable.
- Escalate back to dense checks only when alerts fire.

## Minimal Pre-Rent Gate (Fast)
Do only obvious fit checks before renting:
- VRAM likely fits planned mode.
- CPU RAM is not obviously insufficient.
- Disk has room for model + checkpoints.
- Reliability is acceptable.

Then launch.

## Bring-Up Sequence
1. Confirm GPU visibility (`nvidia-smi`).
2. Bootstrap repo/deps.
3. Launch a short real probe (20-100 steps) with logs.
4. Capture baseline metrics from real run:
   - step/s (or sec/step)
   - eval runtime/frequency
   - GPU util + VRAM
   - error markers (traceback/OOM)
   - transfer speed to real endpoints

## Adaptive Check-In Strategy
Use one of these two modes.

### Attended Mode
- Early risk window: check at ~1, 3, 7, 15 minutes.
- Stabilization window: every 10 minutes until 2 consecutive healthy windows.
- Cruise window: every 30-60 minutes.
- Milestones: check near critical step boundaries and once near expected finish.

### Unattended Mode
- Run one blocking local watcher that returns only on:
  - `ALERT`
  - `CRASH`
  - `DONE`
  - `TIMEOUT`
- Avoid chatty periodic output unless in alert mode.

## Alert Conditions (Escalate Immediately)
Switch to 2-5 minute checks when any trigger fires:
- Step counter stalls across 2 checks.
- Throughput stays below ~70% of baseline across 2 checks.
- GPU utilization stays low (<60%) while job should be active.
- Sustained high memory pressure (OOM risk).
- New traceback/runtime errors.
- Early eval trend is materially worse than expected.

## Check Output Contract (Token Budget)
Every check should emit one compact summary line, not raw logs:
- `ts step rate eta gpu mem eval status`

Only expand logs on alert.

## Watcher Rules
- Detached watcher output is useless unless consumed.
- Do not run multiple watcher layers in parallel.
- Prefer one canonical watcher and one canonical status sink (`STATUS.md`).

## Cost Discipline
- Keep estimated completion time/cost updated from live throughput.
- Do not keep idle instances running.
- If run is unhealthy and unresolved after quick iteration, kill and relaunch intentionally.

## Decision Rule Summary
- Healthy + stable: sparse checks.
- Uncertain/unstable: dense checks.
- Broken/expensive drift: stop and fix before spending more.
