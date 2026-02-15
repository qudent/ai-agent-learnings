# Vast.ai Runtime and Cost Estimation (Adaptive, Run-Calibrated)

## Purpose
Estimate wall-clock and cost with real telemetry while minimizing monitoring noise.

## Policy
This process is not a long upfront blocker.
Default loop:
1. Launch probe quickly.
2. Calibrate from observed throughput.
3. Reforecast at smart intervals.

## Required Deliverables
Within the first 10-15 minutes of a live probe, produce:
- Option table with:
  - GPU option
  - $/h
  - VRAM / CPU RAM
  - observed or predicted step/s
  - time (opt/base/pess)
  - cost (opt/base/pess)
  - setup/debug tax
  - major risks
- A monitoring mode + cadence decision (attended/unattended)

## Step 1: Probe First
Run 20-100 real steps and capture:
- median step time (or step/s)
- eval runtime and cadence
- GPU util + VRAM
- early error markers

## Step 2: Build Forecast
Given target steps:
- `train_hours = target_steps / (step_s * 3600)`
- Add eval overhead from measured eval runtime/frequency.
- `wall_hours = setup_debug_hours + train_hours + eval_overhead_hours`
- `cost = wall_hours * dph_total`

Scenarios:
- optimistic: `step_s * 1.2`
- base: `step_s * 1.0`
- pessimistic: `step_s * 0.6`

## Step 3: Reforecast Cadence (Adaptive)
- Early instability window: reforecast every 10 minutes.
- Stable cruise window: reforecast every 60 minutes.
- Immediate reforecast on any alert trigger.

Do not do high-frequency re-estimation during long stable periods.

## Break-Even Speed Test
For cost-per-step comparison against current baseline:
- `required_step_s_candidate = step_s_current * (dph_candidate / dph_current)`

If candidate cannot realistically exceed this, it is a wall-clock play, not a cost play.

## Setup/Debug Tax
- `setup_debug_tax = setup_debug_hours / wall_hours`

Use as decision aid:
- High tax means reduce complexity first.
- Low tax + stable run means scaling hardware may be justified.

## Alert Triggers (Override Cadence)
- Step progression stalls.
- Throughput <70% of baseline for two checks.
- Low GPU util while active.
- Error markers or repeated instability.

On alert:
- increase check density (2-5 min)
- classify bottleneck quickly
- change one variable and re-run

## Mindset
Do not miss the forest for the trees.
Use dense monitoring for early risk, sparse monitoring for long stable stretches.
