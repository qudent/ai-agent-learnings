# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents.
`AGENTS.md` is the canonical global instruction source, global agent config
files symlink to it, and branch-ref dispatch remains a policy pattern rather
than a tracked helper-script implementation in this repo. The `chatgit`
launcher now serves the Git-backed `codex-web-interface`.

## Human Prompts
clean up stale STATUS.md entries, clean unused branches (both local and upstream).

make a new "codex_dispatch" command where you can put an arbitrary new instruction and it then sends it to codex together with relevant yet concise context/commits (active agents/recent commit history/STATUS.md in branches) and the task to split it up into tasks and do the right thing (eg interrupting running agents, restarting, doing questions in new branches if they are just questions, merging things etc). so to be clear it should end with a single round of new codex_... calls, and leave the further execution to the called agents. the codex dispatch command should, besides calling these, end with a quick status update as reply saying what kind of thing was dispatched. as said, it is important to specify in the prompt that the actual work, and followup, should be delegated to the dispatched agents.

think one more last time hard about the UI of the thing, what is clear, what isn't how it could be changed (eg the "branching from" with the position of the text field staying at the bottom is currently super unintuitive), then implement it, then write note. make sure you make a clear commit of the last save state. on write note that the current frontend is abandoned and has some ai bugs.

change the code that for each new commit starting an agent run, there should be a called-by entry denoting either it is called by the user or the commit hash of the thing calling it. also add requirement that it should cite things.

you can use this (new complex) prompt as a sample for what kind of input the dispatch command would get - the task is to figure out how to cleanly separate this into multiple branches, parallelize and orchestrate, so that it doesn't become a mess in the end.
also make a bit clearer one-line intermediate empty commits clearly flagging checkpoints (last save state before...)

 - repo relocation
Desired state: the learnings repo lives at `~/repos/ai-agent-learnings`, legacy
top-level path references are removed, relative helper paths still work, and
global `AGENTS.md`/`CLAUDE.md` symlinks resolve to the moved repo.


ok wait to be clear, are you using your internal subagent system or are you dispatching multiple codex_commit calls as background processes? you should do the dispatching of larger tasks to codex_commits with git commits


also (experimentally) implement using jujutsu instead of git to do project management, i think it may save some effort or be a more beautiful paradigm that todo lists/a DAG of unfinished work can be done and modified?

also the "chatgit" command should check if something is already running and abort if not. it should output commands before. it should 

## Active Goals
- [x] Keep global agent instructions centralized in
  `~/repos/ai-agent-learnings/AGENTS.md`.
- [x] Maintain project-agnostic learnings and workflow guardrails.
- [x] Support branch-ref dispatch where each branch is worked in its own
  worktree.
- [x] Use `STATUS.md` as the single coordination file instead of splitting state
  and communication across a whiteboard.
- [x] Provide a small local web UI for Git-backed Codex sessions.

## TODO Plan
- [ ] Fix narrow/mobile layout so the composer and detail pane remain reachable
  without scrolling through all 150 conversation commits.
- [ ] Reduce `/api/overview` payload and polling cost; the current live
  RepoProver page returns about 1.27 MB every 2 seconds.
- [ ] Re-run the browser UI pass after those fixes and keep desktop plus narrow
  screenshots as evidence.

## Blockers
- None.

## Recent Results
- Moved the main repo to `/home/name/repos/ai-agent-learnings` and the linked
  `dev` worktree to `/home/name/repos/ai-agent-learnings.worktrees/dev`.
- Retargeted `/home/name/AGENTS.md`, `/home/name/.codex/AGENTS.md`, and
  `/home/name/.claude/CLAUDE.md` to the moved `AGENTS.md`; all three resolve.
- Removed legacy top-level path references from repo Markdown and updated
  script header/docstring examples; verification passed for py_compile,
  codex_wrap tests, codex_web tests, and direct sourcing of helper scripts.
- Merged local branch `dev` into `main` with a normal merge commit.
- Restarted the main web UI in tmux session `chatgit-main` on
  `http://127.0.0.1:6174/`, serving `/home/name/repos/repoprover` with the
  merged `~/repos/ai-agent-learnings/scripts/chatgit` and `codex_wrap.sh`.
- Verification passed:
  `python3 -m py_compile scripts/codex_web.py scripts/codex_wrap.py`,
  `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`, and
  `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- Live Playwright pass against `127.0.0.1:6174` exercised desktop and 390px
  layouts, commit detail selection, branch-base selection/clear, run transcript
  selection, run action menu, repo path disclosure, and Queue's no-active-run
  alert. Screenshots were written to `/tmp/chatgit-desktop_view.png` and
  `/tmp/chatgit-narrow_view.png`.
- Issues found: the narrow layout stacks the full conversation before the
  composer/detail pane, and `/api/overview` repeatedly transfers full raw
  commit data for a large payload.

## Agent Notes
- Tracked dispatcher/logging helper scripts are no longer present in this repo;
  keep future docs at the policy level unless a replacement implementation is
  added.
- `git worktree list` currently shows `/home/name/repos/ai-agent-learnings` on
  `main` and `/home/name/repos/ai-agent-learnings.worktrees/dev` on `dev`.
- Global `/home/name/AGENTS.md`, `/home/name/.codex/AGENTS.md`, and
  `/home/name/.claude/CLAUDE.md` symlink to
  `/home/name/repos/ai-agent-learnings/AGENTS.md`.
- Active web UI instance: tmux session `chatgit-main` on `127.0.0.1:6174`, log
  path `/tmp/chatgit-6174.log`.
- Current verification for the codex-web-interface is `python3 -m py_compile
  scripts/codex_web.py scripts/codex_wrap.py`,
  `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`, and
  `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- Stable repo instructions still belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic
  learnings.
