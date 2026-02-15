# Vast.ai Learnings

## Non-Negotiable Goals
1. No idle Vast instances wasting money for long.
2. If experiment crashes, it is detected and fixed autonomously.
3. Training runs efficiently, with optimization effort and bug-risk proportional to task complexity.

## Operating Model
Use a dedicated **LLM babysitter agent** (Codex in tmux), not complex shell autopilot logic.

Two-agent pattern:
- `runner` agent: launches/changes experiments.
- `babysitter` agent: monitors, debugs, relaunches, and enforces teardown policy.

## Launch Protocol
1. Do minimal hard-fit checks only (VRAM, RAM, disk, reliability).
2. Launch run quickly on real hardware.
3. Write run metadata to project `STATUS.md`:
- instance id
- command/config
- log path
- kill criteria
- teardown policy
4. Start/assign babysitter agent with explicit mandate:
- keep training alive
- fix failures autonomously
- avoid idle spend
- report only meaningful milestones

## Babysitter Monitoring Strategy
Adaptive cadence:
- Early risk window: check at ~1, 3, 7, 15 minutes.
- Stabilization: every 10 minutes until healthy twice consecutively.
- Cruise: every 30-60 minutes.
- Alert mode: every 2-5 minutes until resolved.

Compact status output only:
`ts state step rate gpu mem eval action next_eta`

Expand logs only on alert.

## Alert Triggers
- Process/session died unexpectedly.
- Step counter stopped advancing.
- Traceback/OOM/runtime error appears.
- GPU utilization unexpectedly low while job should train.
- Throughput materially below expected band.
- Early metric trend clearly wrong vs objective.

## Autonomous Recovery Policy
When trigger fires, babysitter acts without waiting:
1. Triage quickly (cause classification).
2. Apply smallest safe fix first.
3. Relaunch and verify forward progress.
4. If repeated failure, escalate one level only.

Escalation ladder:
- transient rerun
- dependency/runtime fix
- conservative config reduction
- instance switch

After bounded failed attempts, stop and report root cause + next best option.

## Teardown Enforcement
- If no active training and no approved debugging reason, destroy instance quickly.
- Always destroy on terminal `done` unless user asked to keep instance.
- Never leave expensive idle instances running "just in case".

## Efficiency and Risk Rules
- Prefer low-complexity changes first on single-GPU runs.
- Do not introduce high-complexity optimizations unless baseline is stable and bottleneck is confirmed.
- Optimize where measured bottleneck exists (data, compute, memory, logging), not by speculation.
- Keep change size small to reduce bug-introduction risk.

## Early-Stop Policy Guardrail
For comprehensive finetuning, prevent premature stop:
- set sufficiently high `min_steps`
- use non-aggressive patience/min-delta
- treat early stop as policy behavior, not crash

## Accountability Rule
Do not just acknowledge goals. Enforce them with actions:
- terminate idle spend
- keep a babysitter agent assigned
- execute fixes autonomously
- update status with what was done
