#!/usr/bin/env bash
set -euo pipefail

repo_arg="${1:?usage: dispatch-agent.sh REPO COMMITISH [SOURCE_BRANCH]}"
commitish="${2:?usage: dispatch-agent.sh REPO COMMITISH [SOURCE_BRANCH]}"
repo="$(git -C "$repo_arg" rev-parse --show-toplevel)"
cd "$repo"

git cat-file -e "$commitish^{commit}" 2>/dev/null || git fetch --quiet origin '+refs/heads/*:refs/remotes/origin/*'
sha="$(git rev-parse "$commitish^{commit}")"
msg="$(git log -1 --format=%B "$sha")"
source_branch="${3:-$(git branch --contains "$sha" --format='%(refname:short)' | grep -v '^agent/' | head -n1 || true)}"
source_branch="${source_branch:-main}"
safe_branch="$(sed -E 's#[^A-Za-z0-9._-]+#-#g; s#^-+##; s#-+$##' <<<"$source_branch")"
state_dir="$(git rev-parse --git-path agent-dispatch)"
mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
flock -n 9 || exit 0

if grep -Eqi '(^|[[:space:]])(@no-dispatch|\[no-dispatch\])([[:space:][:punct:]]|$)' <<<"$msg"; then
  echo "skipping $sha due to no-dispatch marker"
  exit 0
fi

git worktree prune
for tool in codex claude; do
  grep -Eqi "(^|[[:space:]])@$tool([[:space:][:punct:]]|$)" <<<"$msg" || continue
  short="${sha:0:12}"
  done_file="$state_dir/done-$tool-$short"
  [[ -f "$done_file" ]] && continue

  branch="agent/$tool/$safe_branch"
  root="${AGENT_WORKTREE_ROOT:-$repo.worktrees}"
  worktree="$root/$tool-$safe_branch"
  if [[ "${DISPATCH_DRY_RUN:-0}" == 1 ]]; then
    echo "would dispatch $tool for $short from $source_branch on $branch"
    continue
  fi

  mkdir -p "$root"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    existing_branch=1
  else
    existing_branch=0
    git branch "$branch" "$sha"
  fi
  [[ -e "$worktree/.git" ]] || git worktree add "$worktree" "$branch"
  if [[ "$existing_branch" == 1 ]]; then
    if ! git -C "$worktree" diff --quiet || ! git -C "$worktree" diff --cached --quiet || [[ -n "$(git -C "$worktree" ls-files --others --exclude-standard)" ]]; then
      echo "refusing dispatch: $worktree has uncommitted changes" >&2
      exit 1
    fi
    git -C "$worktree" merge --no-edit "$sha" || true
  fi

  prompt="$state_dir/prompt-$tool-$short.md"
  {
    echo "You are a one-off $tool agent."
    echo "Repo: $repo"
    echo "Worktree: $worktree"
    echo "Agent branch: $branch"
    echo "Human/source branch: $source_branch"
    echo "Trigger commit: $sha"
    echo
    echo "Treat the commit message and patch below as durable human input. Text after @$tool is intentional prompt content."
    echo "Read AGENTS.md, STATUS.md, and USER_IO.md if present. Human input is the non-ephemeral signal; do not rewrite USER_IO.md unless explicitly asked."
    echo "Update STATUS.md Agent Output, clear handled active prompts, and commit all changes to $branch."
    echo
    echo "## Trigger Commit Message"
    printf '%s\n' "$msg"
    echo
    echo "## Trigger Patch"
    git show --format=fuller --stat --patch "$sha"
    echo
    echo "## Recent Commit Context"
    git log --oneline --decorate -8 "$sha"
  } >"$prompt"

  echo "dispatching $tool for $short -> $worktree"
  if [[ "$tool" == codex ]]; then
    codex exec -C "$worktree" --dangerously-bypass-approvals-and-sandbox - <"$prompt" 2>&1 | tee "$state_dir/$tool-$short.log"
  else
    (cd "$worktree" && claude -p --permission-mode bypassPermissions <"$prompt") 2>&1 | tee "$state_dir/$tool-$short.log"
  fi

  if ! git -C "$worktree" diff --quiet || ! git -C "$worktree" diff --cached --quiet || [[ -n "$(git -C "$worktree" ls-files --others --exclude-standard)" ]]; then
    git -C "$worktree" add -A
    git -C "$worktree" commit -m "$tool result for $short"
  fi
  git -C "$worktree" rev-parse HEAD >"$done_file"
  [[ "${DISPATCH_PUSH:-1}" == 0 ]] || git -C "$worktree" push -u origin "$branch"
  if [[ "${DISPATCH_CLEANUP:-0}" == 1 ]]; then
    git worktree remove --force "$worktree"
    git branch -D "$branch"
  fi
done
