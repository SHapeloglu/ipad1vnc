#!/usr/bin/env python3
import argparse, html, json, mimetypes, os, secrets, shutil, urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path

ROOT = None
TOKEN = None

def safe_path(rel):
    rel = urllib.parse.unquote(rel or "").lstrip("/")
    p = (ROOT / rel).resolve()
    if p != ROOT and ROOT not in p.parents:
        raise ValueError("invalid path")
    return p

class H(BaseHTTPRequestHandler):
    server_version = "iPad1VNCFiles/2.2"
    def auth(self):
        return self.headers.get("X-iPad1VNC-Token","") == TOKEN or urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query).get("token",[""])[0] == TOKEN
    def json(self, code, obj):
        b=json.dumps(obj,ensure_ascii=False).encode()
        self.send_response(code);self.send_header("Content-Type","application/json; charset=utf-8");self.send_header("Content-Length",str(len(b)));self.end_headers();self.wfile.write(b)
    def target(self):
        q=urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
        return safe_path(q.get("path",[""])[0])
    def do_GET(self):
        u=urllib.parse.urlsplit(self.path)
        if u.path.startswith("/api/"):
            if not self.auth(): return self.json(401,{"error":"unauthorized"})
            if u.path=="/api/stat":
                try:p=self.target()
                except Exception:return self.json(400,{"error":"bad path"})
                if not p.exists():return self.json(404,{"error":"not found"})
                st=p.stat();return self.json(200,{"path":str(p.relative_to(ROOT)) if p!=ROOT else "","dir":p.is_dir(),"size":(st.st_size if p.is_file() else 0),"mtime":int(st.st_mtime)})
            if u.path=="/api/list":
                try:p=self.target()
                except Exception:return self.json(400,{"error":"bad path"})
                if not p.is_dir():return self.json(404,{"error":"not directory"})
                out=[]
                for x in sorted(p.iterdir(),key=lambda z:(not z.is_dir(),z.name.lower())):
                    st=x.stat();out.append({"name":x.name,"dir":x.is_dir(),"size":(st.st_size if x.is_file() else 0),"mtime":int(st.st_mtime)})
                return self.json(200,{"path":str(p.relative_to(ROOT)) if p!=ROOT else "","entries":out})
            return self.json(404,{"error":"not found"})
        if u.path=="/download":
            if not self.auth(): return self.json(401,{"error":"unauthorized"})
            try:p=self.target()
            except Exception:return self.json(400,{"error":"bad path"})
            if not p.is_file():return self.json(404,{"error":"not file"})
            size=p.stat().st_size;start=0;end=size-1;status=200
            rng=self.headers.get("Range","")
            if rng.startswith("bytes="):
                try:
                    spec=rng[6:].split(",",1)[0];lo,hi=spec.split("-",1);start=int(lo or 0);end=int(hi) if hi else size-1
                    if start<0 or start>=size or end<start:raise ValueError()
                    end=min(end,size-1);status=206
                except Exception:
                    self.send_response(416);self.send_header("Content-Range",f"bytes */{size}");self.end_headers();return
            length=max(0,end-start+1)
            self.send_response(status);self.send_header("Accept-Ranges","bytes");self.send_header("Content-Type",mimetypes.guess_type(p.name)[0] or "application/octet-stream");self.send_header("Content-Length",str(length));self.send_header("Content-Disposition",f'attachment; filename="{p.name}"')
            if status==206:self.send_header("Content-Range",f"bytes {start}-{end}/{size}")
            self.end_headers()
            with p.open("rb") as f:
                f.seek(start);remaining=length
                while remaining:
                    chunk=f.read(min(1024*1024,remaining))
                    if not chunk:break
                    self.wfile.write(chunk);remaining-=len(chunk)
            return
        self.json(404,{"error":"not found"})
    def readbody(self):
        n=int(self.headers.get("Content-Length","0") or 0)
        return self.rfile.read(n)
    def do_POST(self):
        u=urllib.parse.urlsplit(self.path)
        if not self.auth(): return self.json(401,{"error":"unauthorized"})
        try:
            if u.path=="/api/mkdir":
                d=json.loads(self.readbody() or b"{}");safe_path(d.get("path","")).mkdir(parents=False,exist_ok=False);return self.json(200,{"ok":True})
            if u.path=="/api/rename":
                d=json.loads(self.readbody() or b"{}");safe_path(d["from"]).rename(safe_path(d["to"]));return self.json(200,{"ok":True})
            if u.path=="/api/delete":
                d=json.loads(self.readbody() or b"{}");p=safe_path(d["path"]);shutil.rmtree(p) if p.is_dir() else p.unlink();return self.json(200,{"ok":True})
            if u.path=="/api/upload-chunk":
                q=urllib.parse.parse_qs(u.query);p=safe_path(q.get("path",[""])[0]);offset=int(q.get("offset",["0"])[0]);total=int(q.get("total",["0"])[0]);p.parent.mkdir(parents=True,exist_ok=True)
                current=p.stat().st_size if p.exists() else 0
                if offset>current:return self.json(409,{"error":"offset ahead of remote file","size":current})
                mode="r+b" if p.exists() else "wb"
                with p.open(mode) as f:
                    f.seek(offset);data=self.readbody();f.write(data)
                size=p.stat().st_size
                return self.json(200,{"ok":True,"size":size,"total":total,"complete":bool(total and size>=total)})
            if u.path=="/api/upload":
                q=urllib.parse.parse_qs(u.query);p=safe_path(q.get("path",[""])[0]);p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(self.readbody());return self.json(200,{"ok":True,"size":p.stat().st_size})
        except Exception as e:return self.json(400,{"error":str(e)})
        return self.json(404,{"error":"not found"})

def main():
    global ROOT,TOKEN
    ap=argparse.ArgumentParser();ap.add_argument("--root",default="/home/desktop/Downloads");ap.add_argument("--bind",default="0.0.0.0");ap.add_argument("--port",type=int,default=8085);ap.add_argument("--token-file",default="/home/desktop/.ipad1vnc-files-token");a=ap.parse_args()
    ROOT=Path(a.root).resolve();ROOT.mkdir(parents=True,exist_ok=True)
    tf=Path(a.token_file)
    if tf.exists(): TOKEN=tf.read_text().strip()
    else:
        TOKEN=secrets.token_urlsafe(24);tf.write_text(TOKEN+"\n");os.chmod(tf,0o600)
    print(f"Serving {ROOT} on {a.bind}:{a.port}");print(f"Token file: {tf}")
    ThreadingHTTPServer((a.bind,a.port),H).serve_forever()
if __name__=="__main__":main()
