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
print(json.dumps({"type":"item.completed","item":{"id":"tool-1","type":"command_execution","command":"git status","output":"ignored"}}))
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

# shellcheck source=/mnt/data/codex_wrap.sh
. "$WRAP"

ok() { printf 'ok - %s\n' "$*"; }
fail() { printf 'not ok - %s\n' "$*" >&2; exit 1; }
contains() { grep -Fq "$1" <<<"$2" || fail "missing: $1"; }
not_contains() { ! grep -Fq "$1" <<<"$2" || fail "unexpected: $1"; }

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
  contains '[codex_start_user] hi' "$s"
  contains '[codex] done: hi' "$s"
  contains '[codex_stop] 11111111-1111-1111-1111-111111111111' "$s"
  git log --format=%B --grep='^\[codex_start_user\]' -1 | grep -F 'OpenAI Codex v0.125.0 (fake)' >/dev/null || fail 'start banner missing'
  sh=$(git log --format=%H --grep='^\[codex_start_user\]' -1)
  ab=$(git log --format=%B --grep='^\[codex\]' -1)
  contains "run-start-commit-hash: $sh" "$ab"
  ok basic
}

test_fold_codex_messages_and_ignore_tools() {
  setup_repo
  codex_commit multi
  count=$(git log --pretty=%s | grep -c '^\[codex\]')
  [ "$count" -eq 1 ] || fail "expected one folded [codex] commit, got $count"
  b=$(git log --format=%B --grep='^\[codex\]' -1)
  contains 'second output' "$b"
  contains 'first output' "$b"
  not_contains 'previous [codex]' "$b"
  not_contains '[codex] first output' "$b"
  not_contains 'command_execution' "$b"
  ok 'fold codex messages'
}

test_autosave_is_rewritten() {
  setup_repo
  echo autosave >file.txt
  git add file.txt
  git commit -q -m '[autosave]'
  codex_commit hi
  s=$(subjects)
  not_contains '[autosave]' "$s"
  contains '[codex_start_user] hi' "$s"
  grep -F autosave file.txt >/dev/null || fail 'autosave tree not preserved'
  ok 'autosave rewritten'
}

test_index_lock_does_not_block_markers() {
  setup_repo
  codex_commit lock
  s=$(subjects)
  contains '[codex_start_user] lock' "$s"
  contains '[codex] lock survived' "$s"
  contains '[codex_stop] 11111111-1111-1111-1111-111111111111' "$s"
  ok 'index lock avoided'
}

test_resume() {
  setup_repo
  codex_commit hi
  codex_resume again
  s=$(subjects)
  contains '[codex_resume_user]' "$s"
  contains '[codex] resumed: again' "$s"
  ok resume
}

test_new_message_interrupts_running_process() {
  setup_repo
  codex_commit long >/tmp/cw-long.out 2>/tmp/cw-long.err & bg=$!
  wait_active_sid || fail 'no active sid for long run'
  codex_new_message interrupt
  wait "$bg" || true
  s=$(subjects)
  contains '[codex_start_user] long' "$s"
  contains '[codex_stop] 11111111-1111-1111-1111-111111111111' "$s"
  contains '[codex_resume_user]' "$s"
  contains '[codex] resumed: interrupt' "$s"
  ok 'new message interrupts'
}

test_abort_from_other_shell_context() {
  setup_repo
  codex_commit long >/tmp/cw-abort.out 2>/tmp/cw-abort.err & bg=$!
  wait_active_sid || fail 'no active sid for abort run'
  wait_subject '[codex_start_user] long' || fail 'no start marker before abort'
  codex_abort
  wait "$bg" || true
  s=$(subjects)
  contains '[codex_start_user] long' "$s"
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
  contains '[codex_start_user] delayed' "$s"
  contains '[codex] delayed done: delayed' "$s"
  contains '[codex_stop] 11111111-1111-1111-1111-111111111111' "$s"
  ok 'interactive job-control setsid child'
}

test_worktree_branch_at_commit() {
  setup_repo
  base=$(git rev-parse HEAD)
  echo next >>file.txt && git add file.txt && git commit -q -m next
  codex_commit @ "$base" branch-task
  branch=$(git rev-parse --abbrev-ref HEAD)
  [[ $branch == codex-* ]] || fail "not on codex branch: $branch"
  pwd | grep -F '.worktrees/codex-' >/dev/null || fail 'not inside codex worktree'
  git merge-base --is-ancestor "$base" HEAD || fail 'worktree branch not rooted at requested commit'
  s=$(subjects)
  contains '[codex_start_user] branch-task' "$s"
  ok 'worktree @ branch'
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
  while [ $SECONDS -lt $deadline ]; do git -C "$wa" log --pretty=%s | grep -F '[codex_start_user] long-a' >/dev/null 2>&1 && break; sleep 0.05; done
  git -C "$wa" log --pretty=%s | grep -F '[codex_start_user] long-a' >/dev/null 2>&1 || fail 'para-a did not start'
  deadline=$((SECONDS + 6))
  while [ $SECONDS -lt $deadline ]; do git -C "$wb" log --pretty=%s | grep -F '[codex_start_user] long-b' >/dev/null 2>&1 && break; sleep 0.05; done
  git -C "$wb" log --pretty=%s | grep -F '[codex_start_user] long-b' >/dev/null 2>&1 || fail 'para-b did not start'
  ( cd "$wa" && codex_new_message a-followup )
  ( cd "$wb" && codex_abort )
  wait "$bga" || true
  wait "$bgb" || true
  sa=$(git -C "$wa" log --reverse --pretty=%s)
  sb=$(git -C "$wb" log --reverse --pretty=%s)
  contains '[codex_start_user] long-a' "$sa"
  contains '[codex_resume_user] a-followup' "$sa"
  not_contains '[codex_abort]' "$sa"
  contains '[codex_start_user] long-b' "$sb"
  contains '[codex_abort]' "$sb"
  not_contains 'a-followup' "$sb"
  ok 'parallel sibling worktrees are branch-local'
}

test_text_transcript_fixture() {
  setup_repo
  codex_commit from-text-transcript
  b=$(git log --format=%B --grep='^\[codex\]' -1)
  contains 'Fixed. main and origin/main are synchronized at 1cea926.' "$b"
  contains 'Both tips have exactly the same tree' "$b"
  contains 'I’ll inspect the repo state first' "$b"
  not_contains 'previous [codex]' "$b"
  not_contains '[codex] Both tips have exactly the same tree' "$b"
  ok 'text transcript mock json'
}

test_basic
test_fold_codex_messages_and_ignore_tools
test_autosave_is_rewritten
test_index_lock_does_not_block_markers
test_resume
test_new_message_interrupts_running_process
test_abort_from_other_shell_context
test_interactive_job_control_tracks_setsid_child
test_worktree_branch_at_commit
test_parallel_sibling_worktrees_are_branch_local
test_text_transcript_fixture

echo "all tests passed"
