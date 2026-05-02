#!/usr/bin/env python3
"""Git-backed Codex wrapper engine.

The sourced shell file exposes small interactive functions. This process owns
child supervision, process-group termination, JSONL parsing, and Git markers.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import shlex
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path


UUID_RE = re.compile(
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
)
HASH_RE = re.compile(r"^[0-9a-fA-F]{7,40}$")


def env(name: str, default: str) -> str:
    return os.environ.get(name, default)


def host() -> str:
    return socket.getfqdn() or socket.gethostname()


def now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def compact_utc() -> str:
    return time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())


def epoch() -> str:
    return str(int(time.time()))


def oneline(text: str) -> str:
    return " ".join(text.split())[:180]


def slugify_task(prompt: str, fallback: str) -> str:
    words = re.findall(r"[a-z0-9]+", prompt.lower())
    stop = {"the", "and", "for", "with", "this", "that", "please", "codex", "agent"}
    words = [word for word in words if word not in stop]
    slug = "-".join(words[:4]).strip("-")
    return slug or fallback


def git(
    args: list[str],
    *,
    stdin: str | None = None,
    check: bool = True,
    extra_env: dict[str, str] | None = None,
) -> str:
    proc = subprocess.run(
        ["git", *args],
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, **(extra_env or {})},
    )
    if check and proc.returncode != 0:
        if proc.stderr:
            sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)
    return proc.stdout


def git_ok(args: list[str]) -> bool:
    return subprocess.run(["git", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def git_index(index_path: Path, args: list[str], *, stdin: str | None = None, check: bool = True) -> str:
    proc = subprocess.run(
        ["git", *args],
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, "GIT_INDEX_FILE": str(index_path)},
    )
    if check and proc.returncode != 0:
        if proc.stderr:
            sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)
    return proc.stdout


def head() -> str:
    return git(["rev-parse", "-q", "--verify", "HEAD"], check=False).strip()


def commit_body(commit: str) -> str:
    raw = git(["cat-file", "commit", commit], check=False)
    return raw.split("\n\n", 1)[1] if "\n\n" in raw else ""


def subject(commit: str = "HEAD") -> str:
    body = commit_body(commit)
    return body.splitlines()[0] if body else ""


def field(commit: str, name: str) -> str:
    prefix = f"{name}:"
    for line in commit_body(commit).splitlines():
        if line.startswith(prefix):
            return line[len(prefix) :].strip()
    return ""


def called_by() -> str:
    value = env("CODEX_WRAP_CALLED_BY", "user").strip() or "user"
    if value == "user":
        return value
    proc = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", "--end-of-options", f"{value}^{{commit}}"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    commit = proc.stdout.strip()
    if proc.returncode == 0 and re.fullmatch(r"[0-9a-fA-F]{40}", commit):
        return commit
    sys.stderr.write(f"codex_wrap: invalid CODEX_WRAP_CALLED_BY value: {value}\n")
    raise SystemExit(2)


def author_for(role: str, slug: str = "") -> dict[str, str]:
    if role == "user":
        return {"GIT_AUTHOR_NAME": "user", "GIT_AUTHOR_EMAIL": "user@local.agent"}
    safe_slug = slug or "unknown"
    if role == "orchestrator":
        return {
            "GIT_AUTHOR_NAME": f"orchestrator:{safe_slug}",
            "GIT_AUTHOR_EMAIL": f"orchestrator+{safe_slug}@local.agent",
        }
    return {"GIT_AUTHOR_NAME": f"codex:{safe_slug}", "GIT_AUTHOR_EMAIL": f"codex+{safe_slug}@local.agent"}


def author_for_caller() -> dict[str, str]:
    caller = called_by()
    if caller == "user":
        return author_for("user")
    return author_for("orchestrator", short_hash(caller))


def common_dir() -> Path:
    out = git(["rev-parse", "--path-format=absolute", "--git-common-dir"], check=False).strip()
    if not out:
        out = git(["rev-parse", "--absolute-git-dir"]).strip()
    path = Path(out) / "codex-wrap"
    (path / "logs").mkdir(parents=True, exist_ok=True)
    return path


def overlay_tree(tree_src: str, set_files: dict[str, str] | None = None, remove_paths: list[str] | None = None) -> str:
    if not set_files and not remove_paths:
        return git(["rev-parse", f"{tree_src}^{{tree}}"]).strip()
    fd, index_name = tempfile.mkstemp(prefix="codex-wrap-index-")
    os.close(fd)
    index_path = Path(index_name)
    try:
        git_index(index_path, ["read-tree", f"{tree_src}^{{tree}}"])
        for path in remove_paths or []:
            git_index(index_path, ["update-index", "--force-remove", "--", path], check=False)
        for path, content in (set_files or {}).items():
            blob = git(["hash-object", "-w", "--stdin"], stdin=content).strip()
            git_index(index_path, ["update-index", "--add", "--cacheinfo", "100644", blob, path])
        return git_index(index_path, ["write-tree"]).strip()
    finally:
        index_path.unlink(missing_ok=True)


def sync_worktree_files(set_files: dict[str, str] | None = None, remove_paths: list[str] | None = None) -> None:
    for path, content in (set_files or {}).items():
        target = Path(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        git(["update-index", "--add", "--", path], check=False)
    for path in remove_paths or []:
        target = Path(path)
        target.unlink(missing_ok=True)
        git(["update-index", "--force-remove", "--", path], check=False)
        try:
            target.parent.rmdir()
        except OSError:
            pass


def update_ref(
    message: str,
    tree_src: str,
    mode: str,
    parent_src: str,
    expected: str,
    *,
    set_files: dict[str, str] | None = None,
    remove_paths: list[str] | None = None,
    author: dict[str, str] | None = None,
) -> str | None:
    tree = overlay_tree(tree_src, set_files=set_files, remove_paths=remove_paths)
    parents: list[str]
    if mode == "normal":
        parents = [expected]
    else:
        rev = git(["rev-list", "--parents", "-n1", parent_src]).split()
        parents = rev[1:]
    args = ["commit-tree", tree]
    for parent in parents:
        args.extend(["-p", parent])
    new = git(args, stdin=message, extra_env=author).strip()
    proc = subprocess.run(
        ["git", "update-ref", "-m", "codex-wrap", "HEAD", new, expected],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return new if proc.returncode == 0 else None


def marker(
    message: str,
    *,
    set_files: dict[str, str] | None = None,
    remove_paths: list[str] | None = None,
    author: dict[str, str] | None = None,
) -> str:
    for _ in range(7):
        old = head()
        if not old:
            raise SystemExit(1)
        mode = "amend" if subject(old).startswith("[autosave]") else "normal"
        new = update_ref(message, old, mode, old, old, set_files=set_files, remove_paths=remove_paths, author=author)
        if new:
            sync_worktree_files(set_files=set_files, remove_paths=remove_paths)
            return new
        time.sleep(0.05)
    raise SystemExit(1)


def short_hash(commit: str) -> str:
    return git(["rev-parse", "--short", commit], check=False).strip() or commit[:7]


def agent_slug(run_start: str, prompt: str) -> str:
    short = short_hash(run_start)
    return f"{slugify_task(prompt, short)}-{short}"


def transcript_paths(run_start: str, prompt: str) -> dict[str, str]:
    slug = agent_slug(run_start, prompt)
    day = time.strftime("%Y-%m-%d", time.gmtime())
    return {
        "slug": slug,
        "profile": f"agents/{slug}/profile.md",
        "inbox": f"agents/{slug}/inbox.md",
        "tools": f"agents/{slug}/tool-calls.md",
        "archive": f"transcripts/archive/{day}-{slug}.md",
        "active": f"transcripts/active/{slug}.md",
        "index": "transcripts/index.md",
    }


def show_path(ref: str, path: str) -> str:
    return git(["show", f"{ref}:{path}"], check=False)


def transcript_paths_for_run(run_start: str) -> dict[str, str]:
    matches = git(
        ["grep", "-l", f"run_start_commit: {run_start}", "HEAD", "--", "agents/*/profile.md"],
        check=False,
    )
    for match in matches.splitlines():
        path = match.split(":", 1)[-1].strip()
        parts = Path(path).parts
        if len(parts) >= 3 and parts[0] == "agents" and parts[2] == "profile.md":
            slug = parts[1]
            day = time.strftime("%Y-%m-%d", time.gmtime())
            archive_matches = git(
                ["ls-tree", "--name-only", "-r", "HEAD", "--", f"transcripts/archive/*-{slug}.md"],
                check=False,
            ).splitlines()
            archive = archive_matches[0] if archive_matches else f"transcripts/archive/{day}-{slug}.md"
            return {
                "slug": slug,
                "profile": f"agents/{slug}/profile.md",
                "inbox": f"agents/{slug}/inbox.md",
                "tools": f"agents/{slug}/tool-calls.md",
                "archive": archive,
                "active": f"transcripts/active/{slug}.md",
                "index": "transcripts/index.md",
            }
    return transcript_paths(run_start, "")


def markdown_block(role: str, text: str, *, at: str | None = None) -> str:
    stamp = at or now()
    return f"## {stamp} {role}\n\n{text.strip() or '(empty)'}\n"


def agent_profile_content(
    run_start: str,
    sid: str,
    status: str,
    prompt: str,
    json_path: Path,
    err_path: Path,
    paths: dict[str, str],
) -> str:
    slug = paths["slug"]
    return (
        "---\n"
        f"agent: {slug}\n"
        "kind: codex\n"
        f"status: {status}\n"
        f"branch: {git(['rev-parse', '--abbrev-ref', 'HEAD'], check=False).strip() or 'unknown'}\n"
        f"worktree: {Path.cwd()}\n"
        f"parent: {called_by()}\n"
        f"session_id: {sid or 'unknown'}\n"
        f"run_start_commit: {run_start}\n"
        f"created_at: {now()}\n"
        f"transcript: {paths['archive']}\n"
        f"inbox: {paths['inbox']}\n"
        f"tool_calls: {paths['tools']}\n"
        "---\n\n"
        f"# {slug}\n\n"
        f"Task: {prompt.strip() or '(empty)'}\n\n"
        "## Logs\n"
        f"- json: {json_path}\n"
        f"- stderr: {err_path}\n"
    )


def agent_inbox_content(slug: str) -> str:
    return f"# Inbox: {slug}\n\n## pending\n\n## consumed\n"


def tool_calls_content(slug: str) -> str:
    return (
        f"# Tool Calls: {slug}\n\n"
        "Bounded metadata only. Raw tool outputs stay in ignored wrapper JSON/stderr logs.\n\n"
        "| time_utc | epoch | caller | item | tool | status | args | args_sha256 | output_bytes |\n"
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |\n"
    )


def transcript_content(run_start: str, sid: str, status: str, prompt: str, paths: dict[str, str]) -> str:
    slug = paths["slug"]
    return (
        "---\n"
        f"agent: {slug}\n"
        "kind: codex\n"
        f"branch: {git(['rev-parse', '--abbrev-ref', 'HEAD'], check=False).strip() or 'unknown'}\n"
        f"status: {status}\n"
        f"session_id: {sid or 'unknown'}\n"
        f"run_start_commit: {run_start}\n"
        "---\n\n"
        f"# Transcript: {slug}\n\n"
        f"{markdown_block('user', prompt)}"
    )


def active_pointer_content(paths: dict[str, str], latest: str) -> str:
    slug = paths["slug"]
    return (
        f"# Active: {slug}\n\n"
        f"- profile: ../../{paths['profile']}\n"
        f"- transcript: ../archive/{Path(paths['archive']).name}\n"
        f"- inbox: ../../{paths['inbox']}\n"
        f"- latest: {latest}\n"
    )


def transcript_index_content(paths: dict[str, str], status: str, latest: str) -> str:
    return (
        "# Transcript Index\n\n"
        "Agent-specific state is stored in `agents/<slug>/profile.md`, "
        "`agents/<slug>/inbox.md`, `transcripts/active/<slug>.md`, and "
        "`transcripts/archive/<date>-<slug>.md`.\n\n"
        "List active agents with:\n\n"
        "```bash\n"
        "find transcripts/active agents -maxdepth 3 -type f 2>/dev/null | sort\n"
        "```\n"
    )


def transcript_agent_start(run_start: str, sid: str, prompt: str, json_path: Path, err_path: Path) -> None:
    paths = transcript_paths(run_start, prompt)
    latest = f"{now()} user"
    files = {
        paths["profile"]: agent_profile_content(run_start, sid, "active", prompt, json_path, err_path, paths),
        paths["inbox"]: agent_inbox_content(paths["slug"]),
        paths["tools"]: tool_calls_content(paths["slug"]),
        paths["archive"]: transcript_content(run_start, sid, "active", prompt, paths),
        paths["active"]: active_pointer_content(paths, latest),
        paths["index"]: transcript_index_content(paths, "active", latest),
    }
    message = (
        f"[transcript] start {paths['slug']}\n\n"
        f"agent: {paths['slug']}\n"
        f"profile: {paths['profile']}\n"
        f"inbox: {paths['inbox']}\n"
        f"transcript: {paths['archive']}\n"
        f"active: {paths['active']}\n"
        f"run-start-commit-hash: {run_start}\n"
        f"session-id: {sid or 'unknown'}\n"
        f"at: {now()}\n"
    )
    marker(message, set_files=files, author=author_for_caller())


def transcript_agent_output(run_start: str, sid: str, prompt: str, output: str) -> dict[str, str]:
    paths = transcript_paths_for_run(run_start)
    previous = show_path("HEAD", paths["archive"])
    entry = markdown_block(f"codex:{paths['slug']}", output)
    latest = f"{now()} codex:{paths['slug']}"
    return {
        paths["archive"]: previous.rstrip() + "\n\n" + entry,
        paths["active"]: active_pointer_content(paths, latest),
        paths["index"]: transcript_index_content(paths, "active", latest),
    }


def markdown_cell(text: str) -> str:
    return oneline(str(text)).replace("|", "\\|") or "-"


def compact_json(value) -> str:
    try:
        return json.dumps(value, sort_keys=True, ensure_ascii=True, separators=(",", ":"))
    except TypeError:
        return json.dumps(str(value), ensure_ascii=True)


def output_byte_count(item: dict) -> int:
    for key in ("output", "result"):
        if key not in item:
            continue
        value = item.get(key)
        if isinstance(value, str):
            return len(value.encode("utf-8"))
        return len(compact_json(value).encode("utf-8"))
    return 0


def tool_call_row(item: dict) -> str:
    tool = item.get("name") or item.get("tool_name") or item.get("type") or "unknown"
    status = item.get("status") or "completed"
    args = {}
    if item.get("command"):
        args = {"command": item.get("command")}
    else:
        for key in ("arguments", "args", "input"):
            if key in item:
                args = item.get(key)
                break
    args_text = compact_json(args)
    args_hash = hashlib.sha256(args_text.encode("utf-8")).hexdigest()[:16]
    if isinstance(args, dict) and args.get("command"):
        summary = args["command"]
    else:
        summary = args_text
    return (
        f"| {markdown_cell(compact_utc())} | {markdown_cell(epoch())} | {markdown_cell(called_by())} | "
        f"{markdown_cell(item.get('id') or '-')} | "
        f"{markdown_cell(tool)} | {markdown_cell(status)} | {markdown_cell(summary)} | "
        f"{args_hash} | {output_byte_count(item)} |\n"
    )


def append_tool_call(previous: str, item: dict) -> str:
    lines = previous.rstrip().splitlines()
    row = tool_call_row(item).rstrip()
    header_end = 0
    for idx, line in enumerate(lines):
        if line.startswith("| --- "):
            header_end = idx + 1
            break
    if not header_end:
        lines = tool_calls_content("unknown").rstrip().splitlines()
        header_end = len(lines)
    rows = [line for line in lines[header_end:] if line.startswith("| ")]
    try:
        cap = max(1, int(env("CODEX_WRAP_TOOL_LOG_LIMIT", "200")))
    except ValueError:
        cap = 200
    rows = (rows + [row])[-cap:]
    return "\n".join(lines[:header_end] + rows) + "\n"


def transcript_tool_call(run_start: str, item: dict) -> dict[str, str]:
    paths = transcript_paths_for_run(run_start)
    previous = show_path("HEAD", paths["tools"]) or tool_calls_content(paths["slug"])
    return {paths["tools"]: append_tool_call(previous, item)}


def should_log_tool_item(item: dict) -> bool:
    item_type = item.get("type") or ""
    return bool(item_type and item_type not in {"agent_message", "user_message"})


def tool_marker(sid: str, run_start: str, item: dict, *, set_files: dict[str, str]) -> str:
    paths = transcript_paths_for_run(run_start)
    tool = item.get("name") or item.get("tool_name") or item.get("type") or "unknown"
    message = (
        f"tool: update {paths['slug']}\n\n"
        f"agent: {paths['slug']}\n"
        "message-role: tool-summary\n"
        f"tool: {tool}\n"
        f"tool-calls: {paths['tools']}\n"
        f"run-start-commit-hash: {run_start}\n"
        f"session-id: {sid or 'unknown'}\n"
        f"at: {now()}\n"
    )
    return marker(message, set_files=set_files, author=author_for("codex", paths["slug"]))


def append_pending_user_entry(inbox: str, entry: str) -> str:
    if "\n## consumed" in inbox:
        return inbox.replace("\n## consumed", f"\n{entry}\n## consumed", 1)
    return inbox.rstrip() + "\n\n" + entry


def transcript_user_followup(run_start: str, prompt: str) -> str:
    paths = transcript_paths_for_run(run_start)
    stamp = now()
    inbox_previous = show_path("HEAD", paths["inbox"]) or agent_inbox_content(paths["slug"])
    archive_previous = show_path("HEAD", paths["archive"])
    inbox_entry = f"### {stamp} user\n\n{prompt.strip() or '(empty)'}\n"
    archive_entry = markdown_block("user", prompt, at=stamp)
    files = {
        paths["inbox"]: append_pending_user_entry(inbox_previous, inbox_entry).rstrip() + "\n",
        paths["archive"]: archive_previous.rstrip() + "\n\n" + archive_entry,
        paths["index"]: transcript_index_content(paths, "active", f"{stamp} user"),
    }
    message = (
        f"user: message to {paths['slug']}\n\n"
        f"agent: {paths['slug']}\n"
        "message-role: user\n"
        f"inbox: {paths['inbox']}\n"
        f"transcript: {paths['archive']}\n"
        f"run-start-commit-hash: {run_start}\n"
        f"at: {stamp}\n"
    )
    return marker(message, set_files=files, author=author_for("user"))


def agent_marker(text: str, sid: str, run_start: str, *, set_files: dict[str, str] | None = None) -> str | None:
    paths = transcript_paths_for_run(run_start)
    message = (
        f"codex: update {paths['slug']}\n\n"
        f"agent: {paths['slug']}\n"
        "message-role: assistant\n"
        f"transcript: {paths['archive']}\n"
        f"run-start-commit-hash: {run_start}\n"
        f"session-id: {sid or 'unknown'}\n"
        f"at: {now()}\n"
    )
    return marker(message, set_files=set_files, author=author_for("codex", paths["slug"]))


def last_sid(ref: str = "HEAD") -> str:
    body = git(["log", "--format=%B", "-n", "500", ref], check=False)
    match = UUID_RE.search(body)
    return match.group(0) if match else ""


def start_message(kind: str, prompt: str, sid: str, pid: int, pgid: int, stderr_path: Path | None = None) -> str:
    label = "[codex_start_user]" if kind == "start" else "[codex_resume_user]"
    return (
        f"{label}\n\n"
        "message-role: user\n"
        f"session-id: {sid or 'unknown'}\n"
        f"called-by: {called_by()}\n"
        f"pid: {pid}\n"
        f"pgid: {pgid}\n"
        f"host: {host()}\n"
        f"cwd: {Path.cwd()}\n"
        f"started-at: {now()}\n"
    )


def stop_message(label: str, sid: str, run_start: str, detail: str) -> str:
    return f"{label} {sid or 'unknown'}\n\nrun-start-commit-hash: {run_start}\nsession-id: {sid or 'unknown'}\n{detail}\nat: {now()}\n"


def stop_marker(label: str, sid: str, run_start: str, detail: str) -> str:
    remove_paths = []
    author = None
    if run_start:
        paths = transcript_paths_for_run(run_start)
        remove_paths.append(paths["active"])
        author = author_for("codex", paths["slug"])
    return marker(stop_message(label, sid, run_start, detail), remove_paths=remove_paths, author=author)


def run_closed(run_start: str) -> bool:
    raw = git(["log", "--format=%B%x1e", f"{run_start}..HEAD"], check=False)
    for record in raw.split("\x1e"):
        if (record.startswith("[codex_stop]") or record.startswith("[codex_abort]")) and f"run-start-commit-hash: {run_start}" in record:
            return True
    return False


def proc_alive(pid: str | int) -> bool:
    if not pid:
        return False
    try:
        pid_int = int(pid)
        os.kill(pid_int, 0)
    except (OSError, ValueError):
        return False
    try:
        stat = subprocess.run(["ps", "-o", "stat=", "-p", str(pid_int)], text=True, stdout=subprocess.PIPE)
        return stat.returncode == 0 and "Z" not in stat.stdout
    except OSError:
        return True


def latest_active_run() -> str:
    scan = env("CODEX_WRAP_ACTIVE_SCAN", "120")
    raw = git(
        [
            "log",
            "--extended-regexp",
            "--format=%H%x1f%s",
            "--grep=^\\[codex_(start_user|resume_user)\\]",
            "-n",
            scan,
        ],
        check=False,
    )
    for line in raw.splitlines():
        if "\x1f" not in line:
            continue
        commit, _ = line.split("\x1f", 1)
        if run_closed(commit):
            continue
        run_host = field(commit, "host")
        if run_host and run_host != host():
            continue
        if proc_alive(field(commit, "pid")):
            return commit
    return ""


def active_agents() -> list[dict[str, str]]:
    scan = env("CODEX_WRAP_ACTIVE_SCAN", "120")
    raw = git(
        [
            "log",
            "--extended-regexp",
            "--format=%H%x1f%s",
            "--grep=^\\[codex_(start_user|resume_user)\\]",
            "-n",
            scan,
        ],
        check=False,
    )
    agents = []
    for line in raw.splitlines():
        if "\x1f" not in line:
            continue
        commit, subject = line.split("\x1f", 1)
        if run_closed(commit):
            continue
        run_host = field(commit, "host")
        if run_host and run_host != host():
            continue
        pid = field(commit, "pid")
        if not proc_alive(pid):
            continue
        task = re.sub(r"^\[codex_(?:start|resume)_user\]\s*", "", subject).strip()
        agents.append(
            {
                "commit": commit,
                "short": git(["rev-parse", "--short", commit], check=False).strip() or commit[:7],
                "pid": pid,
                "pgid": field(commit, "pgid") or pid,
                "cwd": field(commit, "cwd"),
                "session": field(commit, "session-id"),
                "task": task,
            }
        )
    return agents


def print_active_agents() -> int:
    agents = active_agents()
    if not agents:
        print("none")
        return 0
    for agent in agents:
        print(
            f"{agent['short']} pid={agent['pid']} pgid={agent['pgid']} "
            f"cwd={agent['cwd']} task={agent['task']}"
        )
    return 0


def rename_logs(base: Path, pending: str, final: str) -> tuple[Path, Path]:
    json_path = base / "logs" / f"{pending}.jsonl"
    err_path = base / "logs" / f"{pending}.stderr"
    final_json = base / "logs" / f"{final}.jsonl"
    final_err = base / "logs" / f"{final}.stderr"
    if json_path.exists():
        json_path.rename(final_json)
    if err_path.exists():
        err_path.rename(final_err)
    return final_json, final_err


def kill_process(pid: str | int, pgid: str | int = "") -> None:
    try:
        if pgid:
            os.killpg(int(pgid), signal.SIGTERM)
        else:
            os.kill(int(pid), signal.SIGTERM)
    except (OSError, ValueError):
        try:
            os.kill(int(pid), signal.SIGTERM)
        except (OSError, ValueError):
            pass
    try:
        time.sleep(float(env("CODEX_WRAP_KILL_GRACE", "0.2")))
    except ValueError:
        time.sleep(0.2)


def tee_stderr(src, err_path: Path) -> None:
    with err_path.open("a", encoding="utf-8", errors="replace") as err_file:
        for chunk in iter(src.readline, ""):
            err_file.write(chunk)
            err_file.flush()
            sys.stderr.write(chunk)
            sys.stderr.flush()


def base_cmd() -> list[str]:
    return ["codex", "exec", "--json", *shlex.split(env("CODEX_WRAP_CODEX_FLAGS", "--dangerously-bypass-approvals-and-sandbox"))]


def run_agent(mode: str, args: list[str], sid: str = "") -> int:
    base = common_dir()
    pending = f"pending-{time.strftime('%Y%m%d-%H%M%S')}-{os.getpid()}-{random.randint(0, 32767)}"
    json_path = base / "logs" / f"{pending}.jsonl"
    err_path = base / "logs" / f"{pending}.stderr"
    prompt = " ".join(args)
    cmd = base_cmd()
    if mode == "resume":
        cmd.extend(["resume", sid])
    cmd.extend(args)

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    pgid = proc.pid
    stderr_thread = threading.Thread(target=tee_stderr, args=(proc.stderr, err_path), daemon=True)
    stderr_thread.start()

    run_start = ""
    started = False
    seen: set[str] = set()
    seen_tools: set[str] = set()
    if mode == "resume":
        run_start = marker(start_message("resume", prompt, sid, proc.pid, pgid), author=author_for_caller())
        json_path, err_path = rename_logs(base, pending, run_start)
        transcript_agent_start(run_start, sid, prompt, json_path, err_path)

    with json_path.open("a", encoding="utf-8", errors="replace") as json_file:
        assert proc.stdout is not None
        for line in proc.stdout:
            json_file.write(line)
            json_file.flush()
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") == "thread.started":
                sid = event.get("thread_id") or event.get("session_id") or sid
                if mode == "start" and not started:
                    run_start = marker(start_message("start", prompt, sid, proc.pid, pgid, err_path), author=author_for_caller())
                    json_file.close()
                    json_path, err_path = rename_logs(base, pending, run_start)
                    transcript_agent_start(run_start, sid, prompt, json_path, err_path)
                    json_file = json_path.open("a", encoding="utf-8", errors="replace")
                    started = True
                continue
            if event.get("type") != "item.completed":
                continue
            item = event.get("item") or {}
            if item.get("type") != "agent_message":
                if not should_log_tool_item(item):
                    continue
                item_id = item.get("id") or ""
                if not run_start or run_closed(run_start) or (item_id and item_id in seen_tools):
                    continue
                if item_id:
                    seen_tools.add(item_id)
                tool_marker(sid, run_start, item, set_files=transcript_tool_call(run_start, item))
                continue
            text = item.get("text") or item.get("message") or item.get("content") or ""
            if not text or not run_start or run_closed(run_start):
                continue
            item_id = item.get("id") or ""
            if item_id in seen:
                continue
            seen.add(item_id)
            sys.stderr.write(f"\ncodex\n{text}\n")
            sys.stderr.flush()
            transcript_files = transcript_agent_output(run_start, sid, prompt, text)
            agent_marker(text, sid, run_start, set_files=transcript_files)

    rc = proc.wait()
    stderr_thread.join(timeout=1)
    if run_start and not run_closed(run_start):
        stop_marker("[codex_stop]", sid or last_sid(), run_start, f"exit-status: {rc}")
    return rc


def abort_run(run: str = "") -> int:
    target = run if HASH_RE.match(run or "") else latest_active_run()
    if not target:
        sys.stderr.write("codex_wrap: no active Codex run found in current branch history\n")
        return 1
    run_host = field(target, "host")
    if run_host and run_host != host():
        sys.stderr.write(f"codex_wrap: active run is on host {run_host}\n")
        return 1
    pid = field(target, "pid")
    pgid = field(target, "pgid") or pid
    if not proc_alive(pid):
        sys.stderr.write(f"codex_wrap: process {pid} is not alive\n")
        return 1
    stop_marker("[codex_abort]", field(target, "session-id"), target, "reason: abort")
    kill_process(pid, pgid)
    return 0


def new_message(args: list[str]) -> int:
    run = latest_active_run()
    if run:
        run_host = field(run, "host")
        if run_host and run_host != host():
            sys.stderr.write(f"codex_wrap: active run is on host {run_host}\n")
            return 1
        sid = field(run, "session-id")
        pid = field(run, "pid")
        pgid = field(run, "pgid") or pid
        transcript_user_followup(run, " ".join(args))
        stop_marker("[codex_stop]", sid, run, "reason: restart with new user message")
        kill_process(pid, pgid)
        return run_agent("resume", args, sid)
    sid = last_sid()
    if not sid:
        sys.stderr.write("codex_wrap: no session id found in current branch history\n")
        return 1
    return run_agent("resume", args, sid)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    run_p = sub.add_parser("run")
    run_p.add_argument("mode", choices=["start", "resume"])
    run_p.add_argument("rest", nargs=argparse.REMAINDER)
    sub.add_parser("active")
    sub.add_parser("agents")
    last_p = sub.add_parser("last-sid")
    last_p.add_argument("ref", nargs="?", default="HEAD")
    abort_p = sub.add_parser("abort")
    abort_p.add_argument("run", nargs="?", default="")
    msg_p = sub.add_parser("new-message")
    msg_p.add_argument("rest", nargs=argparse.REMAINDER)
    ns = parser.parse_args(argv)

    if ns.cmd == "run":
        if ns.mode == "resume":
            if not ns.rest:
                sys.stderr.write("codex_wrap: resume requires a session id\n")
                return 2
            return run_agent("resume", ns.rest[1:], ns.rest[0])
        return run_agent("start", ns.rest)
    if ns.cmd == "active":
        active = latest_active_run()
        if active:
            print(active)
            return 0
        return 1
    if ns.cmd == "agents":
        return print_active_agents()
    if ns.cmd == "last-sid":
        sid = last_sid(ns.ref)
        if sid:
            print(sid)
            return 0
        return 1
    if ns.cmd == "abort":
        return abort_run(ns.run)
    if ns.cmd == "new-message":
        return new_message(ns.rest)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
