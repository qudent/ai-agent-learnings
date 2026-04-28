#!/usr/bin/env bash
set -euo pipefail

repo_arg="${1:?usage: log-human-input.sh REPO [MESSAGE...]}"
shift
repo="$(git -C "$repo_arg" rev-parse --show-toplevel)"
cd "$repo"

message="${*:-$(cat)}"
file="${STATUS_FILE:-STATUS.md}"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ ! -f "$file" ]]; then
  printf '# Project Status\n\n## Current State\nUnknown.\n\n## Active Human Prompts\n- None active.\n\n## Active Goals\n- [ ] Define current goal.\n\n## TODO Plan\n- [ ] Update this status file.\n\n## Blockers\n- None known.\n\n## Recent Results\n- None yet.\n\n## Agent Notes\n- None.\n\n## Open Questions\n- None.\n' >"$file"
fi

{
  printf '\n## Human Input - %s\n\n' "$ts"
  printf '%s\n' "$message"
} >>"$file"

git add "$file"
git commit --allow-empty -m "[no-dispatch] usr: log human input"
