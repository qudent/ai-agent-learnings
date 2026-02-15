# Vast.ai Learnings

## Objective
Enable true sleep-mode execution:
- start a run,
- auto-handle common failures,
- monitor with low noise,
- tear down automatically on terminal states.

## Canonical Architecture
Use two roles only:
1. **Remote Supervisor** (on the instance)
- owns run attempts
- writes machine-readable state
- applies bounded auto-fixes
- retries up to a limit

2. **Local Watcher** (where the agent runs)
- reads supervisor state/log heartbeat
- uses adaptive check cadence
- escalates only on alerts
- triggers teardown policy on `done`/`failed`

Do not add extra watcher layers.

## Run-First Gate
Before launch, do only hard checks:
- VRAM likely fits mode
- CPU RAM not obviously insufficient
- disk headroom exists
- reliability acceptable

Then launch immediately and use live signal.

## Unattended Algorithm
1. Start remote supervisor with explicit config and retry budget.
2. Supervisor starts attempt 1 and records state (`running/retrying/done/failed`).
3. On failure, supervisor applies cheap auto-fixes, then retries:
- missing runtime/tooling deps
- missing compiler/build deps
- low-disk cleanup
- safe eval-size reduction on OOM
4. Local watcher checks status with adaptive cadence:
- early risk: `1m, 2m, 4m, 8m`
- stable cruise: every `30m`
- alert mode: every `3m`
5. Alert triggers:
- traceback/runtime error markers
- stalled step/log heartbeat across consecutive checks
- low GPU util during expected training
- throughput collapse vs baseline
6. Stall handling:
- only treat as stall when heartbeat is stale **and** GPU is mostly idle
- perform one safe recovery action (kill stuck trainer process) and let supervisor retry
7. Exit handling:
- `done`: collect summary, then optional teardown
- `failed`: stop monitoring loop, optional teardown
8. Always keep one-line status output per check.

## Status Line Contract
Emit one compact line per check:
`ts status attempt step gpu mem fix run`

Expand logs only on alert.

## Early-Stop Policy Guardrail
For long/comprehensive finetunes, prevent premature stop:
- set `auto_stop_min_steps` to a meaningful floor (e.g., mid/late training)
- use less aggressive `min_delta`/patience than short probes
- treat early stop as a policy outcome, not a crash

## Teardown Policy
Make teardown explicit per run:
- `destroy_on_done` (usually true for cost control)
- `destroy_on_fail` (usually true unless interactive debugging is planned)

Never leave idle expensive instances running.

## Decision Rules
- healthy and stable: sparse cadence
- uncertain/alerting: dense cadence
- repeated failure after retry budget: fail fast, tear down, report root cause + next change
