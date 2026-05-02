#!/usr/bin/env bash
set -euo pipefail

SCRIPT=${1:-scripts/agent_context.sh}
SCRIPT_ABS=$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")
ROOT=${TMPDIR:-/tmp}/agent-context-test.$$
trap 'rm -rf "$ROOT"' EXIT

fail() { echo "not ok - $*" >&2; exit 1; }
ok() { echo "ok - $*"; }
contains() { case "$2" in *"$1"*) return 0;; *) fail "expected to find: $1";; esac; }
not_contains() { case "$2" in *"$1"*) fail "unexpected text: $1";; *) return 0;; esac; }

setup_repo() {
  rm -rf "$ROOT/repo"
  mkdir -p "$ROOT/repo"
  cd "$ROOT/repo"
  git init -q
  git config user.email test@example.invalid
  git config user.name Tester
  printf '# Demo\n' >README.md
  cat >STATUS.md <<'EOF'
# Demo - Status

## Current State
Active implementation branch.

## Active Goals
- [ ] Current task survives
- [x] Finished task must not stay here

## TODO Plan
- [ ] Next live action
- [x] Old action to prune

## Blockers
- None

## Recent Results
- Keep only fresh summaries.
EOF
  git add README.md STATUS.md && git commit -q -m 'base status'
  mkdir -p transcripts/archive agents/root-agent agents/child-agent transcripts/active
  cat >agents/root-agent/profile.md <<'EOF'
---
agent: root-agent
kind: codex
status: finished
branch: main
parent: user
session_id: root-session
run_start_commit: ROOTSTART
transcript: transcripts/archive/2026-05-02-root-agent.md
inbox: agents/root-agent/inbox.md
---
# root-agent
Task: Dispatch children.
EOF
  cat >agents/child-agent/profile.md <<'EOF'
---
agent: child-agent
kind: codex
status: active
branch: child
parent: ROOTSTART
session_id: child-session
run_start_commit: CHILDSTART
transcript: transcripts/archive/2026-05-02-child-agent.md
inbox: agents/child-agent/inbox.md
---
# child-agent
Task: Implement focused child work.
EOF
  cat >agents/child-agent/inbox.md <<'EOF'
# Inbox: child-agent

## pending

### 2026-05-02T00:01:00Z user

Please continue the child task.

## consumed
EOF
  cat >transcripts/archive/2026-05-02-root-agent.md <<'EOF'
---
agent: root-agent
run_start_commit: ROOTSTART
---
# Transcript: root-agent

## 2026-05-02T00:00:00Z user

Dispatch this broad task.

## 2026-05-02T00:00:30Z codex:root-agent

Spawned child-agent for focused implementation.
EOF
  cat >transcripts/archive/2026-05-02-child-agent.md <<'EOF'
---
agent: child-agent
run_start_commit: CHILDSTART
---
# Transcript: child-agent

## 2026-05-02T00:01:00Z user

Implement focused child work.

## 2026-05-02T00:02:00Z codex:child-agent

Found the current blocker and next step.
EOF
  printf '# Active child\n- transcript: ../archive/2026-05-02-child-agent.md\n' >transcripts/active/child-agent.md
  git add agents transcripts STATUS.md && git commit -q -m '[transcript] seed agents'
  git commit --allow-empty -q -m '[codex] Legacy assistant body that must be elided from audit context'
  git commit --allow-empty -q -m '[codex_start_user]' -m $'message-role: user\ncalled-by: user\nrun-start-commit-hash: ROOTSTART\npid: 111\ncwd: /tmp/root'
  git commit --allow-empty -q -m '[codex_start_user]' -m $'message-role: user\ncalled-by: ROOTSTART\nrun-start-commit-hash: CHILDSTART\npid: 222\ncwd: /tmp/child'
  git commit --allow-empty -q -m 'tool: update child-agent' -m $'agent: child-agent\nmessage-role: tool-summary\ntool: command_execution\ntool-calls: agents/child-agent/tool-calls.md\nrun-start-commit-hash: CHILDSTART'
  git commit --allow-empty -q -m 'codex: update child-agent' -m $'agent: child-agent\nmessage-role: assistant\ntranscript: transcripts/archive/2026-05-02-child-agent.md\nrun-start-commit-hash: CHILDSTART'
}

test_context_prefers_current_transcripts_and_audit() {
  setup_repo
  out=$(bash "$SCRIPT_ABS" context --limit 40)
  contains 'Agent Context Pack' "$out"
  contains 'Current STATUS.md' "$out"
  contains 'Active transcript pointers' "$out"
  contains 'agents/child-agent/profile.md' "$out"
  contains 'transcripts/archive/2026-05-02-child-agent.md' "$out"
  contains 'Audit trail' "$out"
  contains 'called-by: ROOTSTART' "$out"
  contains 'tool-calls: agents/child-agent/tool-calls.md' "$out"
  contains 'codex: update child-agent' "$out"
  contains '[codex] <assistant elided>' "$out"
  not_contains 'Legacy assistant body that must be elided' "$out"
  contains 'Found the current blocker and next step.' "$out"
  not_contains 'Dispatch this broad task.' "$out"
  ok 'context prefers current transcripts and audit trail'
}

test_status_prune_removes_finished_entries() {
  setup_repo
  bash "$SCRIPT_ABS" prune-status STATUS.md >/tmp/pruned-status.out
  pruned=$(cat STATUS.md)
  not_contains '[x]' "$pruned"
  not_contains 'Finished task must not stay here' "$pruned"
  not_contains 'Old action to prune' "$pruned"
  contains 'Current task survives' "$pruned"
  contains 'Next live action' "$pruned"
  contains 'Completed work is intentionally omitted' "$pruned"
  git diff -- STATUS.md | grep -F -- '- [x] Finished task must not stay here' >/dev/null || fail 'prune should leave deletion in git diff'
  ok 'status prune removes finished entries and leaves history as archive'
}

test_audit_trail_outputs_parent_child_edges() {
  setup_repo
  out=$(bash "$SCRIPT_ABS" audit --limit 20)
  contains 'ROOTSTART -> CHILDSTART' "$out"
  contains 'user -> ROOTSTART' "$out"
  contains 'child-agent' "$out"
  ok 'audit trail outputs parent child edges'
}

test_context_prefers_branch_status_over_old_finished_history() {
  setup_repo
  out=$(bash "$SCRIPT_ABS" context --limit 20)
  contains 'Current task survives' "$out"
  not_contains 'Finished task must not stay here' "$out"
  not_contains 'Old action to prune' "$out"
  ok 'context uses pruned active status not stale finished entries'
}

test_context_prefers_current_transcripts_and_audit
test_status_prune_removes_finished_entries
test_audit_trail_outputs_parent_child_edges
test_context_prefers_branch_status_over_old_finished_history
