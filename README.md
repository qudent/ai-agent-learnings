# AI Agent Learnings

This repository tracks project-agnostic learnings for local AI coding agents.
It is backed by `~/Dropbox/learnings` so the same guidance is available across machines and sessions.

## Setup

- Directory: `~/Dropbox/learnings`
- Canonical global instructions: `/home/name/AGENTS.md` (symlink) and `/home/name/CLAUDE.md`
- Purpose: store reusable lessons, not project-specific commands

## Maintenance Workflow

- Keep learnings project-agnostic; move project-specific run commands to that project's `STATUS.md` or docs.
- When learnings workflow/structure changes, update this `README.md` and `STATUS.md` in the same session.
- Commit and push learnings updates (`~/Dropbox/learnings` git repo) before ending the task.

Current learnings files:
- `antipatterns.md`
- `ml-experiments.md`
- `vast-ai.md`
- `vast-preestimate.md`
- `agent-coordination.md`

## Relevant global AGENTS.md / CLAUDE.md passage

> ## Learnings -- READ THESE and remind proactively
> Hard-won lessons from past sessions live in `~/Dropbox/learnings/`. **Read them at the start of non-trivial tasks.** When you see the user or an agent falling into a known antipattern, flag it immediately -- don't wait.
>
> Scope rule for learnings:
> - Keep files in `~/Dropbox/learnings/` project-agnostic.
> - Do not add one-off project paths/commands there; put concrete run commands in the relevant project's `STATUS.md` or project docs.
>
> ## STATUS.md -- every project gets one
> Each non-trivial project must have a `STATUS.md` at its root (~50-100 lines max). This is the coordination point for all agents working on that project.
