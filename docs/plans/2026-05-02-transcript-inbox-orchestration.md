# Transcript Inbox Orchestration Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Replace commit-message-heavy Codex orchestration markers with a version-controlled transcript and inbox folder model, while keeping branch/worktree isolation and introducing Jujutsu only as the project-management overlay.

**Architecture:** Git remains the durable artifact store and branch/worktree isolation mechanism. Agent and user messages become small Markdown files under `transcripts/` plus agent inbox files under `agents/`; commit messages become concise pointers with correct authorship instead of the primary transcript body. Jujutsu (`jj`) is used for mutable planning/task DAGs, not as the first storage layer for transcripts.

**Tech Stack:** Git, Python wrapper in `scripts/codex_wrap.py`, shell helpers in `scripts/branch_commands.sh`, optional `jj` via `scripts/jj_project.sh`, existing wrapper tests in `scripts/test_codex_wrap/test_codex_wrap.sh` and web tests in `scripts/test_codex_web/test_codex_web.sh`.

---

## What I found in history

I reviewed the pre/current orchestration sequence around these commits:

- `110096f` — introduced branch-scoped dispatch, `USER_IO.md`, and `log-human-input.sh`.
- `e88cda1` / `d5b3e57` / `a673d21` — removed the separate whiteboard and made `STATUS.md` the single coordination file.
- `1b86658` — added experimental `jj_project.sh` helpers.
- `7f9a5fa` / `077c34c` / `f3cbae1` — added active-agent transcript artifacts and dispatch classification.

I also created and pushed an archive pointer before changing the design docs:

- `archive/marker-orchestration-before-transcript-inbox` points at the current marker-orchestration state (`d291d83`).

This keeps the existing working design recoverable while `main` can move toward the transcript/inbox model.

## Critique of the proposed plan

### What makes sense

1. **Move transcript bodies out of commit messages.** The current `[codex] ...` marker commits are useful but too noisy. They create long subjects, merge/rebase friction, and repeated ahead/behind confusion. Storing message bodies as files makes Git history reviewable again.

2. **Keep transcripts in the repo, not in external chat logs.** This preserves the original insight from `110096f`: human prompts are the valuable durable signal, and future agents should be able to reconstruct intent from the repository itself.

3. **Give agents human-readable names.** `019de42c-a9a2-...` and short hashes are good machine IDs but bad UI. A slug like `fix-chatgit-paths` is better for directories, branch names, and ChatGit sidebars.

4. **Have agent inboxes.** A committed inbox gives a clean primitive for follow-up messages: append a user/parent-agent message to a file, commit it as authored by that sender, and let the target agent consume it.

5. **Branch-specific status stacks.** A global `STATUS.md` is useful for the root project, but branch/worktree agents need local instructions and pending items that do not constantly conflict on `main`.

6. **Introduce `jj` for project management, not transcript storage.** Jujutsu is well suited to mutable task/change DAGs; Git is still better as the portable transcript artifact that tools and GitHub already understand.

### What I would change

1. **Do not make “all user messages come from one file” literally true.** A single append-only `USER_IO.md` will become a conflict hotspot and loses per-agent routing. Better: one *index* file plus per-agent inbox files.

2. **Do not keep active transcripts under `transcripts/active/` and finished transcripts by moving files.** Moving files on finish creates noisy renames and conflicts. Better: keep immutable transcripts under `transcripts/archive/` from the start, and use `transcripts/active/<agent-slug>.md` as a tiny pointer/summary file that is deleted on completion.

3. **Do not rely on commit author alone to distinguish speaker.** Git author should be correct, but transcript files should still include explicit message blocks like `### user: ...` or YAML fields. Some Git hosts rewrite committer metadata, and merges obscure author relationships.

4. **Do not put every token streamed by Codex into Git.** Commit semantic message chunks: new user message, assistant final/meaningful update, tool/agent status checkpoint, completion. Token-by-token commits would recreate the current marker noise.

5. **Do not make `jj` required before the Git-backed model is stable.** `jj` should be optional until smoke tests prove colocated `.jj` plus Git worktrees does not create surprises.

## Proposed vocabulary

Use these names:

- `transcripts/archive/` — durable per-run transcript storage. “Archive” is clearer than “storage” or “index” because files remain meaningful and human-readable.
- `transcripts/active/` — live pointers/summaries only, not the canonical transcript body.
- `transcripts/index.md` — branch-local index of current/known agents and latest messages.
- `agents/<agent-slug>/inbox.md` — pending messages to a named agent.
- `agents/<agent-slug>/profile.md` — stable metadata for the agent run: task, branch, parent, session id, status.
- `STATUS.md` — branch-local current project state and instruction stack, not the full transcript.
- `PROJECT.jj.md` or `tasks/` later — human-readable mirror of `jj` project-management state if needed.

## Target repository layout

```text
STATUS.md
transcripts/
  index.md
  active/
    fix-chatgit-paths.md
  archive/
    2026-05-02-fix-chatgit-paths.md
agents/
  fix-chatgit-paths/
    profile.md
    inbox.md
```

### `agents/<slug>/profile.md`

```markdown
---
agent: fix-chatgit-paths
kind: codex
status: active
branch: chatgit-paths
worktree: /home/name/repos/example.worktrees/chatgit-paths
parent: user
session_id: 019de42c-a9a2-7f10-9dd6-33f33fc4ddd7
created_at: 2026-05-02T00:00:00Z
transcript: transcripts/archive/2026-05-02-fix-chatgit-paths.md
inbox: agents/fix-chatgit-paths/inbox.md
---

# fix-chatgit-paths

Task: Fix ChatGit path routing and restart behavior.
```

### `agents/<slug>/inbox.md`

```markdown
# Inbox: fix-chatgit-paths

## pending

### 2026-05-02T00:03:10Z user

Please also make the browser URL copyable.

## consumed

### 2026-05-02T00:01:05Z parent:dispatch-chatgit

Implement the path handling half only; do not touch CSS.
```

### `transcripts/archive/<date>-<slug>.md`

```markdown
---
agent: fix-chatgit-paths
kind: codex
branch: chatgit-paths
status: active
session_id: 019de42c-a9a2-7f10-9dd6-33f33fc4ddd7
---

# Transcript: fix-chatgit-paths

## 2026-05-02T00:00:00Z user

Fix ChatGit path routing.

## 2026-05-02T00:00:20Z codex:fix-chatgit-paths

I inspected `scripts/codex_web.py` and will add a path-style route regression.

## 2026-05-02T00:05:40Z codex:fix-chatgit-paths

Done. Changed `scripts/codex_web.py` and `scripts/test_codex_web/test_codex_web.sh`.
```

### `transcripts/active/<slug>.md`

```markdown
# Active: fix-chatgit-paths

- profile: ../../agents/fix-chatgit-paths/profile.md
- transcript: ../archive/2026-05-02-fix-chatgit-paths.md
- inbox: ../../agents/fix-chatgit-paths/inbox.md
- latest: 2026-05-02T00:05:40Z codex:fix-chatgit-paths
```

## Commit authorship policy

The wrapper should set both commit message and Git author deliberately.

Recommended author identities:

- User-authored inbox/transcript commits:
  - `GIT_AUTHOR_NAME="user"`
  - `GIT_AUTHOR_EMAIL="user@local.agent"`
- Codex wrapper commits:
  - `GIT_AUTHOR_NAME="codex:<agent-slug>"`
  - `GIT_AUTHOR_EMAIL="codex+<agent-slug>@local.agent"`
- Dispatch/orchestrator commits:
  - `GIT_AUTHOR_NAME="orchestrator:<agent-slug>"`
  - `GIT_AUTHOR_EMAIL="orchestrator+<agent-slug>@local.agent"`
- Human user identity can later map to real Git config when known, but the role prefix should remain visible.

Commit messages should become short pointers, for example:

```text
user: message to fix-chatgit-paths

agent: fix-chatgit-paths
inbox: agents/fix-chatgit-paths/inbox.md
transcript: transcripts/archive/2026-05-02-fix-chatgit-paths.md
```

```text
codex: update fix-chatgit-paths transcript

agent: fix-chatgit-paths
message-role: assistant
transcript: transcripts/archive/2026-05-02-fix-chatgit-paths.md
```

This preserves the current “commit message says what happened” property without making the commit message the whole transcript.

## Branch and STATUS model

Keep branch/worktree isolation:

- Every implementation agent still works in one branch-owned worktree.
- `STATUS.md` is branch-specific and should contain that branch’s instruction stack:

```markdown
## Instruction Stack
- source: user commit <sha> / inbox item <id>
- parent agent: dispatch-chatgit
- branch scope: scripts/codex_web.py, scripts/test_codex_web/

## Active Goals
- [ ] Fix path-style URL behavior.

## Done
- [x] Added failing route test.
```

Avoid making `STATUS.md` the transcript. It should remain current state plus next actions.

## Jujutsu project-management direction

Use `jj` for mutable task orchestration once the transcript model works:

- One `jj` change per task/inbox item.
- `jj describe` contains task title, owner, status, and pointers to transcript/inbox files.
- Git remains the exported/public transcript and code history.
- `jj` is allowed to rewrite mutable planning changes; transcript commits should remain append-style and easy to audit.

Do **not** make `jj` the first implementation step. The current helper `scripts/jj_project.sh` is still experimental and should be expanded only after tests cover transcript/inbox Git behavior.

## Codex high-thinking handoff

The local Codex config currently has `model_reasoning_effort = "high"` in `~/.codex/config.toml`. If this plan is handed to Codex, do not guess model names or flags. Use the installed CLI defaults or explicitly pass:

```bash
codex exec -C /home/name/repos/ai-agent-learnings \
  -c model_reasoning_effort='"high"' \
  --dangerously-bypass-approvals-and-sandbox \
  - < docs/plans/2026-05-02-transcript-inbox-orchestration.md
```

The implementer should still verify `codex exec --help` on the target machine before relying on CLI flags.

---

## Implementation Tasks

### Task 1: Add a transcript/inbox behavior contract

**Objective:** Specify the new file layout and message semantics in tests before changing the wrapper.

**Files:**
- Modify: `scripts/test_codex_wrap/test_codex_wrap.sh`
- Create: `scripts/test_codex_wrap/TRANSCRIPT_INBOX_BEHAVIOR.md`

**Step 1: Write the Markdown behavior contract**

Create `TRANSCRIPT_INBOX_BEHAVIOR.md` with:

```markdown
# Transcript Inbox Behavior

- Starting a wrapper run creates:
  - `agents/<slug>/profile.md`
  - `agents/<slug>/inbox.md`
  - `transcripts/archive/<date>-<slug>.md`
  - `transcripts/active/<slug>.md`
- Commit bodies are concise pointers, not full transcript bodies.
- Git author identifies the speaker or agent that caused the commit.
- User follow-up messages append to the target inbox and transcript with a `user:` block.
- Assistant output appends to the transcript with a `codex:<slug>:` block.
- Stopping or aborting removes only `transcripts/active/<slug>.md`; archive transcript and inbox remain.
```

**Step 2: Add failing shell assertions**

In `scripts/test_codex_wrap/test_codex_wrap.sh`, replace or extend the current active-agent artifact test so it expects the new paths. Assert:

```bash
[ -f "agents/$slug/profile.md" ]
[ -f "agents/$slug/inbox.md" ]
[ -f "transcripts/archive/$archive.md" ]
[ -f "transcripts/active/$slug.md" ]
git show -s --format='%an <%ae>' HEAD | grep -E 'codex:|user|orchestrator:'
```

**Step 3: Run test to verify failure**

Run:

```bash
PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh
```

Expected: FAIL on missing transcript/inbox files.

**Step 4: Commit the red contract**

```bash
git add scripts/test_codex_wrap/test_codex_wrap.sh scripts/test_codex_wrap/TRANSCRIPT_INBOX_BEHAVIOR.md
git commit -m "test: define transcript inbox contract"
```

### Task 2: Add naming and path helpers to `codex_wrap.py`

**Objective:** Generate stable human-readable agent slugs and transcript paths.

**Files:**
- Modify: `scripts/codex_wrap.py`

**Step 1: Add slug helper**

Add a helper near `oneline()`:

```python
def slugify_task(prompt: str, fallback: str) -> str:
    words = re.findall(r"[a-z0-9]+", prompt.lower())
    stop = {"the", "and", "for", "with", "this", "that", "please", "codex", "agent"}
    words = [w for w in words if w not in stop]
    slug = "-".join(words[:4]).strip("-")
    return slug or fallback
```

**Step 2: Add path helpers**

```python
def agent_slug(run_start: str, prompt: str) -> str:
    return f"{slugify_task(prompt, short_hash(run_start))}-{short_hash(run_start)}"

def transcript_paths(run_start: str, prompt: str) -> dict[str, str]:
    slug = agent_slug(run_start, prompt)
    day = time.strftime("%Y-%m-%d", time.gmtime())
    return {
        "slug": slug,
        "profile": f"agents/{slug}/profile.md",
        "inbox": f"agents/{slug}/inbox.md",
        "archive": f"transcripts/archive/{day}-{slug}.md",
        "active": f"transcripts/active/{slug}.md",
        "index": "transcripts/index.md",
    }
```

**Step 3: Run syntax check**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile scripts/codex_wrap.py
```

**Step 4: Commit**

```bash
git add scripts/codex_wrap.py
git commit -m "feat: add transcript inbox naming helpers"
```

### Task 3: Replace active-agent files with transcript/inbox files

**Objective:** Write profile, inbox, archive transcript, active pointer, and index files from wrapper marker commits.

**Files:**
- Modify: `scripts/codex_wrap.py`

**Step 1: Replace `active_agent_path` usage**

Keep backwards compatibility only if tests require it; otherwise replace `active-agents/<short>.md` with `transcripts/active/<slug>.md`.

**Step 2: Add content builders**

Implement builders for:

- `agent_profile_content(...)`
- `agent_inbox_content(...)`
- `transcript_content(...)`
- `active_pointer_content(...)`
- `transcript_index_content(...)`

Keep them simple Markdown with YAML frontmatter for machine metadata.

**Step 3: Start run writes all initial files**

`active_agent_start(...)` should become `transcript_agent_start(...)` and call `marker(..., set_files={...})` for profile, inbox, archive transcript, active pointer, and index.

**Step 4: Assistant output appends only archive/index/active pointer**

On Codex output, update the archive transcript and active pointer. Do not rewrite inbox unless consuming pending messages.

**Step 5: Stop/abort removes only active pointer**

`stop_marker(...)` should remove `transcripts/active/<slug>.md`, not archive/profile/inbox files.

**Step 6: Run test**

```bash
PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh
```

Expected: PASS for transcript/inbox contract.

**Step 7: Commit**

```bash
git add scripts/codex_wrap.py
git commit -m "feat: store wrapper transcripts and inboxes as files"
```

### Task 4: Set commit authors for wrapper events

**Objective:** Make Git authors reflect user, Codex agent, or orchestrator identity.

**Files:**
- Modify: `scripts/codex_wrap.py`
- Modify: `scripts/test_codex_wrap/test_codex_wrap.sh`

**Step 1: Add author support to commit creation**

Extend `git_index`, `update_ref`, `marker`, and `agent_marker` to accept an `author` object or env dict. Use subprocess env:

```python
env={**os.environ, "GIT_AUTHOR_NAME": name, "GIT_AUTHOR_EMAIL": email}
```

`git commit-tree` respects author env.

**Step 2: Define role identities**

```python
def author_for(role: str, slug: str = "") -> dict[str, str]:
    if role == "user":
        return {"GIT_AUTHOR_NAME": "user", "GIT_AUTHOR_EMAIL": "user@local.agent"}
    if role == "orchestrator":
        return {"GIT_AUTHOR_NAME": f"orchestrator:{slug}", "GIT_AUTHOR_EMAIL": f"orchestrator+{slug}@local.agent"}
    return {"GIT_AUTHOR_NAME": f"codex:{slug}", "GIT_AUTHOR_EMAIL": f"codex+{slug}@local.agent"}
```

**Step 3: Assign authors**

- Start/user prompt commit: `user` unless `CODEX_WRAP_CALLED_BY` is not user, then `orchestrator:<caller-slug>`.
- Assistant output commit: `codex:<slug>`.
- Stop/abort commit: `codex:<slug>` or `orchestrator:<slug>` for abort commands.

**Step 4: Assert author names in tests**

Use:

```bash
git show -s --format='%an <%ae>' HEAD
```

**Step 5: Run tests and commit**

```bash
PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh
git add scripts/codex_wrap.py scripts/test_codex_wrap/test_codex_wrap.sh
git commit -m "feat: set wrapper commit authors by speaker"
```

### Task 5: Implement user follow-up inbox commits

**Objective:** Make `codex_new_message` append user messages to the target agent inbox/transcript before resuming.

**Files:**
- Modify: `scripts/codex_wrap.py`
- Modify: `scripts/test_codex_wrap/test_codex_wrap.sh`

**Step 1: Add failing test**

Start a long run, call `codex_new_message "new instruction"`, then assert:

- `agents/<slug>/inbox.md` has a `pending` or `consumed` `user` entry.
- Archive transcript has a `## <timestamp> user` block.
- The commit author for the message append commit is `user <user@local.agent>`.

**Step 2: Implement append before restart**

Before killing/restarting the active process, append the user message to inbox and transcript using `marker(..., set_files=..., author=user)`.

**Step 3: Run tests and commit**

```bash
PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh
git add scripts/codex_wrap.py scripts/test_codex_wrap/test_codex_wrap.sh
git commit -m "feat: route follow-up messages through agent inboxes"
```

### Task 6: Update dispatcher prompt and docs

**Objective:** Make dispatchers reason from transcript/inbox files rather than long marker subjects.

**Files:**
- Modify: `scripts/branch_commands.sh`
- Modify: `README.md`
- Modify: `scripts/codex-wrap/SKILL.md`

**Step 1: Update `_codex_dispatch_context`**

Include compact listings:

```bash
find transcripts/active agents -maxdepth 3 -type f 2>/dev/null | sort | sed -n '1,80p'
```

Do not dump full transcripts into the dispatch prompt by default.

**Step 2: Update dispatch contract**

Add rules:

- Read `transcripts/index.md` and relevant `agents/*/profile.md` first.
- Send follow-ups by appending to target inbox, not by embedding everything in a marker commit.
- Spawn new agents with named slugs and disjoint branch scopes.

**Step 3: Update docs**

README should say commit messages are concise pointers and transcript bodies live under `transcripts/`.

**Step 4: Run tests and commit**

```bash
PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh
PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py
git add scripts/branch_commands.sh README.md scripts/codex-wrap/SKILL.md
git commit -m "docs: route dispatch through transcript inbox files"
```

### Task 7: Add `jj` task mirror helpers

**Objective:** Keep `jj` optional but useful for production/project management.

**Files:**
- Modify: `scripts/jj_project.sh`
- Create or modify tests if a shell-test harness exists for `jj_project.sh`

**Step 1: Add helpers**

Add:

```bash
jj_task_from_inbox agents/<slug>/inbox.md <message-id>
jj_task_claim <agent-slug> <task-change-id>
jj_task_done_from_transcript <task-change-id> transcripts/archive/<file>.md
```

**Step 2: Guard when `jj` is absent**

Every helper must fail clearly with the existing `jj_project: jj is not installed` message.

**Step 3: Add smoke test where `jj` exists**

If `command -v jj` succeeds, run a temporary repo smoke test. If not, assert the clear failure path only.

**Step 4: Commit**

```bash
git add scripts/jj_project.sh
git commit -m "feat: mirror inbox tasks into jj changes"
```

### Task 8: Migration cleanup

**Objective:** Remove or deprecate old marker-heavy active-agent paths safely.

**Files:**
- Modify: `README.md`
- Modify: `scripts/codex-wrap/SKILL.md`
- Modify: `STATUS.md`

**Step 1: Keep archive branch reference**

Document that `archive/marker-orchestration-before-transcript-inbox` preserves the previous model.

**Step 2: Deprecate `active-agents/`**

Leave a compatibility note only if old history depends on it; new runs should use `transcripts/active/`.

**Step 3: Final validation**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile scripts/codex_wrap.py scripts/codex_web.py
PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_wrap/test_codex_wrap.sh scripts/codex_wrap.sh
PYTHONDONTWRITEBYTECODE=1 bash scripts/test_codex_web/test_codex_web.sh scripts/codex_web.py
git status --short --branch
```

**Step 4: Push**

```bash
git push origin main
```

## Success criteria

- A new Codex run creates readable `agents/` and `transcripts/` files.
- Commit subjects are short and scan-friendly.
- `git log --format='%h %an %s'` clearly distinguishes user, codex agent, and orchestrator commits.
- A user follow-up can be represented as a committed inbox update without a giant prompt commit.
- Finished transcripts remain under `transcripts/archive/`; only active pointers are removed.
- Branch/worktree isolation still works.
- `jj` helpers remain optional and fail clearly when `jj` is absent.
