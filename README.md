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

Workflow: commit with `@codex` or `@claude` in the commit message. The full trigger commit message and human-authored patch are included in the prompt; text after the tag is intentional extra prompt content, not the only prompt content. Tags inside changed files do not trigger dispatch by themselves. If a commit message must mention a tag without spawning an agent, include `[no-dispatch]` or `@no-dispatch`. The dispatcher resolves the source branch, finds or creates that branch's worktree, feeds the triggering patch to `codex exec` or `claude -p` in that exact worktree, commits any remaining changes to the same branch, and pushes that branch.

The hook passes the changed `refs/heads/<branch>` name as `SOURCE_BRANCH`; a commit object alone does not reliably identify which branch created it. When the branch has no worktree yet, the dispatcher follows the same setup convention as the `parallel-worktrees` skill: sibling worktrees under `<repo>.worktrees/`, with `pnpm install` run for a new worktree when `package.json` exists. Existing branch worktrees are reused exactly.

To trigger agents when any local branch pointer changes on the always-on machine, install `scripts/reference-transaction-dispatch.sample` as a local `reference-transaction` hook in each target repo. It is guarded to run only on host `theserver`, exits successfully when the dispatcher script is missing, starts work in a persistent `tmux` session, and writes logs under `/home/name/agent-dispatch-logs` by default.

```bash
cp /home/name/learnings/scripts/reference-transaction-dispatch.sample .git/hooks/reference-transaction
chmod +x .git/hooks/reference-transaction
```

`codex exec` and `claude -p` are non-interactive after launch. To add more instructions while a dispatched run is active, make another `@codex` or `@claude` commit on the same branch; the dispatcher lock queues it until the current run exits. Attach to the tmux session for monitoring, not for prompt input.
