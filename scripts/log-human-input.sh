#!/usr/bin/env bash
set -euo pipefail

repo_arg="${1:?usage: log-human-input.sh REPO [MESSAGE...]}"
shift
repo="$(git -C "$repo_arg" rev-parse --show-toplevel)"
cd "$repo"

message="${*:-$(cat)}"
file="${USER_IO_FILE:-USER_IO.md}"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ ! -f "$file" ]]; then
  printf '# User IO\n\nDurable human prompts, feedback, and scribbles. Agents read this file but should not edit it unless explicitly asked.\n' >"$file"
fi

{
  printf '\n## %s\n\n' "$ts"
  printf '%s\n' "$message"
} >>"$file"

git add "$file"
git commit --allow-empty -m "[no-dispatch] usr: log human input"
