# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents. `AGENTS.md` is the canonical global instruction source, global agent config files symlink to it, and a KISS `@codex`/`@claude` dispatcher now lives under `scripts/`.

## Human Prompts
- None active.@codex trying this, i see the urge to give feedback to you while i see you working. there should be a way to prevent triggering another dispatch then, any idea how that is possible? maybe the model can become one agent per branch and codex resume? or we write into that branch? think of something. but also it doesn't have to be too complicated for now. maybe its enough if, if i type things into the codex chatbox as feedback, _you_ make sure it gets logged in the repo

## Active Goals
- [x] Move canonical global instructions into `~/learnings/AGENTS.md`.
- [x] Fold agent coordination guidance into `AGENTS.md`.
- [x] Replace global `AGENTS.md`/`CLAUDE.md` files with symlinks to `~/learnings/AGENTS.md`.
- [x] Commit and push the learnings repo update.
- [x] Add a first-pass main-branch dispatcher for `@codex` and `@claude` commits.

## Blockers
- None.

## Recent Results
- Added git-dispatched worktree workflow guidance.
- Removed separate `agent-coordination.md` from the intended policy surface.
- Replaced `/home/name/AGENTS.md`, `/home/name/.codex/AGENTS.md`, and `/home/name/.claude/CLAUDE.md` with symlinks to `/home/name/learnings/AGENTS.md`.
- Added `scripts/dispatch-agent.sh` and README setup notes for watching `/home/name/repos/endepromotion`.

## Agent Output
- Implemented a KISS polling dispatcher: push `@codex` or `@claude` commits to `origin/main`, run the script on the server, and it creates/pushes agent branches with the commit message and patch as prompt. Temporary worktrees/local branches are removed after successful push unless `DISPATCH_KEEP_WORKTREE=1`.

## Next Steps
- Install the dispatcher as a cron job or systemd timer on the always-on machine.
