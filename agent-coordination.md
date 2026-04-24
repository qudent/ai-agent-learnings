# Agent Coordination Learnings

## The STATUS.md pattern

Every non-trivial project should have a `STATUS.md` at its root. This is the single mutable coordination surface for current project state, human prompts, and agent output.

`AGENTS.md` is for stable or slow-changing repo instructions: build commands, architecture notes, package managers, test policy, and durable gotchas. `STATUS.md` is for volatile coordination state. Do not create a separate `AGENT_IO.md` unless the project has a specific reason.

### Rules
- **Keep it small**: ~50-100 lines, 2-4KB max. If it's longer, it's a document, not a status board.
- **Update on meaningful state changes**: not every commit, but when a subgoal completes, a blocker appears, or direction changes.
- **Rewrite, don't append**: STATUS.md is current state, not a changelog. Old state lives in git history.
- **Resolved prompts should leave the current file**: remove or rewrite old human prompts once handled so agents do not re-process stale requests.
- **Agents must read it before starting work** and update it when done.
- **For one-off git-dispatched agents**: the triggering commit diff is the primary prompt. Agents should infer the new human intent from that diff, use `STATUS.md` as current context/output, and avoid treating old unchanged text as a fresh request.

### AGENTS.md coordination note

Each repo's `AGENTS.md` should point agents to `STATUS.md`:

```markdown
## Coordination

Read `./STATUS.md` before starting non-trivial work. `STATUS.md` is the current coordination surface: project state, human prompts, and agent output. Rewrite it after meaningful state changes; keep it compact and current. For git-dispatched `@codex` runs, treat the triggering commit diff as the primary prompt and use `STATUS.md` for current output/status.
```

### Structure
```markdown
# Project Name - Status

## Current State
One paragraph: what is this project, what phase is it in right now.

## Human Prompts
- Current human requests or review notes that still need action.
- Keep only active prompts here; git history is the archive.

## Active Goals
- [ ] Goal A -- brief description
  - [x] Subgoal A1
  - [ ] Subgoal A2 -- BLOCKED on X
- [ ] Goal B -- brief description

## Blockers
- Description of what's stuck and what would unblock it

## Recent Results
- 2-3 bullet points of what was just tried and what happened

## Agent Output
- Concise latest agent result: what changed, what failed, and what needs human attention.

## Next Steps
- Concrete next actions, in priority order
```

## Dispatching agents

When spawning a tmux agent:
1. Tell it the project path and point it to STATUS.md
2. Give it a specific goal -- not "work on the project"
3. Tell it to write current output to the `Agent Output` section of STATUS.md
4. Tell it to update STATUS.md when done

Example prompt:
```
Read ~/project/STATUS.md for context. Your task: implement X.
Write code where appropriate. When done, update ~/project/STATUS.md:
mark the goal complete, clear handled Human Prompts, and write a concise
Agent Output note with issues or next steps.
```

For git-dispatched one-off agents, prefer a commit message trigger such as `@codex` and feed the agent the full triggering commit diff. The diff is the fresh instruction channel; STATUS.md is the bounded current state/output file.

## Checking on agents

Don't check one session at a time. Use the batch check:
```bash
tmux ls -F '#{session_name}' | while read -r s; do
  echo "===== $s ====="
  tmux capture-pane -t "$s" -p | tail -n 40
done
```

If an agent looks stuck for >15 minutes with no output, kill and re-dispatch with more context.

## Common mistakes
- Dispatching without enough context -- agent wastes time re-discovering what you already know
- Dispatching duplicate tasks -- two agents doing the same thing
- Not cleaning up finished sessions -- tmux fills up, hard to see what's active
- Agents not updating STATUS.md -- coordination breaks down
