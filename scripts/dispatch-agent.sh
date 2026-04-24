#!/usr/bin/env bash
set -euo pipefail

repo_arg="${1:?usage: dispatch-agent.sh REPO COMMITISH [SOURCE_BRANCH]}"
commitish="${2:?usage: dispatch-agent.sh REPO COMMITISH [SOURCE_BRANCH]}"
repo="$(git -C "$repo_arg" rev-parse --show-toplevel)"
cd "$repo"

if ! git cat-file -e "$commitish^{commit}" 2>/dev/null && git remote get-url origin >/dev/null 2>&1; then
  git fetch --quiet origin '+refs/heads/*:refs/remotes/origin/*'
fi
sha="$(git rev-parse "$commitish^{commit}")"
msg="$(git log -1 --format=%B "$sha")"
state_dir="$(git rev-parse --git-path agent-dispatch)"
mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
flock 9

if grep -Eqi '(^|[[:space:]])(@no-dispatch|\[no-dispatch\])([[:space:][:punct:]]|$)' <<<"$msg"; then
  echo "skipping $sha due to no-dispatch marker"
  exit 0
fi

git worktree prune

detect_source_branch() {
  if [[ "${3:-}" != "" ]]; then
    sed 's#^refs/heads/##' <<<"$3"
    return 0
  fi

  local branches
  mapfile -t branches < <(git for-each-ref --format='%(refname:short) %(objectname)' refs/heads | awk -v sha="$sha" '$2 == sha && $1 !~ /^agent\// { print $1 }')
  if [[ "${#branches[@]}" == 1 ]]; then
    printf '%s\n' "${branches[0]}"
    return 0
  fi

  mapfile -t branches < <(git branch --contains "$sha" --format='%(refname:short)' | awk '$1 !~ /^agent\// { print $1 }')
  if [[ "${#branches[@]}" == 1 ]]; then
    printf '%s\n' "${branches[0]}"
    return 0
  fi

  echo "refusing dispatch: cannot infer a unique source branch for $sha; pass SOURCE_BRANCH" >&2
  exit 1
}

source_branch="$(detect_source_branch "$@")"
safe_branch="$(sed -E 's#[^A-Za-z0-9._-]+#-#g; s#^-+##; s#-+$##' <<<"$source_branch")"

init_worktree() {
  local wt="$1"
  [[ "${DISPATCH_INSTALL:-1}" == 0 ]] && return 0
  [[ -f "$wt/package.json" ]] || return 0
  [[ -z "$(git -C "$wt" ls-files -u)" ]] || return 0
  (cd "$wt" && pnpm install)
}

ensure_clean() {
  local wt="$1"
  if ! git -C "$wt" diff --quiet || ! git -C "$wt" diff --cached --quiet || [[ -n "$(git -C "$wt" ls-files --others --exclude-standard)" ]]; then
    echo "refusing dispatch: $wt has uncommitted changes" >&2
    exit 1
  fi
}

ensure_source_branch() {
  if git show-ref --verify --quiet "refs/heads/$source_branch"; then
    return 0
  fi
  if git remote get-url origin >/dev/null 2>&1; then
    git fetch --quiet origin "+refs/heads/$source_branch:refs/remotes/origin/$source_branch" || true
  fi
  if git show-ref --verify --quiet "refs/remotes/origin/$source_branch"; then
    git branch "$source_branch" "origin/$source_branch"
  else
    git branch "$source_branch" "$sha"
  fi
}

worktree_for_branch() {
  local branch_ref="refs/heads/$1"
  git worktree list --porcelain | awk -v branch_ref="$branch_ref" '
    /^worktree / { wt = substr($0, 10); next }
    /^branch / && $2 == branch_ref { print wt }
  '
}

ensure_branch_worktree() {
  ensure_source_branch

  local matches root wt
  mapfile -t matches < <(worktree_for_branch "$source_branch")
  if [[ "${#matches[@]}" -gt 1 ]]; then
    echo "refusing dispatch: multiple worktrees are associated with $source_branch" >&2
    printf '%s\n' "${matches[@]}" >&2
    exit 1
  fi
  if [[ "${#matches[@]}" == 1 ]]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  root="${BRANCH_WORKTREE_ROOT:-$repo.worktrees}"
  wt="$root/$safe_branch"
  mkdir -p "$root"
  git worktree add --quiet "$wt" "$source_branch" >&2
  init_worktree "$wt" >&2
  printf '%s\n' "$wt"
}

worktree="$(ensure_branch_worktree)"
branch="$source_branch"
ensure_clean "$worktree"
if ! git -C "$worktree" merge-base --is-ancestor "$sha" HEAD; then
  if git -C "$worktree" merge-base --is-ancestor HEAD "$sha"; then
    git -C "$worktree" merge --ff-only "$sha"
  else
    echo "refusing dispatch: $sha is not on branch $source_branch in $worktree" >&2
    exit 1
  fi
fi

for tool in codex claude; do
  grep -Eqi "(^|[[:space:]])@$tool([[:space:][:punct:]]|$)" <<<"$msg" || continue
  short="${sha:0:12}"
  done_file="$state_dir/done-$tool-$short"
  [[ -f "$done_file" ]] && continue

  if [[ "${DISPATCH_DRY_RUN:-0}" == 1 ]]; then
    echo "would dispatch $tool for $short on $branch in $worktree"
    continue
  fi

  prompt="$state_dir/prompt-$tool-$short.md"
  {
    echo "You are a one-off $tool agent."
    echo "Repo: $repo"
    echo "Worktree: $worktree"
    echo "Branch: $branch"
    echo "Trigger commit: $sha"
    echo
    echo "Treat the commit message and human-authored patch text below as durable human input. The whole trigger commit is prompt context; text after @$tool is intentional extra prompt content, not the only prompt content."
    echo "Read AGENTS.md, STATUS.md, and USER_IO.md if present. Human input is the non-ephemeral signal; do not rewrite USER_IO.md unless explicitly asked."
    echo "Work directly in the listed branch worktree. Update STATUS.md Agent Output, clear handled active prompts, and commit all changes to $branch."
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

  log_dir="${AGENT_DISPATCH_LOG_DIR:-$state_dir}"
  mkdir -p "$log_dir"
  log_file="$log_dir/$tool-$short.log"
  echo "dispatching $tool for $short -> $worktree"
  if [[ "$tool" == codex ]]; then
    codex exec -C "$worktree" --dangerously-bypass-approvals-and-sandbox - <"$prompt" 2>&1 | tee "$log_file"
  else
    (cd "$worktree" && claude -p --permission-mode bypassPermissions <"$prompt") 2>&1 | tee "$log_file"
  fi

  if ! git -C "$worktree" diff --quiet || ! git -C "$worktree" diff --cached --quiet || [[ -n "$(git -C "$worktree" ls-files --others --exclude-standard)" ]]; then
    git -C "$worktree" add -A
    git -C "$worktree" commit -m "$tool result for $short"
  fi
  git -C "$worktree" rev-parse HEAD >"$done_file"
  [[ "${DISPATCH_PUSH:-1}" == 0 ]] || git -C "$worktree" push -u origin "$branch"
done
