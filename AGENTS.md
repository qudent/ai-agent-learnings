# AI Agent Instructions

If an instruction does not make sense, ask the user to clarify before acting.

This file is the canonical global agent instruction file. Global `AGENTS.md`, Codex `AGENTS.md`, and Claude `CLAUDE.md` should symlink here.

## Learnings -- READ THESE and remind proactively

Hard-won lessons from past sessions live in `~/learnings/`. **Read them at the start of non-trivial tasks.** When you see the user or an agent falling into a known antipattern, flag it immediately -- don't wait.

Scope rule for learnings:
- Keep files in `~/learnings/` project-agnostic.
- Do not add one-off project paths/commands there; put concrete run commands in the relevant project's `STATUS.md` or project docs.
- If you change files in `~/learnings/`, update `~/learnings/README.md` when structure or workflow expectations change.
- Treat `~/learnings/` as a real repo: commit and push learnings updates in the same session.

| File | When to reference |
|------|-------------------|
| `antipatterns.md` | Always -- patterns to watch for and interrupt |
| `ml-experiments.md` | Any training run, search, or optimization task |
| `vast-ai.md` | Any work involving Vast.ai GPU instances, including cost estimation |
| `modal-inference.md` | Modal inference deployments |

## Per-Repo AGENTS.md

Each non-trivial repo should have its own `AGENTS.md` for stable or slow-changing repo instructions: build commands, architecture notes, package managers, test policy, deployment notes, and durable gotchas.

Every repo `AGENTS.md` should include this coordination note or an equivalent:

```markdown
## Coordination

Read `./STATUS.md` before starting non-trivial work. `STATUS.md` is the current coordination surface: project state, human prompts, and agent output. Rewrite it after meaningful state changes; keep it compact and current. For git-dispatched `@codex` runs, treat the triggering commit message and human-authored patch text as the primary prompt and use `STATUS.md` for current output/status.
```

## Human Input vs Agent Output

Human input is the durable, high-value part of the repository. Agent output is useful but fungible. Preserve that distinction:

- **Human-owned input**: commit messages beginning with `usr:` or containing `@codex`/`@claude`, human edits to source/docs, and `USER_IO.md` when present.
- **Agent-owned output**: code changes, generated artifacts, and the `Agent Output` section of `STATUS.md`.
- **Do not rewrite `USER_IO.md`** unless the human explicitly asks. Agents should read it as durable prompt/context, not tidy it as status.
- **Live chat feedback** typed into an active agent session should be committed as human input with `[no-dispatch] usr: ...` if it should survive. Use `scripts/log-human-input.sh` to append it to `USER_IO.md`.
- **Commit prefix convention**: use `usr:` for human-only notes, `@codex`/`@claude` for dispatching human requests, and `agent:` or `<tool> result` for agent commits.

## STATUS.md -- project state and agent IO

Each non-trivial project must have a `STATUS.md` at its root, kept to roughly 50-100 lines and 2-4KB. This is the coordination point and current human/agent communication surface for the project.

- **Read it before starting work** on a project.
- **Rewrite it when state changes meaningfully** -- goal completed, blocker found, direction changed.
- **Rewrite, don't append** -- it is current state, not a log. Git history is the archive.
- **Use it for active human prompts and agent output** -- active human requests belong in `Human Prompts`; durable prompt transcripts belong in commit messages or `USER_IO.md`; current agent results belong in `Agent Output`.
- **Clear resolved prompts** -- do not leave stale requests in the current file once handled.
- **Always update it immediately after each meaningful state change** -- do not ask first.

Recommended structure:

```markdown
# Project Name - Status

## Current State
One paragraph: what this project is and what phase it is in right now.

## Human Prompts
- Current human requests or review notes that still need action, or pointers to relevant `USER_IO.md` sections/commits.
- Keep only active prompts here; commit history and `USER_IO.md` are the durable human-input archive.

## Active Goals
- [ ] Goal A -- brief description
- [ ] Goal B -- brief description

## Blockers
- Description of what is stuck and what would unblock it.

## Recent Results
- Two or three bullets describing what was just tried and what happened.

## Agent Output
- Concise latest agent result: what changed, what failed, and what needs human attention.

## Next Steps
- Concrete next actions in priority order.
```

## Git-Dispatched Branch Work

Prefer git-dispatched branch worktrees over interactive tmux subagents for parallel development. Tmux is useful for launching and logging long-running dispatcher processes, but commits remain the coordination primitive.

Preferred workflow:

1. Human creates a request branch and commits with `@codex` or similar in the commit message.
2. The commit message and human-authored patch are the fresh durable human prompt. The human may put comments in any changed file, `USER_IO.md`, or `STATUS.md`.
3. A local `reference-transaction` hook detects `refs/heads/<branch>` pointer updates. If the new tip commit message contains `@codex` or `@claude`, it passes both the new commit and branch name to the dispatcher.
4. The dispatcher finds or creates the worktree associated with that exact branch, for example `main` at the primary repo path or `feature-x` at `<repo>.worktrees/feature-x`.
5. The agent works directly in that branch worktree and receives the repo instructions, current `STATUS.md`, branch metadata, and the full triggering commit patch.
6. The agent treats unchanged older text as context, not as a new request.
7. The agent commits one coherent result to the same branch and rewrites `STATUS.md`, including `Agent Output`.
8. Human reviews, merges, or continues by making another `@codex` commit.

The KISS implementation is a one-shot dispatcher at `scripts/dispatch-agent.sh`: call it as `dispatch-agent.sh REPO COMMITISH SOURCE_BRANCH`. A local `reference-transaction` hook on the always-on machine starts it inside a persistent tmux session and writes logs under `/home/name/agent-dispatch-logs`. A GitHub webhook can call the same command later. Polling is not the desired primitive. The dispatcher prompt includes the full trigger commit message and patch; text after the tag in the commit message is intentional extra prompt content, not the only prompt content.

The dispatcher mirrors the `parallel-worktrees` skill's sibling worktree layout (`<repo>.worktrees/<branch-ish>`) for branch worktrees beyond the primary repo. It creates or reuses the branch worktree and initializes a new worktree by running `pnpm install` when `package.json` is present, matching the skill's setup expectation without sourcing the interactive helper.

Only commit messages trigger dispatch. Tags inside changed files are prompt content only when the commit message itself triggers an agent. Use `[no-dispatch]` or `@no-dispatch` in the commit message when mentioning `@codex`/`@claude` without wanting a new run. Live feedback typed into an active Codex/Claude chat should be logged with `scripts/log-human-input.sh` rather than turned into another trigger commit.

Do not create `agent/codex/<branch>` child branches for ordinary dispatch. The branch itself owns the worktree where the agent should work; if the worktree is dirty, the dispatcher should refuse rather than risk overwriting human edits.

If a human leaves task comments in source files, the agent should either satisfy and remove them or convert them into durable documentation. Do not leave completed one-off prompt comments in code.

`codex exec` and `claude -p` are non-interactive once launched. To add instructions while a dispatched run is active, commit another `@codex`/`@claude` request on the same branch; the dispatcher lock queues it until the current run exits. Attach to tmux for monitoring logs, not as the primary prompt channel.

## Working Style

- **Bias toward action**: Small, revertable commits are cheap; blocked time is expensive.
- **Commit discipline**: Frequent, logical commits. Each commit = one coherent unit.
- **Don't block on confirmation**: If the path forward is clear, do it. Git history is the safety net.
- **Smoke-test risky assumptions first**: Before building on an API, library, or technique, write a 10-line spike that proves the critical integration works.

## Package Managers

- **JavaScript/Node**: Use `pnpm`, not npm.
- **Python**: Use `uv`, not pip.

## Dependency Discipline

When deploying to fresh/ephemeral environments such as Vast, Docker, or CI:
- **Cap major versions** of fast-moving libraries: `transformers>=4.47,<5` not `transformers>=4.47`.
- Do not over-pin patches/minors.
- If you cannot pin, check the installed version on the target before running.

## This Machine (Hetzner vserver)

**Resource limits**: 8 GB RAM, ~75 GB disk, often less than 15 GB free. Stream data rather than materializing in memory. Budget disk before downloading large files.

**Installed tools**: aider, codex, interpreter, browser-use, playwright.

**Environment**: `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_CLOUD_VISION_API_KEY`, `HF_API_KEY`, `VAST_API_KEY` are set.

**Repos**: All in `~/repos/` plus some active projects in `~/Dropbox/`. Dotfiles repo: https://github.com/qudent/pilot

**Skills**: `parallel-worktrees` is installed under both `~/.claude/skills/parallel-worktrees/` and `~/.codex/skills/parallel-worktrees/`.

**Pilot** (dormant since 2026-02-10): `~/repos/pilot/`, port 7777. `sudo systemctl enable pilot && sudo systemctl start pilot` to resume.
