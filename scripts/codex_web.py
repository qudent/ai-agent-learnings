#!/usr/bin/env python3
"""Small loopback codex-web-interface for codex_wrap.sh.

Run:
  python3 codex_web.py --repo ~/repos/repo --wrapper ~/learnings/scripts/codex_wrap.sh --port 6174

No auth; binds to 127.0.0.1 by default. Do NOT run on 0.0.0.0. Use SSH port forwarding for remote use.
"""
from __future__ import annotations
import argparse, base64, binascii, json, os, re, subprocess, sys, threading, time
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
    try:
        active = active_run(Path(cur.get('path', repo)))
        if active:
            cur['active'] = {k: active.get(k, '') for k in ('hash', 'short', 'subject', 'timestamp', 'fields')}
    except Exception:
        pass
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
    return ans

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

def active_run(repo):
    script = 'source "$1"; codex_active'
    proc = subprocess.run(
        ['bash', '-lc', script, 'bash', str(WRAPPER)],
        cwd=str(repo),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    commit = proc.stdout.strip().splitlines()[-1] if proc.returncode == 0 and proc.stdout.strip() else ''
    if not commit:
        return {}
    for row in records(repo, 200):
        if row['hash'] == commit:
            return row
    return {'hash': commit, 'short': commit[:7]}

def codex_dir(repo):
    return common_dir(repo) / 'codex-wrap'

def safe_codex_path(repo, value):
    path = Path(value).expanduser().resolve()
    base = codex_dir(repo).resolve()
    if path != base and base not in path.parents:
        raise ValueError('path is outside codex-wrap state')
    return path

def transcript(repo, log='', commit=''):
    paths = []
    if log:
        paths.append(safe_codex_path(repo, log))
    if commit:
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
    return git(repo, 'show', '--format=fuller', '--patch', '--stat', '--find-renames', '--find-copies', '--no-ext-diff', commit, check=False)

HTML = r'''<!doctype html><meta charset="utf-8"><title>codex-web-interface</title>
<style>
*{box-sizing:border-box}body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;margin:0;color:CanvasText;background:Canvas}header{position:sticky;top:0;z-index:2;display:flex;gap:.5rem;align-items:center;padding:.65rem .75rem;border-bottom:1px solid #8885;background:Canvas}input,textarea,button{font:inherit}input,textarea{border:1px solid #8888;border-radius:.45rem;padding:.45rem;background:Field;color:FieldText;min-width:0}button{border:1px solid #8888;border-radius:.45rem;padding:.4rem .62rem;cursor:pointer;background:ButtonFace;color:ButtonText;white-space:nowrap}button:disabled{opacity:.5;cursor:default}main{display:grid;grid-template-columns:minmax(220px,24vw) minmax(320px,1fr) minmax(360px,39vw);height:calc(100vh - 57px);min-height:0}.brand{font-weight:750}.top-hint{max-width:24rem}.pane{min-width:0;min-height:0;border-right:1px solid #8885;display:flex;flex-direction:column}.pane:last-child{border-right:0}.pane-head{padding:.75rem;border-bottom:1px solid #8885;display:grid;gap:.35rem}.pane-title{font-weight:700}.hint{font-size:.82rem;opacity:.68}.row{display:flex;gap:.4rem;align-items:center;flex-wrap:wrap}.repo-row{flex:1;min-width:240px}.repo-row input{width:100%}#worktrees{overflow:auto;padding:.5rem}.wt{width:100%;text-align:left;display:grid;gap:.18rem;border:1px solid transparent;background:transparent;color:CanvasText;border-radius:.35rem;margin-bottom:.35rem;padding:.5rem}.wt:hover,.wt.active{border-color:#8887;background:color-mix(in srgb,CanvasText 6%,Canvas)}.wt.running{border-color:#0b7d53;background:color-mix(in srgb,#0b7d53 12%,Canvas)}.wt-main{font-weight:650;overflow:hidden;text-overflow:ellipsis}.wt-path,.wt-parent,.wt-status{font-size:.78rem;opacity:.7;overflow:hidden;text-overflow:ellipsis}.agent-active{color:#0b7d53;font-weight:700;opacity:1}#state{min-width:0;overflow:hidden;border-top:1px solid #8885;padding:.6rem .75rem;display:grid;gap:.3rem}.state-line{display:block;width:100%;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:.82rem;text-align:left}.queued{color:#8a5a00}.active-run{color:#06623b}#chat{overflow:auto;padding:.8rem;flex:1}.msg{margin:.55rem 0;padding:.65rem .72rem;border:1px solid #8884;border-radius:.5rem;white-space:pre-wrap}.msg.selected{border-color:#888;background:color-mix(in srgb,CanvasText 5%,Canvas)}.user{margin-left:2rem;background:color-mix(in srgb,CanvasText 7%,Canvas)}.assistant{margin-right:2rem}.system{opacity:.78;font-size:.88rem;border-style:dashed}.meta{display:flex;gap:.38rem;align-items:center;opacity:.78;font-size:.78rem;margin-bottom:.35rem;white-space:nowrap;min-width:0}.subject{overflow:hidden;text-overflow:ellipsis}.actions{margin-left:auto;display:flex;gap:.25rem;flex-wrap:wrap}.hash{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}#composer{padding:.75rem;border-top:1px solid #8885;display:grid;gap:.5rem}#composer.dragging{background:color-mix(in srgb,#0b7d53 10%,Canvas)}#prompt{min-height:6rem;resize:vertical}.attachments{display:flex;gap:.35rem;flex-wrap:wrap}.drop-hint{border:1px dashed #8888;border-radius:.45rem;padding:.42rem .55rem;font-size:.82rem;opacity:.74}.chip{display:inline-flex;gap:.35rem;align-items:center;max-width:100%;border:1px solid #8886;border-radius:.35rem;padding:.18rem .25rem .18rem .4rem;font-size:.78rem}.chip-name{overflow:hidden;text-overflow:ellipsis}.chip-x{border:0;background:transparent;padding:.05rem .25rem}.detail-tools{display:flex;gap:.4rem;align-items:center;flex-wrap:wrap}.detail-hash{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.82rem;overflow:hidden;text-overflow:ellipsis}#diff{flex:1;overflow:auto;padding:.8rem;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.8rem;white-space:pre-wrap;overflow-wrap:anywhere}.empty{padding:.8rem;color:color-mix(in srgb,CanvasText 58%,Canvas)}
@media (max-width:900px){main{grid-template-columns:1fr;height:auto}.pane{min-height:40vh;border-right:0;border-bottom:1px solid #8885}header{position:static}.repo-row{min-width:100%}}
</style>
<header><span class="brand">codex-web-interface</span><span class="hint top-hint">Git-backed Codex interface; chatgit launcher; codex_wrap runner; worktree helpers. Path changes auto-load.</span><label class="repo-row"><input id="repo" aria-label="Repository path"></label><button onclick="refreshAll()">Sync now</button><button onclick="abortRun()">Abort active</button></header>
<main>
  <section class="pane" id="left"><div class="pane-head"><div class="pane-title">Branches</div><div class="hint">Worktrees and parent metadata</div></div><div id="worktrees"></div><div id="state"></div></section>
  <section class="pane"><div class="pane-head"><div class="pane-title">Conversation</div><div id="base" class="hint">No branch base selected. Click a hash to copy it.</div></div><div id="chat"></div><div id="composer"><textarea id="prompt" placeholder="Prompt. Send queues behind an active run; Fresh starts a new session; Branch starts a child worktree from selected commit."></textarea><div id="dropHint" class="drop-hint">Paste or drop files into this composer.</div><div id="attachments" class="attachments"></div><div class="row"><button onclick="send('send')">Send / queue</button><button onclick="send('fresh')">Fresh</button><button onclick="send('branch')">Branch from selected</button><button onclick="clearBase()">Clear base</button></div></div></section>
  <aside class="pane"><div class="pane-head"><div class="pane-title">Detail</div><div class="hint">Commit patch or Full transcript. Click a hash to copy it.</div><div class="detail-tools"><span id="detailHash" class="detail-hash hint">Select a commit or process</span><button id="copyDetail" onclick="copySelected()" disabled>Copy hash</button></div></div><pre id="diff" class="empty">Select a commit to view git show --format=fuller --patch output, or click a process row for its Full transcript.</pre></aside>
</main>
<script>
let baseCommit='', selectedCommit='', repoTimer=null, attachments=[], refreshing=false;
const $=id=>document.getElementById(id);
const esc=s=>(s||'').replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
async function api(path,opt={}){let r=await fetch(path,opt),j=await r.json(); if(!r.ok||j.error)throw new Error(j.error||r.statusText); return j}
function setBase(h,t=''){baseCommit=h; $('base').textContent='Branch base: '+h.slice(0,12); if(t)$('prompt').value=t}
function clearBase(){baseCommit=''; $('base').textContent='No branch base selected.'}
function setRepo(path){$('repo').value=path; selectedCommit=''; clearBase(); refreshAll()}
function repoPathChanged(){clearTimeout(repoTimer); repoTimer=setTimeout(()=>{selectedCommit=''; clearBase(); refreshAll()},350)}
async function copyText(text){try{await navigator.clipboard.writeText(text)}catch(e){window.prompt('Copy hash',text)}}
function copySelected(){if(selectedCommit)copyText(selectedCommit)}
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
async function loadWorktrees(){
  let j=await api('/api/worktrees?repo='+encodeURIComponent($('repo').value));
  let box=$('worktrees'), cur=$('repo').value; box.innerHTML='';
  for(let wt of j.worktrees){
    let b=document.createElement('button'); b.className='wt'+(wt.path===cur?' active':'')+(wt.active?' running':''); b.onclick=()=>setRepo(wt.path);
    let p=wt.parent_branch?' ← '+wt.parent_branch:''; let pc=wt.parent_commit?' @ '+wt.parent_commit.slice(0,12):'';
    let active=wt.active?`<span class="wt-status agent-active">agent active ${esc(wt.active.short||'')}</span>`:'';
    let pathArg=JSON.stringify(wt.path), branchArg=JSON.stringify(wt.branch||'');
    b.innerHTML=`<span class="wt-main">${esc(wt.branch||'(detached)')}${esc(p)}</span><span class="wt-path">${esc(wt.path)}</span><span class="wt-parent">${esc(wt.parent_branch?'parent '+wt.parent_branch+pc:'root conversation')}</span>${active}<span class="actions"><button onclick='event.stopPropagation();renameBranch(${pathArg},${branchArg})'>Rename branch</button></span>`;
    box.appendChild(b);
  }
}
async function loadStatus(){
  let j=await api('/api/status?repo='+encodeURIComponent($('repo').value));
  let lines=[];
  for(let q of (j.queue||[]))lines.push(`<div class="state-line queued">Queued: ${esc(q.mode||q.func)} ${esc((q.prompt||'').slice(0,90))}</div>`);
  if(j.active&&j.active.hash)lines.push(`<button class="state-line active-run" onclick="showTranscript('${esc(j.active.hash)}','')">Active: <span class="hash">${esc(j.active.short||j.active.hash.slice(0,7))}</span> ${esc(j.active.subject||'Codex run')} · Full transcript</button>`);
  else if(j.active&&j.active.pid)lines.push(`<button class="state-line active-run" onclick="showTranscript('', '${esc(j.active.log||'')}')">Starting: PID ${esc(String(j.active.pid))} ${esc(j.active.mode||j.active.func||'Codex run')} · Full transcript</button>`);
  if(!lines.length)lines.push('<div class="state-line hint">No active run or queued message.</div>');
  $('state').innerHTML=lines.join('');
}
async function loadMessages(){
  let j=await api('/api/messages?repo='+encodeURIComponent($('repo').value)); let c=$('chat');
  let nearBottom=(c.scrollHeight-c.scrollTop-c.clientHeight)<80;
  c.innerHTML='';
  for(let m of j.messages){
    let cls=m.role==='assistant'?'assistant':(m.role==='user'?'user':'system'); let d=document.createElement('div'); d.className='msg '+cls+(m.hash===selectedCommit?' selected':'');
    let t=m.timestamp?new Date(m.timestamp*1000).toLocaleString():''; let edit=m.role==='user'?`<button onclick='setBase("${m.parent||m.hash}", ${JSON.stringify(m.text)})'>Edit branch</button>`:'';
    d.innerHTML=`<div class="meta"><button class="hash" title="Click a hash to copy it" onclick="copyText('${m.hash}')">${m.short}</button><span>${esc(t)}</span><span class="subject">${esc(m.subject)}</span><span class="actions"><button onclick="diff('${m.hash}')">Show</button><button onclick="setBase('${m.hash}')">Branch here</button>${edit}</span></div><div>${esc(m.text)}</div>`;
    c.appendChild(d);
  }
  if(nearBottom)c.scrollTop=c.scrollHeight;
}
async function diff(h){
  selectedCommit=h; $('detailHash').textContent=h; $('copyDetail').disabled=false;
  let j=await api('/api/show?repo='+encodeURIComponent($('repo').value)+'&commit='+encodeURIComponent(h));
  $('diff').className=''; $('diff').textContent=j.patch; await loadMessages();
}
async function showTranscript(commit='', log=''){
  selectedCommit=commit||''; $('detailHash').textContent=commit||log||'Full transcript'; $('copyDetail').disabled=!commit;
  let j=await api('/api/transcript?repo='+encodeURIComponent($('repo').value)+'&commit='+encodeURIComponent(commit)+'&log='+encodeURIComponent(log));
  $('diff').className=''; $('diff').textContent=j.transcript||'No transcript log available yet.';
}
async function renameBranch(path, oldBranch){
  if(!oldBranch||oldBranch==='(detached)')return;
  let next=window.prompt('Rename branch', oldBranch);
  if(!next||next===oldBranch)return;
  await api('/api/branch/rename',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({repo:path,old_branch:oldBranch,new_branch:next})});
  if($('repo').value===path)clearBase();
  await refreshAll();
}
async function send(mode){
  let p=$('prompt').value.trim(); if(!p)return; if(mode==='branch'&&!baseCommit){alert('choose a branch base first');return}
  let body={repo:$('repo').value,prompt:p,mode:mode,base_commit:mode==='branch'?baseCommit:'',attachments:attachments.map(a=>a.path)};
  let j=await api('/api/run',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
  if(j.worktree){$('repo').value=j.worktree.path; clearBase()}
  $('prompt').value=''; attachments=[]; renderAttachments(); await refreshAll();
}
async function abortRun(){await api('/api/abort',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({repo:$('repo').value})}); await refreshAll()}
async function refreshAll(){if(refreshing)return; refreshing=true; try{await loadWorktrees(); await loadMessages(); await loadStatus()}catch(e){$('diff').textContent=String(e)}finally{refreshing=false}}
window.onload=async()=>{let c=await api('/api/config'); $('repo').value=c.repo; $('repo').addEventListener('input',repoPathChanged); $('repo').addEventListener('change',repoPathChanged); $('repo').addEventListener('keydown',e=>{if(e.key==='Enter')repoPathChanged()}); let comp=$('composer'); comp.addEventListener('paste',handlePaste); comp.addEventListener('dragover',e=>{e.preventDefault(); comp.classList.add('dragging')}); comp.addEventListener('dragleave',()=>comp.classList.remove('dragging')); comp.addEventListener('drop',handleDrop); setInterval(()=>{if(!document.hidden)refreshAll()},2000); await refreshAll()}
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
                b=HTML.encode(); self.send_response(200); self.send_header('content-type','text/html; charset=utf-8'); self.send_header('content-length',str(len(b))); self.end_headers(); self.wfile.write(b); return
            if u.path=='/api/config': self.j({'repo':str(ROOT),'wrapper':str(WRAPPER)}); return
            r=self.repo(q.get('repo',[str(ROOT)])[0])
            if u.path=='/api/worktrees': self.j({'worktrees':worktrees(r)})
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
