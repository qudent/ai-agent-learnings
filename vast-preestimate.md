# Vast.ai Runtime and Cost Estimation (Sleep-Mode Compatible)

## Purpose
Produce reliable ETA/cost forecasts from live telemetry, with minimal monitoring noise.

## Policy
Forecasting is run-calibrated, not a long pre-launch blocker.

Workflow:
1. launch quickly after hard-fit checks
2. calibrate from live probe/run telemetry
3. reforecast on schedule + alert triggers

## Required Outputs
Within 10-15 minutes of live run start:
- option table:
  - GPU option, $/h, VRAM, CPU RAM
  - observed/predicted step/s
  - time (opt/base/pess)
  - cost (opt/base/pess)
  - setup/debug tax
  - major risks
- chosen monitoring mode and cadence
- teardown policy (`on_done`, `on_fail`)

## Live Throughput Model
For target steps:
- `train_hours = target_steps / (step_s * 3600)`
- `wall_hours = setup_debug_hours + train_hours + eval_overhead_hours`
- `cost = wall_hours * dph_total`

Scenarios:
- optimistic: `step_s * 1.2`
- base: `step_s`
- pessimistic: `step_s * 0.6`

## Reforecast Cadence
- early instability window: every 10 minutes
- stable cruise window: every 60 minutes
- immediate reforecast when alert triggers fire

Do not reforecast at high frequency during stable long runs.

## Alert Triggers (Override Cadence)
- stalled progress heartbeat
- sustained low GPU utilization while active
- throughput drops below expected band
- runtime/traceback errors
- repeated retries/fix cycles

When triggered:
- move to alert cadence
- classify bottleneck quickly
- change one variable only

## Cost-Per-Step Break-Even
Compare candidate vs current baseline:
- `required_step_s_candidate = step_s_current * (dph_candidate / dph_current)`

If realistic candidate speed is below this threshold, candidate is not a cost win.

## Setup/Debug Tax
- `setup_debug_tax = setup_debug_hours / wall_hours`

Interpretation:
- high tax: reduce complexity first
- low tax + stable path: scaling hardware may be justified

## Long-Finetune Guardrail
When objective is comprehensive finetuning (not short probe):
- set early-stop floor late enough (high `min_steps`)
- avoid aggressive stop thresholds tuned for quick probes
- include this policy in forecast assumptions
