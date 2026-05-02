# AI Agent Learnings - Status

## Current State
`main` contains the active-dispatcher orchestration update. `codex_dispatch` now starts an active orchestration thread that reconciles the Agent Context Pack, inspects active runs/interruption intent, updates task surfaces (`STATUS.md`, optional JJ mirrors, and targeted inboxes), and does at least one meaningful routing/work slice itself before stopping. `codex_spawn` children receive a bounded fresh Agent Context Pack and preserve caller ancestry.

## Active Goals
- [ ] Keep Agent Context Pack size useful and bounded; monitor real active-agent dispatch prompts.
- [ ] Validate the active-dispatcher/JJ/task-surface pattern on the next RepoProver-style coding task.

## TODO Plan
- [ ] Use the repo context check-in skill for human-facing status snapshots when asked to check/watch a repo; treat the generated Agent Context Pack as the shared source-of-truth view.

## Blockers
- None for the focused active-dispatcher update. JJ remains optional: this repo has colocated `.jj`, but normal Git/Codex workflows must not depend on JJ until the pattern proves useful.

## Recent Results
- Real dispatcher run `d392927` treated the architecture correction as dispatcher-owned first-slice work, changed `scripts/branch_commands.sh`, `scripts/agent_context.sh`, `scripts/codex_wrap.py`, and wrapper tests, and did not spawn a ceremony-only child.
- Focused validation passed after the dispatcher changes: `python3 -m py_compile scripts/codex_wrap.py`, `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`, and `bash scripts/test_agent_context/test_agent_context.sh scripts/agent_context.sh`.
- Repo check-in smoke test generated `/tmp/ai-agent-learnings-checkin.md` and `/tmp/repoprover-checkin.md`; `ai-agent-learnings` was clean/synced and RepoProver had existing local work ahead of origin.

## Agent Notes
- Context pack order is now more agent-friendly: header/status, active pointers, live wrapper agents, optional JJ task surface, compact active profile summaries/inboxes, current active transcript excerpts, audit trail. Finished profile prompts/transcripts are not replayed when no active agent exists.
- Tool-call logs now include compact UTC time, Unix epoch, caller, item/tool/status, args hash/summary, and output byte count.
