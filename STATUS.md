# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents. `AGENTS.md` is now the canonical global instruction source, and the global agent config files symlink to it.

## Human Prompts
- None active.

## Active Goals
- [x] Move canonical global instructions into `~/learnings/AGENTS.md`.
- [x] Fold agent coordination guidance into `AGENTS.md`.
- [x] Replace global `AGENTS.md`/`CLAUDE.md` files with symlinks to `~/learnings/AGENTS.md`.
- [x] Commit and push the learnings repo update.

## Blockers
- None.

## Recent Results
- Added git-dispatched worktree workflow guidance.
- Removed separate `agent-coordination.md` from the intended policy surface.
- Replaced `/home/name/AGENTS.md`, `/home/name/.codex/AGENTS.md`, and `/home/name/.claude/CLAUDE.md` with symlinks to `/home/name/learnings/AGENTS.md`.

## Agent Output
- Canonical policy file and symlinks are in place. This status reflects the completed refactor.

## Next Steps
- None.
