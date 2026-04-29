# AI Agent Learnings

Project-agnostic operating guidance for local AI coding agents. This repo lives at `~/learnings`. The canonical global instruction file is `AGENTS.md`; global `AGENTS.md`, Codex `AGENTS.md`, and Claude `CLAUDE.md` should symlink to it.

## What this is

A collection of hard-won lessons and policies that AI agents should read before starting non-trivial work. Everything here should be reusable across projects — project-specific commands and paths belong in each project's own docs.

## How agents use it

Agents are instructed (via `AGENTS.md`) to read relevant files at the start of tasks and to proactively flag known antipatterns. The file-to-context mapping:

| File | When to reference |
|------|-------------------|
| `AGENTS.md` | Canonical global operating policy (CLAUDE.md and AGENTS.md symlink here)|
| `ml-experiments.md` | Any training run, search, or optimization task |
| `vast-ai.md` | Any work involving Vast.ai GPU instances (includes cost estimation) |
| `modal-inference.md` | Modal inference deployments |

## Maintenance rules

- **Rewrite, don't append** — files should reflect current policy, not be a changelog.
- When workflow changes materially, update this README in the same session.
- Commit and push changes in the same session they're made.

## Local helper scripts

- `scripts/chatgit`: launcher for the Git-backed `codex-web-interface` for the current
  repository. Add `export PATH="$HOME/learnings/scripts:$PATH"` to `.zshrc` or
  `.bashrc`, then run `chatgit` from any Git repo. Set `CHATGIT_PORT` to choose
  a non-default port.
- `scripts/codex_web.py`: loopback web UI for Git-backed Codex conversations.
  When it creates a branch, it records `branch.<name>.parent-branch` and
  `branch.<name>.parent-commit` in Git config so the UI has an explicit
  parent-branch convention instead of inferring ancestry from worktree paths.
- `scripts/codex_wrap.sh` / `scripts/codex_wrap.py`: Codex session wrapper only.
  It records start/resume/agent/stop marker commits and manages the live Codex
  process. It should not own branch or worktree placement.
- `scripts/parallel-worktrees/worktrees.sh`: shared worktree primitives for
  creating, finding, merging, and cleaning branch worktrees.
- `scripts/branch_commands.sh`: generic command placement helpers such as
  `do_at_branch`, `do_at_commit`, and thin tool-specific wrappers like
  `codex_in_branch`.

## Tests

- `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`
- `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`

## Related: coordination files

`AGENTS.md` defines the repo coordination scheme. Every non-trivial project gets a `STATUS.md` at its root as the single coordination source of truth: compact project state, active prompts, questions, agent handoffs, latest agent-to-human notes, and reviewable TODO plans. Agents read it before starting work and rewrite it when state changes. Durable human prompts live in commit messages, human-authored diffs, `STATUS.md`, and `USER_IO.md` when present. Stable repo instructions stay in each repo's `AGENTS.md`.

## Human input convention

Use `STATUS.md` for active instructions and agent communication. Use `USER_IO.md` only when the human wants a durable prompt archive or scratchpad that agents should not tidy. For quick feedback typed into an active agent chat, preserve it in `STATUS.md` or a human-authored commit, and use a `[no-dispatch] usr: ...` commit message when it should not start another agent run.

## KISS dispatcher

The tracked local dispatcher helper scripts have been retired from this repo. The coordination contract remains: commit with `@codex` or `@claude` in the commit message when a local dispatcher is installed, and treat the full trigger commit message plus human-authored patch as the durable prompt. Tags inside changed files do not trigger dispatch by themselves. If a commit message must mention a tag without spawning an agent, include `[no-dispatch]` or `@no-dispatch`.

When branch-ref dispatch is configured outside this repo, the hook should pass the changed `refs/heads/<branch>` name as `SOURCE_BRANCH`; a commit object alone does not reliably identify which branch created it. Branch work should happen in the branch-owned worktree, following the `parallel-worktrees` sibling layout for new worktrees.

`codex exec` and `claude -p` are non-interactive after launch. To add more instructions while a dispatched run is active, make another `@codex` or `@claude` commit on the same branch; the dispatcher lock queues it until the current run exits. Attach to the tmux session for monitoring, not for prompt input.
