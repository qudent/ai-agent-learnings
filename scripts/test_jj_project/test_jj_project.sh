#!/usr/bin/env bash
set -euo pipefail

SCRIPT=${1:-scripts/jj_project.sh}
SCRIPT_ABS=$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")
ROOT=${TMPDIR:-/tmp}/jj-project-test.$$
trap 'rm -rf "$ROOT"' EXIT

fail() { echo "not ok - $*" >&2; exit 1; }
ok() { echo "ok - $*"; }
contains() { case "$2" in *"$1"*) return 0;; *) fail "expected to find: $1";; esac; }

setup_repo() {
  rm -rf "$ROOT/repo" "$ROOT/bin" "$ROOT/jj.log"
  mkdir -p "$ROOT/repo" "$ROOT/bin"
  cd "$ROOT/repo"
  git init -q
  git config user.email test@example.invalid
  git config user.name Tester
  printf '# Demo\n' >README.md
  mkdir -p agents/child transcripts/archive
  cat >STATUS.md <<'EOF'
# Demo - Status

## Active Goals
- [ ] Implement context pack generator
- [ ] Add jj planning mirror
- [x] Finished stale item

## TODO Plan
- [ ] Write failing tests
- [x] Old completed task
EOF
  cat >agents/child/inbox.md <<'EOF'
# Inbox: child

## pending

### 2026-05-02T00:00:00Z user

Please fix the context pack.

## consumed
EOF
  cat >transcripts/archive/2026-05-02-child.md <<'EOF'
# Transcript: child

## 2026-05-02T00:00:00Z user

Please fix the context pack.
EOF
  git add . && git commit -q -m base
  cat >"$ROOT/bin/jj" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$JJ_FAKE_LOG"
case "$1 $2" in
  'git init') mkdir -p .jj; exit 0;;
  'new -m') exit 0;;
  'describe -m') exit 0;;
  'log -r') echo 'abc xyz todo: fake'; exit 0;;
esac
exit 0
EOF
  chmod +x "$ROOT/bin/jj"
  export PATH="$ROOT/bin:$PATH" JJ_FAKE_LOG="$ROOT/jj.log"
}

test_plan_from_status_creates_one_jj_task_per_active_item() {
  setup_repo
  . "$SCRIPT_ABS"
  jj_project_init >/tmp/jj-init.out
  jj_task_plan_from_status STATUS.md
  log=$(cat "$JJ_FAKE_LOG")
  contains 'new -m todo: Implement context pack generator' "$log"
  contains 'new -m todo: Add jj planning mirror' "$log"
  contains 'new -m todo: Write failing tests' "$log"
  case "$log" in *'Finished stale item'*|*'Old completed task'*) fail 'finished STATUS items should not create jj tasks';; esac
  ok 'jj plan from status creates active tasks only'
}

test_task_from_inbox_links_source_file() {
  setup_repo
  . "$SCRIPT_ABS"
  jj_task_from_inbox agents/child/inbox.md
  log=$(cat "$JJ_FAKE_LOG")
  contains 'new -m todo: inbox agents/child/inbox.md' "$log"
  contains 'Source inbox: agents/child/inbox.md' "$log"
  contains 'Please fix the context pack.' "$log"
  ok 'jj task from inbox links source file'
}

test_task_done_from_transcript_records_source() {
  setup_repo
  . "$SCRIPT_ABS"
  jj_task_done_from_transcript 'context task finished' transcripts/archive/2026-05-02-child.md
  log=$(cat "$JJ_FAKE_LOG")
  contains 'describe -m done: context task finished' "$log"
  contains 'Transcript: transcripts/archive/2026-05-02-child.md' "$log"
  ok 'jj done from transcript records source'
}

test_plan_from_status_creates_one_jj_task_per_active_item
test_task_from_inbox_links_source_file
test_task_done_from_transcript_records_source
