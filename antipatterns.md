# Antipatterns -- Proactively Remind the User

These are recurring mistakes from past sessions. Flag them immediately, before they burn time or spend.

## 1. Over-verifying locally before deploying

**Pattern**: building large local validation trees for failures that show up quickly on real hardware.

**Do instead**:
- launch a real probe early
- verify on the real environment in the first minutes
- reserve local deep checks for subtle correctness issues

## 2. No feedback loop on long-running processes

**Pattern**: starting multi-hour runs with no early-kill criteria.

**Do instead**:
- log metrics from the start
- define abort conditions before launch
- check early milestones in the first 5-15 minutes

## 3. Over-polling stable long runs

**Pattern**: checking every 1-2 minutes for hours, creating token noise without decisions.

**Do instead**:
- use adaptive cadence:
  - dense early checks while risk is high
  - sparse milestone checks once stable
- increase check frequency only when alert triggers fire

**Trigger question**: "Are these checks changing decisions, or just burning tokens?"

## 4. Detached watcher with no consumer

**Pattern**: running watchers that no one reads and assuming automatic wake-up.

**Do instead**:
- use one blocking watcher that returns on `ALERT|CRASH|DONE|TIMEOUT`
- avoid parallel watcher stacks

## 5. Parallel agents with weak coordination

**Pattern**: multiple agents with unclear done criteria and output locations.

**Do instead**:
- explicit task + output path + done signal per agent
- keep project `STATUS.md` current

## 6. Tool friction without switching

**Pattern**: prolonged workarounds for a failing tool.

**Do instead**:
- if blocked ~10 minutes without progress, switch tools

## 7. Vague spec, repeated redesign

**Pattern**: coding with ambiguous outputs and redesigning repeatedly.

**Do instead**:
- write concrete I/O examples before implementation
