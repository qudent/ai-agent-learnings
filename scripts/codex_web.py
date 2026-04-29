#!/usr/bin/env python3
"""Small loopback codex-web-interface for codex_wrap.sh.

Run:
  python3 codex_web.py --repo ~/repos/repo --wrapper ~/learnings/scripts/codex_wrap.sh --port 6174

No auth; binds to 127.0.0.1 by default. Do NOT run on 0.0.0.0. Use SSH port forwarding for remote use.
"""
from __future__ import annotations
import argparse, base64, binascii, json, os, re, socket, subprocess, sys, threading, time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path.cwd()
WRAPPER = Path(__file__).with_name('codex_wrap.sh')
RUN_LOCK = threading.RLock()
RUNNERS = {}

def sh(cmd, cwd, check=True):
    return subprocess.run(cmd, cwd=str(cwd), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check)

def git(repo, *args, check=True):
    return sh(['git', *args], repo, check=check).stdout

def repo_root(repo):
    return Path(git(repo, 'rev-parse', '--show-toplevel').strip()).resolve()

def common_dir(repo):
    return Path(git(repo, 'rev-parse', '--path-format=absolute', '--git-common-dir').strip()).resolve()

def current_branch(repo):
    branch = git(repo, 'rev-parse', '--abbrev-ref', 'HEAD', check=False).strip()
    return '' if branch == 'HEAD' else branch

def branch_config(repo, branch, key):
    if not branch or branch == '(detached)':
        return ''
    return git(repo, 'config', '--get', f'branch.{branch}.{key}', check=False).strip()

def add_worktree_metadata(repo, cur):
    cur['parent_branch'] = branch_config(repo, cur.get('branch', ''), 'parent-branch')
    cur['parent_commit'] = branch_config(repo, cur.get('branch', ''), 'parent-commit')
    return cur

def worktrees(repo):
    out = git(repo, 'worktree', 'list', '--porcelain', check=False)
    ans, cur = [], {}
    for line in out.splitlines():
        if not line:
            if cur:
                ans.append(add_worktree_metadata(repo, cur))
                cur = {}
        elif line.startswith('worktree '): cur['path'] = line[9:]
        elif line.startswith('HEAD '): cur['head'] = line[5:]
        elif line.startswith('branch '):
            b = line[7:]
            cur['branch'] = b.removeprefix('refs/heads/')
        elif line.startswith('detached'): cur['branch'] = '(detached)'
    if cur:
        ans.append(add_worktree_metadata(repo, cur))
    return attach_runs(repo, ans)

def create_worktree(repo, commit):
    root = repo_root(repo)
    parent = current_branch(repo)
    base = git(repo, 'rev-parse', commit).strip()
    short = git(repo, 'rev-parse', '--short', base).strip()
    for i in range(100):
        suf = f'-{i}' if i else ''
        stamp = f'{time.strftime("%Y%m%d-%H%M%S")}-{time.time_ns() % 1_000_000_000:09d}'
        branch = f'codex-web-interface-{short}-{stamp}{suf}'
        wt = Path(f'{root}.worktrees') / branch
        if not wt.exists():
            try:
                sh(['git', 'worktree', 'add', '-b', branch, str(wt), base], repo)
            except subprocess.CalledProcessError:
                time.sleep(.05)
                continue
            if parent:
                git(repo, 'config', f'branch.{branch}.parent-branch', parent)
            git(repo, 'config', f'branch.{branch}.parent-commit', base)
            return {'branch': branch, 'path': str(wt.resolve()), 'parent_branch': parent, 'parent_commit': base}
        time.sleep(.05)
    raise RuntimeError('could not allocate worktree name')

def spawn_process(repo, func, args, meta=None):
    logdir = common_dir(repo) / 'codex-wrap' / 'web'
    logdir.mkdir(parents=True, exist_ok=True)
    stamp = f'{time.strftime("%Y%m%d-%H%M%S")}-{time.time_ns() % 1_000_000_000:09d}'
    log = logdir / f'{stamp}-{os.getpid()}-{func}.log'
    env = os.environ.copy(); env['CODEX_WRAP_STDIN_NEW_MESSAGE'] = '0'
    script = 'source "$1"; shift; fn="$1"; shift; "$fn" "$@"'
    fh = open(log, 'ab')
    p = subprocess.Popen(['bash', '-lc', script, 'bash', str(WRAPPER), func, *args], cwd=str(repo), stdin=subprocess.DEVNULL, stdout=fh, stderr=subprocess.STDOUT, env=env, start_new_session=True)
    fh.close()
    info = {'pid': p.pid, 'log': str(log), 'func': func, 'started_at': int(time.time())}
    if meta:
        info.update({k: v for k, v in meta.items() if k in ('mode', 'prompt')})
    return p, info

def public_process(info):
    return {k: v for k, v in (info or {}).items() if k != 'process'}

def runner_key(repo):
    return str(Path(repo).resolve())

def runner_state(key):
    state = RUNNERS.get(key)
    if not state:
        state = {'active': None, 'queue': deque(), 'external_waiter': False}
        RUNNERS[key] = state
    return state

def process_alive(proc):
    return proc is not None and proc.poll() is None

def start_queued_locked(key, item, watch=True):
    proc, info = spawn_process(Path(item['repo']), item['func'], item['args'], item)
    runner_state(key)['active'] = {**info, 'process': proc}
    if watch:
        threading.Thread(target=wait_and_drain, args=(key, proc), daemon=True).start()
    return info

def wait_and_drain(key, proc):
    proc.wait()
    while True:
        with RUN_LOCK:
            state = runner_state(key)
            active = state.get('active')
            if active and active.get('process') is proc:
                state['active'] = None
            if not state['queue']:
                return
            item = state['queue'].popleft()
            start_queued_locked(key, item, watch=False)
            proc = runner_state(key)['active']['process']
        proc.wait()

def wait_external_and_drain(key, repo):
    while active_run(repo):
        time.sleep(0.5)
    with RUN_LOCK:
        state = runner_state(key)
        state['external_waiter'] = False
        if not state['queue']:
            return
        item = state['queue'].popleft()
        start_queued_locked(key, item)

def submit_or_queue(repo, func, args, mode, prompt):
    key = runner_key(repo)
    item = {'repo': key, 'func': func, 'args': args, 'mode': mode, 'prompt': prompt}
    with RUN_LOCK:
        state = runner_state(key)
        active = state.get('active')
        if active and process_alive(active.get('process')):
            state['queue'].append(item)
            return {'queued': True, 'queue_depth': len(state['queue']), 'process': None}
        state['active'] = None
    external_active = active_run(repo)
    with RUN_LOCK:
        state = runner_state(key)
        active = state.get('active')
        if active and process_alive(active.get('process')):
            state['queue'].append(item)
            return {'queued': True, 'queue_depth': len(state['queue']), 'process': None}
        if external_active:
            state['queue'].append(item)
            if not state['external_waiter']:
                state['external_waiter'] = True
                threading.Thread(target=wait_external_and_drain, args=(key, Path(repo)), daemon=True).start()
            return {'queued': True, 'queue_depth': len(state['queue']), 'process': None}
        info = start_queued_locked(key, item)
        return {'queued': False, 'queue_depth': len(state['queue']), 'process': public_process(info)}

def clear_queue(repo):
    key = runner_key(repo)
    with RUN_LOCK:
        runner_state(key)['queue'].clear()

def run_status(repo):
    key = runner_key(repo)
    web_active = None
    with RUN_LOCK:
        state = runner_state(key)
        active = state.get('active')
        if active and process_alive(active.get('process')):
            web_active = public_process(active)
        elif active:
            state['active'] = None
        queued = [public_process(item) for item in state['queue']]
    git_active = active_run(repo)
    active = git_active or web_active or {}
    if active and web_active:
        active = {**active, **web_active}
    return {'active': active, 'queue': queued, 'queue_depth': len(queued)}

def records(repo, limit=150):
    fmt = '%H%x1f%P%x1f%ct%x1f%s%x1f%B%x1e'
    out = git(repo, 'log', f'--max-count={limit}', f'--format={fmt}', check=False)
    rows = []
    for rec in out.split('\x1e'):
        if not rec.strip(): continue
        parts = rec.split('\x1f', 4)
        if len(parts) != 5: continue
        h, parents, ts, subj, raw = parts
        h, parents, ts, subj = h.strip(), parents.strip(), ts.strip(), subj.strip()
        body = raw.split('\n\n', 1)[1] if '\n\n' in raw else ''
        role, kind, text = 'system', 'commit', subj
        if subj.startswith('[codex_start_user]') or subj.startswith('[codex_resume_user]'):
            role, kind = 'user', 'user'
            m = re.search(r'\nuser\n(.*?)(?:\n\nsession-id:|\Z)', raw, re.S)
            text = m.group(1).strip() if m else subj.split(']',1)[-1].strip()
        elif subj.startswith('[codex]'):
            role, kind = 'assistant', 'assistant'
            m = re.search(r'\n\n(.*?)(?:\n\nsession-id:|\n\nprevious \[codex\]|\Z)', raw, re.S)
            text = m.group(1).strip() if m else subj.split(']',1)[-1].strip()
        elif subj.startswith('[codex_stop]'): kind, text = 'stop', body.strip() or subj
        elif subj.startswith('[codex_abort]'): kind, text = 'abort', body.strip() or subj
        fields = dict(re.findall(r'^([A-Za-z0-9_-]+):\s*(.*)$', raw, re.M))
        rows.append({'hash':h,'short':h[:7],'parents':parents.split(),'parent':parents.split()[0] if parents else '', 'timestamp':int(ts or 0),'subject':subj,'raw':raw,'body':body,'role':role,'kind':kind,'text':text,'fields':fields})
    rows.reverse(); return rows

def pid_alive(pid):
    if not pid:
        return False
    try:
        os.kill(int(pid), 0)
    except (OSError, ValueError):
        return False
    stat = subprocess.run(['ps', '-o', 'stat=', '-p', str(pid)], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return stat.returncode == 0 and 'Z' not in stat.stdout

def run_closed_rows(rows, start_hash):
    for row in rows:
        if row['kind'] in ('stop', 'abort') and row['fields'].get('run-start-commit-hash') == start_hash:
            return True
    return False

def active_run(repo, rows=None):
    rows = rows or records(repo, 200)
    local_host = socket.getfqdn() or socket.gethostname()
    for row in reversed(rows):
        if row['kind'] != 'user' or not row['fields'].get('pid'):
            continue
        if run_closed_rows(rows, row['hash']):
            continue
        run_host = row['fields'].get('host', '')
        if run_host and run_host != local_host:
            continue
        if pid_alive(row['fields'].get('pid', '')):
            return row
    return {}

def infer_branch_from_cwd(cwd, path_branches):
    if not cwd:
        return '(unknown)'
    try:
        resolved = str(Path(cwd).expanduser().resolve())
    except Exception:
        resolved = str(cwd)
    if resolved in path_branches:
        return path_branches[resolved]
    path = Path(resolved)
    if '.worktrees' in path.parts:
        return path.name
    return path.name or '(archived)'

def run_archive(repo, limit=300):
    rows = records(repo, limit)
    active_hash = active_run(repo, rows).get('hash', '')
    runs = {}
    order = []
    for row in rows:
        if row['kind'] != 'user' or not row['fields'].get('pid'):
            continue
        h = row['hash']
        runs[h] = {
            'hash': h,
            'short': row['short'],
            'subject': row['subject'],
            'raw': row['raw'],
            'prompt': row['text'],
            'timestamp': row['timestamp'],
            'session_id': row['fields'].get('session-id', ''),
            'cwd': row['fields'].get('cwd', ''),
            'started_at': row['fields'].get('started-at', ''),
            'pid': row['fields'].get('pid', ''),
            'status': 'active' if h == active_hash else 'open',
            'stop_hash': '',
            'message_count': 0,
            'has_transcript': False,
        }
        order.append(h)
    for row in rows:
        start = row['fields'].get('run-start-commit-hash', '')
        if start not in runs:
            continue
        if row['kind'] == 'assistant':
            runs[start]['message_count'] += 1
        elif row['kind'] in ('stop', 'abort'):
            runs[start]['status'] = 'aborted' if row['kind'] == 'abort' else 'finished'
            runs[start]['stop_hash'] = row['hash']
    logs = codex_dir(repo) / 'logs'
    for h, run in runs.items():
        run['has_transcript'] = (logs / f'{h}.stderr').exists() or (logs / f'{h}.jsonl').exists()
    return [runs[h] for h in reversed(order)]

def attach_runs(repo, wts):
    path_branches = {}
    for wt in wts:
        try:
            path_branches[str(Path(wt.get('path', '')).resolve())] = wt.get('branch') or '(detached)'
        except Exception:
            pass
        wt['runs'] = []
        try:
            status = run_status(Path(wt.get('path', repo)))
            wt['queue'] = status.get('queue', [])
            if status.get('active'):
                wt['active'] = status.get('active')
        except Exception:
            wt['queue'] = []
    by_path = {str(Path(wt.get('path', '')).resolve()): wt for wt in wts if wt.get('path')}
    archived = []
    for run in run_archive(repo):
        cwd = run.get('cwd', '')
        try:
            key = str(Path(cwd).expanduser().resolve()) if cwd else ''
        except Exception:
            key = cwd
        run['branch'] = infer_branch_from_cwd(cwd, path_branches)
        if key in by_path:
            by_path[key]['runs'].append(run)
        else:
            archived.append(run)
    return {'worktrees': wts, 'archived_runs': archived}

def overview(repo):
    wt_payload = worktrees(repo)
    return {**wt_payload, 'messages': records(repo, 150), 'status': run_status(repo)}

def codex_dir(repo):
    return common_dir(repo) / 'codex-wrap'

def safe_codex_path(repo, value):
    path = Path(value).expanduser().resolve()
    base = codex_dir(repo).resolve()
    if path != base and base not in path.parents:
        raise ValueError('path is outside codex-wrap state')
    return path

def safe_commit(repo, value):
    value = str(value or '').strip()
    if not value:
        raise ValueError('missing commit')
    proc = sh(['git', 'rev-parse', '--verify', '--quiet', '--end-of-options', f'{value}^{{commit}}'], repo, check=False)
    commit = proc.stdout.strip()
    if not re.fullmatch(r'[0-9a-fA-F]{40}', commit or ''):
        raise ValueError('invalid commit')
    return commit

def transcript(repo, log='', commit=''):
    paths = []
    if log:
        paths.append(safe_codex_path(repo, log))
    if commit:
        commit = safe_commit(repo, commit)
        logs = codex_dir(repo) / 'logs'
        paths.extend([logs / f'{commit}.stderr', logs / f'{commit}.jsonl'])
    chunks = []
    for path in paths:
        if path.exists():
            chunks.append(f'===== {path} =====\n{path.read_text(errors="replace")}')
    return '\n\n'.join(chunks)

def clean_upload_name(name):
    name = Path(name or 'screenshot').name
    name = re.sub(r'[^A-Za-z0-9._-]+', '-', name).strip('.-')
    return name or 'screenshot'

def upload(repo, name, data, content_type=''):
    if ',' in data and data.split(',', 1)[0].startswith('data:'):
        data = data.split(',', 1)[1]
    try:
        raw = base64.b64decode(data, validate=True)
    except binascii.Error as e:
        raise ValueError('invalid base64 upload') from e
    if not raw:
        raise ValueError('empty upload')
    updir = codex_dir(repo) / 'chatgit-uploads' / f'{time.strftime("%Y%m%d-%H%M%S")}-{time.time_ns() % 1_000_000_000:09d}'
    updir.mkdir(parents=True, exist_ok=True)
    path = updir / clean_upload_name(name)
    path.write_bytes(raw)
    return {'path': str(path.resolve()), 'name': path.name, 'content_type': content_type or 'application/octet-stream', 'size': len(raw)}

def prompt_with_attachments(prompt, attachments):
    clean = []
    for item in attachments or []:
        path = Path(str(item)).expanduser().resolve()
        if not path.exists():
            raise ValueError(f'attachment not found: {path}')
        clean.append(str(path))
    if not clean:
        return prompt
    return prompt + '\n\nAttached files:\n' + '\n'.join(f'- {path}' for path in clean)

def rename_branch(repo, old_branch, new_branch):
    if not old_branch or old_branch == '(detached)':
        raise ValueError('cannot rename detached worktree')
    new_branch = str(new_branch or '').strip()
    if not new_branch:
        raise ValueError('missing new branch name')
    sh(['git', 'check-ref-format', '--branch', new_branch], repo)
    if current_branch(repo) == old_branch:
        git(repo, 'branch', '-m', new_branch)
    else:
        git(repo, 'branch', '-m', old_branch, new_branch)
    return {'branch': new_branch}

def show(repo, commit):
    commit = safe_commit(repo, commit)
    return git(repo, 'show', '--format=fuller', '--patch', '--stat', '--find-renames', '--find-copies', '--no-ext-diff', '--end-of-options', commit, check=False)

HTML = r'''<!doctype html><meta charset="utf-8"><title>codex-web-interface</title>
<style>
*{box-sizing:border-box}body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;margin:0;color:CanvasText;background:Canvas}header{position:sticky;top:0;z-index:2;display:flex;gap:.5rem;align-items:center;padding:.55rem .7rem;border-bottom:1px solid #8885;background:Canvas}input,textarea,button{font:inherit}input,textarea{border:1px solid #8888;border-radius:.35rem;padding:.38rem .45rem;background:Field;color:FieldText;min-width:0}button{border:1px solid #8888;border-radius:.35rem;padding:.28rem .46rem;cursor:pointer;background:ButtonFace;color:ButtonText;white-space:nowrap;font-size:.84rem;line-height:1.2}button:disabled{opacity:.5;cursor:default}main{display:grid;grid-template-columns:minmax(260px,30vw) minmax(320px,1fr) minmax(360px,38vw);height:calc(100vh - 50px);min-height:0}.brand{font-weight:750}.top-hint{max-width:24rem}.pane{min-width:0;min-height:0;border-right:1px solid #8885;display:flex;flex-direction:column}.pane:last-child{border-right:0}.pane-head{padding:.6rem .7rem;border-bottom:1px solid #8885;display:grid;gap:.25rem}.pane-title{font-weight:700}.hint{font-size:.78rem;opacity:.68}.row{display:flex;gap:.35rem;align-items:center;flex-wrap:wrap}.repo-row{flex:1;min-width:240px}.repo-row input{width:100%}#worktrees{overflow:auto;padding:.45rem}.section-title{font-size:.72rem;font-weight:750;text-transform:uppercase;letter-spacing:0;margin:.45rem .15rem .28rem;opacity:.62}.section-note{font-size:.74rem;opacity:.62;margin:-.15rem .15rem .35rem}.wt{width:100%;text-align:left;display:grid;gap:.18rem;border:1px solid #8884;background:color-mix(in srgb,CanvasText 2%,Canvas);color:CanvasText;border-radius:.35rem;margin-bottom:.42rem;padding:.48rem}.wt:hover,.wt.active{border-color:#8887;background:color-mix(in srgb,CanvasText 6%,Canvas)}.wt.running{border-color:#0b7d53;background:color-mix(in srgb,#0b7d53 10%,Canvas)}.wt-head{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:.35rem;align-items:start}.wt-main{font-weight:720;font-size:1rem;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.wt-path,.wt-parent,.wt-status{font-size:.76rem;opacity:.7;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.agent-active{color:#0b7d53;font-weight:700;opacity:1}.runs{position:relative;display:grid;gap:.12rem;margin-top:.24rem;padding-left:.72rem}.runs:before{content:"";position:absolute;left:.28rem;top:.25rem;bottom:.25rem;border-left:1px solid #8885}.run{position:relative;display:grid;gap:.16rem;padding:.24rem .12rem;background:transparent;border-radius:.22rem;cursor:pointer}.run:hover{background:color-mix(in srgb,CanvasText 4%,Canvas)}.run:before{content:"";position:absolute;left:-.52rem;top:.48rem;width:.48rem;height:.48rem;border:2px solid #8887;border-radius:50%;background:Canvas}.run.active:before{border-color:#0b7d53;background:#0b7d53;box-shadow:0 0 0 3px color-mix(in srgb,#0b7d53 16%,Canvas)}.run.finished:before{border-color:#4567b7}.run.aborted:before{border-color:#9a3b30;background:#9a3b30}.run.queued:before{border-color:#8a5a00;border-style:dashed}.run-title{font-size:.78rem;font-weight:680;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.run-meta{font-size:.72rem;opacity:.68;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.run-actions{display:flex;gap:.22rem;flex-wrap:wrap}.run-actions button{font-size:.72rem;padding:.18rem .32rem}#state{min-width:0;overflow:hidden;border-top:1px solid #8885;padding:.55rem .7rem;display:grid;gap:.25rem}.state-line{display:block;width:100%;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:.8rem;text-align:left}.queued{color:#8a5a00}.active-run{color:#06623b}#chat{overflow:auto;padding:.75rem;flex:1}.msg{margin:.5rem 0;padding:.6rem .68rem;border:1px solid #8884;border-radius:.4rem;white-space:pre-wrap;cursor:pointer}.msg.selected{border-color:#888;background:color-mix(in srgb,CanvasText 5%,Canvas)}.user{margin-left:2rem;background:color-mix(in srgb,CanvasText 7%,Canvas)}.assistant{margin-right:2rem}.system{opacity:.78;font-size:.88rem;border-style:dashed}.meta{display:flex;gap:.34rem;align-items:center;opacity:.78;font-size:.76rem;margin-bottom:.3rem;white-space:nowrap;min-width:0}.subject{overflow:hidden;text-overflow:ellipsis}.actions{margin-left:auto;display:flex;gap:.22rem;flex-wrap:wrap}.hash{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}#composer{padding:.7rem;border-top:1px solid #8885;display:grid;gap:.45rem}#composer.dragging{background:color-mix(in srgb,#0b7d53 10%,Canvas)}#prompt{min-height:5.5rem;resize:vertical}.attachments{display:flex;gap:.35rem;flex-wrap:wrap}.drop-hint{border:1px dashed #8888;border-radius:.35rem;padding:.36rem .5rem;font-size:.78rem;opacity:.74}.chip{display:inline-flex;gap:.35rem;align-items:center;max-width:100%;border:1px solid #8886;border-radius:.3rem;padding:.16rem .22rem .16rem .35rem;font-size:.76rem}.chip-name{overflow:hidden;text-overflow:ellipsis}.chip-x{border:0;background:transparent;padding:.04rem .22rem}.detail-tools{display:flex;gap:.35rem;align-items:center;flex-wrap:wrap}.detail-hash{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.8rem;overflow:hidden;text-overflow:ellipsis}#diff{flex:1;overflow:auto;padding:.75rem;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.8rem;white-space:pre-wrap;overflow-wrap:anywhere}.empty{padding:.75rem;color:color-mix(in srgb,CanvasText 58%,Canvas)}
@media (max-width:900px){main{grid-template-columns:1fr;height:auto}.pane{min-height:40vh;border-right:0;border-bottom:1px solid #8885}header{position:static}.repo-row{min-width:100%}}
</style>
<header><span class="brand">codex-web-interface</span><span class="hint top-hint">Git-backed Codex interface; chatgit launcher; codex_wrap runner; worktree helpers. Path changes auto-load.</span><label class="repo-row"><input id="repo" aria-label="Repository path"></label><button onclick="refreshAll()" title="Reload repository, branch, message, and status data">Sync now</button><button onclick="abortRun()" title="Stop the active Codex run in this worktree and clear web-queued messages">Abort run</button></header>
<main>
  <section class="pane" id="left"><div class="pane-head"><div class="pane-title">Branches</div><div class="hint">Active worktrees and runs from closed worktrees</div></div><div id="worktrees"></div><div id="state"></div></section>
  <section class="pane"><div class="pane-head"><div class="pane-title">Conversation</div><div id="base" class="hint">No branch base selected. Click a hash to copy it.</div></div><div id="chat"></div><div id="composer"><textarea id="prompt" placeholder="Prompt. Continue resumes the latest session; active worktree runs are queued server-side until they finish."></textarea><div id="dropHint" class="drop-hint">Paste or drop files into this composer.</div><div id="attachments" class="attachments"></div><div class="row"><button onclick="send('send')" title="Resume the latest Codex session; queue behind an active run in this worktree">Continue</button><button onclick="send('fresh')" title="Start a new Codex session; queue behind an active run in this worktree">Fresh</button><button onclick="send('branch')" title="Start a child worktree from the selected commit; queue if that new worktree is active">Branch from selected</button><button onclick="clearBase()" title="Clear the selected branch base commit">Clear base</button></div></div></section>
  <aside class="pane"><div class="pane-head"><div class="pane-title">Detail</div><div class="hint">Commit patch or Full transcript. Click a hash to copy it.</div><div class="detail-tools"><span id="detailHash" class="detail-hash hint">Select a commit or process</span><button id="copyDetail" onclick="copyDetail()" disabled>Copy message</button></div></div><pre id="diff" class="empty">Select a commit to view git show --format=fuller --patch output, or click a process row for its Full transcript.</pre></aside>
</main>
<script>
window.CHATGIT_CONFIG=__CHATGIT_CONFIG__;
let baseCommit='', selectedCommit='', repoTimer=null, attachments=[], refreshing=false, messagesByHash={};
const $=id=>document.getElementById(id);
const esc=s=>(s||'').replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
async function api(path,opt={}){let r=await fetch(path,opt),j=await r.json(); if(!r.ok||j.error)throw new Error(j.error||r.statusText); return j}
function ce(tag, cls='', text=''){let e=document.createElement(tag); if(cls)e.className=cls; if(text!==undefined&&text!=='')e.textContent=text; return e}
function action(label, fn, title=''){let b=ce('button','',label); b.type='button'; if(title){b.title=title; b.setAttribute('aria-label',title)} b.onclick=e=>{e.stopPropagation(); fn(e)}; return b}
function setBase(h,t=''){baseCommit=h; $('base').textContent='Branch base: '+h.slice(0,12); if(t)$('prompt').value=t}
function clearBase(){baseCommit=''; $('base').textContent='No branch base selected.'}
function setRepo(path){$('repo').value=path; selectedCommit=''; clearBase(); refreshAll(true)}
function repoPathChanged(){clearTimeout(repoTimer); repoTimer=setTimeout(()=>{selectedCommit=''; clearBase(); refreshAll(true)},350)}
async function copyText(text,label='Copy text'){try{await navigator.clipboard.writeText(text)}catch(e){window.prompt(label,text)}}
function copyDetail(){let text=$('diff').textContent||''; if(text&&!$('copyDetail').disabled)copyText(text,'Copy message')}
function hasTextSelection(){let s=window.getSelection&&window.getSelection(); return !!(s&&!s.isCollapsed&&String(s).trim())}
function renderAttachments(){$('attachments').innerHTML=attachments.map((a,i)=>`<span class="chip"><span class="chip-name">${esc(a.name||a.path)}</span><button class="chip-x" title="Remove attachment" onclick="removeAttachment(${i})">x</button></span>`).join('')}
function removeAttachment(i){attachments.splice(i,1); renderAttachments()}
async function uploadFileList(files){
  for(let f of Array.from(files||[])){
    let data=await new Promise((res,rej)=>{let r=new FileReader(); r.onload=()=>res(String(r.result).split(',',2)[1]||''); r.onerror=rej; r.readAsDataURL(f)});
    attachments.push(await api('/api/upload',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({repo:$('repo').value,name:f.name,content_type:f.type||'application/octet-stream',data:data})}));
  }
  renderAttachments();
}
async function handlePaste(e){
  let files=[...((e.clipboardData&&e.clipboardData.files)||[])];
  if(files.length){e.preventDefault(); await uploadFileList(files)}
}
async function handleDrop(e){
  e.preventDefault(); $('composer').classList.remove('dragging'); await uploadFileList(e.dataTransfer&&e.dataTransfer.files);
}
async function loadWorktrees(j=null){
  j = j || await api('/api/worktrees?repo='+encodeURIComponent($('repo').value));
  let box=$('worktrees'), cur=$('repo').value; box.innerHTML='';
  box.appendChild(ce('div','section-title','Active worktrees'));
  for(let wt of j.worktrees){
    let b=ce('div','wt'+(wt.path===cur?' active':'')+(wt.active?' running':'')); b.onclick=e=>{if(!e.target.closest('button'))setRepo(wt.path)};
    let p=wt.parent_branch?' ← '+wt.parent_branch:''; let pc=wt.parent_commit?' @ '+wt.parent_commit.slice(0,12):'';
    let head=ce('div','wt-head');
    head.appendChild(ce('div','wt-main',(wt.branch||'(detached)')+p));
    let acts=ce('div','actions'); acts.appendChild(action('...',()=>renameBranch(wt.path,wt.branch||''),'Rename branch')); head.appendChild(acts);
    b.appendChild(head);
    b.appendChild(ce('div','wt-path',wt.path||''));
    b.appendChild(ce('div','wt-parent',wt.parent_branch?'parent '+wt.parent_branch+pc:'root conversation'));
    if(wt.active)b.appendChild(ce('div','wt-status agent-active','agent active '+(wt.active.short||'')));
    renderRuns(b, wt.runs||[], wt.queue||[]);
    box.appendChild(b);
  }
  let archived=j.archived_runs||[];
  if(archived.length){
    box.appendChild(ce('div','section-title','Closed worktree runs'));
    box.appendChild(ce('div','section-note','Runs whose recorded cwd no longer maps to an attached worktree.'));
    let wrap=ce('div','runs');
    for(let run of archived.slice(0,20))renderRun(wrap, run, true);
    box.appendChild(wrap);
  }
}
function renderRuns(parent, runs, queue){
  if(!(runs&&runs.length)&&!(queue&&queue.length))return;
  let box=ce('div','runs');
  for(let q of queue||[]){
    let r=ce('div','run queued'); r.appendChild(ce('div','run-title',(q.prompt||'Queued message').slice(0,130))); r.appendChild(ce('div','run-meta','queued '+(q.mode||q.func||''))); let acts=ce('div','run-actions'); acts.appendChild(action('Copy prompt',()=>copyText(q.prompt||'','Copy queued prompt'),'Copy queued prompt text')); r.appendChild(acts); box.appendChild(r);
  }
  for(let run of (runs||[]).slice(0,5))renderRun(box, run, false);
  parent.appendChild(box);
}
function renderRun(parent, run, archived){
  let r=ce('div','run '+(run.status||'open')); let branch=archived&&run.branch?' · '+run.branch:'';
  r.title='Click row to show the full transcript';
  r.onclick=e=>{if(!e.target.closest('button')&&!hasTextSelection())showTranscript(run.hash,'')};
  r.appendChild(ce('div','run-title',(run.prompt||run.subject||'Codex run').slice(0,130)));
  r.appendChild(ce('div','run-meta',(run.short||'')+' · '+(run.status||'open')+branch));
  let acts=ce('div','run-actions');
  acts.appendChild(action('Transcript',()=>showTranscript(run.hash,''),'Show full transcript for this run'));
  acts.appendChild(action('Patch',()=>diff(run.hash),'Show patch for the run-start commit'));
  acts.appendChild(action('Copy message',()=>copyText(run.raw||run.subject||run.prompt||'','Copy commit message'),'Copy the run-start commit message'));
  r.appendChild(acts); parent.appendChild(r);
}
async function loadStatus(j=null){
  j = j || await api('/api/status?repo='+encodeURIComponent($('repo').value));
  let lines=[];
  for(let q of (j.queue||[]))lines.push(`<div class="state-line queued">Queued: ${esc(q.mode||q.func)} ${esc((q.prompt||'').slice(0,90))}</div>`);
  if(j.active&&j.active.hash)lines.push(`<button class="state-line active-run" onclick="showTranscript('${esc(j.active.hash)}','')">Active: <span class="hash">${esc(j.active.short||j.active.hash.slice(0,7))}</span> ${esc(j.active.subject||'Codex run')} · Full transcript</button>`);
  else if(j.active&&j.active.pid)lines.push(`<button class="state-line active-run" onclick="showTranscript('', '${esc(j.active.log||'')}')">Starting: PID ${esc(String(j.active.pid))} ${esc(j.active.mode||j.active.func||'Codex run')} · Full transcript</button>`);
  if(!lines.length)lines.push('<div class="state-line hint">No active run or queued message.</div>');
  $('state').innerHTML=lines.join('');
}
async function loadMessages(j=null){
  j = j || await api('/api/messages?repo='+encodeURIComponent($('repo').value)); let c=$('chat');
  let nearBottom=(c.scrollHeight-c.scrollTop-c.clientHeight)<80;
  c.innerHTML=''; messagesByHash={};
  for(let m of j.messages){
    messagesByHash[m.hash]=m;
    let cls=m.role==='assistant'?'assistant':(m.role==='user'?'user':'system'); let d=ce('div','msg '+cls+(m.hash===selectedCommit?' selected':''));
    d.title='Click row to show this commit patch';
    d.onclick=e=>{if(!e.target.closest('button')&&!hasTextSelection())diff(m.hash)};
    let t=m.timestamp?new Date(m.timestamp*1000).toLocaleString():'';
    let meta=ce('div','meta');
    let hb=action(m.short,()=>copyText(m.hash,'Copy hash')); hb.className='hash'; hb.title='Click a hash to copy it'; meta.appendChild(hb);
    meta.appendChild(ce('span','',t)); meta.appendChild(ce('span','subject',m.subject));
    let acts=ce('span','actions'); acts.appendChild(action('Patch',()=>diff(m.hash),'Show git patch for this commit')); acts.appendChild(action('Copy message',()=>copyText(m.raw||m.subject||'','Copy commit message'),'Copy this full Git commit message')); acts.appendChild(action('Branch here',()=>setBase(m.hash),'Use this commit as the branch base'));
    if(m.role==='user')acts.appendChild(action('Edit branch',()=>setBase(m.parent||m.hash, (messagesByHash[m.hash]||m).text||''),'Branch from the parent and reuse this prompt text'));
    meta.appendChild(acts); d.appendChild(meta); d.appendChild(ce('div','',m.text));
    c.appendChild(d);
  }
  if(nearBottom)c.scrollTop=c.scrollHeight;
}
async function diff(h){
  selectedCommit=h; $('detailHash').textContent=h; $('copyDetail').disabled=false;
  let j=await api('/api/show?repo='+encodeURIComponent($('repo').value)+'&commit='+encodeURIComponent(h));
  $('diff').className=''; $('diff').textContent=j.patch; $('copyDetail').disabled=!$('diff').textContent; await loadMessages();
}
async function showTranscript(commit='', log=''){
  selectedCommit=commit||''; $('detailHash').textContent=commit||log||'Full transcript';
  let j=await api('/api/transcript?repo='+encodeURIComponent($('repo').value)+'&commit='+encodeURIComponent(commit)+'&log='+encodeURIComponent(log));
  $('diff').className=''; $('diff').textContent=j.transcript||'No transcript log available yet.'; $('copyDetail').disabled=!$('diff').textContent;
}
async function renameBranch(path, oldBranch){
  if(!oldBranch||oldBranch==='(detached)')return;
  let next=window.prompt('Rename branch', oldBranch);
  if(!next||next===oldBranch)return;
  await api('/api/branch/rename',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({repo:path,old_branch:oldBranch,new_branch:next})});
  if($('repo').value===path)clearBase();
  await refreshAll(true);
}
async function send(mode){
  let p=$('prompt').value.trim(); if(!p)return; if(mode==='branch'&&!baseCommit){alert('choose a branch base first');return}
  let body={repo:$('repo').value,prompt:p,mode:mode,base_commit:mode==='branch'?baseCommit:'',attachments:attachments.map(a=>a.path)};
  let j=await api('/api/run',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
  if(j.worktree){$('repo').value=j.worktree.path; clearBase()}
  $('prompt').value=''; attachments=[]; renderAttachments(); await refreshAll(true);
}
async function abortRun(){await api('/api/abort',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({repo:$('repo').value})}); await refreshAll(true)}
async function refreshAll(force=false){if(refreshing||(!force&&hasTextSelection()))return; refreshing=true; try{let j=await api('/api/overview?repo='+encodeURIComponent($('repo').value)); if(!force&&hasTextSelection())return; await loadWorktrees(j); await loadMessages({messages:j.messages||[]}); await loadStatus(j.status||{})}catch(e){$('diff').textContent=String(e)}finally{refreshing=false}}
window.onload=async()=>{let c=window.CHATGIT_CONFIG; $('repo').value=c.repo; $('repo').addEventListener('input',repoPathChanged); $('repo').addEventListener('change',repoPathChanged); $('repo').addEventListener('keydown',e=>{if(e.key==='Enter')repoPathChanged()}); let comp=$('composer'); comp.addEventListener('paste',handlePaste); comp.addEventListener('dragover',e=>{e.preventDefault(); comp.classList.add('dragging')}); comp.addEventListener('dragleave',()=>comp.classList.remove('dragging')); comp.addEventListener('drop',handleDrop); setInterval(()=>{if(!document.hidden&&!hasTextSelection())refreshAll()},2000); await refreshAll(true)}
</script>'''

class H(BaseHTTPRequestHandler):
    def j(self, obj, code=200):
        b=json.dumps(obj,ensure_ascii=False).encode(); self.send_response(code); self.send_header('content-type','application/json; charset=utf-8'); self.send_header('content-length',str(len(b))); self.end_headers(); self.wfile.write(b)
    def repo(self, v):
        p=Path(v or str(ROOT)).expanduser().resolve(); git(p,'rev-parse','--git-dir'); return p
    def body(self):
        n=int(self.headers.get('content-length','0') or 0); return json.loads(self.rfile.read(n).decode() or '{}') if n else {}
    def do_GET(self):
        try:
            u=urlparse(self.path); q=parse_qs(u.query)
            if u.path=='/':
                html=HTML.replace('__CHATGIT_CONFIG__', json.dumps({'repo':str(ROOT),'wrapper':str(WRAPPER)}))
                b=html.encode(); self.send_response(200); self.send_header('content-type','text/html; charset=utf-8'); self.send_header('content-length',str(len(b))); self.end_headers(); self.wfile.write(b); return
            if u.path=='/api/config': self.j({'repo':str(ROOT),'wrapper':str(WRAPPER)}); return
            r=self.repo(q.get('repo',[str(ROOT)])[0])
            if u.path=='/api/worktrees': self.j(worktrees(r))
            elif u.path=='/api/overview': self.j(overview(r))
            elif u.path=='/api/messages': self.j({'messages':records(r,int(q.get('limit',['150'])[0]))})
            elif u.path=='/api/status': self.j(run_status(r))
            elif u.path=='/api/show': self.j({'patch':show(r,q.get('commit',[''])[0])})
            elif u.path=='/api/transcript': self.j({'transcript':transcript(r,q.get('log',[''])[0],q.get('commit',[''])[0])})
            else: self.j({'error':'not found'},404)
        except Exception as e: self.j({'error':str(e)},500)
    def do_POST(self):
        try:
            u=urlparse(self.path); b=self.body(); r=self.repo(b.get('repo') or str(ROOT))
            if u.path=='/api/run':
                prompt=prompt_with_attachments(str(b.get('prompt') or ''), b.get('attachments') or []); mode=str(b.get('mode') or 'send'); wt=None
                if not prompt: raise ValueError('missing prompt')
                target=r
                if mode=='branch': wt=create_worktree(r,str(b.get('base_commit') or '')); target=Path(wt['path']); func='codex_commit'
                elif mode=='fresh': func='codex_commit'
                elif mode in ('send','new_message'): func='codex_new_message'
                elif mode=='resume': func='codex_resume'
                else: raise ValueError('bad mode')
                result = submit_or_queue(target, func, [prompt], mode, prompt)
                result.update({'ok': True, 'worktree': wt})
                self.j(result)
            elif u.path=='/api/abort':
                clear_queue(r)
                proc, info = spawn_process(r,'codex_abort',[], {'mode': 'abort', 'prompt': ''})
                self.j({'ok':True,'process':public_process(info)})
            elif u.path=='/api/upload':
                self.j({'ok':True, **upload(r, str(b.get('name') or ''), str(b.get('data') or ''), str(b.get('content_type') or ''))})
            elif u.path=='/api/branch/rename':
                self.j({'ok':True, **rename_branch(r, str(b.get('old_branch') or ''), str(b.get('new_branch') or ''))})
            else: self.j({'error':'not found'},404)
        except Exception as e: self.j({'error':str(e)},500)

def main():
    global ROOT, WRAPPER
    ap=argparse.ArgumentParser(); ap.add_argument('--repo',default=os.getcwd()); ap.add_argument('--wrapper',default=str(WRAPPER)); ap.add_argument('--port',type=int,default=6174)
    ns=ap.parse_args(); ROOT=Path(ns.repo).expanduser().resolve(); WRAPPER=Path(ns.wrapper).expanduser().resolve(); git(ROOT,'rev-parse','--git-dir')
    if not WRAPPER.exists(): raise SystemExit(f'wrapper not found: {WRAPPER}')
    print(f'codex-web-interface: http://127.0.0.1:{ns.port}/\nrepo: {ROOT}\nwrapper: {WRAPPER}')
    ThreadingHTTPServer(('127.0.0.1',ns.port),H).serve_forever()
if __name__=='__main__': main()
