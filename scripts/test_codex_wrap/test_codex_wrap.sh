#!/usr/bin/env bash
set -euo pipefail

WRAP=${1:-/mnt/data/codex_wrap_parallel.sh}
ROOT=$(mktemp -d)
FAKEBIN="$ROOT/bin"
mkdir -p "$FAKEBIN"

cat >"$FAKEBIN/codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
SID="11111111-1111-1111-1111-111111111111"

emit_agent() {
  /usr/bin/python3 - "$1" "$2" <<'PY'
import json, sys
print(json.dumps({"type":"item.completed","item":{"id":sys.argv[1],"type":"agent_message","text":sys.argv[2]}}))
PY
}
emit_tool() {
  /usr/bin/python3 - <<'PY'
import json
print(json.dumps({"type":"item.completed","item":{"id":"tool-1","type":"command_execution","command":"git status","output":"RAW_TOOL_OUTPUT_SHOULD_NOT_APPEAR"}}))
PY
}
banner() {
  {
    echo 'OpenAI Codex v0.125.0 (fake)'
    echo '--------'
    echo "workdir: $PWD"
    echo 'model: gpt-5.5'
    echo 'provider: openai'
    echo 'approval: never'
    echo 'sandbox: danger-full-access'
    echo "session id: $SID"
    echo '--------'
    echo 'user'
    echo "$*"
  } >&2
}

if [[ ${1:-} == --version ]]; then echo 'OpenAI Codex v0.125.0 (fake)'; exit 0; fi
[[ ${1:-} == exec ]] || { echo "fake codex: expected exec" >&2; exit 2; }
shift
mode=start
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json|--experimental-json|--dangerously-bypass-approvals-and-sandbox|--yolo) shift ;;
    --sandbox|--model|-m|--cd|-C|-c|--config|--profile|-p|--color|--output-last-message|-o) shift 2 ;;
    resume) mode=resume; SID=$2; shift 2; break ;;
    --*) shift ;;
    *) break ;;
  esac
done
prompt="$*"
banner "$prompt"
printf '{"type":"thread.started","thread_id":"%s"}\n' "$SID"
printf '{"type":"item.completed","item":{"id":"user-1","type":"user_message","text":"ignored user"}}\n'

if [[ $mode == resume ]]; then
  emit_agent resume-1 "resumed: $prompt"
  exit 0
fi

case "$prompt" in
  multi*)
    emit_agent agent-1 'first output'
    emit_tool
    emit_agent agent-2 'second output'
    ;;
  lock*)
    lock=$(git rev-parse --git-path index.lock)
    mkdir -p "$(dirname "$lock")"
    echo $$ >"$lock"
    trap 'rm -f "$lock"' EXIT TERM
    emit_agent agent-1 'lock survived'
    sleep 0.2
    ;;
  long*)
    trap 'exit 143' TERM INT
    while :; do sleep 0.2; done
    ;;
  delayed*)
    sleep 0.3
    emit_agent agent-1 "delayed done: $prompt"
    ;;
  from-text-transcript*)
    emit_agent t1 'I’ll inspect the repo state first: current branch, local changes, upstream relation, and the project status notes so I can fix the divergence without trampling unrelated work.'
    emit_tool
    emit_agent t2 'Both tips have exactly the same tree: the only divergence is commit history for the same STATUS.md rewrite.'
    emit_agent t3 'Fixed. main and origin/main are synchronized at 1cea926.'
    ;;
  *)
    emit_agent agent-1 "done: $prompt"
    ;;
esac
FAKE
chmod +x "$FAKEBIN/codex"
export PATH="$FAKEBIN:$PATH"
export CODEX_WRAP_STDIN_NEW_MESSAGE=0
export CODEX_WRAP_PNPM_INSTALL=0
export CODEX_WRAP_POLL_SECONDS=0.01
unset CODEX_WRAP_CALLED_BY

# shellcheck source=/mnt/data/codex_wrap.sh
. "$WRAP"
WRAP_DIR=$(cd "$(dirname "$WRAP")" && pwd)
# shellcheck source=/mnt/data/branch_commands.sh
. "$WRAP_DIR/branch_commands.sh"

ok() { printf 'ok - %s\n' "$*"; }
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
contains() { grep -Fq "$1" <<<"$2" || fail "missing: $1"; }
not_contains() { ! grep -Fq "$1" <<<"$2" || fail "unexpected: $1"; }
equals() {
  [ "$1" = "$2" ] && return 0
  printf 'not ok - exact mismatch\nexpected:\n%s\nactual:\n%s\n' "$1" "$2" >&2
  exit 1
}
field_from_text() {
  awk -F': ' -v key="$1" '$1 == key { sub("^[^:]*: ", ""); print; exit }' <<<"$2"
}
assert_compact_run_marker() {
  local label=$1 body=$2 prompt=$3
  [ "$(printf '%s\n' "$body" | sed -n '1p')" = "$label" ] || fail "run marker subject should be exactly $label"
  contains 'message-role: user' "$body"
  contains 'session-id: 11111111-1111-1111-1111-111111111111' "$body"
  contains 'called-by: user' "$body"
  contains 'pid: ' "$body"
  contains 'pgid: ' "$body"
  contains 'host: ' "$body"
  contains 'cwd: ' "$body"
  contains 'started-at: ' "$body"
  ! printf '%s' "$body" | grep -F -x 'user' >/dev/null || fail 'run marker should not contain legacy user delimiter'
  not_contains 'OpenAI Codex v0.125.0 (fake)' "$body"
  not_contains "$prompt" "$body"
}
assert_assistant_pointer() {
  local body=$1 run_start=$2 forbidden=$3
  [[ $(printf '%s\n' "$body" | sed -n '1p') == codex:\ update\ * ]] || fail 'assistant commit subject should be a compact codex pointer'
  contains 'agent: ' "$body"
  contains 'message-role: assistant' "$body"
  contains 'transcript: transcripts/archive/' "$body"
  contains "run-start-commit-hash: $run_start" "$body"
  contains 'session-id: 11111111-1111-1111-1111-111111111111' "$body"
  contains 'at: ' "$body"
  [ -z "$forbidden" ] || not_contains "$forbidden" "$body"
}
assert_no_legacy_active_agents() {
  ! git ls-tree --name-only -r HEAD | grep -E '^active-agents/' >/dev/null || fail 'legacy active-agents path present in HEAD'
  ! git log --all --name-only --format= -- active-agents | grep -E '^active-agents/' >/dev/null || fail 'legacy active-agents path created in history'
}

setup_repo() {
  local d
  d=$(mktemp -d "$ROOT/repo.XXXXXX")
  cd "$d"
  git init -q -b main
  git config user.email test@example.com
  git config user.name Tester
  echo base >file.txt
  git add file.txt
  git commit -q -m base
}
subjects() { git log --reverse --pretty=%s; }
body_head() { git log -1 --format=%B; }
wait_active_sid() {
  local common deadline
  deadline=$((SECONDS + 5))
  while [ $SECONDS -lt $deadline ]; do
    codex_active >/dev/null 2>&1 && return 0
    sleep 0.05
  done
  return 1
}

wait_subject() {
  local needle=$1 deadline
  deadline=$((SECONDS + 5))
  while [ $SECONDS -lt $deadline ]; do
    git log --pretty=%s | grep -F "$needle" >/dev/null 2>&1 && return 0
    sleep 0.05
  done
  return 1
}

test_basic() {
  setup_repo
  codex_commit hi
  s=$(subjects)
  contains '[codex_start_user]' "$s"
  contains 'codex: update hi-' "$s"
  contains '[codex_stop] 11111111-1111-1111-1111-111111111111' "$s"
  start_body=$(git log --format=%B --grep='^\[codex_start_user\]' -1)
  assert_compact_run_marker '[codex_start_user]' "$start_body" 'hi'
  sh=$(git log --format=%H --grep='^\[codex_start_user\]' -1)
  ab=$(git log --format=%B --grep='^codex: update' -1)
  assert_assistant_pointer "$ab" "$sh" 'done: hi'
  archive=$(field_from_text transcript "$ab")
  [ -n "$archive" ] || fail 'assistant pointer missing transcript field'
  grep -F 'done: hi' "$archive" >/dev/null || fail 'assistant output missing from transcript file'
  assert_no_legacy_active_agents
  ok basic
}


test_assistant_messages_use_pointer_commits_and_ignore_tools() {
  setup_repo
  codex_commit multi
  count=$(git log --pretty=%s | grep -c '^codex: update')
  [ "$count" -eq 2 ] || fail "expected one pointer commit per assistant message, got $count"
  sh=$(git log --format=%H --grep='^\[codex_start_user\]' -1)
  b=$(git log --format=%B --grep='^codex: update' -1)
  assert_assistant_pointer "$b" "$sh" 'second output'
  not_contains 'first output' "$b"
  archive=$(field_from_text transcript "$b")
  [ -n "$archive" ] || fail 'assistant pointer missing transcript field'
  grep -F 'first output' "$archive" >/dev/null || fail 'first output missing from transcript file'
  grep -F 'second output' "$archive" >/dev/null || fail 'second output missing from transcript file'
  ok 'assistant messages use transcript pointers'
}

test_tool_calls_use_bounded_summary_logs() {
  setup_repo
  codex_commit multi
  tool_commit=$(git log --format=%B --grep='^tool: update' -1)
  contains 'message-role: tool-summary' "$tool_commit"
  contains 'tool: command_execution' "$tool_commit"
  tool_log=$(field_from_text tool-calls "$tool_commit")
  [ -n "$tool_log" ] || fail 'tool summary pointer missing tool-calls field'
  [ -f "$tool_log" ] || fail 'tool summary file missing'
  log_text=$(cat "$tool_log")
  contains 'Bounded metadata only' "$log_text"
  contains 'command_execution' "$log_text"
  contains 'git status' "$log_text"
  contains 'output_bytes |' "$log_text"
  contains '| 33 |' "$log_text"
  not_contains 'RAW_TOOL_OUTPUT_SHOULD_NOT_APPEAR' "$log_text"
  ok 'tool calls use bounded summary logs'
}


test_autosave_is_rewritten() {
  setup_repo
  echo autosave >file.txt
  git add file.txt
  git commit -q -m '[autosave]'
  codex_commit hi
  s=$(subjects)
  not_contains '[autosave]' "$s"
  contains '[codex_start_user]' "$s"
  grep -F autosave file.txt >/dev/null || fail 'autosave tree not preserved'
  ok 'autosave rewritten'
}

test_index_lock_does_not_block_markers() {
  setup_repo
  codex_commit lock
  s=$(subjects)
  contains '[codex_start_user]' "$s"
  contains 'codex: update lock-' "$s"
  contains '[codex_stop] 11111111-1111-1111-1111-111111111111' "$s"
  ok 'index lock avoided'
}

test_resume() {
  setup_repo
  codex_commit hi
  codex_resume again
  s=$(subjects)
  contains '[codex_resume_user]' "$s"
  contains 'codex: update again-' "$s"
  resume_body=$(git log --format=%B --grep='^\[codex_resume_user\]' -1)
  assert_compact_run_marker '[codex_resume_user]' "$resume_body" 'again'
  ok resume
}

test_called_by_env_commit() {
  setup_repo
  caller=$(git rev-parse HEAD)
  CODEX_WRAP_CALLED_BY=$caller codex_commit child
  git log --format=%B --grep='^\[codex_start_user\]' -1 | grep -F "called-by: $caller" >/dev/null || fail 'explicit caller metadata missing'
  ok 'called-by env commit'
}

test_called_by_env_rejects_invalid_commit() {
  setup_repo
  if CODEX_WRAP_CALLED_BY=not-a-commit codex_commit invalid >/tmp/cw-invalid.out 2>/tmp/cw-invalid.err; then
    fail 'invalid called-by should fail'
  fi
  ! git log --format=%B --grep='^\[codex_start_user\]' -1 | grep -F 'invalid' >/dev/null || fail 'invalid called-by created start marker'
  grep -F 'invalid CODEX_WRAP_CALLED_BY value' /tmp/cw-invalid.err >/dev/null || fail 'invalid called-by error missing'
  ok 'called-by env rejects invalid commit'
}

test_new_message_interrupts_running_process() {
  setup_repo
  codex_commit long >/tmp/cw-long.out 2>/tmp/cw-long.err & bg=$!
  wait_active_sid || fail 'no active sid for long run'
  codex_new_message interrupt
  wait "$bg" || true
  s=$(subjects)
  contains '[codex_start_user]' "$s"
  contains '[codex_stop] 11111111-1111-1111-1111-111111111111' "$s"
  contains '[codex_resume_user]' "$s"
  contains 'codex: update interrupt-' "$s"
  ok 'new message interrupts'
}

test_new_message_appends_user_followup_to_inbox_and_transcript() {
  setup_repo
  codex_commit long >/tmp/cw-followup.out 2>/tmp/cw-followup.err & bg=$!
  wait_active_sid || fail 'no active sid for followup run'
  active_path=$(git ls-tree --name-only -r HEAD | grep -E '^transcripts/active/[^/]+\.md$' | head -n1 || true)
  [ -n "$active_path" ] || fail 'active transcript pointer missing before followup'
  slug=${active_path#transcripts/active/}
  slug=${slug%.md}
  inbox_path="agents/$slug/inbox.md"
  archive_path=$(git ls-tree --name-only -r HEAD | grep -E "^transcripts/archive/[0-9]{4}-[0-9]{2}-[0-9]{2}-$slug\\.md$" | head -n1 || true)
  [ -n "$archive_path" ] || fail 'archive transcript missing before followup'
  codex_new_message 'new instruction'
  wait "$bg" || true
  [ -f "$inbox_path" ] || fail 'original inbox missing after followup'
  [ -f "$archive_path" ] || fail 'original archive missing after followup'
  grep -F '### ' "$inbox_path" | grep -F ' user' >/dev/null || fail 'inbox missing user followup header'
  grep -F 'new instruction' "$inbox_path" >/dev/null || fail 'inbox missing user followup text'
  grep -F '## ' "$archive_path" | grep -F ' user' >/dev/null || fail 'archive missing user followup header'
  grep -F 'new instruction' "$archive_path" >/dev/null || fail 'archive missing user followup text'
  user_commit=$(git log --format='%H' --grep="^user: message to $slug" -1)
  [ -n "$user_commit" ] || fail 'user followup commit missing'
  [ "$(git show -s --format='%an <%ae>' "$user_commit")" = 'user <user@local.agent>' ] || fail 'user followup author mismatch'
  ok 'new message appends user followup to inbox and transcript'
}

test_abort_from_other_shell_context() {
  setup_repo
  codex_commit long >/tmp/cw-abort.out 2>/tmp/cw-abort.err & bg=$!
  wait_active_sid || fail 'no active sid for abort run'
  wait_subject '[codex_start_user]' || fail 'no start marker before abort'
  codex_abort
  wait "$bg" || true
  s=$(subjects)
  contains '[codex_start_user]' "$s"
  contains '[codex_abort] 11111111-1111-1111-1111-111111111111' "$s"
  headsub=$(git log -1 --pretty=%s)
  [[ $headsub == '[codex_abort]'* ]] || fail "head should be abort, got $headsub"
  ok abort
}

test_interactive_job_control_tracks_setsid_child() {
  setup_repo
  set -m
  codex_commit delayed >/tmp/cw-delayed.out 2>/tmp/cw-delayed.err
  set +m
  s=$(subjects)
  contains '[codex_start_user]' "$s"
  contains 'codex: update delayed-' "$s"
  contains '[codex_stop] 11111111-1111-1111-1111-111111111111' "$s"
  ok 'interactive job-control setsid child'
}

test_codex_commit_at_is_plain_prompt() {
  setup_repo
  base=$(git rev-parse HEAD)
  echo next >>file.txt && git add file.txt && git commit -q -m next
  codex_commit @ "$base" branch-task
  branch=$(git rev-parse --abbrev-ref HEAD)
  [[ $branch == main ]] || fail "codex_commit @ changed branch: $branch"
  [ ! -d "$PWD.worktrees" ] || fail 'codex_commit @ should not create a worktree'
  s=$(subjects)
  contains '[codex_start_user]' "$s"
  contains 'codex: update ' "$s"
  ok 'codex @ is plain prompt'
}

test_codex_prompt_metacharacters_are_literal() {
  setup_repo
  target="$ROOT/should-not-exist"
  prompt="literal shell metacharacters \$(touch $target) ; echo nope 'quoted'"
  codex_commit "$prompt"
  [ ! -e "$target" ] || fail 'prompt shell metacharacters executed'
  b=$(git log --format=%B --grep='^\[codex_start_user\]' -1)
  not_contains '$(touch ' "$b"
  archive=$(git ls-tree --name-only -r HEAD | grep -E '^transcripts/archive/.*literal-shell-metacharacters.*\.md$' | head -n1)
  grep -F '$(touch ' "$archive" >/dev/null || fail 'prompt missing from transcript file'
  grep -F "'quoted'" "$archive" >/dev/null || fail 'quoted prompt missing from transcript file'
  ok 'codex prompt metacharacters are literal'
}

test_codex_in_branch_at_commit_uses_worktree_wrapper() {
  setup_repo
  root=$PWD
  base=$(git rev-parse HEAD)
  echo next >>file.txt && git add file.txt && git commit -q -m next
  codex_in_branch @ "$base" branch-task
  [ "$PWD" = "$root" ] || fail 'codex_in_branch should not cd parent shell'
  branch=$(git branch --format='%(refname:short)' --list 'work-*' | head -n1)
  [ -n "$branch" ] || fail 'codex_in_branch did not create work branch'
  wt=$(worktree_find_for_branch "$branch") || fail 'created worktree not found'
  [ "$(git config --get "branch.$branch.parent-branch")" = main ] || fail 'created worktree missing parent branch metadata'
  [ "$(git config --get "branch.$branch.parent-commit")" = "$base" ] || fail 'created worktree missing parent commit metadata'
  git -C "$wt" merge-base --is-ancestor "$base" HEAD || fail 'worktree branch not rooted at requested commit'
  s=$(git -C "$wt" log --reverse --pretty=%s)
  contains '[codex_start_user]' "$s"
  contains 'codex: update ' "$s"
  ok 'codex_in_branch @ commit'
}

test_do_at_branch_uses_existing_branch_worktree() {
  setup_repo
  root=$PWD
  git worktree add -q -b existing "$root.worktrees/existing" HEAD
  do_at_branch existing sh -c 'printf "%s\n" "$PWD" > ../branch-pwd.txt'
  [ "$PWD" = "$root" ] || fail 'do_at_branch should not cd parent shell'
  actual=$(cat "$root.worktrees/branch-pwd.txt")
  [ "$actual" = "$root.worktrees/existing" ] || fail "do_at_branch ran in $actual"
  ok 'do_at_branch existing worktree'
}

test_codex_checkpoint_empty_commit() {
  setup_repo
  before=$(git rev-parse HEAD)
  codex_checkpoint 'last save state before risky edit'
  after=$(git rev-parse HEAD)
  [ "$before" != "$after" ] || fail 'checkpoint did not create a commit'
  [ "$(git log -1 --pretty=%s)" = 'checkpoint: last save state before risky edit' ] || fail 'checkpoint subject mismatch'
  [ "$(git diff-tree --no-commit-id --name-only -r HEAD)" = "" ] || fail 'checkpoint should be empty'
  ok 'codex checkpoint empty commit'
}

test_codex_status_empty_commit() {
  setup_repo
  before=$(git rev-parse HEAD)
  codex_status 'summarized work refs abc123 def456'
  after=$(git rev-parse HEAD)
  [ "$before" != "$after" ] || fail 'status did not create a commit'
  [ "$(git log -1 --pretty=%s)" = '[status] summarized work refs abc123 def456' ] || fail 'status subject mismatch'
  [ "$(git diff-tree --no-commit-id --name-only -r HEAD)" = "" ] || fail 'status should be empty'
  ok 'codex status empty commit'
}

test_codex_spawn_detached_agent() {
  setup_repo
  out=$(codex_spawn codex_commit long-spawn)
  contains 'codex_spawn: pid=' "$out"
  log=$(printf '%s\n' "$out" | sed -n 's/.* log=\([^ ]*\) .*/\1/p')
  [ -n "$log" ] || fail 'spawn log missing'
  wait_subject '[codex_start_user]' || fail 'spawned run did not start'
  codex_active >/tmp/cw-spawn-active || fail 'spawned run is not active'
  [ -f "$log" ] || fail 'spawn log file not created'
  git log --format=%B --grep='^\[codex_start_user\]' -1 | grep -F 'called-by: user' >/dev/null || fail 'spawn caller metadata missing'
  codex_abort >/tmp/cw-spawn-abort.out 2>/tmp/cw-spawn-abort.err || fail 'could not abort spawned run'
  ok 'codex spawn detached agent'
}

test_codex_agents_lists_live_pid_tasks() {
  setup_repo
  h=$(python3 - <<'PY'
import socket
print(socket.getfqdn() or socket.gethostname())
PY
)
  msg="$ROOT/agent-msg"
  cat >"$msg" <<EOF
[codex_start_user] inspect active agents

user
inspect active agents

session-id: 11111111-1111-1111-1111-111111111111
called-by: user
pid: $$
pgid: $$
host: $h
cwd: $PWD
started-at: 2026-05-01T00:00:00+0000
EOF
  git commit --allow-empty -q -F "$msg"
  out=$(codex_agents)
  contains 'inspect active agents' "$out"
  contains "pid=$$" "$out"
  contains "cwd=$PWD" "$out"
  ok 'codex agents lists live pid tasks'
}

test_transcript_inbox_artifacts_are_tracked_and_active_pointer_removed() {
  setup_repo
  codex_commit long >/tmp/cw-transcript-inbox.out 2>/tmp/cw-transcript-inbox.err & bg=$!
  wait_active_sid || fail 'no active sid for transcript inbox run'
  run=$(codex_active)
  active_path=$(git ls-tree --name-only -r HEAD | grep -E '^transcripts/active/[^/]+\.md$' | head -n1 || true)
  [ -n "$active_path" ] || fail 'active transcript pointer missing from active HEAD'
  slug=${active_path#transcripts/active/}
  slug=${slug%.md}
  profile_path="agents/$slug/profile.md"
  inbox_path="agents/$slug/inbox.md"
  archive_path=$(git ls-tree --name-only -r HEAD | grep -E "^transcripts/archive/[0-9]{4}-[0-9]{2}-[0-9]{2}-$slug\\.md$" | head -n1 || true)
  [ -f "$profile_path" ] || fail 'agent profile missing from worktree'
  [ -f "$inbox_path" ] || fail 'agent inbox missing from worktree'
  [ -n "$archive_path" ] || fail 'archive transcript missing from active HEAD'
  [ -f "$archive_path" ] || fail 'archive transcript missing from worktree'
  git show "HEAD:$profile_path" | grep -F "agent: $slug" >/dev/null || fail 'profile does not include slug metadata'
  git show "HEAD:$inbox_path" | grep -F '## pending' >/dev/null || fail 'inbox missing pending section'
  git show "HEAD:$archive_path" | grep -F '## ' | grep -F ' user' >/dev/null || fail 'archive transcript missing user block'
  git show "HEAD:$active_path" | grep -F "transcript: ../archive/" >/dev/null || fail 'active pointer missing transcript reference'
  git show -s --format='%an <%ae>' HEAD | grep -E '^(codex:|user <user@local\.agent>|orchestrator:)' >/dev/null || fail 'wrapper commit author does not identify speaker'
  codex_abort >/tmp/cw-transcript-inbox-abort.out 2>/tmp/cw-transcript-inbox-abort.err || fail 'could not abort transcript inbox run'
  wait "$bg" || true
  [ ! -e "$active_path" ] || fail 'active transcript pointer should be deleted after abort'
  ! git ls-tree --name-only -r HEAD | grep -F "$active_path" >/dev/null || fail 'active transcript pointer should be absent from final HEAD'
  [ -f "$profile_path" ] || fail 'profile should remain after abort'
  [ -f "$inbox_path" ] || fail 'inbox should remain after abort'
  [ -f "$archive_path" ] || fail 'archive transcript should remain after abort'
  git log --all --name-only --format= -- transcripts agents | grep -F "$archive_path" >/dev/null || fail 'archive transcript was not preserved in git history'
  assert_no_legacy_active_agents
  ok 'transcript inbox artifacts are tracked and active pointer removed'
}

test_codex_sync_push_skips_duplicate_upstream_patch() {
  setup_repo
  remote=$(mktemp -d "$ROOT/remote.XXXXXX")
  other=$(mktemp -d "$ROOT/other.XXXXXX")
  git init -q --bare "$remote"
  git remote add origin "$remote"
  git push -q -u origin main

  printf 'same\n' >sync.txt
  git add sync.txt
  git commit -q -m local-same

  git clone -q "$remote" "$other"
  git -C "$other" config user.email test@example.com
  git -C "$other" config user.name Tester
  printf 'same\n' >"$other/sync.txt"
  git -C "$other" add sync.txt
  git -C "$other" commit -q -m remote-same
  git -C "$other" push -q

  git fetch -q origin
  status=$(git status --short --branch)
  contains 'ahead 1, behind 1' "$status"
  codex_sync_push >/tmp/cw-sync-push.out 2>/tmp/cw-sync-push.err
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fail 'sync push did not align HEAD with origin/main'
  [ "$(git log -1 --pretty=%s)" = remote-same ] || fail 'duplicate local patch was not skipped'
  ok 'codex sync push skips duplicate upstream patch'
}

test_codex_sync_push_refuses_active_run() {
  setup_repo
  h=$(python3 - <<'PY'
import socket
print(socket.getfqdn() or socket.gethostname())
PY
)
  msg="$ROOT/active-sync-msg"
  cat >"$msg" <<EOF
[codex_start_user] active sync guard

user
active sync guard

session-id: 11111111-1111-1111-1111-111111111111
called-by: user
pid: $$
pgid: $$
host: $h
cwd: $PWD
started-at: 2026-05-01T00:00:00+0000
EOF
  git commit --allow-empty -q -F "$msg"
  if codex_sync_push >/tmp/cw-active-sync.out 2>/tmp/cw-active-sync.err; then
    fail 'codex_sync_push should refuse active runs'
  fi
  grep -F 'refusing to sync while a local Codex run is active' /tmp/cw-active-sync.err >/dev/null || fail 'active sync refusal message missing'
  ok 'codex sync push refuses active run'
}

test_codex_dispatch_prompt_contract() {
  setup_repo
  target="$ROOT/dispatch-should-not-exist"
  printf '# Test Status\n\n## Active Goals\n- [ ] dispatch sample\n' >STATUS.md
  git add STATUS.md && git commit -q -m status
  git commit --allow-empty -q -m '[codex_start_user] You are a Codex dispatch/orchestration agent. Prior duplicated body that should be elided from context' -m $'user\nYou are a Codex dispatch/orchestration agent. Prior duplicated body that should be elided from context\n\nsession-id: 22222222-2222-2222-2222-222222222222\ncalled-by: user\npid: 999999\npgid: 999999\nhost: test-host\ncwd: /tmp/test\nstarted-at: 2026-05-01T00:00:00+0000'
  codex_dispatch "split this safely \$(touch $target)"
  [ ! -e "$target" ] || fail 'dispatch prompt shell metacharacters executed'
  b=$(git log --format=%B --grep='^codex: update' -1)
  sh=$(git log --format=%H --grep='^\[codex_start_user\]' -1)
  assert_assistant_pointer "$b" "$sh" ''
  archive=$(field_from_text transcript "$b")
  [ -n "$archive" ] || fail 'dispatch assistant pointer missing transcript field'
  transcript=$(cat "$archive")
  contains 'You are a Codex dispatch/orchestration agent.' "$transcript"
  contains 'Agent Context Pack' "$transcript"
  contains 'Audit trail' "$transcript"
  not_contains 'Prior duplicated body that should be elided from context' "$transcript"
  contains 'First reconcile state from the Agent Context Pack' "$transcript"
  expected_dispatch_contract=$(cat <<'EOF'
- Classify the request as exactly one of: status-only, trivial-chat, delegated-implementation, cleanup, or blocked.
- If status-only or trivial-chat, do not spawn; answer directly in the final status.
- If delegated-implementation is needed, create or update the task surface first: STATUS.md for current state and plan, agents/<slug>/inbox.md for targeted follow-up when an agent already exists, and codex_spawn child tasks for implementation work.
- Broad implementation must be delegated via codex_spawn: split into independent, reviewable tasks with disjoint write scopes and call child agents rather than doing broad work in the dispatcher.
EOF
)
  contains "$expected_dispatch_contract" "$transcript"
  contains 'Do local implementation only for the tiny glue needed to decide dispatch, unblock routing, update task routing surfaces, or fix the dispatcher itself; otherwise delegate.' "$transcript"
  contains 'compare recent run-start marker pid/cwd metadata with the live process table' "$transcript"
  contains 'Read transcripts/index.md and the relevant agents/*/profile.md' "$transcript"
  contains 'Send follow-ups through codex_new_message or a target agents/<slug>/inbox.md update' "$transcript"
  contains 'Spawn new agents with named task scopes' "$transcript"
  contains 'Source the helpers before calling them' "$transcript"
  contains 'After each codex_spawn call, verify that a child start marker appears' "$transcript"
  contains 'marker-only/no-op' "$transcript"
  contains 'codex_spawn codex_in_branch @ <branch-or-commit> "<prompt>"' "$transcript"
  contains 'codex_spawn sets CODEX_WRAP_CALLED_BY from codex_active by default' "$transcript"
  contains 'End with a single round of codex_spawn calls' "$transcript"
  contains 'Include concise citations in dispatched prompts' "$transcript"
  contains 'periodic empty [status] commits' "$transcript"
  contains 'checkpoint: last save state before <work>' "$transcript"
  contains '## Current STATUS.md' "$transcript"
  contains 'dispatch sample' "$transcript"
  contains '$(touch ' "$transcript"
  ok 'codex dispatch prompt contract'
}


test_parallel_sibling_worktrees_are_branch_local() {
  setup_repo
  root=$PWD
  base=$(git rev-parse HEAD)
  git worktree add -q -b para-a "$root.worktrees/para-a" "$base"
  git worktree add -q -b para-b "$root.worktrees/para-b" "$base"
  wa="$root.worktrees/para-a"
  wb="$root.worktrees/para-b"
  ( cd "$wa" && codex_commit long-a >/tmp/cw-para-a.out 2>/tmp/cw-para-a.err ) & bga=$!
  ( cd "$wb" && codex_commit long-b >/tmp/cw-para-b.out 2>/tmp/cw-para-b.err ) & bgb=$!
  deadline=$((SECONDS + 6))
  while [ $SECONDS -lt $deadline ]; do git -C "$wa" log --pretty=%s | grep -F '[codex_start_user]' >/dev/null 2>&1 && break; sleep 0.05; done
  git -C "$wa" log --pretty=%s | grep -F '[codex_start_user]' >/dev/null 2>&1 || fail 'para-a did not start'
  deadline=$((SECONDS + 6))
  while [ $SECONDS -lt $deadline ]; do git -C "$wb" log --pretty=%s | grep -F '[codex_start_user]' >/dev/null 2>&1 && break; sleep 0.05; done
  git -C "$wb" log --pretty=%s | grep -F '[codex_start_user]' >/dev/null 2>&1 || fail 'para-b did not start'
  ( cd "$wa" && codex_new_message a-followup )
  ( cd "$wb" && codex_abort )
  wait "$bga" || true
  wait "$bgb" || true
  sa=$(git -C "$wa" log --reverse --pretty=%s)
  sb=$(git -C "$wb" log --reverse --pretty=%s)
  contains '[codex_start_user]' "$sa"
  contains '[codex_resume_user]' "$sa"
  not_contains '[codex_abort]' "$sa"
  contains '[codex_start_user]' "$sb"
  contains '[codex_abort]' "$sb"
  not_contains 'a-followup' "$sb"
  ok 'parallel sibling worktrees are branch-local'
}

test_text_transcript_fixture() {
  setup_repo
  codex_commit from-text-transcript
  count=$(git log --pretty=%s | grep -c '^codex: update')
  [ "$count" -eq 3 ] || fail "expected three assistant pointer commits, got $count"
  b=$(git log --format=%B --grep='^codex: update' -1)
  sh=$(git log --format=%H --grep='^\[codex_start_user\]' -1)
  assert_assistant_pointer "$b" "$sh" 'Fixed. main and origin/main are synchronized at 1cea926.'
  archive=$(field_from_text transcript "$b")
  [ -n "$archive" ] || fail 'assistant pointer missing transcript field'
  grep -F 'I’ll inspect the repo state first' "$archive" >/dev/null || fail 'first text transcript output missing'
  grep -F 'Both tips have exactly the same tree' "$archive" >/dev/null || fail 'second text transcript output missing'
  grep -F 'Fixed. main and origin/main are synchronized at 1cea926.' "$archive" >/dev/null || fail 'final text transcript output missing'
  ok 'text transcript mock json'
}


test_basic
test_assistant_messages_use_pointer_commits_and_ignore_tools
test_tool_calls_use_bounded_summary_logs
test_autosave_is_rewritten
test_index_lock_does_not_block_markers
test_resume
test_called_by_env_commit
test_called_by_env_rejects_invalid_commit
test_new_message_interrupts_running_process
test_new_message_appends_user_followup_to_inbox_and_transcript
test_abort_from_other_shell_context
test_interactive_job_control_tracks_setsid_child
test_codex_commit_at_is_plain_prompt
test_codex_prompt_metacharacters_are_literal
test_codex_in_branch_at_commit_uses_worktree_wrapper
test_do_at_branch_uses_existing_branch_worktree
test_codex_checkpoint_empty_commit
test_codex_status_empty_commit
test_codex_spawn_detached_agent
test_codex_agents_lists_live_pid_tasks
test_transcript_inbox_artifacts_are_tracked_and_active_pointer_removed
test_codex_sync_push_skips_duplicate_upstream_patch
test_codex_sync_push_refuses_active_run
test_codex_dispatch_prompt_contract
test_parallel_sibling_worktrees_are_branch_local
test_text_transcript_fixture

echo "all tests passed"
