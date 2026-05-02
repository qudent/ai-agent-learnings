---
agent: you-are-a-dispatch-fb53c6b
kind: codex
status: active
branch: main
worktree: /home/name/repos/ai-agent-learnings
parent: user
session_id: 019dea56-687e-7a60-aa08-2f77892bbbdc
run_start_commit: fb53c6bd2c3f0c8788d656225276cc2199daea88
created_at: 2026-05-02T20:17:04+0000
transcript: transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md
inbox: agents/you-are-a-dispatch-fb53c6b/inbox.md
tool_calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
---

# you-are-a-dispatch-fb53c6b

Task: You are a Codex dispatch/orchestration agent. Do not complete the requested implementation yourself unless it is needed only to decide dispatch.

User instruction:
User correction: Hermes should route future coding tasks through the Codex dispatcher/wrapper by default, not raw Codex or manual implementation. Review the current wrapper/dispatcher surface in this repo for stale behavior: codex_dispatch currently allows 'direct-implementation', but the desired state is that dispatcher reconciles the Agent Context Pack and creates/updates task work (STATUS.md, agents/<slug>/inbox.md, codex_spawn child tasks) rather than doing broad implementation itself. Make the minimal docs/instruction/wrapper-surface changes needed so future Hermes/Codex agents follow that. Keep STATUS.md current-only. Commit changes with a clear non-autosave subject. Do not run paid external APIs. After spawning any children or changing files, report exact files and tests.

Relevant concise context:
# Agent Context Pack

- branch: main
- head: 7b35eae
- generated_at: 2026-05-02T20:17:03Z

## Current STATUS.md
# AI Agent Learnings - Status

## Current State
`main` contains the context-pack refactor and current status refresh. `codex_dispatch` now injects `scripts/agent_context.sh context --limit 80`, and the Codex wrapper writes branch-local transcript/profile/inbox/tool-call files. ChatGit is running on port `6174` and sources the current wrapper/branch helper files for each run, so dispatch-mode web executions will use the context-pack path.

## Active Goals
- [ ] Keep Agent Context Pack size useful and bounded; monitor real dispatch prompts once active agents exist.
- [ ] Verify performance impact empirically on the next few dispatcher runs rather than assuming it from structure alone.

## TODO Plan
- [ ] After the next `codex_dispatch` run, inspect its start prompt/log and compare task routing quality, context length, and whether stale transcript replay was avoided.

## Blockers
- No active Codex agents or `agents/`/`transcripts/` files exist in the repo right now, so the current context-pack output only exercises the idle/no-active-agent path.

## Recent Results
- Current idle Agent Context Pack is 76 lines / 3,582 bytes / roughly 900 tokens, mostly current `STATUS.md` plus compact recent commit audit.
- Last-hour local work updated global guidance in `AGENTS.md`: `4d49e81` codified voice/action-continuation behavior, and `ee88e26` added exponential-backoff guidance for process waits.
- Process check shows ChatGit (`scripts/codex_web.py`) still running on port `6174` and Hermes gateway running since `2026-05-02 19:33:56`; no live Codex wrapper processes are currently active.

## Agent Notes
- The context-pack design likely improves dispatcher performance for multi-agent routing by replacing stale full marker prompt replay with current status, active transcript pointers, recent tails, and parent/child audit edges. Risk is prompt bloat once many agents/transcripts exist; current caps (`--limit 80`, first 5 profiles when idle, audit 30) make the idle path small, but real active-agent packs still need measured follow-up.
- Hermes itself is not a Codex wrapper execution. This Discord/Hermes session has loaded the updated repo instructions from `AGENTS.md`, but only Codex runs launched through `codex_dispatch`/ChatGit dispatch mode receive the generated Agent Context Pack.


## Active transcript pointers
none

## Relevant agent profiles and inboxes
none

## Current transcript excerpts
none

## Audit trail
# Agent Audit Trail

## Profile edges

## Recent run/update commits
- 7b35eae	qudent	docs: update context pack status
- ee88e26	qudent	docs: require backoff for process waits
- 4d49e81	qudent	docs: codify voice and action continuation
- b13db97	qudent	feat: add dispatch context and bounded tool logs
- 2857ff8	qudent	feat: simplify transcript pointer commits
- d988bb0	qudent	docs: update transcript inbox implementation status
- 5770bf7	qudent	docs: route dispatch through transcript inbox files
- a6ad16c	qudent	feat: route follow-up messages through agent inboxes
- 18c29d4	qudent	feat: set wrapper commit authors by speaker
- 776c02f	qudent	feat: store wrapper transcripts and inboxes as files
- 8c4e821	qudent	feat: add transcript inbox naming helpers
- 365c530	qudent	test: define transcript inbox contract
- 1a1f68d	qudent	docs: plan transcript inbox orchestration
- d291d83	qudent	Mark prompt flow work ready to push
- d2a0bc7	qudent	Merge remote-tracking branch 'origin/main'
- 223e161	qudent	Record active agent validation status
- f3cbae1	qudent	Document prompt flow audit and active agents
- 077c34c	qudent	Classify dispatch requests before spawning
- 7f9a5fa	qudent	Track active agent artifacts through run lifecycle
- 51273ae	qudent	Add failing active agent artifact contract
- 907223e	qudent	[codex_stop] 019de42c-a9a2-7f10-9dd6-33f33fc4ddd7
- a858e8b	qudent	[codex] <assistant elided>
- 31738d4	qudent	[autosave]
- b9c93b6	qudent	[autosave]
- 02581d1	qudent	[autosave]
- 0c7d333	qudent	[codex] <assistant elided>
- 182e81d	qudent	Merge remote-tracking branch 'origin/main'
- 3a4c084	qudent	[codex] <assistant elided>
- 9ee3fcb	qudent	[codex_start_user] <prompt elided> | called-by: user
- f105d84	qudent	[codex_stop] 019de421-a726-76d1-80c8-9890dd936be7

Dispatch contract:
- First reconcile state from the Agent Context Pack: branch/worktree, upstream divergence if visible, active local wrapper runs, queued work, current STATUS goals, active transcript pointers, inboxes, recent transcript excerpts, and the audit trail.
- Classify the request as exactly one of: status-only, trivial-chat, direct-implementation, parallel-dispatch, cleanup, or blocked.
- If status-only or trivial-chat, do not spawn; answer directly in the final status.
- If implementation/subagent work is needed, prefer dispatch/delegation: split into independent, reviewable tasks with disjoint write scopes and call child agents through codex_spawn rather than doing broad work in the dispatcher.
- Do direct implementation locally only for the tiny glue needed to decide dispatch, unblock routing, or fix the dispatcher itself; otherwise delegate.
- Inspect currently running sessions before dispatching: compare recent run-start marker pid/cwd metadata with the live process table above, then decide whether to call codex_commit, codex_new_message/codex_continue-style followup, codex_abort, or explicitly report blocked-by.
- Read transcripts/index.md and the relevant agents/*/profile.md before routing follow-ups or spawning related work.
- Send follow-ups through codex_new_message or a target agents/<slug>/inbox.md update; do not embed full transcript bodies into new marker commits.
- Spawn new agents with named task scopes that map cleanly to readable agent slugs and disjoint branch/worktree ownership.
- Source the helpers before calling them: . scripts/codex_wrap.sh && . scripts/branch_commands.sh.
- Use codex_spawn for child implementation agents so they run detached from the dispatcher and survive this dispatcher exiting. The web UI will still show them because codex_spawn runs the normal wrapper, which writes pid/cwd marker commits and transcript files.
- After each codex_spawn call, verify that a child start marker appears with the expected called-by, branch/worktree cwd, pid, and dispatch log path. If a child produces only marker commits and no useful diff, report it as marker-only/no-op.
- Command quick reference:
  - codex_spawn codex_in_branch @ <branch-or-commit> "<prompt>": detached child in a branch/worktree rooted at the target.
  - codex_spawn codex_commit "<prompt>": detached child in the current worktree.
  - codex_spawn codex_new_message "<prompt>": detached followup to the active/latest session.
  - codex_abort [run-start-commit]: stop an active wrapper run.
  - codex_agents: list live local wrapper agents from marker commits and live PIDs.
- End with a single round of codex_spawn calls, or codex_abort only when aborting is the task, then stop.
- Leave the actual work and followup to the called agents.
- codex_spawn sets CODEX_WRAP_CALLED_BY from codex_active by default; set CODEX_WRAP_CALLED_BY explicitly only when you need to override that caller.
- Include concise citations in dispatched prompts and your final status: cite commit hashes, branch names, STATUS.md sections, and file paths that justify each task.
- For long work, create periodic empty [status] commits that summarize the last interval and cite the commit hashes that matter for the next agent context.
- Use one-line empty checkpoint commits before disruptive work, for example: git commit --allow-empty -m "checkpoint: last save state before <work>".
- Finish with a quick status update saying what kind of work was dispatched and where.

## Logs
- json: /home/name/repos/ai-agent-learnings/.git/codex-wrap/logs/fb53c6bd2c3f0c8788d656225276cc2199daea88.jsonl
- stderr: /home/name/repos/ai-agent-learnings/.git/codex-wrap/logs/fb53c6bd2c3f0c8788d656225276cc2199daea88.stderr
