# Vast.ai Learnings

## Core Principle
Run first, analyze in parallel.
Do not block on elaborate upfront analysis that can be replaced by 5-10 minutes of real-run signal.

## Forest-First Workflow
1. Pick a likely-fit instance quickly.
2. Start a real smoke run quickly (20-100 steps).
3. While it runs, measure throughput, memory, stability, and transfer speed.
4. Decide quickly: keep, optimize, switch instance, or kill.
5. Only after real measurements, do detailed ETA/$ projections.

## Minimal Pre-Rent Gate (2-3 Minutes)
Use only hard checks before renting:
- GPU VRAM likely fits the run mode.
- CPU RAM is not obviously too small.
- Disk has enough room for model + checkpoints.
- Reliability is acceptable.

Do not spend long on speculative throughput math before this probe.

## Fast Bring-Up Checklist
1. Confirm GPU visibility: `nvidia-smi`
2. Bootstrap repo and dependencies
3. Start smoke run with logging to file
4. Verify the run is truly progressing (steps increase, no traceback)
5. Record first live numbers:
   - step/s or step time
   - GPU util and memory
   - eval cadence and eval runtime
   - transfer speed to real endpoints

## Analyze While Running
As soon as smoke is alive, compute ETA and cost from observed step/s.
Use optimistic/base/pessimistic ranges from live throughput rather than only hardware specs.

- If signal is good: continue or relaunch longer with early-stop policy.
- If signal is bad: stop quickly, change one thing, retry.

## Kill Fast Rules
Stop and re-evaluate immediately when any of these hold:
- Throughput stays below ~70% of expectation for 2 checks.
- GPU utilization stays low (<60%) while job should be active.
- No meaningful metric movement by early checkpoint.
- Network/setup friction dominates and blocks progress.
- Repeated runtime/dependency failures consume expensive GPU time.

## Optimization Order (After It Runs)
1. Batch/micro-batch sizing and gradient accumulation
2. Data pipeline (`num_workers`, pinning, host bottlenecks)
3. Logging/checkpoint overhead
4. Precision and checkpointing tradeoffs
5. Compile/distributed complexity only if needed

Avoid heavyweight distributed stacks on single-GPU runs unless required.

## Monitoring Model
- Detached watcher tmux panes do not wake agents by themselves.
- Prefer one of:
  1. Interactive milestone checks
  2. One blocking local wait loop for unattended windows
- Avoid noisy detached watcher + manual polling combos.

## Cost Discipline
- Do not leave idle instances running.
- If stuck, kill and relaunch intentionally.
- Keep changing one variable at a time so failed spend teaches something.

## SSH and Connectivity
- Keep Vast SSH config ready for fast reconnect.
- API keys live in environment (`$VAST_API_KEY`), not repos.
