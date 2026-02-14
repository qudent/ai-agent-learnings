# ML Experiment Learnings

## The core problem: chaos, not wrong strategy

Hindsight makes it look like "we should have picked the right algorithm first." That's wrong. There is often no principled reason to prefer one search/optimization strategy over another before trying it. The real problem is:

- **No structure around experiments** -- trying things ad-hoc without tracking what was tried, what the result was, and what to try next.
- **No kill criteria** -- letting something run for hours without a threshold for "this isn't working, move on."
- **No parallel comparison** -- running one approach at a time sequentially instead of racing 2-3 in parallel with shared evaluation.

## What to do instead

### Before starting
- Write a 1-paragraph hypothesis: "I expect X because Y. I will measure Z."
- Define kill criteria: "If metric hasn't improved by N steps, stop."
- Decide upfront what 2-3 approaches to race in parallel.

### During
- Log everything to files, not just stdout.
- Use the project's STATUS.md to track: which experiments are running, what the current best result is, what's next.
- Check in at defined intervals, not ad-hoc.
- **Watch the first 2-5 minutes on the real instance** -- don't spend time building local validation that duplicates what you'd see immediately on the real hardware.

### After
- Write a 2-sentence result in STATUS.md: "Approach X got metric Y. Next: try Z."
- Don't delete failed experiments -- note what didn't work and why, so it doesn't get re-tried.

## GRPO-Zero specific
- "Rate 0" / no learning signal: watch the first 50 steps on the real instance. If reward is flat, investigate on the live environment -- don't burn time building local validation harnesses.
- Fork-race: metric filtering matters -- make sure you're not averaging over branch-B samples that pollute the signal.
- Config proliferation: too many config files -- config.yaml, config_24GB.yaml, config_fork.yaml, config_vast_*.yaml. Consolidate or use overrides.
- **The real risk is subtle bugs** (wrong convergence, not no convergence). Fast failure is cheap; wrong learning is expensive. Focus verification effort on output quality, not "does it run."

## Jane puzzle specific
- CPU-bound permutation search was the bottleneck, not the algorithm choice.
- Should have profiled first to see that ~1 perm/sec was the constraint, then focused on making evaluation faster before trying fancier search.
- Renting a GPU helped but only after the evaluation was vectorized.
