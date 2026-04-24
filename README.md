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

`AGENTS.md` defines the `STATUS.md` scheme for project coordination. Every non-trivial project gets a `STATUS.md` at its root (~50–100 lines) that agents read before starting work and rewrite (not append) when state changes. `STATUS.md` is current state and agent output; durable human prompts live in commit messages, human-authored diffs, and `USER_IO.md` when present. Stable repo instructions stay in each repo's `AGENTS.md`.

## Human input convention

Use `USER_IO.md` when human feedback is too long for a commit message or should feel like a scratchpad. Agents read it but should not edit it unless explicitly asked. For quick feedback typed into an active agent chat, commit it without triggering another run:

```bash
./scripts/log-human-input.sh /home/name/repos/endepromotion 'usr: I do not like X; try Y instead.'
```

The helper appends to `USER_IO.md` and commits with `[no-dispatch] usr: log human input`.

## KISS dispatcher

`scripts/dispatch-agent.sh` is a one-shot dispatcher for `@codex` and `@claude` commits:

```bash
./scripts/dispatch-agent.sh /home/name/repos/endepromotion <commit-sha> main
```

Workflow: commit with `@codex` or `@claude` in the commit message. The full trigger commit message and human-authored patch are included in the prompt; text after the tag is intentional extra prompt content, not the only prompt content. Tags inside changed files do not trigger dispatch by themselves. If a commit message must mention a tag without spawning an agent, include `[no-dispatch]` or `@no-dispatch`. The dispatcher creates or reuses `agent/<tool>/<source-branch>` in a sibling worktree, merges the trigger commit into that branch, feeds the triggering patch to `codex exec` or `claude -p`, commits any remaining changes, and pushes the agent branch. Agent worktrees are branch-scoped so follow-up trigger commits continue the same thread; set `DISPATCH_CLEANUP=1` if you want the local worktree removed after a run.

The dispatcher follows the same worktree setup convention as the `parallel-worktrees` skill: sibling worktrees under `<repo>.worktrees/`, with `pnpm install` run for a new worktree when `package.json` exists. It uses its own branch names (`agent/<tool>/<source-branch>`) and worktree names (`<tool>-<source-branch>`) so automated agent runs do not collide with manual feature worktrees.

To make laptop commits trigger the server, install `scripts/post-commit-dispatch.sample` as a local git hook on the laptop and set:

```bash
export AGENT_DISPATCH_SSH=name@your-server
export AGENT_DISPATCH_REPO=/home/name/repos/endepromotion
```

That hook pushes the triggering commit, then SSHes to the always-on machine and invokes the one-shot dispatcher for that exact commit. A GitHub webhook can call the same command later; polling is intentionally not part of the design.
