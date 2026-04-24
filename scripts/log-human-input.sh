#!/usr/bin/env bash
set -euo pipefail

repo_arg="${1:?usage: log-human-input.sh REPO [MESSAGE...]}"
shift
repo="$(git -C "$repo_arg" rev-parse --show-toplevel)"
cd "$repo"

message="${*:-$(cat)}"
file="${HUMAN_AGENTS_WHITEBOARD_FILE:-HUMAN_AGENTS_WHITEBOARD.md}"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ ! -f "$file" ]]; then
  printf '# Human/Agents Whiteboard\n\n## Active Human Prompts\n- None active.\n\n## Agent Notes\n- None.\n\n## Open Questions\n- None.\n' >"$file"
fi

{
  printf '\n## Human Note - %s\n\n' "$ts"
  printf '%s\n' "$message"
} >>"$file"

git add "$file"
git commit --allow-empty -m "[no-dispatch] usr: log human input"
