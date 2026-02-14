# Vast.ai Learnings

## Before Renting (Required)
- Run the manual pre-estimation process in `vast-preestimate.md` first.
- Do not start a long run before you have:
  - memory fit checks (GPU VRAM + system RAM),
  - time/cost ranges (optimistic/base/pessimistic),
  - a 10-minute validation loop with contradiction thresholds.

## Instance Selection
- Some instances have terrible internet -- 170 KB/s observed. Test bandwidth early: `curl -o /dev/null -w '%{speed_download}' https://speed.hetzner.de/100MB.bin` before committing to a long setup.
- **Always check RAM specs before renting**: both GPU VRAM and system RAM. CPU optimizer offloading, large batch sizes, and gradient accumulation all consume system RAM. 32GB instances can OOM silently during gradient computation. Example: GRPO training with batch 64 and CPU offloading needs >=64GB system RAM.
- Always check the instance has enough disk for model weights + checkpoints before starting.

## Setup Checklist
Before launching any training:
1. Test internet speed
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
- Prefer a **KISS local watcher** over complex remote watchdog loops:
  - Run one local blocking script that exits on: timeout, completion, or crashed remote session/process.
  - Use a sparse poll interval for trusted long runs (e.g. 30-90 min, even 1h+) to avoid noisy monitoring.
  - Avoid auto-restart loops on the remote instance. If a run dies, inspect cause first, then relaunch intentionally.
  - Keep monitoring logic local so no extra secrets/config end up on the Vast box.
  - Generic snippet pattern (fill in project path per run context):
    `TIMEOUT_SECS=<timeout_s> CHECK_EVERY=<poll_s> bash <project_path>/scripts/local/wait_or_crash.sh`

## Cost Awareness
- Don't leave instances running idle. If training is done or stuck, stop the instance.
- Check `vast show instances` periodically.

## SSH & Connectivity
- Keep SSH config for vast instances in `~/.ssh/config` so reconnecting is fast.
- API key: `$VAST_API_KEY` in bashrc -- not in repos.
