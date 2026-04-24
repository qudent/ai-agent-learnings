# AI Agent Learnings

Project-agnostic operating guidance for local AI coding agents. This repo lives at `~/learnings`. The canonical global instruction file is `AGENTS.md`; global `AGENTS.md`, Codex `AGENTS.md`, and Claude `CLAUDE.md` should symlink to it.

## What this is

A collection of hard-won lessons and policies that AI agents should read before starting non-trivial work. Everything here should be reusable across projects — project-specific commands and paths belong in each project's own docs.

## How agents use it

Agents are instructed (via `AGENTS.md`) to read relevant files at the start of tasks and to proactively flag known antipatterns. The file-to-context mapping:

| File | When to reference |
|------|-------------------|
| `AGENTS.md` | Canonical global operating policy |
| `antipatterns.md` | Always — patterns to watch for and interrupt |
| `ml-experiments.md` | Any training run, search, or optimization task |
| `vast-ai.md` | Any work involving Vast.ai GPU instances (includes cost estimation) |
| `modal-inference.md` | Modal inference deployments |

## Maintenance rules

- **Rewrite, don't append** — files should reflect current policy, not be a changelog.
- When workflow changes materially, update this README in the same session.
- Commit and push changes in the same session they're made.

## Related: STATUS.md convention

`AGENTS.md` defines the `STATUS.md` scheme for project coordination. Every non-trivial project gets a `STATUS.md` at its root (~50–100 lines) that agents read before starting work and rewrite (not append) when state changes. `STATUS.md` is also the current human-prompt and agent-output surface; git history is the archive. Stable repo instructions stay in each repo's `AGENTS.md`.
