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

Read `./STATUS.md` before starting non-trivial work. `STATUS.md` is the current coordination surface: project state, human prompts, and agent output. Rewrite it after meaningful state changes; keep it compact and current. For git-dispatched `@codex` runs, treat the triggering commit diff as the primary prompt and use `STATUS.md` for current output/status.
```

## STATUS.md -- project state and agent IO

Each non-trivial project must have a `STATUS.md` at its root, kept to roughly 50-100 lines and 2-4KB. This is the coordination point and current human/agent communication surface for the project.

- **Read it before starting work** on a project.
- **Rewrite it when state changes meaningfully** -- goal completed, blocker found, direction changed.
- **Rewrite, don't append** -- it is current state, not a log. Git history is the archive.
- **Use it for human prompts and agent output** -- active human requests belong in `Human Prompts`; current agent results belong in `Agent Output`.
- **Clear resolved prompts** -- do not leave stale requests in the current file once handled.
- **Always update it immediately after each meaningful state change** -- do not ask first.

Recommended structure:

```markdown
# Project Name - Status

## Current State
One paragraph: what this project is and what phase it is in right now.

## Human Prompts
- Current human requests or review notes that still need action.
- Keep only active prompts here; git history is the archive.

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

## Git-Dispatched Parallel Work

Prefer git-dispatched worktrees over interactive tmux subagents for parallel development. Tmux agents were fragile because prompts could fail to submit, sessions accumulated stale state, and coordination depended on reading panes instead of commits.

Preferred workflow:

1. Human creates a request branch and commits with `@codex` or similar in the commit message.
2. The commit diff is the fresh prompt. The human may put comments in any changed file or in `STATUS.md`.
3. A dispatcher detects the `@codex` commit and creates a new agent branch from that exact commit, for example `codex/<trigger-branch>/<short-sha>`.
4. The dispatcher creates a separate worktree for the agent branch, for example `<repo>.worktrees/codex-<short-sha>`.
5. The agent receives the repo instructions, current `STATUS.md`, branch metadata, and the full triggering commit patch.
6. The agent treats unchanged older text as context, not as a new request.
7. The agent commits one coherent result to the agent branch and rewrites `STATUS.md`, including `Agent Output`.
8. Human reviews, merges, or continues by making another `@codex` commit.

Do not check out the human's trigger branch directly in the agent worktree. Git cannot safely check out one branch in two worktrees, and the human may keep editing it. Use a child agent branch from the trigger commit.

If a human leaves task comments in source files, the agent should either satisfy and remove them or convert them into durable documentation. Do not leave completed one-off prompt comments in code.

Tmux is still acceptable for long-running commands, monitoring, or manual debugging, but it is not the default parallel agent dispatch mechanism.

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
