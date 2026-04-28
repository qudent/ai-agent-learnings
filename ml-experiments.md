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

# Antipatterns -- Proactively Remind the User

Flag these immediately; do not wait until they consume hours or budget.

## 1. Over-verifying locally before real run

**Pattern**: long local validation for issues that would appear in first minutes on real hardware.

**Do instead**:
- launch real probe quickly
- verify on real metrics early
- keep local deep checks for subtle correctness only

## 2. No explicit failure loop for long runs

**Pattern**: start long training without retry budget, auto-fix policy, or terminal states.

**Do instead**:
- run under supervisor with bounded retries
- define `done` and `failed` semantics
- define teardown behavior

## 3. Over-polling stable runs

**Pattern**: frequent checks for hours with no decision impact.

**Do instead**:
- adaptive cadence:
  - dense early checks
  - sparse stable checks
  - dense only on alert

**Trigger question**: "Will this check change an action, or only burn tokens?"

## 4. Stall detection without GPU context

**Pattern**: declaring stall from log silence alone, killing healthy training.

**Do instead**:
- require both stale heartbeat and low GPU activity before stall recovery
- use one safe recovery action, then hand back to supervisor retry logic

## 5. Early-stop policy confused with crashes

**Pattern**: treating deliberate early-stop behavior as runtime instability.

**Do instead**:
- inspect stop criteria first (`min_steps`, `patience`, `min_delta`)
- tune stop policy to objective (probe vs comprehensive finetune)

## 6. Detached watcher with no consumer

**Pattern**: background watcher output is never consumed.

**Do instead**:
- one canonical watcher with actionable state output
- no redundant watcher layers

## 7. Tool friction without switching

**Pattern**: extended workaround loops on broken tooling.

**Do instead**:
- switch tools if blocked without forward progress

## 8. Destroying ephemeral instances before verifying artifact persistence

**Pattern**: training finishes, agent destroys GPU instance immediately — but the checkpoint upload failed so the only copy was on the destroyed instance.

**Do instead**: see pre-destroy checklist in `vast-ai.md`. Always verify artifacts exist at their remote destination before destroying.

**Trigger question**: "Can I prove the checkpoint exists somewhere that will survive instance destruction?"
