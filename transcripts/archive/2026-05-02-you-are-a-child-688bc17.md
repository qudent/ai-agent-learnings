

## 2026-05-02T20:18:38+0000 codex:you-are-a-child-688bc17

I’ll ground this in the branch-local state first, then make the narrow wrapper/docs/test changes and commit them. I’ll avoid external provider calls and keep validation to local wrapper tests.

## 2026-05-02T20:18:49+0000 codex:you-are-a-child-688bc17

I’ve confirmed the stale classification is in the dispatch prompt, README, and tests, and the branch already has wrapper transcript artifacts staged from this child run. I’m reading the exact surrounding text now so the edits stay small and don’t disturb unrelated wrapper behavior.

## 2026-05-02T20:19:27+0000 codex:you-are-a-child-688bc17

The change is generalizable: it updates the reusable dispatcher contract, not a one-off project runbook. I’m going to revise the dispatcher prompt, mirror that policy in the canonical docs/skill text, and make the wrapper test assert the allowed classification line and delegation contract positively.

## 2026-05-02T20:21:00+0000 codex:you-are-a-child-688bc17

The prompt/docs no longer mention `direct-implementation` or `parallel-dispatch`; they now use `delegated-implementation` and explicitly require task-surface updates plus `codex_spawn` for broad work. I’m running the focused wrapper suite now, with a compile check because the wrapper skill lists it as cheap validation.

## 2026-05-02T20:21:05+0000 codex:you-are-a-child-688bc17

The wrapper test exposed a local harness issue under dispatcher ancestry: `CODEX_WRAP_CALLED_BY` is inherited into the temp repo, where that commit does not exist, so the fake run exits before reaching the dispatch contract assertions. I’m going to isolate the test environment by clearing that inherited caller in the test harness, then rerun.
