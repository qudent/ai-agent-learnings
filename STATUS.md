# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents.
`AGENTS.md` is the canonical global instruction source, global agent config
files symlink to it, and branch-ref dispatch remains a policy pattern rather
than a tracked helper-script implementation in this repo. The `chatgit`
launcher now serves the Git-backed `codex-web-interface`.

## Active Human Prompts - chatgit main UI verification
Desired state: merge the local `dev` branch into `main`, restart the web UI with
the merged code, and test the UI directly enough to identify remaining issues.

## Active Goals
- [x] Keep global agent instructions centralized in `~/learnings/AGENTS.md`.
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
- Merged local branch `dev` into `main` with a normal merge commit.
- Restarted the main web UI in tmux session `chatgit-main` on
  `http://127.0.0.1:6174/`, serving `/home/name/repos/repoprover` with the
  merged `~/learnings/scripts/chatgit` and `codex_wrap.sh`.
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
- `git worktree list` currently shows `/home/name/learnings` on `main` and
  `/home/name/learnings.worktrees/dev` on `dev`.
- Active web UI instance: tmux session `chatgit-main` on `127.0.0.1:6174`, log
  path `/tmp/chatgit-6174.log`.
- Current verification for the codex-web-interface is `python3 -m py_compile
  scripts/codex_web.py scripts/codex_wrap.py`,
  `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`, and
  `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- Stable repo instructions still belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic
  learnings.
