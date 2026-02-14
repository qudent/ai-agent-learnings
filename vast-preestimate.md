# Vast.ai Pre-Estimation Playbook

Use this file for pre-run planning. It is intentionally rules-based (manual one-off calculations), not a rigid script.

## Goal
Before renting a GPU, produce a short pre-estimate that answers:
- Which hardware options fit memory and stability constraints.
- Expected training time and cost range per option.
- Setup/debug overhead risk and whether expensive hardware is justified yet.
- Which low-effort optimizations are worth doing first.

## Required Output
Before launch, agents must publish one option table with:
- `GPU option`, `$/h`, `VRAM`, `CPU RAM`, `TFLOPS`, `HBM BW`
- `pred tokens/s` or `pred step/s`
- `time (opt/base/pess)`
- `cost (opt/base/pess)`
- `setup/debug tax %`
- `optimization effort` (`low|med|high`)
- `major risks`

## 0) Gather Inputs
Collect these first.

From training config:
- `params_total`
- `params_trainable`
- precision (`bf16`, `fp16`, `fp32`)
- context length, micro-batch, grad accumulation, global batch
- target budget (`target_steps` or `target_tokens` or `epochs`)

From Vast offers (CLI fields):
- `dph_total`
- `total_flops`
- `gpu_mem_bw`
- `gpu_ram`
- `cpu_ram`
- `inet_down`, `inet_up`
- reliability fields (`reliability2` / equivalent)

From prior runs (if any):
- observed `tokens/s` or `step time`
- average GPU utilization over a window
- observed peak VRAM and RAM
- setup/debug time actually spent

## 1) Hard Fit Checks (must pass)

### 1.1 GPU memory fit
Use these conservative rules:
- Mixed precision full fine-tuning with AdamW is often around `18 bytes/parameter` for model+grads+optimizer states (rule of thumb).
- Add activation and fragmentation headroom explicitly.

Manual estimate:
- `model_state_bytes ~= 18 * params_trainable` for full FT AdamW mixed precision.
- `frozen_weight_bytes ~= bytes_per_weight * (params_total - params_trainable)` for PEFT/LoRA style setups.
- `total_vram_bytes ~= model_state_bytes + frozen_weight_bytes + activations_bytes + kv_or_temp_bytes`.
- `required_vram_gb ~= 1.2 * total_vram_bytes / 1e9`.

Pass criterion:
- Prefer `required_vram_gb <= 0.8 * gpu_ram_gb` before launch.
- If `0.8-0.9`, treat as high OOM risk and reduce batch/seq first.

### 1.2 System RAM fit
Especially critical when optimizer offload is enabled.

Manual estimate:
- Adam moments offloaded to CPU are roughly `8 bytes/parameter` for trainable params, plus framework overhead.
- `required_cpu_ram_gb ~= 1.3 * (cpu_offload_bytes + dataloader_bytes + os_and_cache_bytes) / 1e9`.

Pass criterion:
- If estimate is close to machine limit, do not launch full run.
- Solve with smaller batch/seq, no offload, or bigger host RAM.

### 1.3 Disk and network fit
- `required_disk = model + data + (2 * largest_checkpoint) + logs + temp`, then add 30% headroom.
- Reject or downgrade confidence for low `inet_down` / unstable network; bad bandwidth can dominate setup time.

## 2) Throughput Prediction
Use both compute and memory-bandwidth signals, then take the conservative bound.

### 2.1 If you have a baseline run
For baseline hardware `b` and candidate `i`:
- `flops_ratio_i = total_flops_i / total_flops_b`
- `bw_ratio_i = gpu_mem_bw_i / gpu_mem_bw_b`
- `scale_ratio_i = min(flops_ratio_i, bw_ratio_i)`
- `tokens_s_pred_i = tokens_s_base * scale_ratio_i * efficiency_factor`

Choose `efficiency_factor` conservatively:
- `0.9` same architecture and stable stack
- `0.7` architecture/runtime changed
- `0.5` first attempt with multi-GPU or major stack changes

### 2.2 If you have no baseline
Do a short calibration on a cheap fitting GPU first (50-200 steps), then scale with the formula above.

If you still need a cold estimate:
- `tokens_s_upper_compute ~= (total_flops * MFU_assumed) / flops_per_token`
- For dense transformer training, `flops_per_token ~= 6 * params_trainable` is a rough first-pass rule.
- Use conservative `MFU_assumed` values: `0.20` (untuned), `0.30` (normal), `0.40` (well-tuned).

Treat cold estimates as low confidence until probe data exists.

## 3) Time and Cost Model
Convert throughput to schedule and spend.

- `train_hours = target_tokens / (tokens_s_pred * 3600)`
- `wall_hours = setup_debug_hours + train_hours + eval_ckpt_overhead_hours`
- `cost_usd = wall_hours * dph_total`

Always produce 3 scenarios:
- optimistic: `tokens_s * 1.2`
- base: `tokens_s * 1.0`
- pessimistic: `tokens_s * 0.6`

### Setup/debug tax
- `setup_debug_tax = setup_debug_hours / wall_hours`
- If `setup_debug_tax > 25%`, you are not ready for expensive hardware.

Decision rule:
- If `expensive_rate * expected_debug_hours` is larger than a cheap probe + migration cost, debug on cheap hardware first and only then move up.

## 4) Optimization Menu (low-complexity first)
Use this order unless there is a specific reason not to.

1. Confirm mixed precision (`bf16`/`fp16`) and sane batch sizing.
2. Increase micro-batch until VRAM reaches a safe high-util zone (without OOM).
3. Tune data input pipeline (`num_workers`, `pin_memory=True`) so GPU is not waiting.
4. Reduce logging overhead and expensive per-step callbacks.
5. Use `torch.no_grad()` / inference mode for eval-only paths.
6. Consider `torch.compile` after baseline works (can improve speed, but validate correctness and startup overhead).
7. Use gradient checkpointing only when memory-bound; expect slower runtime (often around 20% slower) in exchange for lower memory.
8. Avoid heavyweight distributed stacks on single-GPU runs unless needed (setup friction and failure surface increase).

## 5) Runtime Validation Loop (10-minute cadence)
Prediction must be validated early against reality.

Telemetry capture commands:
- `nvidia-smi --query-gpu=timestamp,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw --format=csv -l 10`
- `nvidia-smi dmon -s u -d 10`

Every 10 minutes, record:
- average GPU utilization
- average memory utilization and peak memory used
- median tokens/s or step time from training logs
- epoch ETA trend (or step ETA trend)

Contradiction triggers (act immediately):
- Actual throughput `< 70%` of predicted for 2 consecutive windows.
- GPU utilization `< 60%` while job is active.
- Memory usage `> 92%` sustained (OOM risk).
- No meaningful metric movement by pre-defined early checkpoint.

Action on contradiction:
- Pause expensive run.
- Reclassify bottleneck (`compute`, `memory`, `input`, `sync`, `logging`).
- Update pre-estimate with actual data before relaunch.

## 6) Transcript-Derived Blockers (Recent)
From local Codex/Claude transcripts, recurring blockers were:
- Expensive runs started without a quantitative pre-estimate.
- Repeated uncertainty about whether training was still running (missing heartbeat/summary loop).
- tmux dispatch friction (`Enter` swallowed) causing agents that looked active but were idle.
- RAM/VRAM surprises with Adam/offload choices.
- Setup/dependency friction (including unnecessary stack complexity) consuming high-cost GPU time.
- Weak expected-vs-actual checks until too late in the run.

Use this playbook specifically to prevent those failures.

## 7) Agent Pre-Run Checklist
Before launch, agent must state:
1. Memory fit numbers (GPU RAM + CPU RAM) and pass/fail.
2. Throughput prediction method (baseline-scaled or cold estimate).
3. Time and cost table with optimistic/base/pessimistic ranges.
4. Setup/debug tax estimate and whether expensive hardware is justified now.
5. First 10-minute validation gates and abort thresholds.

If any item is missing, do not launch a long expensive run.

## Sources (primary docs)
- Vast CLI offer/search fields: https://docs.vast.ai/documentation/cli/commands#search-offers-syntax
- PyTorch tuning guide: https://docs.pytorch.org/tutorials/recipes/recipes/tuning_guide.html
- NVIDIA `nvidia-smi` reference: https://docs.nvidia.com/deploy/nvidia-smi/index.html
- Hugging Face performance/memory anatomy: https://huggingface.co/docs/transformers/v4.13.0/performance
- Hugging Face gradient checkpointing tradeoff: https://huggingface.co/docs/transformers/v4.19.2/en/performance

Accessed: 2026-02-14.
