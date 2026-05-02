# AI Agent Learnings

Project-agnostic operating guidance for local AI coding agents. This repo lives at `~/repos/ai-agent-learnings`. The canonical global instruction file is `AGENTS.md`; global `AGENTS.md`, Codex `AGENTS.md`, and Claude `CLAUDE.md` should symlink to it.

## What this is

A collection of hard-won lessons and policies that AI agents should read before starting non-trivial work. Everything here should be reusable across projects — project-specific commands and paths belong in each project's own docs.

## How agents use it

Agents are instructed (via `AGENTS.md`) to read relevant files at the start of tasks and to proactively flag known antipatterns. The file-to-context mapping:

| File | When to reference |
|------|-------------------|
| `AGENTS.md` | Canonical global operating policy (CLAUDE.md and AGENTS.md symlink here)|
| `frontend-design.md` | Frontend/UI design and behavior guidance distilled from user feedback |
| `ml-experiments.md` | Any training run, search, or optimization task |
| `vast-ai.md` | Any work involving Vast.ai GPU instances (includes cost estimation) |
| `modal-inference.md` | Modal inference deployments |

## Maintenance rules

- **Rewrite, don't append** — files should reflect current policy, not be a changelog.
- **Delete completed items from `STATUS.md`** — finished goals/results belong in Git history, transcript archives, and agent profiles/inboxes. Keep only active state plus at most a fresh summary.
- When workflow changes materially, update this README in the same session.
- Commit and push changes in the same session they're made.

## Local helper scripts

- `scripts/chatgit`: launcher for the Git-backed `codex-web-interface` for the current
  repository. Add `export PATH="$HOME/repos/ai-agent-learnings/scripts:$PATH"` to `.zshrc` or
  `.bashrc`, then run `chatgit` from any Git repo. Set `CHATGIT_PORT` to choose
  a non-default port. The server prints a path-style browser URL using the real
  filesystem path, such as `/home/name/repos/repo-name`. Browser links do not
  use `?repo=`; selecting another worktree updates the address bar to another
  path-style URL. Re-running
  `chatgit` against an already-running server prints the URL and exits without
  a traceback.
- `scripts/codex_web.py`: loopback web UI for Git-backed Codex conversations.
  When it creates a branch, it records `branch.<name>.parent-branch` and
  `branch.<name>.parent-commit` in Git config so the UI has an explicit
  parent-branch convention instead of inferring ancestry from worktree paths.
  Maintenance note: the current frontend is a small legacy plain-JS interface
  with known AI-generated rough edges, not a polished product shell; preserve
  the mobile composer/base-selection behavior before attempting broader UI
  rewrites.
- `scripts/codex_wrap.sh` / `scripts/codex_wrap.py`: Codex session wrapper only.
  It records start/resume/agent/stop marker commits and manages the live Codex
  process. It should not own branch or worktree placement. Start/resume marker
  commits include `called-by: user` unless `CODEX_WRAP_CALLED_BY=<commit>` is
  set by a dispatcher or parent agent. `codex_agents` lists live local wrapper
  agents from recent run-start commits cross-checked with live PIDs. Wrapper
  transcript bodies now live in `transcripts/archive/<date>-<slug>.md`, active
  state is a small pointer in `transcripts/active/<slug>.md`, and follow-up
  routing goes through `agents/<slug>/inbox.md`. `agents/<slug>/profile.md`
  stores run metadata and `transcripts/index.md` documents the layout while
  dispatch context lists the branch-local active/inbox files directly. The
  active pointer is deleted by stop/abort; archive transcript, inbox, and
  profile files remain. Tool call metadata is kept in
  `agents/<slug>/tool-calls.md` as a bounded summary table with timestamp, tool
  name, status, compact args summary/hash, and output byte count; raw tool
  outputs stay in ignored wrapper JSON/stderr logs. New wrapper runs do not
  create `active-agents/` artifacts.
- `scripts/agent_context.sh`: generates the Agent Context Pack used by
  dispatchers. It favors current branch state, active transcript pointers,
  relevant profiles/inboxes, and recent transcript tails over stale historical
  chatter. `agent_context.sh audit` prints parent/child run edges from profiles
  and marker metadata; `agent_context.sh prune-status STATUS.md` deletes
  completed checklist items so finished work remains in Git/transcript history
  rather than active status.
  `codex_commit` and the web UI do not push by themselves. Use
  `codex_sync_push` to fetch, rebase onto the configured upstream, and push; it
  is intentionally the shared end-of-session path for avoiding duplicate
  local/remote patch divergence. It refuses to run while a local Codex wrapper
  run is active, because rebasing active marker history can make live-run
  detection unstable. `codex_commit_push` runs that sync both before and after
  the Codex session.
- `scripts/codex-wrap/SKILL.md`: skill-style command guide for the Codex
  wrapper backend, including when to use `codex_commit`, `codex_resume`,
  `codex_new_message`, `codex_abort`, `codex_active`, and `codex_in_branch`.
- `scripts/parallel-worktrees/worktrees.sh`: shared worktree primitives for
  creating, finding, merging, and cleaning branch worktrees.
- `scripts/branch_commands.sh`: generic command placement helpers such as
  `do_at_branch`, `do_at_commit`, and thin tool-specific wrappers like
  `codex_in_branch`. It also exposes `codex_dispatch`, which sends one
  orchestration prompt to Codex. Dispatch context lists transcript/inbox files
  and requires agents to read `transcripts/index.md` plus relevant
  `agents/*/profile.md` files before routing follow-ups. It requires
  dispatchers to update the task surface (`STATUS.md`, and
  `agents/<slug>/inbox.md` for targeted follow-up when appropriate) and to use
  delegated `codex_spawn ...` calls with citations and `called-by`
  propagation for implementation work.
- `scripts/jj_project.sh`: experimental Jujutsu project-management helpers for
  representing TODO work as mutable `jj` changes. The helper is optional and
  fails clearly when `jj` is not installed. It can mirror active `STATUS.md`
  checklist items with `jj_task_plan_from_status`, create tasks from
  `agents/<slug>/inbox.md` with `jj_task_from_inbox`, and close/annotate work
  from transcript evidence with `jj_task_done_from_transcript`.

### `do_at` direction

Current branch-targeted execution is worktree-backed: `do_at_branch <branch>
<command...>` reuses or creates the branch's worktree, `do_at_commit <commit>
<command...>` creates a temporary branch/worktree rooted at that commit, and
`codex_in_branch @ <branch-or-commit> <prompt...>` is only a Codex-specific edge
around those generic helpers. Plain `codex_commit @ ...` remains prompt text; it
does not create or select worktrees.

An overlayfs or fuse-overlayfs backend may be useful later as an experimental
provider for cheap, disposable `do_at --commit <cmd>` views. Keep Git worktrees
as the stable provider for long-running agents until overlay sessions can prove
mount cleanup, writable diff materialization, branch/index isolation, `.git`
common-dir behavior, submodules/LFS, whiteouts/deletions, and crash recovery.

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

For ad hoc local orchestration, source `scripts/codex_wrap.sh` and
`scripts/branch_commands.sh`, then run `codex_dispatch "<instruction>"`. Use
this dispatcher path by default for future Hermes/Codex coding tasks that need
repository work beyond trivial chat or status. The dispatcher prompt first
reconciles the generated Agent Context Pack: branch, current HEAD, pruned
branch-local `STATUS.md`, active transcript pointers, relevant agent
profiles/inboxes, recent transcript tails, and parent/child audit edges. It then
classifies the request as `status-only`, `trivial-chat`,
`delegated-implementation`, `cleanup`, or `blocked`. Status-only and
trivial-chat requests should not spawn child agents. For delegated
implementation, the dispatcher should create or update the task surface first:
`STATUS.md` for current state and plan, `agents/<slug>/inbox.md` for targeted
follow-up when an agent already exists, and child `codex_spawn ...` calls for
implementation work. Broad implementation or recursive work must be delegated
with disjoint write scopes, cite the files/commits/transcripts or `STATUS.md`
evidence used, verify the child start markers, and use empty one-line checkpoint
commits shaped like `checkpoint: last save state before <reason>` before
disruptive work. Direct implementation inside the dispatcher should be limited
to tiny routing/glue fixes needed to decide delegation, update routing surfaces,
or fix the dispatcher itself.

`codex_spawn <codex_commit|codex_resume|codex_new_message|codex_in_branch>
<args...>` is the detached child-agent launcher. It starts the normal wrapper in
a new session with stdin closed and output redirected under
`.git/codex-wrap/dispatch/`, so children survive the dispatcher process exiting
while still writing the usual pid/cwd marker commits and transcript logs that
ChatGit uses for active-agent and run-history display. `codex_spawn` sets
`CODEX_WRAP_CALLED_BY` from `codex_active` by default; override it only when
deliberately attaching work to a different caller commit.

Typical dispatch calls:

```bash
codex_spawn codex_in_branch @ HEAD "implement the isolated task; cite STATUS.md and commits"
codex_spawn codex_commit "continue in this worktree with this narrow task"
codex_spawn codex_new_message "follow up on the active/latest session"
```

For long runs where marker commits become too noisy, `codex_status "<summary>"`
creates an empty `[status]` commit; include the relevant commit hashes in that
summary so future agents can recover the decision path without loading every
intermediate transcript commit.

### Tool-call logging size contract

Tool-call logs must stay summary-only. Raw command/provider outputs can easily
turn a repo into a transcript artifact store because shell commands, file reads,
test logs, and model tool results are often KB-to-MB each. The tracked
`agents/<slug>/tool-calls.md` contract records one bounded metadata row per
completed tool event and caps retained rows with `CODEX_WRAP_TOOL_LOG_LIMIT`
(default `200`). That should usually be KB per run, not MB. If a run needs raw
outputs for debugging, keep them in ignored local logs under `.git/codex-wrap/`
or attach them as explicit external artifacts, not as default tracked files.

## History Audits and Plans

- `history-prompt-flow-report.md`: timestamped audit of the reachable user
  prompt history, what the user asked for, what happened next, and which
  workflow changes are evidence-backed rather than impressionistic.
- `docs/plans/2026-05-02-transcript-inbox-orchestration.md`: critique and
  implementation plan for replacing marker-heavy commit-message transcripts
  with version-controlled `transcripts/` and `agents/<name>/inbox.md` files,
  explicit commit authors, branch-local instruction stacks, and optional `jj`
  task mirroring. The pre-change marker orchestration state is preserved at
  branch `archive/marker-orchestration-before-transcript-inbox`.

## Experimental Jujutsu Project Management

`scripts/jj_project.sh` is a small experiment for using Jujutsu's mutable change
DAG as a TODO/project-management surface. Source it after installing `jj`, run
`jj_project_init` once in a Git repo to colocate Jujutsu metadata, then use
`jj_task_new`, `jj_task_note`, `jj_task_done`, and `jj_task_log` to create and
review task-shaped changes.

For agent orchestration, mirror only active work into `jj`:

```bash
jj_task_plan_from_status STATUS.md
jj_task_from_inbox agents/<slug>/inbox.md
jj_task_done_from_transcript "summary" transcripts/archive/<file>.md
```

Completed `STATUS.md` checklist entries should be deleted, not mirrored again;
the durable source for finished work is Git history plus transcript/profile
files. Keep this experimental layer optional; do not make normal Git/Codex
workflows depend on `jj` until the pattern has proved useful on a real task.
