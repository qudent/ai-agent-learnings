# Prompt Flow History Report

Generated at Unix time `1777650890` from `git log --all` in
`/home/name/repos/ai-agent-learnings`.

## Method

- Reviewed reachable commits, including local and remote refs, after
  `git fetch --all --prune`.
- Treated commits whose subjects begin with `@codex`, `[codex_start_user]`, or
  `[codex_resume_user]` as user-intent evidence.
- Treated nearby implementation commits, merge commits, `[codex]` summaries,
  and `STATUS.md` changes as outcome evidence.
- Unix timestamps below are commit times (`%ct`) so prompt and outcome ordering
  can be compared mechanically.

## Summary Findings

- The user wanted a low-friction interface: type a request into the Git-backed
  chat/dispatch surface and have the right agent action happen without choosing
  low-level wrapper commands.
- The implementation often improved after explicit test contracts, but the
  flow repeatedly drifted into implicit state: active process state, branch
  ownership, queue state, and remote divergence were spread across marker
  commits, `STATUS.md`, live PIDs, and the web UI.
- The largest recurring failure was not missing code; it was unclear state
  reconciliation before acting. The history repeatedly shows follow-up prompts
  asking "where are you?", "what is active?", "why is this queued?", "why is
  this still ahead/behind?", or "what did you actually implement?"
- Marker commits made the Git log useful as a durable chat trace, but they also
  caused recurring local/remote divergence. The flow needs explicit state
  commits and active transcript artifacts, not unbounded marker noise on the
  primary branch.

## Itemized Prompt Timeline

| Prompt time | Prompt commit | User wanted | Outcome evidence | Result / gap |
| --- | --- | --- | --- | --- |
| `1777068218` | `526a6f2` | Start global agent coordination work from an `@codex` commit. | `5e57aaa` at `1777067804` consolidated global policy; later `110096f` at `1777069439` added dispatch. | Direction established, but early prompt subjects were too terse to recover exact intent without surrounding diffs. |
| `1777068430` | `a2b15ae` | Use commit messages as a chatlog. | `110096f` implemented branch-scoped dispatch and kept prompt commits as durable input. | Durable prompt history emerged, but marker commits later overloaded mainline history. |
| `1777069146` | `26c40d8` | Distinguish human input from agent output because human input is the durable part. | `110096f` and later wrapper marker conventions split `[codex_start_user]` from `[codex]`. | Good separation in commit subjects, but later `STATUS.md` and marker churn still mixed current state with transcript detail. |
| `1777072876` | `331d050` | Install branch dispatch guarded to the right host, use tmux/logs, and answer whether more commands can be added while running. | `e0b68f4` at `1777073624` switched to branch-ref dispatch; `fd7e16c` at `1777073982` split state/whiteboard at that time. | Event-driven dispatch and visibility improved. Later history shows the coordination surface changed again, so future prompts must inspect live repo docs before assuming the old whiteboard model. |
| `1777376199` | implicit via commits | Move back to a single `STATUS.md` coordination file. | `e88cda1` at `1777376199`, `d5b3e57` at `1777376574`, `a673d21` at `1777376604`. | Current repo contract became single `STATUS.md`. This superseded older whiteboard guidance. |
| `1777389968` | `43b909d` | Reconcile remote/local main in another repo and fix autosave autopush behavior. | `03e34e0` reported reconciliation and `104fef3` at `1777402673` added stale model antipattern. | Shows user wants real remote-state inspection, not assumptions. Also establishes that autosave should not silently become autopush. |
| `1777437125` | `45b9159` | Simple liveness check. | `[codex]` response only. | No implementation needed; future dispatch should classify this as `trivial-chat` and not spawn. |
| `1777486894` | `fe136bf` | Read edited `STATUS.md`, make a plan, give opinion. | `d826851` summarized read context. | Appropriate planning response, but no durable structured prompt inbox existed. |
| `1777487162` | `9fdef7c` | Make a TODO list; fix broken web branching first; integrate with ChatGit and stable conversations. | `d918a09` at `1777487612` added branch metadata tests. | Good: converted to tests before deeper UI changes. |
| `1777487200` | `f54ee7a` | Go through the TODO with minimal steps and test the web app. | `d918a09`, then `8b90162` at `1777487954` and `c770ca0` at `1777488043`. | Good implementation progress. Manual/browser verification remained uneven. |
| `1777487359` | `8ad96cf` | Use TDD; clearly specify desired web behavior, possibly in markdown tests. | `d918a09`, `6af2fff`, and `scripts/test_codex_web/WEB_BEHAVIOR.md`. | Strong success pattern. This is the clearest evidence that behavior contracts should precede UI implementation. |
| `1777487649` | `23f2350` | Confirm agent sees the user and is in the correct worktree. | `c61fb14` reported cwd/branch. | Useful status-only prompt; should be handled locally. |
| `1777487697` | `7d8665c` | Report current state. | `657c65c` reported branch and ahead state. | Good, but ahead/behind remained recurring. |
| `1777487821` | `c751e8c` | Support two web tabs issuing commands in parallel to different branches/worktrees. | `8b90162` isolated parallel tab branches; `c770ca0` completed three-pane UI. | Implemented, later expanded by recursive branch tests. |
| `1777488225` | `1c82f84` | Restart daemon; list current Codex sessions and origins. | `cb97fd7` reported PID, port, and script path. | Good live-process inspection pattern. |
| `1777488862` / `1777490814` | `6f0e661`, `8ba05e3` | Merge worktrees into main, reconcile, finish and clean them. | `d9a6c13`, `b889139`, `417bb31`; summaries around `73dc9c3`. | Completed, but conflict-prone `STATUS.md` and remote branch cleanup needed follow-up. |
| `1777491261` | `280f586` | Delete remote non-main branches too. | `b9660b1`; `87843e3` confirmed only remote main remained. | Good verification; this is a model for cleanup prompts. |
| `1777492152` / `1777492192` | `bbf9bc5`, `7e78746` | Create a dev worktree and run a second web UI on another port. | `db34207`, `f4c48f6`. | Done, but creating `dev` through a generic helper exposed missing parent metadata. |
| `1777492466` | `39e7422` | Wishlist: auto-update path changes, transcript access from process list, branch rename, clearer state. | `f34a3a6`, `ec3908c`, `71a1add`, `a460109`. | Mostly implemented through incremental UI passes; roundtrip/performance later needed more work. |
| `1777492613` | `20ee50d` | Show active branches visually; support chatbox uploads. | `f34a3a6`, `f801d13`, `a7a720d`. | Implemented, with later refinements to active semantics and attachments. |
| `1777492700` / `1777492851` | `3e67529`, `e0f93ad` | `main` and `dev` should not both look like root conversations; commands had drifted. | Parent metadata fixes and `fcac97f` recursive branch tests. | Root cause found: generic worktree creation lacked web parent metadata. |
| `1777492921` | `2416ed9` | Implement queuing and recursive branches in the new branch, then merge from parent and finish. | `fcac97f` at `1777493198`; `f34a3a6`; merge commits `45f0d25`, `5ef1050`. | Implemented with tests, but queue wording remained confusing later. |
| `1777493841` | `d748e60` | Use paste/drag-drop instead of attach screenshot button; clarify active branch semantics. | `f801d13` at `1777493990`; later `0f87b44`. | Paste/drop implemented; active semantics required additional bug fixes. |
| `1777494281` | `9ccb5e5` | Explain attachment storage; allow removing attachments; support arbitrary files. | `a7a720d` at `1777494442`; summary `5193a7d`. | Implemented and documented in UI behavior contract. |
| `1777494873` | `0e98811` | Count LOC and compare frontend wishlist to implementation; left bar looked chaotic. | `67664a0` reported LOC; later `71a1add`, `a460109`, `2b84ca7`. | The report happened; UI cleanup continued in several small fixes. |
| `1777494923` | `a530edb` | Investigate marker/empty commits not appearing until refresh, with regression test. | `ec3908c` at `1777495029`. | Fixed auto-refresh; later selection-preserving refresh also needed. |
| `1777495014` | `2eeb3dc` | Fix overflow from attached screenshot report; merge from parent. | `dc1b97a` at `1777495213`. | Fixed containment and preserved parent changes. |
| `1777495976` | `76efbf6` | Finished branches should be split active/archived or not clutter the UI. | `71a1add` at `1777496728`. | Implemented active/closed worktree run grouping. |
| `1777501138` | `b083847` | Measure slow load roundtrips; investigate stale open transcripts and left-pane sizing. | `a460109` at `1777501526`; `e113ef5`, `b37b388`. | Improved refresh/run layout and stale-run cleanup. |
| `1777502350` | `7f54469` | Evaluate a proposed left-bar redesign. | `8395543` replied with critique; later `a07ec73`, `2b84ca7`. | Useful design analysis, but implementation was incremental. |
| `1777502541` | `23479f0` | Preserve text selection; clarify detail copy text; selected commit should show patch. | `0aec54d`, `a07ec73`, `cd39de5`. | Implemented selection preservation, copy behavior, and row click detail. |
| `1777502716` | `1e1468e` | Add copy-message buttons; clarify send/queue semantics. | `608cf15` at `1777505398`. | Implemented explicit queue action and clearer controls after more critique. |
| `1777503082` | `f2de1a3` | Clicking a commit should do something. | `cd39de5` at `1777503283`. | Fixed row click to open patch/detail. |
| `1777503371` | `d536430` | Fix button spacing from screenshot evidence. | `34272af` at `1777503623`. | Fixed spacing. |
| `1777503995` | `ac60b99` | Respond to broad UI critique: too many buttons, weak hierarchy, ugly header/palette, dense text. | `2b84ca7`, `608cf15`. | UI improved, and `frontend-design.md` later captured reusable lessons. |
| `1777505067` | `bd2d3bc` | Detail copy was unclear; abort should be near run controls; queue should be explicit. | `608cf15` at `1777505398`. | Implemented clearer detail hint and queue/run controls. |
| `1777506026` | `8525b4b` | Continue button blocked by active-run state even when nothing looked active. | `ac0d11c` at `1777506221`. | Root cause found: API returned `{}` instead of `null`; fixed. |
| `1777506473` | `37acbd4` | Branch from message should work in parallel despite active parent run. | `0f87b44` at `1777506562`. | Fixed by bypassing same-worktree active guard for branch creation. |
| `1777537298` | `5de0df1` | Merge from `dev`, restart web UI, thoroughly test UI and find issues. | `1dc79c7`, `11b1aea`; summary `ee39ff2`. | Merged and restarted. Manual testing found issues but did not eliminate all process-state ambiguity. |
| `1777545464` | `d828568` | Write a backend skill for Codex wrapper commands. | `7d18f0d` at `1777545582`. | Implemented `scripts/codex-wrap/SKILL.md`. |
| `1777549537` | `061ad01` | Go through commit history and write all frontend design instructions as markdown. | `8403159` at `1777549764`. | Implemented `frontend-design.md`; strong example of history-driven synthesis. |
| `1777641371` | `83a3d90` | Commit human-edited `STATUS.md`, then do/delegate relevant tasks. | `97a5081`, `4e8ba1e`, `baeead6`. | Tasks landed, but generic "do/delegate relevant tasks" made intent extraction fragile. |
| `1777643686` | `61cb1b6` | Path should be selectable/visible from URL; remove header; add dispatch button; sync button questionable. | `ad2098c`, `d90d6c3`, `9359781`, `97094a1`. | URL/path behavior needed multiple corrections; `/repos` was initially elided and later restored. |
| `1777644732` | `7eb0be5` | Dispatch ChatGit path/restart work. | `35739ac` dispatched two workers. | Dispatch worked mechanically, but later evidence showed dispatch could stall or produce marker-only branches. |
| `1777644922` | `ec614fa` | Fix run-history click behavior and branch selection issues. | `8b0f22a`, `74d43d4`, `ec19d11`. | Parent aborted stalled dispatcher and fixed directly. Evidence supports classifying direct vs parallel work more carefully. |
| `1777645743` | `c645952` | `hey`. | `27c8064`, `46748a6` said no dispatch needed. | Correct behavior: trivial chat should not spawn. This should be explicit in dispatcher prompt. |
| `1777647632` | `21ebfa1` | Thorough cleanup/audit of current inconsistencies. | `d3b3003`, `c3f4ad1` dispatched one worker. | Sensible to use one worker due shared files, but follow-up showed status visibility was still weak. |
| `1777647632` | `992a537` | Ask whether there is a `codex_wrap status` overview. | `fdb80e4`, then `b97b8c6` added `codex_agents`. | Partial status command improved live agent visibility. |
| `1777647632` | `ed52233` / `e55fecb` | Process new `STATUS.md` prompts. | `3729334`, `6fe8a54`, `14646f3`, `91fb47a`. | Added active-run guard for `codex_sync_push`; proved rebase during active run destabilized process evidence. |
| `1777648438` | `95a2270` | Dispatch implementation from current context. | `076660d` dispatched worker, but later `9865801` says the worker initially had only marker commits. | Strong evidence for post-spawn verification and marker-only/no-op detection. |
| `1777648904` | `db7444a` | Dispatch contract did not clearly say how to call `codex_*` commands or what they do. | `eac9b30`, `d5c5537`, `9865801`. | Fixed contract/docs, but the gap proves prompt templates must include command quick references. |
| `1777649625` | `9ee3fcb` | Audit recent `STATUS.md` and prompts; find missed changes; recurring ahead/behind still present. | `182e81d`, `a858e8b`. | Audit captured misses, but current state still had marker/autosave divergence. This motivated active-agent files plus stricter sync/classification. |
| `1777650737` | `51273ae` | Red contract for active-agent artifact lifecycle. | Test failed at missing `active-agents/<run>.md`. | Intentional failing commit preserved in history. |
| `1777650843` | `7f9a5fa` | Implement tracked active-agent artifacts. | Wrapper suite passed; active files are added while live and removed on stop/abort. | Addresses current transcript visibility while preserving Git history. |
| `1777650867` | `077c34c` | Make dispatch classify requests before spawning. | Dispatch prompt now classifies status/trivial/direct/parallel/cleanup/blocked and requires post-spawn verification. | Addresses "type into the thing and it should work" without spawning for every input. |

## Evidence-Backed Flow Improvements

1. Keep a clear Git-log update path:
   - User prompts remain durable commits.
   - `codex_status "<summary>"` remains the explicit empty state-update commit.
   - Active runs now write tracked `active-agents/<run>.md` files while live.
   - Stop/abort commits delete those files from `HEAD`, preserving them in
     history.

2. Dispatch should classify before acting:
   - `trivial-chat` and `status-only` answer locally.
   - `direct-implementation` is allowed when spawning would add ceremony.
   - `parallel-dispatch` requires disjoint write scopes and child marker
     verification.
   - `blocked` should name the missing state or unsafe condition.

3. Prompt intake should avoid vague "do/delegate relevant tasks":
   - The history shows this wording caused missed changes.
   - A future improvement is a structured prompt inbox in `STATUS.md`, where
     every new human prompt is moved to `Active Goals`, `Done`, or `Blocked`.

4. Active state must be grounded in live process evidence:
   - Marker commits alone were insufficient.
   - The reliable pattern is run-start metadata plus live PID check plus
     worktree cwd plus active-agent file.

5. Frontend work should continue using behavior contracts:
   - The best UI changes followed markdown/executable tests.
   - The worst loops came from subjective UI fixes without enough state
     semantics.
