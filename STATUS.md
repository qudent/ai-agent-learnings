# AI Agent Learnings - Status

## Current State
Branch `dev/context-jj-dispatch` is complete, locally validated, and pushed to `origin/dev/context-jj-dispatch`. It adds branch-local Agent Context Packs, compact parent/child audit metadata, current-only `STATUS.md` pruning, optional Jujutsu task mirrors, dispatcher guidance through `codex_dispatch`/`codex_spawn`, and bounded per-agent tool-call metadata logs. The branch is ready for review/fast-forward merge; do not merge `main` here.

## Active Goals
- [ ] Keep merge to `main` as a separate reviewed step.

## TODO Plan
- [ ] Review and fast-forward merge this branch separately.

## Blockers
- None.

## Recent Results
- Validation passed for Python compile checks, shell syntax checks, agent context tests, jj project tests, codex wrapper tests, and codex web tests.
- Smoke output in `/tmp/context-pack-smoke.md` and `/tmp/audit-smoke.md` surfaces current branch status and audit metadata while eliding old `[codex]` assistant bodies and run-start prompts.
- Tool-call logging is intentionally summary-only: tracked rows include tool metadata, compact args summary/hash, and output byte counts; raw outputs stay in ignored wrapper logs.

## Agent Notes
- `STATUS.md` remains current-only; finished checklist items are deleted and durable history stays in Git, transcript archives, agent profiles/inboxes, and tool-call summaries.
- A stale test `codex_web.py` process on port `6192` from another temp repo was killed before the web suite rerun; the persistent real ChatGit server on port `6174` was left alone.
