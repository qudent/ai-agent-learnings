# AI Agent Instructions

If an instruction does not make sense, ask the user to clarify before acting.

This file is the canonical global agent instruction file. Global `AGENTS.md`, Codex `AGENTS.md`, and Claude `CLAUDE.md` should symlink here.

## Learnings -- READ THESE and remind proactively

Hard-won lessons from past sessions live in `~/repos/ai-agent-learnings/`. **Read them at the start of non-trivial tasks.** When you see the user or an agent falling into a known antipattern, flag it immediately -- don't wait.

Scope rule for learnings:
- Keep files in `~/repos/ai-agent-learnings/` project-agnostic.
- Do not add one-off project paths/commands there; put concrete run commands in the relevant project's `STATUS.md` or project docs.
- If you change files in `~/repos/ai-agent-learnings/`, update `~/repos/ai-agent-learnings/README.md` when structure or workflow expectations change.
- Treat `~/repos/ai-agent-learnings/` as a real repo: commit and push learnings updates in the same session.

| File | When to reference |
|------|-------------------|
| `ml-experiments.md` | Any training run, search, or optimization task |
| `vast-ai.md` | Any work involving Vast.ai GPU instances, including cost estimation |
| `modal-inference.md` | Modal inference deployments |


You have a tendency to change policy but not commit/push.

**Do instead**:
- rewrite relevant learnings files and AGENTS.md
- commit and push in the same session

Avoid:
You tend to enter things into the learnings directory that are specific to individual projects, using conventions, files and framings specific to the project.
**Do instead**: Keep learnings project-agnostic. Before changing the learnings, confirm and write in your chain of thought whether this is indeed a generalizable insight.

Avoid: provider model IDs from your general knowledge.
- When using models on Openrouter or other providers, you have a tendency to use outdated model numbers if model version is not specific by user (using outdated models like "qwen-3"). 


**Do instead:** Always search for state-of-the-art model versions yourself unless explicitly asked. if you choose which model to use, double check and confirm that this comes either from a research or directly from the user.

## Voice and gateway input handling

When a user message arrives with a generated voice transcript, the first assistant response must begin with a cleaned transcript and concise interpreted instructions before doing the substantive task. Treat the transcript as the user's real input even if the platform message body says it has no text content. Rename the Hermes session/thread from the voice content whenever the platform/gateway exposes a safe way to do so; for Discord, rely on the Hermes-owned auto-thread rename hook for freshly-created threads and do not bulk-rename arbitrary old threads from agent context alone.

## Coordination

Read `./STATUS.md` before starting non-trivial work. `STATUS.md` is the single coordination source of truth for current branch state only: active goals, blockers, current instructions, and next actions. Rewrite it after meaningful state changes; keep it compact and current. **Delete finished items from STATUS.md immediately** and rely on Git history, `transcripts/archive/`, `agents/*/profile.md`, and `agents/*/inbox.md` for the durable audit trail.

## Codex dispatcher orchestration

For future Hermes/Codex coding tasks that need repository work beyond trivial chat or status, use the wrapper dispatcher path by default instead of launching raw Codex sessions:

```bash
. scripts/codex_wrap.sh
. scripts/branch_commands.sh
codex_dispatch "<user/task instruction>"
```

Dispatcher agents reconcile the Agent Context Pack, update task routing surfaces (`STATUS.md`, and `agents/<slug>/inbox.md` when following up with an existing agent), and delegate implementation through `codex_spawn ...` with branch/worktree isolation and disjoint write scopes. Plain `codex_commit` is for a single narrow implementation agent that was already scoped by a human or dispatcher; broad or recursive work should go through `codex_dispatch`, which generates an Agent Context Pack from branch-local `STATUS.md`, active transcript pointers, relevant agent profiles/inboxes, transcript tails, and the audit trail. Child agents inherit ancestry through `CODEX_WRAP_CALLED_BY` and must keep instructions/audit in files rather than long commit messages.

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
- **No performative next steps**: If you are about to say "next I should...", "the next practical step is...", or "I would..." and the action is safe/tool-accessible, do it immediately instead of stopping. Report next steps only when blocked, unsafe without confirmation, or outside available tools.
- **Use exponential backoff for process waits**: When monitoring background processes, prefer bounded exponential-backoff waits/status updates over tight fixed-interval polling or repeated user-visible "still working" spam. Start with short checks only when freshness matters, then back off and cap the interval.
- **Version control is the rollback plan**: Prefer small commits/checkpoints over waiting for confirmation on reversible edits. If a change is wrong, revert it; do not use reversibility as a reason to avoid acting.
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
