#!/usr/bin/env python3
"""Small loopback web UI for codex_wrap_parallel.sh.

Run:
  python3 codex_web.py --repo ~/repos/repo --wrapper ~/learnings/scripts/codex_wrap.sh --port 6174

No auth; binds to 127.0.0.1 by default. Do NOT run on 0.0.0.0. Use SSH port forwarding for remote use.
"""
from __future__ import annotations
import argparse, json, os, re, subprocess, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path.cwd()
WRAPPER = Path(__file__).with_name('codex_wrap.sh')

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

def spawn(repo, func, args):
    logdir = common_dir(repo) / 'codex-wrap' / 'web'
    logdir.mkdir(parents=True, exist_ok=True)
    stamp = f'{time.strftime("%Y%m%d-%H%M%S")}-{time.time_ns() % 1_000_000_000:09d}'
    log = logdir / f'{stamp}-{os.getpid()}-{func}.log'
    env = os.environ.copy(); env['CODEX_WRAP_STDIN_NEW_MESSAGE'] = '0'
    script = 'source "$1"; shift; fn="$1"; shift; "$fn" "$@"'
    fh = open(log, 'ab')
    p = subprocess.Popen(['bash', '-lc', script, 'bash', str(WRAPPER), func, *args], cwd=str(repo), stdin=subprocess.DEVNULL, stdout=fh, stderr=subprocess.STDOUT, env=env, start_new_session=True)
    fh.close()
    return {'pid': p.pid, 'log': str(log)}

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

def show(repo, commit):
    return git(repo, 'show', '--patch', '--stat', '--find-renames', '--find-copies', '--no-ext-diff', commit, check=False)

HTML = r'''<!doctype html><meta charset="utf-8"><title>Codex Git Chat</title>
<style>
body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;margin:0;color:CanvasText;background:Canvas}header{position:sticky;top:0;z-index:2;display:flex;gap:.5rem;align-items:center;padding:.7rem;border-bottom:1px solid #8885;background:Canvas}input,select,textarea,button{font:inherit}input,select,textarea{border:1px solid #8888;border-radius:.45rem;padding:.45rem;background:Field;color:FieldText}button{border:1px solid #8888;border-radius:.45rem;padding:.45rem .7rem;cursor:pointer}main{display:grid;grid-template-columns:minmax(0,1fr) minmax(330px,42vw);height:calc(100vh - 58px)}#chat{overflow:auto;padding:1rem}.msg{max-width:980px;margin:.65rem 0;padding:.75rem .85rem;border:1px solid #8884;border-radius:.75rem;white-space:pre-wrap}.user{margin-left:auto;background:color-mix(in srgb,CanvasText 7%,Canvas)}.assistant{margin-right:auto}.system{opacity:.75;font-size:.85rem;border-style:dashed}.meta{display:flex;gap:.4rem;align-items:center;opacity:.75;font-size:.78rem;margin-bottom:.35rem;white-space:nowrap}.actions{margin-left:auto;display:flex;gap:.25rem}#side{border-left:1px solid #8885;display:flex;flex-direction:column;min-width:0}#diff{flex:1;overflow:auto;padding:.8rem;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.82rem;white-space:pre}#composer{padding:.8rem;border-top:1px solid #8885;display:grid;gap:.5rem}#prompt{min-height:6rem}.hint{font-size:.85rem;opacity:.7}.row{display:flex;gap:.4rem;align-items:center;flex-wrap:wrap}
</style>
<header><strong>Codex Git Chat</strong><input id="repo" size="44"><select id="wts"></select><button onclick="refreshAll()">Refresh</button><button onclick="abortRun()">Abort active</button></header>
<main><section style="display:flex;flex-direction:column;min-width:0"><div id="chat"></div><div id="composer"><div class="row"><span id="base" class="hint">No branch base selected.</span><button onclick="clearBase()">Clear</button></div><textarea id="prompt" placeholder="Prompt. Send interrupts/resumes; Fresh starts a new session; Branch starts a sibling worktree from selected commit."></textarea><div class="row"><button onclick="send('send')">Send / interrupt</button><button onclick="send('fresh')">Fresh</button><button onclick="send('branch')">Branch from selected</button></div></div></section><aside id="side"><div style="padding:.8rem;border-bottom:1px solid #8885"><b>Diff</b><div class="hint">Click Diff on a message.</div></div><pre id="diff"></pre></aside></main>
<script>
let baseCommit=''; const $=id=>document.getElementById(id); const esc=s=>(s||'').replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
async function api(path,opt={}){let r=await fetch(path,opt),j=await r.json(); if(!r.ok||j.error)throw new Error(j.error||r.statusText); return j}
function setBase(h,t=''){baseCommit=h; $('base').textContent='Branch base: '+h.slice(0,12); if(t)$('prompt').value=t} function clearBase(){baseCommit=''; $('base').textContent='No branch base selected.'}
async function loadWorktrees(){let j=await api('/api/worktrees?repo='+encodeURIComponent($('repo').value)); let s=$('wts'), cur=$('repo').value; s.innerHTML=''; for(let wt of j.worktrees){let o=document.createElement('option'); o.value=wt.path; let p=wt.parent_branch?' ← '+wt.parent_branch:''; o.textContent=(wt.branch||'(detached)')+p+' — '+wt.path; if(wt.path===cur)o.selected=true; s.appendChild(o)} s.onchange=()=>{$('repo').value=s.value; clearBase(); refreshAll()}}
async function loadMessages(){let j=await api('/api/messages?repo='+encodeURIComponent($('repo').value)); let c=$('chat'); c.innerHTML=''; for(let m of j.messages){let cls=m.role==='assistant'?'assistant':(m.role==='user'?'user':'system'); let d=document.createElement('div'); d.className='msg '+cls; let t=m.timestamp?new Date(m.timestamp*1000).toLocaleString():''; let edit=m.role==='user'?`<button onclick='setBase("${m.parent||m.hash}", ${JSON.stringify(m.text)})'>Edit→branch</button>`:''; d.innerHTML=`<div class="meta"><code>${m.short}</code><span>${esc(t)}</span><span>${esc(m.subject)}</span><span class="actions"><button onclick="diff('${m.hash}')">Diff</button><button onclick="setBase('${m.hash}')">Branch here</button>${edit}</span></div><div>${esc(m.text)}</div>`; c.appendChild(d)} c.scrollTop=c.scrollHeight}
async function diff(h){let j=await api('/api/show?repo='+encodeURIComponent($('repo').value)+'&commit='+encodeURIComponent(h)); $('diff').textContent=j.patch}
async function send(mode){let p=$('prompt').value.trim(); if(!p)return; if(mode==='branch'&&!baseCommit){alert('choose a branch base first');return} let body={repo:$('repo').value,prompt:p,mode:mode,base_commit:mode==='branch'?baseCommit:''}; let j=await api('/api/run',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)}); if(j.worktree){$('repo').value=j.worktree.path; clearBase()} $('prompt').value=''; refreshAll()}
async function abortRun(){await api('/api/abort',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({repo:$('repo').value})}); refreshAll()}
async function refreshAll(){try{await loadWorktrees(); await loadMessages()}catch(e){$('diff').textContent=String(e)}}
window.onload=async()=>{let c=await api('/api/config'); $('repo').value=c.repo; await refreshAll(); setInterval(loadMessages,2000)}
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
                self.j({'ok':True,'process':spawn(target,func,[prompt]),'worktree':wt})
            elif u.path=='/api/abort': self.j({'ok':True,'process':spawn(r,'codex_abort',[])})
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
