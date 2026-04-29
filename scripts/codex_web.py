#!/usr/bin/env python3
"""Small loopback web UI for codex_wrap_parallel.sh.

Run:
  python3 codex_web.py --repo ~/repos/repo --wrapper ~/learnings/scripts/codex_wrap.sh --port 6174

No auth; binds to 127.0.0.1 by default. Do NOT run on 0.0.0.0. Use SSH port forwarding for remote use.
"""
from __future__ import annotations
import argparse, json, os, re, subprocess, sys, threading, time
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

def worktrees(repo):
    out = git(repo, 'worktree', 'list', '--porcelain', check=False)
    ans, cur = [], {}
    for line in out.splitlines():
        if not line:
            if cur:
                cur['parent_branch'] = branch_config(repo, cur.get('branch', ''), 'chatgit-parent')
                cur['parent_commit'] = branch_config(repo, cur.get('branch', ''), 'chatgit-parent-commit')
                ans.append(cur)
                cur = {}
        elif line.startswith('worktree '): cur['path'] = line[9:]
        elif line.startswith('HEAD '): cur['head'] = line[5:]
        elif line.startswith('branch '):
            b = line[7:]
            cur['branch'] = b.removeprefix('refs/heads/')
        elif line.startswith('detached'): cur['branch'] = '(detached)'
    if cur:
        cur['parent_branch'] = branch_config(repo, cur.get('branch', ''), 'chatgit-parent')
        cur['parent_commit'] = branch_config(repo, cur.get('branch', ''), 'chatgit-parent-commit')
        ans.append(cur)
    return ans

def create_worktree(repo, commit):
    root = repo_root(repo)
    parent = current_branch(repo)
    base = git(repo, 'rev-parse', commit).strip()
    short = git(repo, 'rev-parse', '--short', base).strip()
    for i in range(100):
        suf = f'-{i}' if i else ''
        stamp = f'{time.strftime("%Y%m%d-%H%M%S")}-{time.time_ns() % 1_000_000_000:09d}'
        branch = f'codex-web-{short}-{stamp}{suf}'
        wt = Path(f'{root}.worktrees') / branch
        if not wt.exists():
            try:
                sh(['git', 'worktree', 'add', '-b', branch, str(wt), base], repo)
            except subprocess.CalledProcessError:
                time.sleep(.05)
                continue
            if parent:
                git(repo, 'config', f'branch.{branch}.chatgit-parent', parent)
            git(repo, 'config', f'branch.{branch}.chatgit-parent-commit', base)
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
    queued = []
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

def show(repo, commit):
    return git(repo, 'show', '--format=fuller', '--patch', '--stat', '--find-renames', '--find-copies', '--no-ext-diff', commit, check=False)

HTML = r'''<!doctype html><meta charset="utf-8"><title>Codex Git Chat</title>
<style>
*{box-sizing:border-box}body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;margin:0;color:CanvasText;background:Canvas}header{position:sticky;top:0;z-index:2;display:flex;gap:.5rem;align-items:center;padding:.65rem .75rem;border-bottom:1px solid #8885;background:Canvas}input,textarea,button{font:inherit}input,textarea{border:1px solid #8888;border-radius:.45rem;padding:.45rem;background:Field;color:FieldText;min-width:0}button{border:1px solid #8888;border-radius:.45rem;padding:.4rem .62rem;cursor:pointer;background:ButtonFace;color:ButtonText;white-space:nowrap}button:disabled{opacity:.5;cursor:default}main{display:grid;grid-template-columns:minmax(220px,24vw) minmax(320px,1fr) minmax(360px,39vw);height:calc(100vh - 57px);min-height:0}.pane{min-width:0;min-height:0;border-right:1px solid #8885;display:flex;flex-direction:column}.pane:last-child{border-right:0}.pane-head{padding:.75rem;border-bottom:1px solid #8885;display:grid;gap:.35rem}.pane-title{font-weight:700}.hint{font-size:.82rem;opacity:.68}.row{display:flex;gap:.4rem;align-items:center;flex-wrap:wrap}.repo-row{flex:1;min-width:240px}.repo-row input{width:100%}#worktrees{overflow:auto;padding:.5rem}.wt{width:100%;text-align:left;display:grid;gap:.18rem;border:1px solid transparent;background:transparent;color:CanvasText;border-radius:.35rem;margin-bottom:.35rem;padding:.5rem}.wt:hover,.wt.active{border-color:#8887;background:color-mix(in srgb,CanvasText 6%,Canvas)}.wt-main{font-weight:650;overflow:hidden;text-overflow:ellipsis}.wt-path,.wt-parent{font-size:.78rem;opacity:.7;overflow:hidden;text-overflow:ellipsis}#state{border-top:1px solid #8885;padding:.6rem .75rem;display:grid;gap:.3rem}.state-line{font-size:.82rem}.queued{color:#8a5a00}.active-run{color:#06623b}#chat{overflow:auto;padding:.8rem;flex:1}.msg{margin:.55rem 0;padding:.65rem .72rem;border:1px solid #8884;border-radius:.5rem;white-space:pre-wrap}.msg.selected{border-color:#888;background:color-mix(in srgb,CanvasText 5%,Canvas)}.user{margin-left:2rem;background:color-mix(in srgb,CanvasText 7%,Canvas)}.assistant{margin-right:2rem}.system{opacity:.78;font-size:.88rem;border-style:dashed}.meta{display:flex;gap:.38rem;align-items:center;opacity:.78;font-size:.78rem;margin-bottom:.35rem;white-space:nowrap;min-width:0}.subject{overflow:hidden;text-overflow:ellipsis}.actions{margin-left:auto;display:flex;gap:.25rem;flex-wrap:wrap}.hash{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}#composer{padding:.75rem;border-top:1px solid #8885;display:grid;gap:.5rem}#prompt{min-height:6rem;resize:vertical}.detail-tools{display:flex;gap:.4rem;align-items:center;flex-wrap:wrap}.detail-hash{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.82rem;overflow:hidden;text-overflow:ellipsis}#diff{flex:1;overflow:auto;padding:.8rem;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.8rem;white-space:pre-wrap;overflow-wrap:anywhere}.empty{padding:.8rem;color:color-mix(in srgb,CanvasText 58%,Canvas)}
@media (max-width:900px){main{grid-template-columns:1fr;height:auto}.pane{min-height:40vh;border-right:0;border-bottom:1px solid #8885}header{position:static}.repo-row{min-width:100%}}
</style>
<header><strong>Codex Git Chat</strong><label class="repo-row"><input id="repo" aria-label="Repository path"></label><button onclick="refreshAll()">Refresh</button><button onclick="abortRun()">Abort active</button></header>
<main>
  <section class="pane" id="left"><div class="pane-head"><div class="pane-title">Branches</div><div class="hint">Worktrees and parent metadata</div></div><div id="worktrees"></div><div id="state"></div></section>
  <section class="pane"><div class="pane-head"><div class="pane-title">Conversation</div><div id="base" class="hint">No branch base selected.</div></div><div id="chat"></div><div id="composer"><textarea id="prompt" placeholder="Prompt. Send queues behind an active run; Fresh starts a new session; Branch starts a child worktree from selected commit."></textarea><div class="row"><button onclick="send('send')">Send / queue</button><button onclick="send('fresh')">Fresh</button><button onclick="send('branch')">Branch from selected</button><button onclick="clearBase()">Clear base</button></div></div></section>
  <aside class="pane"><div class="pane-head"><div class="pane-title">Commit Detail</div><div class="detail-tools"><span id="detailHash" class="detail-hash hint">Select a commit</span><button id="copyDetail" onclick="copySelected()" disabled>Copy hash</button></div></div><pre id="diff" class="empty">Select a commit to view git show --format=fuller --patch output.</pre></aside>
</main>
<script>
let baseCommit='', selectedCommit='';
const $=id=>document.getElementById(id);
const esc=s=>(s||'').replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
async function api(path,opt={}){let r=await fetch(path,opt),j=await r.json(); if(!r.ok||j.error)throw new Error(j.error||r.statusText); return j}
function setBase(h,t=''){baseCommit=h; $('base').textContent='Branch base: '+h.slice(0,12); if(t)$('prompt').value=t}
function clearBase(){baseCommit=''; $('base').textContent='No branch base selected.'}
function setRepo(path){$('repo').value=path; selectedCommit=''; clearBase(); refreshAll()}
async function copyText(text){try{await navigator.clipboard.writeText(text)}catch(e){window.prompt('Copy hash',text)}}
function copySelected(){if(selectedCommit)copyText(selectedCommit)}
async function loadWorktrees(){
  let j=await api('/api/worktrees?repo='+encodeURIComponent($('repo').value));
  let box=$('worktrees'), cur=$('repo').value; box.innerHTML='';
  for(let wt of j.worktrees){
    let b=document.createElement('button'); b.className='wt'+(wt.path===cur?' active':''); b.onclick=()=>setRepo(wt.path);
    let p=wt.parent_branch?' ← '+wt.parent_branch:''; let pc=wt.parent_commit?' @ '+wt.parent_commit.slice(0,12):'';
    b.innerHTML=`<span class="wt-main">${esc(wt.branch||'(detached)')}${esc(p)}</span><span class="wt-path">${esc(wt.path)}</span><span class="wt-parent">${esc(wt.parent_branch?'parent '+wt.parent_branch+pc:'root conversation')}</span>`;
    box.appendChild(b);
  }
}
async function loadStatus(){
  let j=await api('/api/status?repo='+encodeURIComponent($('repo').value));
  let lines=[];
  for(let q of (j.queue||[]))lines.push(`<div class="state-line queued">Queued: ${esc(q.mode||q.func)} ${esc((q.prompt||'').slice(0,90))}</div>`);
  if(j.active&&j.active.hash)lines.push(`<div class="state-line active-run">Active: <span class="hash">${esc(j.active.short||j.active.hash.slice(0,7))}</span> ${esc(j.active.subject||'Codex run')}</div>`);
  else if(j.active&&j.active.pid)lines.push(`<div class="state-line active-run">Starting: PID ${esc(String(j.active.pid))} ${esc(j.active.mode||j.active.func||'Codex run')}</div>`);
  if(!lines.length)lines.push('<div class="state-line hint">No active run or queued message.</div>');
  $('state').innerHTML=lines.join('');
}
async function loadMessages(){
  let j=await api('/api/messages?repo='+encodeURIComponent($('repo').value)); let c=$('chat'); c.innerHTML='';
  for(let m of j.messages){
    let cls=m.role==='assistant'?'assistant':(m.role==='user'?'user':'system'); let d=document.createElement('div'); d.className='msg '+cls+(m.hash===selectedCommit?' selected':'');
    let t=m.timestamp?new Date(m.timestamp*1000).toLocaleString():''; let edit=m.role==='user'?`<button onclick='setBase("${m.parent||m.hash}", ${JSON.stringify(m.text)})'>Edit branch</button>`:'';
    d.innerHTML=`<div class="meta"><button class="hash" onclick="copyText('${m.hash}')">${m.short}</button><span>${esc(t)}</span><span class="subject">${esc(m.subject)}</span><span class="actions"><button onclick="diff('${m.hash}')">Show</button><button onclick="setBase('${m.hash}')">Branch here</button>${edit}</span></div><div>${esc(m.text)}</div>`;
    c.appendChild(d);
  }
  c.scrollTop=c.scrollHeight;
}
async function diff(h){
  selectedCommit=h; $('detailHash').textContent=h; $('copyDetail').disabled=false;
  let j=await api('/api/show?repo='+encodeURIComponent($('repo').value)+'&commit='+encodeURIComponent(h));
  $('diff').className=''; $('diff').textContent=j.patch; await loadMessages();
}
async function send(mode){
  let p=$('prompt').value.trim(); if(!p)return; if(mode==='branch'&&!baseCommit){alert('choose a branch base first');return}
  let body={repo:$('repo').value,prompt:p,mode:mode,base_commit:mode==='branch'?baseCommit:''};
  let j=await api('/api/run',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
  if(j.worktree){$('repo').value=j.worktree.path; clearBase()}
  $('prompt').value=''; await refreshAll();
}
async function abortRun(){await api('/api/abort',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({repo:$('repo').value})}); await refreshAll()}
async function refreshAll(){try{await loadWorktrees(); await loadMessages(); await loadStatus()}catch(e){$('diff').textContent=String(e)}}
window.onload=async()=>{let c=await api('/api/config'); $('repo').value=c.repo; await refreshAll()}
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
            else: self.j({'error':'not found'},404)
        except Exception as e: self.j({'error':str(e)},500)
    def do_POST(self):
        try:
            u=urlparse(self.path); b=self.body(); r=self.repo(b.get('repo') or str(ROOT))
            if u.path=='/api/run':
                prompt=str(b.get('prompt') or ''); mode=str(b.get('mode') or 'send'); wt=None
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
            else: self.j({'error':'not found'},404)
        except Exception as e: self.j({'error':str(e)},500)

def main():
    global ROOT, WRAPPER
    ap=argparse.ArgumentParser(); ap.add_argument('--repo',default=os.getcwd()); ap.add_argument('--wrapper',default=str(WRAPPER)); ap.add_argument('--port',type=int,default=6174)
    ns=ap.parse_args(); ROOT=Path(ns.repo).expanduser().resolve(); WRAPPER=Path(ns.wrapper).expanduser().resolve(); git(ROOT,'rev-parse','--git-dir')
    if not WRAPPER.exists(): raise SystemExit(f'wrapper not found: {WRAPPER}')
    print(f'Codex web UI: http://127.0.0.1:{ns.port}/\nrepo: {ROOT}\nwrapper: {WRAPPER}')
    ThreadingHTTPServer(('127.0.0.1',ns.port),H).serve_forever()
if __name__=='__main__': main()
