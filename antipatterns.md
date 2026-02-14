# Antipatterns -- Proactively Remind the User

These are recurring mistakes from past sessions. **When you notice the user or an agent falling into one of these patterns, flag it immediately** -- don't wait until it has already wasted time.

## 1. Over-verifying locally before deploying

**Pattern**: Building elaborate local smoke tests and validation steps that duplicate what you'd see in 2 minutes on the real environment. The verification itself becomes a rabbit hole.

**Examples from history**:
- Planned multi-step local reward function validation + short training run + config checks before deploying to Vast.ai. Would have added hours of local work when a failed Vast.ai run shows the same signal in minutes.
- Local CPU smoke tests that don't match GPU behavior anyway.

**What to do instead**: Deploy to the real environment and watch the first few minutes. If reward is 0 or loss doesn't move by step 50, you know immediately and can fix on the live instance. Reserve local verification for things that are *hard to see* in production (subtle correctness bugs, wrong learning signal that looks like convergence).

**Proactive reminder trigger**: When an agent proposes multiple pre-deployment validation steps, ask: "Would we see this failure in the first 2 minutes on the real instance anyway?"

## 2. No feedback loop on long-running processes

**Pattern**: Kicking off a multi-hour process -- training run, search, build -- with no way to tell if it's working until it finishes.

**Examples from history**:
- Countdown task: "it takes many hours to see if it is getting somewhere"
- No streaming metrics, no early-stopping criteria, no intermediate checkpoints

**What to do instead**: Before starting any process that takes >10 minutes:
- Add logging every N steps to a file or stdout
- Define an early-abort condition -- "if metric X hasn't moved by step Y, stop"
- Check metrics within the first few minutes on the real instance

**Proactive reminder trigger**: When launching a training run or long computation, ask: "What metric will we check, how often, and what's the kill threshold?"

## 3. Parallel agents with no coordination structure

**Pattern**: Spawning multiple tmux agents without clear completion criteria, output locations, or status tracking. Then losing visibility and doing "check in" rounds that waste time.

**Examples from history**:
- Multiple "check in on vast" queries with unclear responses
- Agents doing overlapping or conflicting work
- No single source of truth for what's running and what's done

**What to do instead**:
- Each dispatched agent gets: explicit goal, where to write output, a done-signal
- Use the project's STATUS.md as the coordination point
- Batch-check all sessions with the tmux capture-pane loop, don't check one by one

**Proactive reminder trigger**: When spawning 2+ parallel agents, ask: "Where will each agent write its result, and how will we know it's done?"

## 4. Tool friction -- adapting to a broken tool instead of switching

**Pattern**: Spending hours working around a tool's limitations instead of just using a different tool.

**Examples from history**:
- Claude Code `-p` flag for tmux integration -- multiple sessions debugging CLI flags
- PDF processing -- built extraction pipeline when just using a different tool would've worked

**What to do instead**: If a tool doesn't do what you need within 10 minutes, switch tools. Don't build adapters or workarounds.

## 5. Redesigning mid-project because the spec was vague

**Pattern**: Starting implementation with a fuzzy idea of what the output should look like, then redesigning 2-3 times when the result doesn't match expectations.

**Examples from history**:
- Pilot "display" field -- should it show assistant response or JSON? Redesigned 3 times.
- Context management -- append+truncate vs. fresh rewrite changed mid-project.

**What to do instead**: Before coding, write 2-3 concrete input/output examples. "Given X, the system should return Y." If you can't write the examples, the spec isn't ready.

## 6. Detached watcher with no consumer

**Pattern**: Starting a watcher in tmux and assuming it will wake or notify the agent automatically.

**Why this fails**:
- If no one is reading the watcher output, it provides no real feedback loop.
- It creates false confidence while still requiring manual check-ins.

**What to do instead**:
- If unattended: run one blocking local wait command that returns on crash/completion/timeout.
- If attended: do milestone checks at meaningful points instead of frequent polling.
- Do not combine detached watcher + manual polling unless there is a real alert channel wired.

**Proactive reminder trigger**: When someone proposes "let's run a watcher in tmux," ask: "Who or what is consuming that output, and how does it trigger action?"
