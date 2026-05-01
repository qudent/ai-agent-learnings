# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch,
`chatgit`/`codex_web.py` for the local web UI, `codex_sync_push` for explicit
fetch/rebase/push cleanup, and optional `jj_project.sh` helpers.

Current focus: tighten the Codex dispatch/orchestration contract so it clearly
names the callable helper commands, launches implementation children detached
from the dispatcher, and avoids recursively embedding old dispatcher prompts in
new dispatch context.

also (please start side process for this if relevant): chat-ok-codex-process-disappeared-list-active-869940b ← main
...
chat-ok-codex-process-d...tive-869940b
parent main @ 869940b18c7c
agent active 705ba98
1 queued · no recent runs
ok but the codex process disappeared from the list of active processes in my web interface before i stopped. also, is higher paral
queued branch
Copy prompt

wait, what are the remains of the "queuing" behavior in the web interface? i clicked "create" child branch, and the output was "queued". the point is supposed to be that in the child branch, you can work in parallel. why queued?

## Active Goals
- [x] Answer whether the previous duplicate-context fix actually landed.
- [x] Add an explicit detached child-agent launcher for dispatch agents.
- [x] Compact dispatch context so old dispatcher prompts and process command
  lines are elided.
- [x] Document the dispatch command surface in README and the wrapper skill.
- [x] Validate wrapper and web dispatch behavior.

## TODO Plan
- [ ] Push `main` after the active run reaches a push-safe point, or use a
  fetch-verified direct push if no remote divergence appears.

## Blockers
- `codex_sync_push` intentionally refuses while this local Codex run is active.
  A direct `git fetch` has already shown `main` is only ahead of `origin/main`,
  not behind.

## Recent Results
- The prior worker branch `work-75de1b8-20260501-151455-0` had only wrapper
  marker commits and no implementation diff; it was removed after this fix
  landed on `main`.
- Added `codex_spawn`, which runs supported `codex_*` child commands through
  `setsid` with stdin closed and output logged under `.git/codex-wrap/dispatch/`.
  Children still use the normal wrapper, so ChatGit sees their marker commits,
  pid/cwd metadata, and transcripts.
- Updated `codex_dispatch` to give a command quick reference, instruct
  dispatchers to use `codex_spawn`, and compact recent commits, branch subjects,
  run-start markers, and process listings so recursive dispatcher prompt text is
  not copied into the next dispatcher prompt.

## Agent Notes
- Validation passed:
  `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile scripts/codex_wrap.py scripts/codex_web.py`,
  `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`,
  and `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- The first wrapper test run hit a pre-existing stderr banner race and passed on
  rerun; no code path from this dispatch fix depends on that banner text.
