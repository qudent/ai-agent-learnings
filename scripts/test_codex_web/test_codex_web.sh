#!/usr/bin/env bash
set -euo pipefail

WEB=${1:-scripts/codex_web.py}
SCRIPT_DIR=$(cd "$(dirname "$WEB")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
TMP=$(mktemp -d)
REPO="$TMP/repo"
FAKEBIN="$TMP/bin"
PORT=${CODEX_WEB_TEST_PORT:-6192}

cleanup() {
  if [ -n "${SERVER_PID:-}" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$REPO" "$FAKEBIN"
cat >"$FAKEBIN/codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
SID="22222222-2222-2222-2222-222222222222"
if [[ ${1:-} == --version ]]; then echo 'OpenAI Codex fake'; exit 0; fi
[[ ${1:-} == exec ]] || { echo "fake codex expected exec" >&2; exit 2; }
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json|--experimental-json|--dangerously-bypass-approvals-and-sandbox|--yolo) shift ;;
    --sandbox|--model|-m|--cd|-C|-c|--config|--profile|-p|--color|--output-last-message|-o) shift 2 ;;
    resume) shift 2; break ;;
    --*) shift ;;
    *) break ;;
  esac
done
prompt="$*"
{
  echo 'OpenAI Codex fake'
  echo '--------'
  echo "workdir: $PWD"
  echo "session id: $SID"
  echo '--------'
  echo 'user'
  echo "$prompt"
} >&2
if [[ "$prompt" == *slow* ]]; then sleep 1; fi
printf '{"type":"thread.started","thread_id":"%s"}\n' "$SID"
printf '{"type":"item.completed","item":{"id":"agent-1","type":"agent_message","text":"done: %s"}}\n' "$prompt"
FAKE
chmod +x "$FAKEBIN/codex"

git -C "$REPO" init -q -b main
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name Tester
printf 'base\n' >"$REPO/file.txt"
git -C "$REPO" add file.txt
git -C "$REPO" commit -q -m base

(
  cd "$REPO"
  CHATGIT_PORT=$PORT PATH="$FAKEBIN:$PATH" "$SCRIPT_DIR/chatgit" >"$TMP/server.log" 2>&1
) &
SERVER_PID=$!

for _ in $(seq 1 50); do
  curl -fsS "http://127.0.0.1:$PORT/api/config" >/dev/null 2>&1 && break
  sleep 0.1
done

config=$(curl -fsS "http://127.0.0.1:$PORT/api/config")
printf '%s' "$config" | grep -F "\"repo\": \"$REPO\"" >/dev/null
printf 'ok - chatgit serves the caller repository\n'

base=$(git -C "$REPO" rev-parse HEAD)
response=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"branch test\",\"mode\":\"branch\",\"base_commit\":\"$base\"}" \
  "http://127.0.0.1:$PORT/api/run")
branch=$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["branch"])')
worktree=$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["path"])')
log=$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["log"])')

git -C "$worktree" merge-base --is-ancestor "$base" HEAD
parent=$(git -C "$REPO" config --get "branch.$branch.chatgit-parent")
parent_commit=$(git -C "$REPO" config --get "branch.$branch.chatgit-parent-commit")
[ "$parent" = main ]
[ "$parent_commit" = "$base" ]
printf 'ok - branch mode creates a child branch with explicit parent metadata\n'

child_base=$(git -C "$worktree" rev-parse HEAD)
response_child=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$worktree\",\"prompt\":\"grandchild branch test\",\"mode\":\"branch\",\"base_commit\":\"$child_base\"}" \
  "http://127.0.0.1:$PORT/api/run")
branch_child=$(printf '%s' "$response_child" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["branch"])')
worktree_child=$(printf '%s' "$response_child" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["path"])')
parent_child=$(git -C "$REPO" config --get "branch.$branch_child.chatgit-parent")
parent_commit_child=$(git -C "$REPO" config --get "branch.$branch_child.chatgit-parent-commit")
[ "$parent_child" = "$branch" ]
[ "$parent_commit_child" = "$child_base" ]
git -C "$worktree_child" merge-base --is-ancestor "$child_base" HEAD
printf 'ok - branch mode supports recursive child branches\n'

worktrees=$(curl -fsS "http://127.0.0.1:$PORT/api/worktrees?repo=$REPO")
printf '%s' "$worktrees" | grep -F "\"branch\": \"$branch\"" >/dev/null
printf '%s' "$worktrees" | grep -F '"parent_branch": "main"' >/dev/null
printf '%s' "$worktrees" | grep -F "\"parent_commit\": \"$base\"" >/dev/null
printf '%s' "$worktrees" | grep -F "\"branch\": \"$branch_child\"" >/dev/null
printf '%s' "$worktrees" | grep -F "\"parent_branch\": \"$branch\"" >/dev/null
printf 'ok - worktree API exposes parent branch metadata\n'

response2=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"second branch test\",\"mode\":\"branch\",\"base_commit\":\"$base\"}" \
  "http://127.0.0.1:$PORT/api/run")
branch2=$(printf '%s' "$response2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["branch"])')
worktree2=$(printf '%s' "$response2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["path"])')
log2=$(printf '%s' "$response2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["log"])')
[ "$branch2" != "$branch" ]
[ "$worktree2" != "$worktree" ]
[ "$log2" != "$log" ]
printf 'ok - repeated tab branch requests get distinct branches and logs\n'

show=$(curl -fsS "http://127.0.0.1:$PORT/api/show?repo=$REPO&commit=$base" | python3 -c 'import json,sys; print(json.load(sys.stdin)["patch"])')
printf '%s' "$show" | grep -F 'AuthorDate:' >/dev/null
printf '%s' "$show" | grep -F 'diff --git' >/dev/null
printf 'ok - commit detail API returns fuller git show patch output\n'

curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"slow queue first\",\"mode\":\"fresh\",\"base_commit\":\"\"}" \
  "http://127.0.0.1:$PORT/api/run" >/dev/null
queued_response=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"queued followup\",\"mode\":\"send\",\"base_commit\":\"\"}" \
  "http://127.0.0.1:$PORT/api/run")
printf '%s' "$queued_response" | grep -F '"queued": true' >/dev/null
status=$(curl -fsS "http://127.0.0.1:$PORT/api/status?repo=$REPO")
printf '%s' "$status" | grep -F '"queue_depth": 1' >/dev/null
for _ in $(seq 1 80); do
  git -C "$REPO" log --format=%B -n 40 | grep -F 'queued followup' >/dev/null && break
  sleep 0.1
done
git -C "$REPO" log --format=%B -n 40 | grep -F 'queued followup' >/dev/null
status=$(curl -fsS "http://127.0.0.1:$PORT/api/status?repo=$REPO")
printf '%s' "$status" | grep -F '"queue_depth": 0' >/dev/null
printf 'ok - web server queues messages behind active runs\n'

if command -v google-chrome >/dev/null 2>&1; then
  dom=$(google-chrome --headless --disable-gpu --no-sandbox --dump-dom --virtual-time-budget=3000 "http://127.0.0.1:$PORT/" 2>/dev/null)
  printf '%s' "$dom" | grep -F "$branch ← main" >/dev/null
  printf '%s' "$dom" | grep -F "$branch_child ← $branch" >/dev/null
  printf '%s' "$dom" | grep -F 'Copy hash' >/dev/null
  google-chrome --headless --disable-gpu --no-sandbox --window-size=1280,900 --screenshot="$TMP/chatgit-desktop.png" "http://127.0.0.1:$PORT/" >/dev/null 2>&1
  google-chrome --headless --disable-gpu --no-sandbox --window-size=390,900 --screenshot="$TMP/chatgit-narrow.png" "http://127.0.0.1:$PORT/" >/dev/null 2>&1
  [ -s "$TMP/chatgit-desktop.png" ]
  [ -s "$TMP/chatgit-narrow.png" ]
  printf 'ok - browser renders parent branch metadata\n'
elif command -v playwright >/dev/null 2>&1; then
  playwright screenshot "http://127.0.0.1:$PORT/" "$TMP/chatgit.png" >/dev/null
  [ -s "$TMP/chatgit.png" ]
  printf 'ok - browser renders chatgit page\n'
else
  printf 'skip - playwright CLI not installed\n'
fi
