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

## 8. Weak versioning discipline on learnings

**Pattern**: policy changed but not committed/pushed.

**Do instead**:
- rewrite relevant learnings files
- update learnings `README.md` and `STATUS.md` when workflow meaningfully changes
- commit and push in the same session
