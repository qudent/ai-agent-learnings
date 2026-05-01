# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch, and
`chatgit`/`codex_web.py` for the small local web UI.

## Active Goals
- [x] Replace timestamp-heavy `codex-web-interface-*` auto branch names with
  shorter prompt-derived chatgit branch names.
- [x] Rebase local `main` onto `origin/main` so it is ahead-only before push.
- [ ] Push `main` after the branch-name fix and report exact branch state.
- [ ] Decide whether to merge, preserve, or delete local `dev` and
  `origin/dev`; local `dev` is still checked out in its own worktree.
- [ ] Install `jj` before trying the Jujutsu helper on a real task.

## TODO Plan
- [x] Patch `scripts/codex_web.py` branch creation.
- [x] Add shell behavior coverage for prompt-derived names and duplicate-name
  suffixing.
- [x] Run the chatgit behavior suite.
- [x] Restart the live `chatgit-main` server on port 6174.
- [ ] Push `main`.

## Blockers
- Automatic 30-minute `[status]` commits are not implemented yet; only the
  manual `codex_status` helper and dispatch prompt contract exist.
- `jj` is not installed yet.

## Recent Results
- Changed branch mode so new chatgit worktrees use names like
  `chat-branch-test-abc1234`; repeated same-prompt branches use `-1`, `-2`,
  etc. instead of timestamp/nanosecond identifiers.
- Updated `scripts/test_codex_web/WEB_BEHAVIOR.md` and
  `scripts/test_codex_web/test_codex_web.sh` to reject
  `codex-web-interface-*` branch names and cover duplicate prompt suffixes.
- Verified with `python3 -m py_compile scripts/codex_web.py` and
  `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- Local `main` was rebased onto `origin/main`; current divergence is ahead-only.

## Agent Notes
- The previous divergence pattern came from local wrapper/status commits made
  before or during push while `origin/main` already had equivalent or nearby
  commits. Future workflow should fetch/rebase before committing/pushing UI
  helper changes, then push once from an ahead-only branch.
- `codex_dispatch` lives in `scripts/branch_commands.sh`, not
  `codex_wrap.py`, so branch/worktree orchestration stays outside the low-level
  wrapper.
- Stable repo instructions belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic
  learnings.
