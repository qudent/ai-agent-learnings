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
| `ml-experiments.md` | Any training run, search, or optimization task |
| `vast-ai.md` | Any work involving Vast.ai GPU instances, including cost estimation |
| `modal-inference.md` | Modal inference deployments |


**ANTIPATTERN**: policy changed but not committed/pushed.

**Do instead**:
- rewrite relevant learnings files and AGENTS.md
- commit and push in the same session

**ANTIPATTERN**: project-specific learnings
**Do instead**: Keep learnings project-agnostic

## Coordination

Read `./STATUS.md` before starting non-trivial work. `STATUS.md` is the single coordination source of truth: compact project state, active human prompts, open questions, agent notes, handoffs, and the current TODO plan. Rewrite it after meaningful state changes; keep it compact and current.
```

## STATUS.md -- Project State

Each non-trivial project must have a `STATUS.md` at its root, kept compact and current. This is the single coordination file for project state, active human-agent communication, open questions, and the reviewable TODO plan.

- **Read it before starting work** on a project.
- **Rewrite it when state changes meaningfully** -- goal completed, blocker found, direction changed.
- **Rewrite, don't append** -- it is current state, not a log. Git history is the archive. 50-100 lines max.
- **Include active prompt/chat text when it should coordinate future work** -- no separate human-agent whiteboard is expected.
- **No agent-output diary** -- summarize durable results in `Recent Results`; keep handoff notes, open questions, and the latest TODO plan concise.
- **Always update it immediately after each meaningful state change** -- do not ask first.

Recommended structure:

```markdown
# Project Name - Status
# Overall direction
A concise description of where the human currently wants you to go. This is the target state that you should work towards autonomously. Do not abort your work before you either reach that goal or it is impossible for you to do so (eg budget spent).

Avoid editing above the line (only put new human information into it), but do edit below it.
-------

## Current State
One paragraph: what this project is and what phase it is in right now.

## Active Goals
- [ ] Goal A -- brief description
- [ ] Goal B -- brief description

## TODO Plan
- [ ] Concrete next action the human can review or edit.

## Blockers
- Description of what is stuck and what would unblock it.

## Recent Results
- Two or three bullets describing what was just tried and what happened.

## Agent Notes
- Current agent handoff: what changed, what failed, and what needs attention.
```

Preferred workflow:

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
