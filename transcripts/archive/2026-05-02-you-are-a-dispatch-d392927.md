---
agent: you-are-a-dispatch-d392927
kind: codex
branch: main
status: active
session_id: 019dea72-f4e1-7b32-87f0-1908d8e54d5f
run_start_commit: d39292779432a65a5d401822ab761a1467dda85b
---

# Transcript: you-are-a-dispatch-d392927

## 2026-05-02T20:48:15+0000 user

You are a Codex dispatch/orchestration agent. Do not complete broad implementation yourself; reconcile context and route work through the wrapper surface.

User instruction:
User correction / architecture change request: The current dispatcher pattern still risks ceremony without work. Update ai-agent-learnings so Codex dispatch is an active orchestration thread, not just a trampoline. Desired contract: dispatcher must inspect input, active runs, pids/called-by/context, decide interruption/follow-up/spawn/status, update STATUS.md/JJ-style task surface, and do at least one meaningful routing/work thread itself before stopping. Broad implementation can still be delegated, but dispatcher should not be forbidden from doing routing glue or the first slice. Review and update branch_commands.sh prompt, tests, docs/skills/status accordingly. Also: decide whether subagents should receive the Agent Context Pack; likely yes, but bounded/fresh, and implement/update prompt surface so spawned children receive or can generate the relevant pack. Improve context pack agent-friendliness by avoiding stale full dispatcher prompt replay from finished profiles. Check JJ: repo has jj installed/.jj; integrate helper guidance or task-DAG surface if practical without overbuilding. Tool-call log rows should include compact timestamp and caller metadata; consider Unix epoch or dual compact time, and include caller. Clarify transcripts/active vs transcripts/archive pointer/body semantics. Add a Hermes skill for checking/watching a repo that outputs the Agent Context Pack as user source of truth; if a full cron/watch implementation is too much, add a reusable skill with commands for one-shot check-in and cron scheduling. Keep STATUS.md current-only. Run focused tests and commit. Use codex_spawn children only if useful; otherwise dispatcher can implement the focused changes itself.

Relevant concise context:
# Agent Context Pack

- branch: main
- head: df22c2e
- generated_at: 2026-05-02T20:48:14Z

## Current STATUS.md
# AI Agent Learnings - Status

## Current State
`main` contains the context-pack refactor and the dispatcher-first routing update. Future Hermes/Codex coding tasks that need non-trivial repository work should use `codex_dispatch` by default; dispatchers reconcile the Agent Context Pack, update task routing surfaces (`STATUS.md` and targeted `agents/<slug>/inbox.md` when appropriate), and delegate broad implementation through `codex_spawn` children. ChatGit is running on port `6174` and sources the current wrapper/branch helper files for dispatch-mode executions.

## Active Goals
- [ ] Keep Agent Context Pack size useful and bounded; monitor real active-agent dispatch prompts.
- [ ] Audit cross-repo wrapper artifacts and stale surfaces so RepoProver-style coding work uses the dispatcher path when available.

## TODO Plan
- [ ] Summarize cross-repo findings for the current Hermes thread: `ai-agent-learnings` owns the wrapper/context code; `repoprover` has wrapper-generated transcript artifacts but no local wrapper scripts; `endepromotion` only had unrelated recent commits.

## Blockers
- None for the dispatcher contract update. Empirical performance still needs more real multi-agent runs with active transcript/profile state.

## Recent Results
- A real `codex_dispatch` run from Hermes created dispatcher run `fb53c6b`, spawned child branch `work-99f3c2f-20260502-201821-0`, and child commit `c226410 Update Codex dispatcher routing contract` updated the stale `direct-implementation` surface.
- Dispatcher-first routing update is on `main` as `ac1b255 Update Codex dispatcher routing contract`; focused validation passed with `python3 -m py_compile scripts/codex_wrap.py`, `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`, and `bash scripts/test_agent_context/test_agent_context.sh scripts/agent_context.sh`.
- Cross-repo scan found 45 git repos and 3 relevant/recent repos: `ai-agent-learnings`, `repoprover`, and unrelated recent `endepromotion`. Context-pack measurements: `ai-agent-learnings` active run 250 lines / 19,097 bytes; after stale active-pointer cleanup 222 lines / 18,156 bytes; RepoProver 192 lines / 11,479 bytes.

## Agent Notes
- Hermes itself is not automatically a Codex wrapper execution. The durable fix is instruction-level: this repo's global `AGENTS.md` now says non-trivial Hermes/Codex coding tasks should route through `codex_dispatch` by default when the wrapper is available.
- The prior dispatcher prompt was stale: it exposed `direct-implementation` and `parallel-dispatch`. The updated contract classifies only `status-only`, `trivial-chat`, `delegated-implementation`, `cleanup`, or `blocked`.


## Active transcript pointers
none

## Relevant agent profiles and inboxes

### agents/you-are-a-dispatch-fb53c6b/profile.md
---
agent: you-are-a-dispatch-fb53c6b
kind: codex
status: finished
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

### Transcript tail: transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md
... omitted 63 older transcript lines ...
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

## 2026-05-02T20:17:27+0000 codex:you-are-a-dispatch-fb53c6b

I’ll treat this as dispatcher work: first reconcile the branch state and wrapper surface, then spawn a child through the repo’s Codex wrapper with a narrow implementation scope. I’m not going to edit the docs or wrapper locally unless inspection shows dispatch itself is broken.

## 2026-05-02T20:17:37+0000 codex:you-are-a-dispatch-fb53c6b

The current surface still names `direct-implementation` in both the generated dispatch prompt and README, and `AGENTS.md` only says use the dispatcher when work is split. I’m checking the live wrapper functions and active sessions before deciding the child task shape.

## 2026-05-02T20:17:48+0000 codex:you-are-a-dispatch-fb53c6b

`codex_agents` reports one live wrapper run at commit `fb53c6b` in this worktree. I’m checking whether that is an active dispatcher/session I should follow up instead of creating a competing child.

## 2026-05-02T20:18:08+0000 codex:you-are-a-dispatch-fb53c6b

This is an implementation request, but it is specifically about changing dispatcher behavior, so I’m classifying it as delegated implementation with one narrow child. The child will own the docs/wrapper/test/status edits and commit them; I’ll only verify the start marker here.

## 2026-05-02T20:18:30+0000 codex:you-are-a-dispatch-fb53c6b

The child was spawned with `called-by=fb53c6b` and a dispatch log under `.git/codex-wrap/dispatch/20260502-201821-3751126.log`. I’m waiting just long enough to confirm the wrapper wrote its start marker with the branch/worktree metadata.

## Audit trail
# Agent Audit Trail

## Profile edges
- user -> fb53c6bd2c3f0c8788d656225276cc2199daea88 | agent=you-are-a-dispatch-fb53c6b | profile=agents/you-are-a-dispatch-fb53c6b/profile.md | transcript=transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md

## Recent run/update commits
- df22c2e	qudent	Mark dispatcher run finished
- ac1b255	qudent	Update Codex dispatcher routing contract
- 9b26e24	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 86a3187	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 0386821	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- b4c2da8	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 290b8b9	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- a380eb9	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 405139a	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 58fb4c0	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- cd2571f	codex:you-are-a-dispatch-fb53c6b	codex: update you-are-a-dispatch-fb53c6b | transcript: transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md
- 38a4fbc	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 99f3c2f	codex:you-are-a-dispatch-fb53c6b	codex: update you-are-a-dispatch-fb53c6b | transcript: transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md
- d93c656	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 1bc6f23	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 11736b8	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- c785be8	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 5537f1c	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- fce0904	codex:you-are-a-dispatch-fb53c6b	codex: update you-are-a-dispatch-fb53c6b | transcript: transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md
- 322c9d5	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 69b990e	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 3325868	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 5d6d19a	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 0989b60	codex:you-are-a-dispatch-fb53c6b	codex: update you-are-a-dispatch-fb53c6b | transcript: transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md
- 509fda1	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 97c672b	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- e78c90d	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- 7bd00e4	codex:you-are-a-dispatch-fb53c6b	tool: update you-are-a-dispatch-fb53c6b | tool-calls: agents/you-are-a-dispatch-fb53c6b/tool-calls.md
- d24c31c	codex:you-are-a-dispatch-fb53c6b	codex: update you-are-a-dispatch-fb53c6b | transcript: transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md
- 2c79d28	user	[transcript] start you-are-a-dispatch-fb53c6b | transcript: transcripts/archive/2026-05-02-you-are-a-dispatch-fb53c6b.md

Dispatch contract:
- First reconcile state from the Agent Context Pack: branch/worktree, upstream divergence if visible, active local wrapper runs, queued work, current STATUS goals, active transcript pointers, inboxes, recent transcript excerpts, and the audit trail.
- Classify the request as exactly one of: status-only, trivial-chat, delegated-implementation, cleanup, or blocked.
- If status-only or trivial-chat, do not spawn; answer directly in the final status.
- If delegated-implementation is needed, create or update the task surface first: STATUS.md for current state and plan, agents/<slug>/inbox.md for targeted follow-up when an agent already exists, and codex_spawn child tasks for implementation work.
- Broad implementation must be delegated via codex_spawn: split into independent, reviewable tasks with disjoint write scopes and call child agents rather than doing broad work in the dispatcher.
- Do local implementation only for the tiny glue needed to decide dispatch, unblock routing, update task routing surfaces, or fix the dispatcher itself; otherwise delegate.
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

## 2026-05-02T20:48:36+0000 codex:you-are-a-dispatch-d392927

I’ll first reconcile the live repo state against the supplied context, then decide whether to spawn a child or keep this as a bounded dispatcher-owned change. I’m also checking the learnings memory because this task is directly about the wrapper/dispatcher surface.

## 2026-05-02T20:48:48+0000 codex:you-are-a-dispatch-d392927

The repo is on `main` and ahead of `origin/main` by two commits, with no short-status dirt reported. I also found an active transcript/profile for a newer dispatcher run, so I’m checking live wrapper state before changing or spawning anything.

## 2026-05-02T20:49:08+0000 codex:you-are-a-dispatch-d392927

`codex_agents` reports one live run, `d392927`, in this worktree, which matches the active dispatcher profile for this task. I’m classifying this as dispatcher-owned first-slice work rather than spawning a competing child: the requested changes are focused on the dispatcher contract itself, and the active run is already the right routing thread.

## 2026-05-02T20:49:20+0000 codex:you-are-a-dispatch-d392927

The current code already has an optional `jj_project.sh` helper and a context generator, but the dispatch prompt still frames dispatch mostly as delegation and the child prompt path doesn’t explicitly include a bounded fresh Agent Context Pack. I’m going to edit the wrapper prompt, context/tool-call metadata, tests, README/skill guidance, and `STATUS.md` as one coherent dispatcher contract update.

## 2026-05-02T20:50:00+0000 codex:you-are-a-dispatch-d392927

Before editing, I confirmed `jj` is installed and this repo has `.jj`, so I’m keeping that layer optional but visible in the context pack instead of making it a hard dependency. The edits will be scoped to wrapper orchestration surfaces, context generation, the README/skill docs, focused tests, and current `STATUS.md`.
