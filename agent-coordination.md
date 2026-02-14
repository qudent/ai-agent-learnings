# Agent Coordination Learnings

## The STATUS.md pattern

Every non-trivial project should have a `STATUS.md` at its root. This is the single source of truth for what's happening in the project right now.

### Rules
- **Keep it small**: ~50-100 lines, 2-4KB max. If it's longer, it's a document, not a status board.
- **Update on meaningful state changes**: not every commit, but when a subgoal completes, a blocker appears, or direction changes.
- **Rewrite, don't append**: STATUS.md is current state, not a changelog. Old state gets overwritten.
- **Agents must read it before starting work** and update it when done.

### Structure
```markdown
# Project Name - Status

## Current State
One paragraph: what is this project, what phase is it in right now.

## Active Goals
- [ ] Goal A -- brief description
  - [x] Subgoal A1
  - [ ] Subgoal A2 -- BLOCKED on X
- [ ] Goal B -- brief description

## Blockers
- Description of what's stuck and what would unblock it

## Recent Results
- 2-3 bullet points of what was just tried and what happened

## Next Steps
- Concrete next actions, in priority order
```

## Dispatching agents

When spawning a tmux agent:
1. Tell it the project path and point it to STATUS.md
2. Give it a specific goal -- not "work on the project"
3. Tell it where to write output
4. Tell it to update STATUS.md when done

Example prompt:
```
Read ~/project/STATUS.md for context. Your task: implement X.
Write output to ~/project/X.py. When done, update STATUS.md
to mark the goal complete and note any issues.
```

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
