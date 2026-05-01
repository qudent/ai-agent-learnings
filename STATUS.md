# AI Agent Learnings - Status

## Current State
This repo stores project-agnostic operating guidance and helper scripts for
local AI coding agents. `AGENTS.md` remains the canonical global instruction
source. The active helper surface is `codex_wrap` for Git-backed Codex marker
commits, `branch_commands.sh` for branch/worktree placement and dispatch, and
`chatgit`/`codex_web.py` for the small local web UI.

## Active Goals


wait wait what are you doing with repoprover here? i see repoprover related stuff in the learnings repo web interface...?

also great clean up finished things here in this todo list
where does this pattern of divergence between origin and main come from? can you change your workflow so it doesn't occur anymore?

- [x] Commit the human-updated `STATUS.md` before taking new work.
- [x] Add `codex_dispatch` for one-round Codex delegation with concise context,
  citations, checkpoint guidance, and `called-by` propagation.
- [x] Add `called-by: user|<commit>` metadata to new run-start marker commits.
- [x] Improve the web UI branch-base/composer behavior and document that the
  current frontend is a legacy plain-JS surface with known AI rough edges.
- [x] Clean stale `STATUS.md` entries and inspect local/upstream branch state.
- [x] Add an optional Jujutsu project-management helper experiment.
- [x] Render local file paths in Codex output as clickable download links, with
  tests and bounded downloadable roots.
- [x] Make `chatgit` print a copyable `?repo=<path>` URL and make the web root
  accept `?repo=` to open a specific local Git repository.
- [x] Collapse branch-pane run history so the left panel is less verbose.
- [x] Scan large files/directories that look like cleanup candidates, without
  deleting anything, and record findings in this status file.
- [x] Treat verbose first-words run titles/history as low-value UI; collapse
  run history by default instead of spending branch-pane space on old titles.
- [x] Delete the explicitly approved large cleanup targets:
  `/home/name/.cache/huggingface` and `/home/name/repos/nanochat-d20-play`.
- [x] Add `codex_status` and dispatcher guidance for periodic `[status]`
  summary commits with relevant commit references.
- [ ] Decide whether to merge, preserve, or delete the unmerged `dev` branch and
  `origin/dev`.
- [ ] Install `jj` before trying the Jujutsu helper on a real task.

## TODO Plan
- [x] Restart the `chatgit-main` tmux server again after the latest path-link,
  `?repo=`, and mobile composer changes.
- [ ] Push `main` and report exact branch state.
- [ ] Defer deleting `dev`: it is checked out in a worktree and contains
  unmerged commits/files, so it is not safe to remove as unused.
  oh check this, and do that maybe? if the commits are good. cross check with your own work though.

## Blockers
- `jj` is not installed on this machine, no Rust toolchain is present, and the
  root filesystem has only about 4.8 GB free. The Jujutsu experiment is
  scaffolded but not live-tested with `jj`.
  ok now there is enough space, you can commit. also push.

- Automatic 30-minute `[status]` commits are not implemented yet; only the
  manual `codex_status` helper and dispatch prompt contract were added.

## Recent Results
- Created `Record active coordination prompts` for the human `STATUS.md` edit
  and a checkpoint commit before dispatch/UI work.
- Implemented `called-by` marker metadata, `codex_dispatch`, `codex_checkpoint`,
  compact `/api/overview` polling, mobile composer reachability, visible branch
  base state, clearer branch labels, mobile run actions, and docs/tests.
- Added clickable local path downloads, `chatgit` copyable repo URLs, `?repo=`
  initial config, and collapsed branch run history; changes were developed
  against `scripts/test_codex_web/WEB_BEHAVIOR.md` oh
- Disk scan found the machine is at 67 GB used of 75 GB, with 4.8 GB free; no
  files were deleted during the scan. After explicit approval, deleting the
  Hugging Face cache and `nanochat-d20-play` reduced usage to 39 GB used with
  34 GB free.
- Added `scripts/jj_project.sh` as an optional Jujutsu task-DAG experiment; it
  fails clearly when `jj` is missing.
- Verification passed:
  `python3 -m py_compile scripts/codex_web.py scripts/codex_wrap.py`,
  `bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh`, and
  `bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py`.
- Live `chatgit-main` is running on `127.0.0.1:6174` for
  `/home/name/repos/repoprover`; latest narrow screenshot at
  `/tmp/chatgit-narrow_view.png` shows the composer buttons in one column
  without clipping.
- `git fetch --prune origin` found no stale remote refs. Local `dev` is still
  checked out at `/home/name/repos/ai-agent-learnings.worktrees/dev`, is ahead
  of `origin/dev`, and is not merged into `main`.

  great i deleted it.

## Agent Notes
- This run used internal read-only subagents for UI critique and wrapper tracing,
  not background `codex_commit` workers. The new human correction is now policy
  for larger future dispatch: use Git-backed `codex_dispatch`/`codex_*` calls
  when delegating substantial work.
- `codex_dispatch` lives in `scripts/branch_commands.sh`, not `codex_wrap.py`,
  so branch/worktree orchestration stays outside the low-level wrapper.
- Product direction from the latest human note: old conversation/run titles are
  usually not worth screen real estate; future dispatch/UI work should favor
  search and agent-facing surfacing of relevant prior evidence over human
  browsing of title lists.
- Long-running dispatch should add compact `[status]` commits that cite the
  relevant preceding commit hashes, so future agents can reconstruct decisions
  without loading every marker commit.
- `scripts/.chatgit.swp` was removed in the checkpoint commit.
- Stable repo instructions belong in each repo's `AGENTS.md`; concrete run
  commands belong in repo docs or `STATUS.md`, not in project-agnostic
  learnings.
