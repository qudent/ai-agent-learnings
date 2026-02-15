# Vast.ai Learnings

## Before Renting (Required)
- Run the manual pre-estimation process in `vast-preestimate.md` first.
- Do not start a long run before you have:
  - memory fit checks (GPU VRAM + system RAM),
  - time/cost ranges (optimistic/base/pessimistic),
  - a 10-minute validation loop with contradiction thresholds.

## Instance Selection
- Some instances have terrible internet -- 170 KB/s observed.
- Always test transfer speed early against the **actual sources/sinks you will use** (GitHub/Hugging Face/object storage/target region), not only a generic speed endpoint.
- Keep one neutral sanity check endpoint too (e.g., `https://nbg1-speed.hetzner.com/100MB.bin`) and compare with your real artifact path.
- **Always check RAM specs before renting**: both GPU VRAM and system RAM. CPU optimizer offloading, large batch sizes, and gradient accumulation all consume system RAM. 32GB instances can OOM silently during gradient computation. Example: GRPO training with batch 64 and CPU offloading needs >=64GB system RAM.
- Always check the instance has enough disk for model weights + checkpoints before starting.

## Setup Checklist
Before launching any training:
1. Test internet speed to real artifact endpoints (and one sanity endpoint)
2. Confirm GPU is visible: `nvidia-smi`
3. Clone repo + install deps
4. Run smoke test -- 50 steps, confirm loss decreases and reward > 0
5. Define early-abort criteria and 10-minute monitoring checks
6. Only then start the real run

## Runtime Management
- Set `max_runtime` explicitly or remove the cap -- don't discover 6 hours in that it auto-terminated.
- Write checkpoints frequently enough that a crash doesn't lose more than ~30 min of training.
- Log to a file that can be tailed remotely, not just stdout.
- On single-GPU Trainer runs, avoid installing heavyweight distributed stacks (e.g., `deepspeed`) unless you actually use them. They increase cold-start time and can fail at runtime from missing build/runtime deps.

## Monitoring Model (Important)
- **No push wake-up exists by default**: a detached script cannot "wake" Codex by itself.
- A watcher running in tmux is only useful if someone is actively reading that tmux pane.
- If you want a wake-up behavior in practice, run a **blocking local command** in the active turn that returns on crash/completion/timeout.

## Monitoring Modes (Pick One)
1. Interactive mode (you are present):
   - Manual check-ins at meaningful milestones (e.g., first 5 min, step 100, step 400).
2. Unattended mode (sleep/away):
   - Run one blocking watcher command locally with sparse polling.
   - Example pattern:
     `TIMEOUT_SECS=<timeout_s> CHECK_EVERY=<poll_s> bash <project_path>/scripts/local/wait_or_crash.sh`
3. Milestone mode:
   - Estimate ETA to a critical step and run one delayed check near that time.
   - Use this for "did we pass the known failure point?" without frequent polling.

## Monitoring Rules
- Do not run detached local watcher tmux plus manual polling in parallel; it adds noise without reliability gains.
- Avoid auto-restart loops on remote. If a run dies, inspect first, then relaunch intentionally.
- Keep watcher logic local (not on the Vast instance) so no extra secrets/config are copied remotely.
- For trusted long runs, use sparse intervals (30-90 min or 1h+), not every few minutes.

## Overnight Workflow (Default)
1. Launch training in remote tmux and write run id/path into `STATUS.md`.
2. Do one early smoke check (after 5-10 min): confirm steps are increasing and no traceback.
3. Record one milestone ETA (e.g., known old crash step) and one expected finish ETA.
4. If sleeping/away, run one blocking local wait command with long timeout and sparse polling.
5. On return, run one triage bundle: step, traceback marker, summary marker, GPU util, completion flag.

This keeps context low, avoids noisy polling, and still catches failures at useful times.

## Cost Awareness
- Don't leave instances running idle. If training is done or stuck, stop the instance.
- Check `vast show instances` periodically.

## SSH & Connectivity
- Keep SSH config for vast instances in `~/.ssh/config` so reconnecting is fast.
- API key: `$VAST_API_KEY` in bashrc -- not in repos.
