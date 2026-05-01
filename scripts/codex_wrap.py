#!/usr/bin/env python3
"""Git-backed Codex wrapper engine.

The sourced shell file exposes small interactive functions. This process owns
child supervision, process-group termination, JSONL parsing, and Git markers.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import shlex
import signal
import socket
import subprocess
import sys
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


def oneline(text: str) -> str:
    return " ".join(text.split())[:180]


def git(args: list[str], *, stdin: str | None = None, check: bool = True) -> str:
    proc = subprocess.run(
        ["git", *args],
        input=stdin,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and proc.returncode != 0:
        if proc.stderr:
            sys.stderr.write(proc.stderr)
        raise SystemExit(proc.returncode)
    return proc.stdout


def git_ok(args: list[str]) -> bool:
    return subprocess.run(["git", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


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


def common_dir() -> Path:
    out = git(["rev-parse", "--path-format=absolute", "--git-common-dir"], check=False).strip()
    if not out:
        out = git(["rev-parse", "--absolute-git-dir"]).strip()
    path = Path(out) / "codex-wrap"
    (path / "logs").mkdir(parents=True, exist_ok=True)
    return path


def update_ref(message: str, tree_src: str, mode: str, parent_src: str, expected: str) -> str | None:
    tree = git(["rev-parse", f"{tree_src}^{{tree}}"]).strip()
    parents: list[str]
    if mode == "normal":
        parents = [expected]
    else:
        rev = git(["rev-list", "--parents", "-n1", parent_src]).split()
        parents = rev[1:]
    args = ["commit-tree", tree]
    for parent in parents:
        args.extend(["-p", parent])
    new = git(args, stdin=message).strip()
    proc = subprocess.run(
        ["git", "update-ref", "-m", "codex-wrap", "HEAD", new, expected],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return new if proc.returncode == 0 else None


def marker(message: str) -> str:
    for _ in range(7):
        old = head()
        if not old:
            raise SystemExit(1)
        mode = "amend" if subject(old).startswith("[autosave]") else "normal"
        new = update_ref(message, old, mode, old, old)
        if new:
            return new
        time.sleep(0.05)
    raise SystemExit(1)


def agent_parts_from_commit(commit: str) -> tuple[str, str]:
    lines = commit_body(commit).strip("\n").splitlines()
    if lines and lines[0].startswith("[codex]"):
        lines = lines[1:]
    while lines and not lines[0].strip():
        lines = lines[1:]
    metadata: list[str] = []
    while lines and (
        lines[-1].startswith("session-id:")
        or lines[-1].startswith("run-start-commit-hash:")
        or not lines[-1].strip()
    ):
        metadata.append(lines.pop())
    return "\n".join(lines).strip(), "\n".join(reversed([line for line in metadata if line.strip()]))


def agent_marker(text: str, sid: str, run_start: str) -> str | None:
    for _ in range(7):
        old = head()
        if not old:
            return None
        subj = subject(old)
        message = f"[codex] {oneline(text)}\n\n{text}\n\nsession-id: {sid or 'unknown'}\nrun-start-commit-hash: {run_start}"
        mode = "normal"
        parent = old
        if subj.startswith("[codex]"):
            previous, metadata = agent_parts_from_commit(old)
            message = f"[codex] {oneline(text)}\n\n{text}"
            if previous:
                message += f"\n\n{previous}"
            if metadata:
                message += f"\n\n{metadata}"
            mode = "amend"
            parent = old
        elif subj.startswith("[autosave]"):
            mode = "amend"
            parent = old
            if git_ok(["rev-parse", "-q", "--verify", f"{old}^"]):
                prev = subject(f"{old}^")
                if prev.startswith("[codex]"):
                    previous, metadata = agent_parts_from_commit(f"{old}^")
                    message = f"[codex] {oneline(text)}\n\n{text}"
                    if previous:
                        message += f"\n\n{previous}"
                    if metadata:
                        message += f"\n\n{metadata}"
                    parent = f"{old}^"
        new = update_ref(message, old, mode, parent, old)
        if new:
            return new
        time.sleep(0.05)
    return None


def last_sid(ref: str = "HEAD") -> str:
    body = git(["log", "--format=%B", "-n", "500", ref], check=False)
    match = UUID_RE.search(body)
    return match.group(0) if match else ""


def banner(stderr_path: Path, sid: str) -> str:
    text = stderr_path.read_text(errors="replace") if stderr_path.exists() else ""
    lines = []
    for line in text.splitlines():
        if line == "user":
            break
        if line.strip():
            lines.append(line)
    if lines:
        return "\n".join(lines)
    return f"OpenAI Codex\n--------\nworkdir: {Path.cwd()}\nsession id: {sid or 'unknown'}\n--------"


def start_message(kind: str, prompt: str, sid: str, pid: int, pgid: int, stderr_path: Path | None = None) -> str:
    if kind == "start":
        msg = f"[codex_start_user] {oneline(prompt)}\n\n{banner(stderr_path or Path(), sid)}\nuser\n{prompt}\n\n"
    else:
        msg = f"[codex_resume_user] {oneline(prompt)}\n\nuser\n{prompt}\n\n"
    msg += f"session-id: {sid or 'unknown'}\ncalled-by: {called_by()}\npid: {pid}\npgid: {pgid}\nhost: {host()}\ncwd: {Path.cwd()}\nstarted-at: {now()}\n"
    return msg


def stop_message(label: str, sid: str, run_start: str, detail: str) -> str:
    return f"{label} {sid or 'unknown'}\n\nrun-start-commit-hash: {run_start}\nsession-id: {sid or 'unknown'}\n{detail}\nat: {now()}\n"


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
    if mode == "resume":
        run_start = marker(start_message("resume", prompt, sid, proc.pid, pgid))
        json_path, err_path = rename_logs(base, pending, run_start)

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
                    run_start = marker(start_message("start", prompt, sid, proc.pid, pgid, err_path))
                    json_file.close()
                    json_path, err_path = rename_logs(base, pending, run_start)
                    json_file = json_path.open("a", encoding="utf-8", errors="replace")
                    started = True
                continue
            if event.get("type") != "item.completed":
                continue
            item = event.get("item") or {}
            if item.get("type") != "agent_message":
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
            agent_marker(text, sid, run_start)

    rc = proc.wait()
    stderr_thread.join(timeout=1)
    if run_start and not run_closed(run_start):
        marker(stop_message("[codex_stop]", sid or last_sid(), run_start, f"exit-status: {rc}"))
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
    marker(stop_message("[codex_abort]", field(target, "session-id"), target, "reason: abort"))
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
        marker(stop_message("[codex_stop]", sid, run, "reason: restart with new user message"))
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
