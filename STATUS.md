# AI Agent Learnings - Status

## Current State
`main` contains the context-pack refactor and current status refresh. `codex_dispatch` now injects `scripts/agent_context.sh context --limit 80`, and the Codex wrapper writes branch-local transcript/profile/inbox/tool-call files. ChatGit is running on port `6174` and sources the current wrapper/branch helper files for each run, so dispatch-mode web executions will use the context-pack path.

## Active Goals
- [ ] Keep Agent Context Pack size useful and bounded; monitor real dispatch prompts once active agents exist.
- [ ] Verify performance impact empirically on the next few dispatcher runs rather than assuming it from structure alone.

## TODO Plan
- [ ] After the next `codex_dispatch` run, inspect its start prompt/log and compare task routing quality, context length, and whether stale transcript replay was avoided.

## Blockers
- No active Codex agents or `agents/`/`transcripts/` files exist in the repo right now, so the current context-pack output only exercises the idle/no-active-agent path.

## Recent Results
- Current idle Agent Context Pack is 76 lines / 3,582 bytes / roughly 900 tokens, mostly current `STATUS.md` plus compact recent commit audit.
- Last-hour local work updated global guidance in `AGENTS.md`: `4d49e81` codified voice/action-continuation behavior, and `ee88e26` added exponential-backoff guidance for process waits.
- Process check shows ChatGit (`scripts/codex_web.py`) still running on port `6174` and Hermes gateway running since `2026-05-02 19:33:56`; no live Codex wrapper processes are currently active.

## Agent Notes
- The context-pack design likely improves dispatcher performance for multi-agent routing by replacing stale full marker prompt replay with current status, active transcript pointers, recent tails, and parent/child audit edges. Risk is prompt bloat once many agents/transcripts exist; current caps (`--limit 80`, first 5 profiles when idle, audit 30) make the idle path small, but real active-agent packs still need measured follow-up.
- Hermes itself is not a Codex wrapper execution. This Discord/Hermes session has loaded the updated repo instructions from `AGENTS.md`, but only Codex runs launched through `codex_dispatch`/ChatGit dispatch mode receive the generated Agent Context Pack.
