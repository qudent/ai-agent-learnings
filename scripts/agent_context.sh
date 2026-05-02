#!/usr/bin/env bash
# Source or execute: scripts/agent_context.sh <context|audit|prune-status>
# Builds compact, branch-local context packs from STATUS.md, transcript pointers,
# agent profiles/inboxes, and concise Git audit metadata.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  agent_context.sh context [--limit N]
  agent_context.sh audit [--limit N]
  agent_context.sh prune-status [STATUS.md]
EOF
}

_limit=80
if [ $# -lt 1 ]; then usage; exit 2; fi
cmd=$1; shift
while [ $# -gt 0 ]; do
  case "$1" in
    --limit) shift; _limit=${1:-80}; shift || true ;;
    *) break ;;
  esac
done

_root() { git rev-parse --show-toplevel; }

_pruned_status_to_stdout() {
  local file=${1:-STATUS.md}
  python3 - "$file" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text() if p.exists() else ""
out=[]
skipped=False
for line in text.splitlines():
    stripped=line.lstrip()
    if stripped.startswith('- [x]') or stripped.startswith('- [X]'):
        skipped=True
        continue
    out.append(line.rstrip())
# collapse excessive blank lines
compact=[]
blank=False
for line in out:
    if line.strip():
        compact.append(line); blank=False
    elif not blank:
        compact.append(line); blank=True
while compact and not compact[-1].strip(): compact.pop()
if skipped:
    compact.append("")
    compact.append("<!-- Completed work is intentionally omitted from STATUS.md; use Git history, transcripts/archive/, and agents/*/profile.md for the audit trail. -->")
print("\n".join(compact) + "\n")
PY
}

prune_status() {
  local file=${1:-STATUS.md} tmp
  tmp=$(mktemp)
  _pruned_status_to_stdout "$file" >"$tmp"
  mv "$tmp" "$file"
  printf 'pruned %s\n' "$file"
}

_field() {
  local file=$1 key=$2
  awk -F': ' -v k="$key" '$1==k {print substr($0, length(k)+3); exit}' "$file" 2>/dev/null || true
}

profile_for_active() {
  local active=$1 line rel
  line=$(grep -E '^- profile: ' "$active" 2>/dev/null | head -n1 || true)
  rel=${line#- profile: }
  rel=${rel#../../}
  [ -n "$rel" ] && [ -f "$rel" ] && printf '%s\n' "$rel"
}

transcript_for_active() {
  local active=$1 prof trans
  prof=$(profile_for_active "$active" || true)
  if [ -n "$prof" ]; then
    trans=$(_field "$prof" transcript)
    [ -n "$trans" ] && [ -f "$trans" ] && printf '%s\n' "$trans" && return 0
  fi
  trans=$(grep -E '^- transcript: ' "$active" 2>/dev/null | head -n1 || true)
  trans=${trans#- transcript: }
  trans=${trans#../archive/}
  [ -f "transcripts/archive/$trans" ] && printf 'transcripts/archive/%s\n' "$trans"
}

print_profile_summary() {
  local file=$1
  [ -f "$file" ] || return 0
  python3 - "$file" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
text = p.read_text(errors="replace")
front = []
lines = text.splitlines()
if lines and lines[0].strip() == "---":
    front.append("---")
    for line in lines[1:]:
        front.append(line.rstrip())
        if line.strip() == "---":
            break
else:
    front = lines[:12]
print("\n".join(front))
task = ""
for idx, line in enumerate(lines):
    if line.startswith("Task:"):
        task = line[len("Task:"):].strip()
        if idx + 1 < len(lines) and lines[idx + 1].strip() and not lines[idx + 1].startswith("## "):
            task += " ..."
        break
if task:
    task = re.sub(r"\s+", " ", task)
    if len(task) > 220:
        task = task[:217].rstrip() + "..."
    print("")
    print(f"Task summary: {task}")
PY
}

print_transcript_tail() {
  local file=$1 limit=${2:-80}
  [ -f "$file" ] || return 0
  printf '\n### Transcript tail: %s\n' "$file"
  python3 - "$file" "$limit" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); limit=int(sys.argv[2])
lines=p.read_text(errors='replace').splitlines()
# Keep frontmatter header plus the last N lines. This favors current work and avoids ancient prompt replay.
if len(lines) <= limit:
    keep=lines
else:
    keep=[f"... omitted {len(lines)-limit} older transcript lines ..."] + lines[-limit:]
print("\n".join(keep))
PY
}

audit() {
  local limit=${1:-$_limit}
  printf '# Agent Audit Trail\n\n'
  printf '## Profile edges\n'
  if [ -d agents ] && find agents -path '*/profile.md' -type f >/tmp/agent-profiles.$$ 2>/dev/null; then
    sort /tmp/agent-profiles.$$ | while read -r prof; do
      [ -n "$prof" ] || continue
      agent=$(_field "$prof" agent); parent=$(_field "$prof" parent); start=$(_field "$prof" run_start_commit); trans=$(_field "$prof" transcript)
      printf -- '- %s -> %s | agent=%s | profile=%s | transcript=%s\n' "${parent:-unknown}" "${start:-unknown}" "${agent:-unknown}" "$prof" "${trans:-unknown}"
    done | head -n "$limit"
    rm -f /tmp/agent-profiles.$$
  fi
  printf '\n## Recent run/update commits\n'
  git log --format='%h%x09%an%x09%s%n%b%x1e' --max-count="$limit" 2>/dev/null \
    | awk 'BEGIN{RS="\036"; FS="\n"} NF{while(NF && $1==""){for(j=1;j<NF;j++) $j=$(j+1); NF--} if(!NF) next; head=$1; split(head,p,"\t"); if (p[3] ~ /^\[codex_start_user\]/) p[3]="[codex_start_user] <prompt elided>"; if (p[3] ~ /^\[codex_resume_user\]/) p[3]="[codex_resume_user] <prompt elided>"; if (p[3] ~ /^\[codex\]/) p[3]="[codex] <assistant elided>"; called=""; transcript=""; tools=""; for(i=2;i<=NF;i++){if($i ~ /^called-by: /) called=$i; if($i ~ /^transcript: /) transcript=$i; if($i ~ /^tool-calls: /) tools=$i} if (length(p[1])) print "- " p[1] "\t" p[2] "\t" p[3] (called?" | " called:"") (transcript?" | " transcript:"") (tools?" | " tools:"")}'
}

live_agents() {
  printf '## Live local wrapper agents\n'
  if [ -x "$(_root)/scripts/codex_wrap.py" ]; then
    python3 "$(_root)/scripts/codex_wrap.py" agents 2>/dev/null || printf 'none\n'
  else
    printf 'none\n'
  fi
}

jj_surface() {
  printf '## JJ task surface\n'
  if ! command -v jj >/dev/null 2>&1; then
    printf 'jj unavailable; use STATUS.md and agents/*/inbox.md as the task surface.\n'
    return
  fi
  if [ ! -d .jj ]; then
    printf 'jj installed, but .jj is not configured in this repo. Optional helper: . scripts/jj_project.sh && jj_project_init\n'
    return
  fi
  jj log -r 'mutable()' --template 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"' 2>/dev/null | sed -n '1,20p' || {
    printf 'jj configured, but task log could not be read. Keep STATUS.md as source of truth.\n'
  }
}

context() {
  local limit=${1:-$_limit} branch head active_any=0 prof trans
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf unknown)
  head=$(git rev-parse --short HEAD 2>/dev/null || printf unknown)
  printf '# Agent Context Pack\n\n'
  printf -- '- branch: %s\n- head: %s\n- generated_at: %s\n\n' "$branch" "$head" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '## Current STATUS.md\n'
  if [ -f STATUS.md ]; then _pruned_status_to_stdout STATUS.md | sed -n '1,120p'; else printf 'none\n'; fi
  printf '\n## Active transcript pointers\n'
  if find transcripts/active -maxdepth 1 -type f >/tmp/active-transcripts.$$ 2>/dev/null; then
    while read -r active; do
      [ -n "$active" ] || continue
      active_any=1
      printf -- '- %s\n' "$active"
      prof=$(profile_for_active "$active" || true)
      [ -n "$prof" ] && printf '  profile: %s\n' "$prof"
      trans=$(transcript_for_active "$active" || true)
      [ -n "$trans" ] && printf '  transcript: %s\n' "$trans"
    done < <(sort /tmp/active-transcripts.$$)
    rm -f /tmp/active-transcripts.$$
  fi
  [ "$active_any" -eq 1 ] || printf 'none\n'
  printf '\n'
  live_agents
  printf '\n'
  jj_surface
  printf '\n## Relevant agent profiles and inboxes\n'
  if [ "$active_any" -eq 1 ]; then
    find transcripts/active -maxdepth 1 -type f 2>/dev/null | sort | while read -r active; do
      prof=$(profile_for_active "$active" || true)
      [ -n "$prof" ] || continue
      printf '\n### %s\n' "$prof"
      print_profile_summary "$prof"
      inbox=$(_field "$prof" inbox)
      if [ -n "$inbox" ] && [ -f "$inbox" ]; then
        printf '\n### %s\n' "$inbox"
        sed -n '1,80p' "$inbox"
      fi
    done
  else
    printf 'none (no active agent profiles; finished agents are summarized in the audit trail)\n'
  fi
  printf '\n## Current transcript excerpts\n'
  if [ "$active_any" -eq 1 ]; then
    find transcripts/active -maxdepth 1 -type f 2>/dev/null | sort | while read -r active; do
      trans=$(transcript_for_active "$active" || true)
      [ -n "$trans" ] && print_transcript_tail "$trans" "$limit"
    done
  else
    printf 'none (no active transcript pointers; archived transcripts stay in transcripts/archive/)\n'
  fi
  printf '\n## Audit trail\n'
  audit 30
}

case "$cmd" in
  context) context "$_limit" ;;
  audit) audit "$_limit" ;;
  prune-status) prune_status "${1:-STATUS.md}" ;;
  *) usage; exit 2 ;;
esac
