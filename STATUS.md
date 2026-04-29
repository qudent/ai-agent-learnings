# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance for local AI coding agents.
`AGENTS.md` is the canonical global instruction source, global agent config
files symlink to it, and branch-ref dispatch remains a policy pattern rather
than a tracked helper-script implementation in this repo.

`STATUS.md` is now the single coordination source of truth for project state,
active human prompts, agent replies, handoff notes, open questions, and TODO
plans. The separate human-agent whiteboard pattern is retired.

## Active Human Prompts
- Remove human-agent whiteboards and integrate active coordination into
  `STATUS.md` as the source of truth.
- Keep coordination plain and simple: the human writes what they want, the agent
  replies with what they need to reply, and the current coordination file is
  committed and pushed whenever there is meaningful new information.
- Fix the `codex_commit` interactive job-control `setsid` bug, commit that
  regression fix, then move the wrapper engine from shell to Python while
  keeping the sourced shell function interface.
- Fix `[codex]` marker folding so repeated agent messages amend into one clean
  commit body without recursive `previous [codex]` sections or duplicated
  embedded commit messages.
- Tighten the folding tests to specify the exact `[codex]` commit body and
  preserve the original metadata block on amend instead of rewriting it.
- Keep branch/worktree placement out of the Codex wrapper; use the shared
  parallel-worktrees primitives through generic `do_at_branch`/`do_at_commit`
  helpers, with `codex_in_branch` as thin sugar.

## Active Goals
- [x] Keep global agent instructions centralized in `~/learnings/AGENTS.md`.
- [x] Maintain project-agnostic learnings and workflow guardrails.
- [x] Support branch-ref dispatch where each branch is worked in its own
  worktree.
- [x] Use `STATUS.md` as the single coordination file instead of splitting state
  and communication across a whiteboard.

## TODO Plan
- [ ] Watch the next real branch-update dispatch log under
  `/home/name/agent-dispatch-logs` and tighten hook behavior if Git reports an
  unexpected ref-update edge case.
- [ ] When touching existing project repos, remove stale whiteboard files only
  when the active context has been preserved in `STATUS.md`.
- [ ] After the Python wrapper lands, run one live `codex_commit` smoke from an
  interactive shell before treating the migration as fully proven.
- [ ] Review whether the legacy `parallel-worktrees` skill should keep
  destructive `worktree_abort`/`worktree_finish` semantics before building more
  automation on top of it.

## Blockers
- None.

## Recent Results
- Fixed the shell wrapper's interactive job-control `setsid` PID tracking bug
  with a regression test; committed as `11c5765`.
- Replaced the shell implementation with a Python engine behind the same
  `codex_commit`/`codex_resume`/`codex_abort`/`codex_new_message` functions;
  the fake-Codex wrapper suite and `py_compile` pass.
- Corrected Python marker folding to keep newest agent text first and prior
  text as plain body content only; regression tests now reject `previous
  [codex]` and embedded old `[codex]` subjects.
- Tightened `[codex]` folding again: exact-shape tests now compare the whole
  commit body, and amend paths keep existing `session-id`/`run-start` metadata.
- Split branch/worktree execution back out of Codex: `codex_wrap` no longer
  handles `@`, `scripts/branch_commands.sh` provides `do_at_branch`,
  `do_at_commit`, and `codex_in_branch`, and it delegates worktree primitives to
  `scripts/parallel-worktrees/worktrees.sh`.
- Replaced ordinary `agent/<tool>/<branch>` dispatch semantics with
  branch-owned worktree dispatch.
- Removed `HUMAN_AGENTS_WHITEBOARD.md`; active coordination now belongs in
  `STATUS.md`.
- Removed tracked dispatcher/logging helper scripts from `scripts/` and cleaned
  stale documentation references to them.
- Updated coordination policy back to one file: `STATUS.md` contains state,
  active prompts, open questions, agent notes, and TODO plans.

## Agent Notes
- Tracked dispatcher/logging helper scripts are no longer present in this repo;
  keep future docs at the policy level unless a replacement implementation is
  added.
- Stable repo instructions still belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic learnings.
