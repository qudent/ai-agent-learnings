# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch, and
`chatgit`/`codex_web.py` for the small local web UI.

## Active Goals
ok do the things. you should look at the diff of local dev and check if there is anything left there worth keeping
name@theserver:~/repos/ai-agent-learnings$ chatgit
chatgit: http://127.0.0.1:6174/?repo=%2Fhome%2Fname%2Frepos%2Fai-agent-learnings
codex-web-interface: http://127.0.0.1:6174/?repo=%2Fhome%2Fname%2Frepos%2Fai-agent-learnings
repo: /home/name/repos/ai-agent-learnings
wrapper: /home/name/repos/ai-agent-learnings/scripts/codex_wrap.sh
Traceback (most recent call last):
  File "/home/name/repos/ai-agent-learnings/scripts/codex_web.py", line 726, in <module>
    if __name__=='__main__': main()
                             ^^^^^^
  File "/home/name/repos/ai-agent-learnings/scripts/codex_web.py", line 725, in main
    ThreadingHTTPServer(('127.0.0.1',ns.port),H).serve_forever()
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/lib/python3.12/socketserver.py", line 457, in __init__
    self.server_bind()
  File "/usr/lib/python3.12/http/server.py", line 136, in server_bind
    socketserver.TCPServer.server_bind(self)
  File "/usr/lib/python3.12/socketserver.py", line 473, in server_bind
    self.socket.bind(self.server_address)
OSError: [Errno 98] Address already in use
name@theserver:~/repos/ai-agent-learnings$ 

you didn't do the goal that it should be graceful when already running.
go through the STATUS.md history once again and check my tasks and whether you skipped some of them.

also http://127.0.0.1:6174/?repo=%2Fhome%2Fname%2Frepos%2Frepoprover is ugly
I want http://127.0.0.1:6174/home/name/repoprover

do the jj in branch now. clean up stale branches report to me. are you doing dispatch now?
also update README.md and testing (you do tdd) for the dispatch you made?

path-style repo URLs while keeping the old query-string form as a compatibility path nonono no compatibility path!

- [ ] Decide whether to merge, preserve, or delete local `dev` and
  `origin/dev`; local `dev` is still checked out in its own worktree.
- [ ] Install `jj` before trying the Jujutsu helper on a real task.

## TODO Plan
- [x] Patch `scripts/codex_web.py` branch creation.
- [x] Add shell behavior coverage for prompt-derived names and duplicate-name
  suffixing.
- [x] Run the chatgit behavior suite.
- [x] Restart the live `chatgit-main` server on port 6174.
- [x] Push `main`.

## Blockers
- Automatic 30-minute `[status]` commits are not implemented yet; only the
  manual `codex_status` helper and dispatch prompt contract exist.
- `jj` is not installed yet.

## Recent Results
- Changed branch mode so new chatgit worktrees use names like
  `chat-branch-test-abc1234`; repeated same-prompt branches use `-1`, `-2`,
  etc. instead of timestamp/nanosecond identifiers.
- Updated `scripts/test_codex_web/WEB_BEHAVIOR.md` and
  `scripts/test_codex_web/test_codex_web.sh` to reject
  `codex-web-interface-*` branch names and cover duplicate prompt suffixes.
- Verified with `python3 -m py_compile scripts/codex_web.py` and
  `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- Local `main` was rebased onto `origin/main`; current divergence is ahead-only.
- Pushed `main` to `origin/main` through commit `3c42d47`.

## Agent Notes
- The previous divergence pattern came from local wrapper/status commits made
  before or during push while `origin/main` already had equivalent or nearby
  commits. Future workflow should fetch/rebase before committing/pushing UI
  helper changes, then push once from an ahead-only branch.
- `codex_dispatch` lives in `scripts/branch_commands.sh`, not
  `codex_wrap.py`, so branch/worktree orchestration stays outside the low-level
  wrapper.
- Stable repo instructions belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic
  learnings.
