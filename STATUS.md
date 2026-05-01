# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch,
`chatgit`/`codex_web.py` for the local web UI, and optional `jj_project.sh`
helpers now that `jj` is installed.


name@theserver:~/repos/ai-agent-learnings$ chatgit
chatgit: http://127.0.0.1:6174/home/name/ai-agent-learnings
codex-web-interface: http://127.0.0.1:6174/home/name/ai-agent-learnings
repo: /home/name/repos/ai-agent-learnings
wrapper: /home/name/repos/ai-agent-learnings/scripts/codex_wrap.sh
it still gives wrong paths! did you read and process/dispatch my feedback?
the dispatching state should be in STATUS.md i think. answer here

## Active Goals
- [x] Make `chatgit` graceful when port 6174 is already running.
- [x] Replace browser `?repo=` links with path-style repo URLs such as
  `http://127.0.0.1:6174/home/name/repoprover`; do not keep browser query
  compatibility.
- [x] Add tested web dispatch support and keep dispatch orchestration in
  `branch_commands.sh`.
- [x] Fix dispatch/run UI follow-ups: no active-run warning for Dispatch,
  run-history disclosure clicks stay expanded, and dispatch prompts list live
  run-start/process evidence.
- [x] Install `jj` and smoke-test `jj_project.sh`.
- [x] Preserve useful `dev` content before branch cleanup.
- [ ] Push `main`, remove stale local/remote branches, and restart live
  `chatgit-main` on port 6174.

## TODO Plan
- [ ] Push `main` to `origin/main`.
- [ ] Remove stale local worktrees/branches: `dev`,
  `chat-ugly-my-point-should-selectable-visible-url-d6224ce`, and temporary
  `dispatch-*` branches.
- [ ] Delete stale remote branches after `main` is safely pushed:
  `origin/dev` and `origin/chat-ugly-my-point-should-selectable-visible-url-d6224ce`.
- [ ] Restart the live port-6174 server from updated `main`.

## Blockers
- None.

## Recent Results
- `scripts/chatgit` now prints path-style URLs, exits cleanly if a chatgit
  server already responds on the chosen port, and no longer crashes with
  `OSError: [Errno 98] Address already in use`.
- `scripts/codex_web.py` accepts path-style browser routes, ignores `?repo=`
  browser selection, removes the old header/Sync controls, and updates the URL
  when selecting worktrees.
- Web dispatch now sources `branch_commands.sh`, exposes a Dispatch button,
  bypasses the direct-action active-run warning, and starts immediately so the
  dispatch prompt can decide whether to continue, block, abort, or create new
  work.
- Dispatch context now includes recent run-start marker summaries plus a live
  Codex-related process table for PID/cwd cross-checking.
- Preserved useful `dev` artifacts on `main`: `frontend-design.md` and
  `scripts/codex-wrap/SKILL.md`, with README links and current repo paths.
- Installed `jj 0.40.0` to `~/.local/bin`; `jj_project.sh` works after
  colocated repo init, but `jj git init --colocate` cannot be run inside a Git
  linked worktree.

## Agent Notes
- Verification passed:
  `PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile scripts/codex_web.py`,
  `PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`,
  and `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`.
- Branch audit: `dev` and `origin/dev` are now stale after preserving
  `frontend-design.md` and `scripts/codex-wrap/SKILL.md`; the
  `chat-ugly...` branch/remote are stale after porting dispatch, no-query URL,
  and header removal behavior to `main`.
- The active dispatcher started by `ec614fa` stalled in analysis and was aborted
  with `e3c7993`; the concrete fixes were implemented directly on `main`.
- Stable repo instructions belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic
  learnings.
