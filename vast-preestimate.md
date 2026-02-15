# Vast.ai Runtime and Cost Estimation (Run-Calibrated)

## Purpose
Estimate runtime and cost from real measurements, not only speculation.

## Important Policy
This is **not** a hard blocker before renting.
Default flow is:
1. Launch a quick real probe run.
2. Calibrate throughput from that probe.
3. Produce ETA/$ estimates while the run is active.

## Required Output (Within First 10-15 Minutes)
Publish one option table with:
- `GPU option`, `$/h`, `VRAM`, `CPU RAM`, `TFLOPS`, `HBM BW`
- observed or predicted `step/s`
- `time (opt/base/pess)`
- `cost (opt/base/pess)`
- `setup/debug tax %`
- `major risks`
- `keep/switch/kill decision`

## Stage A: Minimal Pre-Rent Checks
Do these quickly only to avoid obvious dead ends:
- VRAM likely fits mode and batch.
- CPU RAM is not obviously insufficient.
- Disk has enough room for model + checkpoints + temp.
- Reliability/network are not obviously bad.

If it passes these checks, rent and probe.

## Stage B: Probe Run First
Run 20-100 steps on the real instance with real config family.
Capture:
- median step time (or step/s)
- eval runtime at least once (if possible)
- GPU util, memory util, VRAM used
- transfer speed to real artifact endpoints
- setup/debug time spent so far

## Stage C: Estimate From Live Throughput
Use live measured throughput as baseline.

- `train_hours = target_steps / (step_s * 3600)`
- Add eval overhead from measured eval runtime and eval frequency.
- `wall_hours = setup_debug_hours + train_hours + eval_overhead_hours`
- `cost_usd = wall_hours * dph_total`

Scenarios:
- optimistic: `step_s * 1.2`
- base: `step_s * 1.0`
- pessimistic: `step_s * 0.6`

## Stage D: Setup/Debug Tax
- `setup_debug_tax = setup_debug_hours / wall_hours`

Interpretation:
- If tax is high (roughly >25%), avoid expensive hardware until run path is stable.
- If tax is low and run is stable, upgrade hardware only if it improves total time materially.

## Contradiction Triggers (Act Immediately)
- Throughput <70% of expected for 2 consecutive checks.
- GPU utilization <60% while job is active.
- Sustained memory pressure near OOM.
- No meaningful metric movement by early checkpoint.

Action:
- Stop or pause expensive run.
- Identify bottleneck type: input, compute, memory, logging, infra.
- Change one variable and relaunch quickly.

## Optimization Priority
1. Batch sizing and grad accumulation
2. Data pipeline bottlenecks
3. Logging/eval/checkpoint overhead
4. Precision/checkpointing tradeoffs
5. Advanced complexity (`torch.compile`, distributed) only after stable baseline

## Mindset
Do not miss the forest for the trees.
A running probe with clear telemetry beats long speculative pre-analysis.
