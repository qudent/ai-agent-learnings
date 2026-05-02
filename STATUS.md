# AI Agent Learnings - Status

## Current State
This child worktree updates the Codex dispatcher/wrapper contract so future Hermes/Codex coding tasks default through `codex_dispatch` for non-trivial repo work. The dispatcher prompt now classifies implementation as `delegated-implementation` and requires task-surface updates plus `codex_spawn` children for broad work.

## Active Goals
- [ ] Review and merge the child branch `work-99f3c2f-20260502-201821-0` back to `main`.

## TODO Plan
- [ ] Parent dispatcher/human should inspect the committed diff and merge if the dispatcher contract change is acceptable.

## Blockers
- None.

## Recent Results
- Updated `AGENTS.md`, `README.md`, `scripts/branch_commands.sh`, and `scripts/codex-wrap/SKILL.md` to make dispatcher-first routing the default for non-trivial Hermes/Codex coding work.
- Updated `scripts/test_codex_wrap/test_codex_wrap.sh` to assert the exact dispatch classification/delegation prompt shape, unset inherited dispatcher caller metadata in temp repos, and make `contains`/`not_contains` handle patterns beginning with `-`.
- Validation passed: `python3 -m py_compile scripts/codex_wrap.py`; `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`.

## Agent Notes
- No paid external APIs were run; wrapper tests use the existing fake Codex binary.
