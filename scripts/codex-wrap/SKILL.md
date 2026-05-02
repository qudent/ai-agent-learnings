---
name: codex-wrap-backend
description: Work on the Git-backed Codex wrapper backend in the learnings repo. Use when debugging or changing codex_wrap.sh, codex_wrap.py, active-run detection, marker commits, abort/resume/new-message behavior, or the wrapper regression tests.
allowed-tools: Bash, Read, Edit
---

# Codex Wrap Backend

Use this skill for the backend wrapper that records Codex sessions as Git
commits. Keep it focused on session management. Branch and worktree placement
belongs in `scripts/branch_commands.sh` and `scripts/parallel-worktrees/`.

## Start Here

Read the live files before changing behavior:

```bash
sed -n '1,140p' scripts/codex_wrap.sh
sed -n '1,220p' scripts/codex_wrap.py
sed -n '1,140p' scripts/branch_commands.sh
sed -n '1,220p' scripts/test_codex_wrap/test_codex_wrap.sh
```

## Load Commands

In an interactive shell, source the wrapper:

```bash
. ~/repos/ai-agent-learnings/scripts/codex_wrap.sh
```

For branch-targeted Codex work, source the branch helper too:

```bash
. ~/repos/ai-agent-learnings/scripts/codex_wrap.sh
. ~/repos/ai-agent-learnings/scripts/branch_commands.sh
```

## User Commands

| Command | Purpose |
| --- | --- |
| `codex_commit <prompt...>` | Start a new Codex session in the current worktree and commit start/agent/stop markers. |
| `codex_resume [session-id] <prompt...>` | Resume an existing session; without an explicit session id, use the last session id found in current branch history. |
| `codex_new_message <prompt...>` | Add instructions to the active/current session: if a run is active, stop/kill it and resume with the new prompt; otherwise resume the last session. |
| `codex_active` / `codex_active_run` | Print the active run-start commit hash and exit 0 when the current branch has a live local wrapper run. |
| `codex_agents` | List currently live local wrapper agents from recent run-start commits cross-checked against live PIDs, with concise task text. |
| `codex_abort [run-start-commit]` | Abort the active run, or a specified run-start commit, and write a `[codex_abort]` marker. |
| `codex_sync_push` | `git fetch --prune origin`, rebase onto the configured upstream so duplicate patches are skipped, then push. Refuses while a local Codex run is active unless `CODEX_SYNC_PUSH_ALLOW_ACTIVE=1` is set. |
| `codex_commit_push <prompt...>` | Run `codex_sync_push`, then `codex_commit`, then `codex_sync_push` again; use only when that combined workflow is intentional. |
| `codex_in_branch @ <branch-or-commit> <prompt...>` | Run Codex in the target branch/worktree via `do_at_branch` or create a commit-rooted worktree via `do_at_commit`. |
| `codex_spawn <codex_commit|codex_resume|codex_new_message|codex_in_branch> <args...>` | Start a detached child wrapper run that survives the dispatcher shell exiting while still writing normal marker commits/logs for ChatGit. |

Plain `codex_commit @ ...` is prompt text. It must not select branches or create
worktrees.

Dispatch agents should source both helper files, then use `codex_spawn` for
implementation children:

```bash
. scripts/codex_wrap.sh
. scripts/branch_commands.sh
codex_spawn codex_in_branch @ HEAD "implement the isolated task; cite STATUS.md and commits"
```

`codex_spawn` sets `CODEX_WRAP_CALLED_BY` from `codex_active` by default. Its
stdout reports the detached launcher pid and dispatch log path; the child run
itself appears in ChatGit after the normal `[codex_start_user]` marker is
written.

## Transcript And Inbox Artifacts

Each active wrapper run has tracked files under `agents/<slug>/` and
`transcripts/`. The durable transcript body lives in
`transcripts/archive/<date>-<slug>.md`, active state is a small pointer at
`transcripts/active/<slug>.md`, and follow-up routing goes through
`agents/<slug>/inbox.md`. `transcripts/index.md` is the compact branch-local
listing for current/known agents.

The active pointer is removed by `[codex_stop]` or `[codex_abort]`; profile,
inbox, and archive transcript files remain. New wrapper runs do not create
`active-agents/` artifacts.

Use this when the user asks "what is running?" or wants to inspect the current
active transcript from the filesystem. Read `transcripts/index.md`, then the
relevant `agents/<slug>/profile.md`, `agents/<slug>/inbox.md`, and archive
transcript.

## Backend CLI

The shell functions are thin wrappers over:

```bash
python3 scripts/codex_wrap.py run start <prompt...>
python3 scripts/codex_wrap.py run resume <session-id> <prompt...>
python3 scripts/codex_wrap.py new-message <prompt...>
python3 scripts/codex_wrap.py active
python3 scripts/codex_wrap.py agents
python3 scripts/codex_wrap.py last-sid [ref]
python3 scripts/codex_wrap.py abort [run-start-commit]
```

Prefer shell functions for normal use; use the Python CLI in tests and focused
backend debugging.

## Guardrails

- Keep `scripts/codex_wrap.py` / `scripts/codex_wrap.sh` on session
  supervision, JSONL parsing, marker commits, active-run lookup, abort, and
  resume behavior.
- Do not move branch/worktree placement into `codex_wrap`; use
  `do_at_branch`, `do_at_commit`, and `codex_in_branch`.
- Do not trust a launcher `$!` as the real Codex child in interactive
  job-control cases; verify the actual child/session leader behavior.
- Preserve existing `session-id` and `run-start-commit-hash` metadata when
  folding/amending wrapper marker commits.
- Prefer exact-shape regression assertions for marker commit bodies.
- Keep transcript/inbox files wrapper-managed. Do not put project-specific
  runbooks there, and do not leave active pointer files present after stop/abort.

## Validation

Run these after backend changes:

```bash
python3 -m py_compile scripts/codex_wrap.py
bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh
```

If a backend change affects the web interface or branch execution, also run:

```bash
bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py
```
