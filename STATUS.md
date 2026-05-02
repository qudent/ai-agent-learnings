# AI Agent Learnings - Status

## Current State
`main` contains the context-pack refactor and the dispatcher-first routing update. Future Hermes/Codex coding tasks that need non-trivial repository work should use `codex_dispatch` by default; dispatchers reconcile the Agent Context Pack, update task routing surfaces (`STATUS.md` and targeted `agents/<slug>/inbox.md` when appropriate), and delegate broad implementation through `codex_spawn` children. ChatGit is running on port `6174` and sources the current wrapper/branch helper files for dispatch-mode executions.

## Active Goals
- [ ] Keep Agent Context Pack size useful and bounded; monitor real active-agent dispatch prompts.
- [ ] Audit cross-repo wrapper artifacts and stale surfaces so RepoProver-style coding work uses the dispatcher path when available.

## TODO Plan
- [ ] Push the dispatcher-first contract update after focused wrapper tests pass.
- [ ] Summarize cross-repo findings for the current Hermes thread: `ai-agent-learnings` owns the wrapper/context code; `repoprover` has wrapper-generated transcript artifacts but no local wrapper scripts; `endepromotion` only had unrelated recent commits.

## Blockers
- None for the dispatcher contract update. Empirical performance still needs more real multi-agent runs with active transcript/profile state.

## Recent Results
- A real `codex_dispatch` run from Hermes created dispatcher run `fb53c6b`, spawned child branch `work-99f3c2f-20260502-201821-0`, and child commit `c226410 Update Codex dispatcher routing contract` updated the stale `direct-implementation` surface.
- Current active-agent context pack in `ai-agent-learnings` measured 250 lines / 19,097 bytes; RepoProver cross-repo context pack measured 192 lines / 11,479 bytes using the central `agent_context.sh`.
- Cross-repo scan found 45 git repos and 3 relevant/recent repos: `ai-agent-learnings`, `repoprover`, and unrelated recent `endepromotion`.

## Agent Notes
- Hermes itself is not automatically a Codex wrapper execution. The durable fix is instruction-level: this repo's global `AGENTS.md` now says non-trivial Hermes/Codex coding tasks should route through `codex_dispatch` by default when the wrapper is available.
- The prior dispatcher prompt was stale: it exposed `direct-implementation` and `parallel-dispatch`. The updated contract classifies only `status-only`, `trivial-chat`, `delegated-implementation`, `cleanup`, or `blocked`.
