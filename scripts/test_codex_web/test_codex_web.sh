#!/usr/bin/env bash
set -euo pipefail

WEB=${1:-scripts/codex_web.py}
SCRIPT_DIR=$(cd "$(dirname "$WEB")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
TMP=$(mktemp -d)
REPO="$TMP/repo"
FAKEBIN="$TMP/bin"
PORT=${CODEX_WEB_TEST_PORT:-6192}

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

wait_pid() {
  local pid=$1
  for _ in $(seq 1 50); do
    ps -p "$pid" >/dev/null 2>&1 || return 0
    sleep 0.1
  done
  return 0
}

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
if [[ "$prompt" == *"hold active"* ]]; then sleep 4; fi
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

page=$(curl -fsS "http://127.0.0.1:$PORT/")
printf '%s' "$page" | grep -F 'codex-web-interface' >/dev/null
printf '%s' "$page" | grep -F 'Path changes auto-load' >/dev/null
printf '%s' "$page" | grep -F 'hasTextSelection' >/dev/null
printf '%s' "$page" | grep -F 'setInterval(()=>{if(!document.hidden&&!hasTextSelection())refreshAll()},2000)' >/dev/null
printf '%s' "$page" | grep -F 'Click a hash to copy it' >/dev/null
printf '%s' "$page" | grep -F 'Copy message' >/dev/null
printf '%s' "$page" | grep -F 'Continue resumes the latest session; active worktree runs are queued server-side until they finish.' >/dev/null
printf '%s' "$page" | grep -F 'Stop the active Codex run in this worktree and clear web-queued messages' >/dev/null
printf '%s' "$page" | grep -F 'Full transcript' >/dev/null
printf '%s' "$page" | grep -F 'Rename' >/dev/null
printf '%s' "$page" | grep -F 'Active worktrees' >/dev/null
printf '%s' "$page" | grep -F 'Closed worktree runs' >/dev/null
printf '%s' "$page" | grep -F 'recorded cwd no longer maps' >/dev/null
printf '%s' "$page" | grep -F 'window.CHATGIT_CONFIG' >/dev/null
printf '%s' "$page" | grep -F '/api/overview' >/dev/null
! printf '%s' "$page" | grep -F "api('/api/config')" >/dev/null
! printf '%s' "$page" | grep -F 'Archived runs' >/dev/null
printf '%s' "$page" | grep -F 'Paste or drop files' >/dev/null
printf '%s' "$page" | grep -F 'Remove attachment' >/dev/null
printf '%s' "$page" | grep -F '.state-line{display:block;width:100%;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap' >/dev/null
! printf '%s' "$page" | grep -F 'Attach screenshot' >/dev/null
printf '%s' "$page" | grep -F 'agent-active' >/dev/null
printf '%s' "$page" | grep -F 'chatgit launcher' >/dev/null
printf '%s' "$page" | grep -F 'codex_wrap runner' >/dev/null
printf 'ok - page copy exposes interface name, auto-load, polling, copy-message, queue, transcript, and rename hints\n'

overview=$(curl -fsS "http://127.0.0.1:$PORT/api/overview?repo=$(urlencode "$REPO")")
printf '%s' "$overview" | grep -F '"worktrees": [' >/dev/null
printf '%s' "$overview" | grep -F '"messages": [' >/dev/null
printf '%s' "$overview" | grep -F '"status": {' >/dev/null
printf 'ok - overview API combines branch, message, and status data\n'

base=$(git -C "$REPO" rev-parse HEAD)
response=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"branch test\",\"mode\":\"branch\",\"base_commit\":\"$base\"}" \
  "http://127.0.0.1:$PORT/api/run")
branch=$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["branch"])')
worktree=$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["path"])')
log=$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["log"])')
pid=$(printf '%s' "$response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["pid"])')
wait_pid "$pid"

git -C "$worktree" merge-base --is-ancestor "$base" HEAD
parent=$(git -C "$REPO" config --get "branch.$branch.parent-branch")
parent_commit=$(git -C "$REPO" config --get "branch.$branch.parent-commit")
[ "$parent" = main ]
[ "$parent_commit" = "$base" ]
printf 'ok - branch mode creates a child branch with explicit parent metadata\n'

child_base=$(git -C "$worktree" rev-parse HEAD)
response_child=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$worktree\",\"prompt\":\"grandchild branch test\",\"mode\":\"branch\",\"base_commit\":\"$child_base\"}" \
  "http://127.0.0.1:$PORT/api/run")
branch_child=$(printf '%s' "$response_child" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["branch"])')
worktree_child=$(printf '%s' "$response_child" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worktree"]["path"])')
pid_child=$(printf '%s' "$response_child" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["pid"])')
wait_pid "$pid_child"
parent_child=$(git -C "$REPO" config --get "branch.$branch_child.parent-branch")
parent_commit_child=$(git -C "$REPO" config --get "branch.$branch_child.parent-commit")
[ "$parent_child" = "$branch" ]
[ "$parent_commit_child" = "$child_base" ]
git -C "$worktree_child" merge-base --is-ancestor "$child_base" HEAD
printf 'ok - branch mode supports recursive child branches\n'

transcript=$(curl -fsS "http://127.0.0.1:$PORT/api/transcript?repo=$(urlencode "$worktree")&log=$(urlencode "$log")" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transcript"])')
printf '%s' "$transcript" | grep -F 'OpenAI Codex fake' >/dev/null
printf '%s' "$transcript" | grep -F 'branch test' >/dev/null
printf 'ok - transcript API returns full spawned process log\n'

worktree_runs=$(curl -fsS "http://127.0.0.1:$PORT/api/worktrees?repo=$(urlencode "$worktree")")
printf '%s' "$worktree_runs" | grep -F '"runs": [' >/dev/null
printf '%s' "$worktree_runs" | grep -F '"status": "finished"' >/dev/null
printf '%s' "$worktree_runs" | grep -F 'branch test' >/dev/null
printf 'ok - worktree API groups finished runs under active worktrees\n'

printf 'plain text attachment\n' >"$TMP/notes.txt"
upload_response=$(python3 - "$TMP/notes.txt" "$REPO" "$PORT" <<'PY'
import base64, json, sys, urllib.request
path, repo, port = sys.argv[1:]
payload = json.dumps({
    "repo": repo,
    "name": "notes.txt",
    "content_type": "text/plain",
    "data": base64.b64encode(open(path, "rb").read()).decode(),
}).encode()
req = urllib.request.Request(
    f"http://127.0.0.1:{port}/api/upload",
    data=payload,
    headers={"content-type": "application/json"},
)
print(urllib.request.urlopen(req).read().decode())
PY
)
upload_path=$(printf '%s' "$upload_response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["path"])')
[ -s "$upload_path" ]
printf '%s' "$upload_path" | grep -F 'chatgit-uploads' >/dev/null
printf '%s' "$upload_response" | grep -F '"content_type": "text/plain"' >/dev/null
upload_run=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"read attached file\",\"mode\":\"fresh\",\"attachments\":[\"$upload_path\"]}" \
  "http://127.0.0.1:$PORT/api/run")
upload_log=$(printf '%s' "$upload_run" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["log"])')
upload_pid=$(printf '%s' "$upload_run" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["pid"])')
wait_pid "$upload_pid"
upload_transcript=$(curl -fsS "http://127.0.0.1:$PORT/api/transcript?repo=$(urlencode "$REPO")&log=$(urlencode "$upload_log")" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transcript"])')
printf '%s' "$upload_transcript" | grep -F "$upload_path" >/dev/null
printf 'ok - arbitrary file upload stores a file and includes its path in prompts\n'

injection_file="$TMP/should-not-exist"
injection_run=$(python3 - "$REPO" "$PORT" "$injection_file" <<'PY'
import json, sys, urllib.request
repo, port, target = sys.argv[1:]
prompt = f"literal shell metacharacters $(touch {target}) ; echo nope 'quoted'"
payload = json.dumps({"repo": repo, "prompt": prompt, "mode": "fresh"}).encode()
req = urllib.request.Request(
    f"http://127.0.0.1:{port}/api/run",
    data=payload,
    headers={"content-type": "application/json"},
)
print(urllib.request.urlopen(req).read().decode())
PY
)
injection_pid=$(printf '%s' "$injection_run" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["pid"])')
injection_log=$(printf '%s' "$injection_run" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["log"])')
wait_pid "$injection_pid"
[ ! -e "$injection_file" ]
injection_transcript=$(curl -fsS "http://127.0.0.1:$PORT/api/transcript?repo=$(urlencode "$REPO")&log=$(urlencode "$injection_log")" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transcript"])')
printf '%s' "$injection_transcript" | grep -F '$(touch ' >/dev/null
printf 'ok - web prompts keep shell metacharacters literal\n'

curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"slow queue first\",\"mode\":\"fresh\",\"base_commit\":\"\"}" \
  "http://127.0.0.1:$PORT/api/run" >/dev/null
queued_response=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"queued followup\",\"mode\":\"send\",\"base_commit\":\"\"}" \
  "http://127.0.0.1:$PORT/api/run")
printf '%s' "$queued_response" | grep -F '"queued": true' >/dev/null
status=$(curl -fsS "http://127.0.0.1:$PORT/api/status?repo=$REPO")
printf '%s' "$status" | grep -F '"queue_depth": 1' >/dev/null
printf '%s' "$status" | grep -F '"queue": [' >/dev/null
for _ in $(seq 1 80); do
  git -C "$REPO" log --format=%B -n 40 | grep -F 'queued followup' >/dev/null && break
  sleep 0.1
done
git -C "$REPO" log --format=%B -n 40 | grep -F 'queued followup' >/dev/null
status=$(curl -fsS "http://127.0.0.1:$PORT/api/status?repo=$REPO")
printf '%s' "$status" | grep -F '"queue_depth": 0' >/dev/null
printf 'ok - web server queues messages behind active runs\n'

active_response=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$REPO\",\"prompt\":\"hold active\",\"mode\":\"fresh\"}" \
  "http://127.0.0.1:$PORT/api/run")
active_pid=$(printf '%s' "$active_response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["pid"])')
active_seen=0
for _ in $(seq 1 30); do
  active_worktrees=$(curl -fsS "http://127.0.0.1:$PORT/api/worktrees?repo=$REPO")
  if printf '%s' "$active_worktrees" | grep -F '"active": {' >/dev/null; then
    active_seen=1
    break
  fi
  sleep 0.1
done
[ "$active_seen" = 1 ]
kill "$active_pid" 2>/dev/null || true
wait_pid "$active_pid"
printf 'ok - worktree API marks branches with active agents\n'
active_cleared=0
for _ in $(seq 1 30); do
  active_worktrees=$(curl -fsS "http://127.0.0.1:$PORT/api/worktrees?repo=$REPO")
  if ! printf '%s' "$active_worktrees" | grep -F '"active": {' >/dev/null; then
    active_cleared=1
    break
  fi
  sleep 0.1
done
[ "$active_cleared" = 1 ]
printf 'ok - worktree API clears active marker after process exit\n'

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
pid2=$(printf '%s' "$response2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["process"]["pid"])')
wait_pid "$pid2"
[ "$branch2" != "$branch" ]
[ "$worktree2" != "$worktree" ]
[ "$log2" != "$log" ]
printf 'ok - repeated tab branch requests get distinct branches and logs\n'

git -C "$REPO" merge -q --no-edit "$branch2"
git -C "$REPO" worktree remove --force "$worktree2"
git -C "$REPO" branch -D "$branch2" >/dev/null
archived=$(curl -fsS "http://127.0.0.1:$PORT/api/worktrees?repo=$(urlencode "$REPO")")
printf '%s' "$archived" | grep -F '"archived_runs": [' >/dev/null
printf '%s' "$archived" | grep -F "\"branch\": \"$branch2\"" >/dev/null
printf '%s' "$archived" | grep -F '"raw": "[codex_start_user]' >/dev/null
archive_hash=$(printf '%s' "$archived" | python3 -c 'import json,sys; j=json.load(sys.stdin); print(j["archived_runs"][0]["hash"])')
archive_transcript=$(curl -fsS "http://127.0.0.1:$PORT/api/transcript?repo=$(urlencode "$REPO")&commit=$archive_hash" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transcript"])')
printf '%s' "$archive_transcript" | grep -F 'second branch test' >/dev/null
printf 'ok - archived runs survive finished branch cleanup with transcripts\n'

renamed="renamed-$branch"
rename_response=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d "{\"repo\":\"$worktree\",\"old_branch\":\"$branch\",\"new_branch\":\"$renamed\"}" \
  "http://127.0.0.1:$PORT/api/branch/rename")
printf '%s' "$rename_response" | grep -F "\"branch\": \"$renamed\"" >/dev/null
[ "$(git -C "$worktree" branch --show-current)" = "$renamed" ]
renamed_worktrees=$(curl -fsS "http://127.0.0.1:$PORT/api/worktrees?repo=$worktree")
printf '%s' "$renamed_worktrees" | grep -F "\"branch\": \"$renamed\"" >/dev/null
printf 'ok - branch rename API renames the owning worktree branch\n'

show=$(curl -fsS "http://127.0.0.1:$PORT/api/show?repo=$REPO&commit=$base" | python3 -c 'import json,sys; print(json.load(sys.stdin)["patch"])')
printf '%s' "$show" | grep -F 'AuthorDate:' >/dev/null
printf '%s' "$show" | grep -F 'diff --git' >/dev/null
printf 'ok - commit detail API returns fuller git show patch output\n'

bad_show_code=$(curl -sS -o "$TMP/bad-show.json" -w '%{http_code}' "http://127.0.0.1:$PORT/api/show?repo=$REPO&commit=--help")
[ "$bad_show_code" = 500 ]
grep -F 'invalid commit' "$TMP/bad-show.json" >/dev/null
printf 'ok - commit detail rejects git option-shaped commits\n'

if command -v google-chrome >/dev/null 2>&1; then
  dom=$(google-chrome --headless --disable-gpu --no-sandbox --dump-dom --virtual-time-budget=3000 "http://127.0.0.1:$PORT/" 2>/dev/null)
  printf '%s' "$dom" | grep -F "$branch ← main" >/dev/null
  printf '%s' "$dom" | grep -F "$branch_child ← $branch" >/dev/null
  printf '%s' "$dom" | grep -F 'Closed worktree runs' >/dev/null
  printf '%s' "$dom" | grep -F 'Transcript' >/dev/null
  printf '%s' "$dom" | grep -F 'Patch' >/dev/null
  printf '%s' "$dom" | grep -F 'Copy message' >/dev/null
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
