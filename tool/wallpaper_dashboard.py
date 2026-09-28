#!/usr/bin/env python3
"""Local dashboard for editing Bayan wallpapers.

Run:    python3 tool/wallpaper_dashboard.py          (http://127.0.0.1:8765)
Root:   portfolio repo  (/home/hamzah/develop/portfolio)

Edits (titles, category names, moves, deletes, uploads) are written straight
into the portfolio working tree: images under bayan/wallpapers/ and metadata
into bayan/wallpapers.json. Nothing is committed or pushed. When you are done,
ask the assistant to review `git diff` and deploy.
"""

from __future__ import annotations

import argparse
import datetime
import io
import json
import mimetypes
import re
import threading
import unicodedata
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

from PIL import Image

MAX_W = 1080
JPEG_Q = 85
MAX_UPLOAD = 20 * 1024 * 1024
ALLOWED = {".jpg", ".jpeg", ".png", ".webp"}

ROOT = Path("/home/hamzah/develop/portfolio")
IMAGES = ROOT / "bayan" / "wallpapers"
JSONF = ROOT / "bayan" / "wallpapers.json"
LOCK = threading.RLock()

ID_RE = re.compile(r"^[a-z0-9_\-]+$")


# ---------------------------------------------------------------- helpers
def derive_id(filename: str) -> str:
    stem = Path(filename).stem
    return re.sub(r"^\d+_", "", stem).lower()


def slugify(text: str, fallback: str = "image") -> str:
    text = unicodedata.normalize("NFKD", str(text)).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-zA-Z0-9]+", "_", text).strip("_").lower()
    return text or fallback


def pretty(cat: str) -> str:
    return cat.replace("_", " ").title()


def title_from_filename(filename: str) -> str:
    stem = re.sub(r"^\d+_", "", Path(filename).stem)
    return stem.replace("_", " ").strip().title()


def all_disk_files() -> dict[str, tuple[str, Path]]:
    """derived_id -> (category, path)"""
    out: dict[str, tuple[str, Path]] = {}
    if not IMAGES.exists():
        return out
    for d in sorted(IMAGES.iterdir()):
        if not d.is_dir() or d.name.startswith("."):
            continue
        for f in sorted(d.iterdir()):
            if f.suffix.lower() in ALLOWED:
                out[derive_id(f.name)] = (d.name, f)
    return out


def build_state() -> dict:
    meta_by_url: dict[str, dict] = {}
    cat_meta: dict[str, dict] = {}
    order: list[str] = []
    if JSONF.exists():
        try:
            doc = json.loads(JSONF.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            doc = {}
        for c in doc.get("categories", []):
            cid = c.get("id", "")
            order.append(cid)
            cat_meta[cid] = {k: c.get(k, "") for k in ("name", "name_ar", "name_ur")}
            for i in c.get("images", []):
                meta_by_url[i.get("url", "")] = i

    dirs = sorted(p for p in IMAGES.iterdir() if p.is_dir() and not p.name.startswith("."))
    dirs.sort(key=lambda p: order.index(p.name) if p.name in order else len(order))
    cats = []
    for d in dirs:
        imgs = []
        for f in sorted(d.iterdir()):
            if f.suffix.lower() not in ALLOWED:
                continue
            url = f"bayan/wallpapers/{d.name}/{f.name}"
            m = meta_by_url.get(url, {})
            imgs.append(
                {
                    "id": derive_id(f.name),
                    "file": f.name,
                    "title": (m.get("title") or "").strip() or title_from_filename(f.name),
                    "title_ar": m.get("title_ar", "") or "",
                    "title_ur": m.get("title_ur", "") or "",
                }
            )
        cm = cat_meta.get(d.name, {})
        cats.append(
            {
                "id": d.name,
                "name": cm.get("name") or pretty(d.name),
                "name_ar": cm.get("name_ar") or "",
                "name_ur": cm.get("name_ur") or "",
                "images": imgs,
            }
        )
    return {"categories": cats}


def write_json(state: dict) -> None:
    doc = {
        "version": "1.0",
        "last_updated": datetime.date.today().isoformat(),
        "categories": [
            {
                "id": c["id"],
                "name": c["name"],
                "name_ar": c.get("name_ar", ""),
                "name_ur": c.get("name_ur", ""),
                "images": [
                    {
                        "id": i["id"],
                        "title": i["title"],
                        "url": f"bayan/wallpapers/{c['id']}/{i['file']}",
                        "title_ar": i.get("title_ar", ""),
                        "title_ur": i.get("title_ur", ""),
                    }
                    for i in c["images"]
                ],
            }
            for c in state["categories"]
        ],
    }
    JSONF.parent.mkdir(parents=True, exist_ok=True)
    tmp = JSONF.with_name(JSONF.name + ".tmp")
    tmp.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    tmp.replace(JSONF)  # atomic: readers never see a half-written file


def validate_state(state: dict) -> None:
    if not isinstance(state.get("categories"), list):
        raise ValueError("bad payload: categories missing")
    seen_cat: set[str] = set()
    seen_img: set[str] = set()
    for c in state["categories"]:
        cid = str(c.get("id", ""))
        if not ID_RE.match(cid):
            raise ValueError(f"bad category id: {cid!r}")
        if cid in seen_cat:
            raise ValueError(f"duplicate category id: {cid}")
        seen_cat.add(cid)
        for k in ("name", "name_ar", "name_ur"):
            c[k] = str(c.get(k) or "").strip()
        c["name"] = c["name"] or pretty(cid)
        for i in c.get("images", []):
            iid = str(i.get("id", ""))
            if not ID_RE.match(iid):
                raise ValueError(f"bad image id: {iid!r}")
            if iid in seen_img:
                raise ValueError(f"duplicate image id: {iid}")
            seen_img.add(iid)
            if not str(i.get("file", "")):
                raise ValueError(f"image {iid}: missing file")
            for k in ("title", "title_ar", "title_ur"):
                i[k] = str(i.get(k) or "").strip()
            i["title"] = i["title"] or title_from_filename(i["file"])


def apply_state(state: dict) -> None:
    """Move/delete image files to match the state, then rewrite wallpapers.json."""
    validate_state(state)
    desired: dict[str, tuple[str, dict]] = {}
    for c in state["categories"]:
        for i in c["images"]:
            desired[i["id"]] = (c["id"], i)

    with LOCK:
        current = all_disk_files()
        staging = IMAGES / ".staging"
        moves: list[tuple[Path, Path]] = []

        for iid, (cat, rec) in desired.items():
            cur = current.get(iid)
            if cur is None:
                target = IMAGES / cat / rec["file"]
                if not target.exists():
                    raise ValueError(f"image file missing: {iid} ({cat}/{rec['file']})")
                continue
            src = cur[1]
            dst = IMAGES / cat / rec["file"]
            if src != dst:
                moves.append((src, dst))

        # two-phase move so swaps/collisions are safe
        staged: list[tuple[Path, Path, Path]] = []
        if moves:
            staging.mkdir(exist_ok=True)
            for n, (src, dst) in enumerate(moves):
                tmp = staging / f"{n}_{src.name}"
                src.rename(tmp)
                staged.append((tmp, src, dst))
            for tmp, orig_src, dst in staged:
                dst.parent.mkdir(exist_ok=True)
                if dst.exists():
                    tmp.rename(orig_src)  # roll back
                    raise ValueError(f"target already exists: {dst.relative_to(IMAGES)}")
                tmp.rename(dst)
            staging.rmdir()

        for iid, (cat, path) in current.items():
            if iid not in desired:
                path.unlink()

        for c in state["categories"]:
            (IMAGES / c["id"]).mkdir(exist_ok=True)
        keep = {c["id"] for c in state["categories"]}
        for d in IMAGES.iterdir():
            if d.is_dir() and not d.name.startswith(".") and d.name not in keep:
                try:
                    d.rmdir()  # only removes empty leftovers
                except OSError:
                    pass

        write_json(state)


def to_jpeg(data: bytes) -> bytes:
    im = Image.open(io.BytesIO(data))
    im.load()
    if im.mode in ("RGBA", "LA", "P"):
        rgba = im.convert("RGBA")
        bg = Image.new("RGB", rgba.size, (255, 255, 255))
        bg.paste(rgba, mask=rgba.split()[-1])
        im = bg
    else:
        im = im.convert("RGB")
    if im.width > MAX_W:
        im = im.resize((MAX_W, max(1, round(im.height * MAX_W / im.width))), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=JPEG_Q, optimize=True, progressive=True)
    return buf.getvalue()


def unique_name(cat: str, slug: str) -> str:
    d = IMAGES / cat
    d.mkdir(parents=True, exist_ok=True)
    existing = all_disk_files()
    base, n = slug, 2
    while slug in existing:
        slug = f"{base}-{n}"
        n += 1
    nums = [
        int(m.group(1))
        for f in d.iterdir()
        if f.is_file() and (m := re.match(r"^(\d+)_", f.name))
    ]
    i = max(nums, default=0) + 1
    name = f"{i:02d}_{slug}.jpg"
    while (d / name).exists():
        i += 1
        name = f"{i:02d}_{slug}.jpg"
    return name


def fetch_url(url: str) -> bytes:
    if not urlparse(url).scheme in ("http", "https"):
        raise ValueError("only http/https URLs allowed")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (wallpaper-dashboard)"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read(MAX_UPLOAD + 1)
    if len(data) > MAX_UPLOAD:
        raise ValueError("file too large (>20MB)")
    if not data:
        raise ValueError("empty response")
    return data


def handle_upload(form: dict[str, str], files: list[tuple[str, bytes]]) -> dict:
    cat = form.get("category", "").strip()
    if not ID_RE.match(cat):
        raise ValueError("bad category")
    if not files and form.get("url"):
        files = [("download", fetch_url(form["url"].strip()))]
    if not files:
        raise ValueError("no image provided")

    title = (form.get("title") or "").strip()
    added = []
    with LOCK:
        for orig_name, data in files:
            try:
                jpeg = to_jpeg(data)
            except Exception as e:  # noqa: BLE001
                raise ValueError(f"{orig_name}: not a readable image ({e})") from e
            slug = slugify(title) if title else slugify(Path(orig_name).stem)
            name = unique_name(cat, slug)
            (IMAGES / cat / name).write_bytes(jpeg)
            added.append(
                {
                    "id": derive_id(name),
                    "file": name,
                    "title": title or title_from_filename(name),
                    "title_ar": (form.get("title_ar") or "").strip(),
                    "title_ur": (form.get("title_ur") or "").strip(),
                }
            )

        state = build_state()
        # keep the other form fields / titles we just created
        for a in added:
            for c in state["categories"]:
                if c["id"] == cat:
                    for i in c["images"]:
                        if i["id"] == a["id"]:
                            i.update(a)
        write_json(state)
    return {"ok": True, "added": added}


def handle_replace(form: dict[str, str], files: list[tuple[str, bytes]]) -> dict:
    """Re-encode an existing image in place (used by the crop tool)."""
    cat = (form.get("category") or "").strip()
    fname = (form.get("file") or "").strip()
    if not ID_RE.match(cat):
        raise ValueError("bad category")
    if not fname or Path(fname).name != fname or Path(fname).suffix.lower() not in ALLOWED:
        raise ValueError("bad filename")
    if not files:
        raise ValueError("no image provided")
    path = IMAGES / cat / fname
    if not path.is_file():
        raise ValueError(f"not found: {cat}/{fname}")
    jpeg = to_jpeg(files[0][1])
    with LOCK:
        path.write_bytes(jpeg)
    return {"ok": True, "bytes": len(jpeg)}


def handle_optimize() -> dict:
    changed, saved = [], 0
    with LOCK:
        for iid, (cat, path) in all_disk_files().items():
            try:
                im = Image.open(path)
                im.load()
            except Exception:  # noqa: BLE001
                continue
            size = path.stat().st_size
            needs = im.width > MAX_W or size > 400_000
            if not needs:
                continue
            before = size
            if im.mode != "RGB":
                im = im.convert("RGB")
            if im.width > MAX_W:
                im = im.resize((MAX_W, max(1, round(im.height * MAX_W / im.width))), Image.LANCZOS)
            im.save(path, "JPEG", quality=JPEG_Q, optimize=True, progressive=True)
            after = path.stat().st_size
            saved += before - after
            changed.append(f"{cat}/{path.name}: {before//1024}K -> {after//1024}K")
    return {"ok": True, "changed": changed, "saved_kb": saved // 1024}


def parse_multipart(body: bytes, content_type: str) -> tuple[dict[str, str], list[tuple[str, bytes]]]:
    m = re.search(r'boundary="?([^";,]+)"?', content_type)
    if not m:
        return {}, []
    boundary = b"--" + m.group(1).encode()
    fields: dict[str, str] = {}
    files: list[tuple[str, bytes]] = []
    for chunk in body.split(boundary):
        chunk = chunk.strip(b"\r\n")
        if not chunk or chunk == b"--":
            continue
        if b"\r\n\r\n" not in chunk:
            continue
        head, data = chunk.split(b"\r\n\r\n", 1)
        if data.endswith(b"\r\n"):
            data = data[:-2]
        headers = head.decode("utf-8", "replace")
        fn = re.search(r"filename\*=UTF-8''([^;\r\n]+)", headers) or re.search(
            r'filename="([^"]*)"', headers
        )
        nm = re.search(r'name="([^"]*)"', headers)
        if fn:
            name = unquote(fn.group(1))
            if name:
                files.append((name, data))
        elif nm:
            fields[nm.group(1)] = data.decode("utf-8", "replace")
    return fields, files


# ---------------------------------------------------------------- html
HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Bayan Wallpaper Dashboard</title>
<style>
  :root { --bg:#0f1115; --panel:#171a21; --card:#1d212b; --line:#2a2f3d; --tx:#e7eaf0;
          --dim:#93a0b4; --ac:#4f8cff; --ok:#2ecc71; --bad:#ff5c6c; }
  * { box-sizing:border-box }
  body { margin:0; background:var(--bg); color:var(--tx);
         font:14px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif }
  header { position:sticky; top:0; z-index:5; display:flex; gap:12px; align-items:center;
           flex-wrap:wrap; padding:12px 18px; background:#12151c; border-bottom:1px solid var(--line) }
  h1 { font-size:16px; margin:0 8px 0 0 }
  .pill { font-size:12px; padding:3px 10px; border-radius:999px; background:#232936; color:var(--dim) }
  .pill.ok { color:var(--ok) } .pill.bad { color:var(--bad) }
  button { background:var(--ac); color:#fff; border:0; border-radius:8px; padding:7px 13px;
           font-size:13px; cursor:pointer }
  button.ghost { background:#232936; color:var(--tx) }
  button.danger { background:#3a1d24; color:var(--bad) }
  button:hover { filter:brightness(1.12) }
  main { padding:18px; max-width:1500px; margin:0 auto }
  .hint { color:var(--dim); font-size:12.5px; margin:0 0 18px }
  .hint code { background:#1b1f29; padding:1px 6px; border-radius:5px }
  section.cat { background:var(--panel); border:1px solid var(--line); border-radius:14px;
                padding:14px; margin-bottom:22px }
  .cathead { display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin-bottom:12px }
  .cathead .badge { background:#232936; color:var(--dim); font-size:12px; padding:3px 9px;
                    border-radius:999px }
  input,select,textarea { background:#12151c; color:var(--tx); border:1px solid var(--line);
           border-radius:8px; padding:7px 9px; font-size:13px; font-family:inherit }
  input:focus,select:focus { outline:1px solid var(--ac) }
  input.ar,input.ur { direction:rtl }
  .cathead input { width:150px }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)); gap:14px }
  .card { background:var(--card); border:1px solid var(--line); border-radius:12px; overflow:hidden;
          display:flex; flex-direction:column }
  .card img { width:100%; aspect-ratio:16/10; object-fit:cover; background:#0b0d12; display:block }
  .card .body { padding:10px; display:flex; flex-direction:column; gap:7px }
  .card .file { color:var(--dim); font-size:11.5px; word-break:break-all }
  .card .row { display:flex; gap:6px; align-items:center }
  .card select { flex:1; min-width:0 }
  .card button { padding:5px 9px; font-size:13px; line-height:1 }
  .drop { border:1.5px dashed var(--line); border-radius:10px; color:var(--dim);
          text-align:center; padding:10px; font-size:12.5px; margin-top:12px; cursor:pointer }
  .drop.hot { border-color:var(--ac); color:var(--ac) }
  .empty { color:var(--dim); font-size:13px; padding:8px 2px }
  .modal { position:fixed; inset:0; background:rgba(0,0,0,.6); display:flex; align-items:center;
           justify-content:center; z-index:20 }
  .modal[hidden] { display:none }
  .sheet { width:min(560px,92vw); background:var(--panel); border:1px solid var(--line);
           border-radius:14px; padding:18px; display:flex; flex-direction:column; gap:10px }
  .sheet h2 { margin:0 0 4px; font-size:15px }
  .sheet label { font-size:12px; color:var(--dim) }
  .sheet .f { display:flex; flex-direction:column; gap:4px }
  .sheet input,.sheet select { width:100% }
  .zone { border:1.5px dashed var(--line); border-radius:10px; padding:16px; text-align:center;
          color:var(--dim); cursor:pointer }
  .zone.hot { border-color:var(--ac); color:var(--ac) }
  .sheet .acts { display:flex; gap:8px; justify-content:flex-end; margin-top:4px }
  .files { font-size:12px; color:var(--ok) }
  .sheet.wide { width:min(880px,94vw) }
  .aspects { display:flex; gap:6px; flex-wrap:wrap; position:relative; z-index:1 }
  .aspects button { padding:5px 11px; font-size:12.5px }
  .aspects button.sel { outline:2px solid var(--ok) }
  #cropStage { position:relative; display:block; text-align:center; background:#0b0d12;
               border:1px solid var(--line); border-radius:10px; padding:8px; overflow:auto }
  #cropWrap { position:relative; display:inline-block; max-width:100%; line-height:0 }
  #cropImg { display:block; max-width:100%; max-height:58vh;
             pointer-events:none; user-select:none }
  #cropBox { position:absolute; z-index:2; box-shadow:0 0 0 9999px rgba(0,0,0,.6);
             border:1.5px solid var(--ac); cursor:move; touch-action:none }
  #cropBox .h { position:absolute; width:14px; height:14px; background:var(--ac);
                border:2px solid #fff; border-radius:50%; touch-action:none }
  #cropBox .h.nw { left:-8px; top:-8px; cursor:nwse-resize }
  #cropBox .h.ne { right:-8px; top:-8px; cursor:nesw-resize }
  #cropBox .h.sw { left:-8px; bottom:-8px; cursor:nesw-resize }
  #cropBox .h.se { right:-8px; bottom:-8px; cursor:nwse-resize }
  .crdims { color:var(--dim); font-size:12px; text-align:center; position:relative; z-index:1 }
  .sheet .acts { position:relative; z-index:1 }
</style>
</head>
<body>
<header>
  <h1>🕌 Bayan Wallpaper Dashboard</h1>
  <span id="status" class="pill">loading…</span>
  <button id="addBtn">+ Add images</button>
  <button id="catBtn" class="ghost">+ Category</button>
  <button id="optBtn" class="ghost">Optimize sizes</button>
  <button id="reloadBtn" class="ghost">Reload from disk</button>
</header>
<main>
  <p class="hint">Edits auto-save to <b>/home/hamzah/develop/portfolio</b> (images + <code>bayan/wallpapers.json</code>).
  Nothing is pushed. When finished, tell the assistant to review and deploy.</p>
  <div id="app"></div>
</main>

<div class="modal" id="modal" hidden>
  <div class="sheet">
    <h2>Add images</h2>
    <div class="zone" id="zone">Drop images here, click to browse,<br>or paste with <b>Ctrl+V</b></div>
    <div class="files" id="files"></div>
    <input type="file" id="file" accept="image/*" multiple hidden>
    <div class="f"><label>or image URL</label><input id="url" placeholder="https://…"></div>
    <div class="f"><label>Category</label><select id="mcat"></select></div>
    <div class="f"><label>Title (blank = from filename)</label><input id="mtitle" placeholder="Kaaba at Night"></div>
    <div class="f"><label>Title Arabic</label><input id="mtitlear" class="ar" dir="rtl" placeholder="الكعبة ليلاً"></div>
    <div class="f"><label>Title Urdu</label><input id="mtitleur" class="ur" dir="rtl" placeholder="رات کاکعبہ"></div>
    <div class="acts">
      <button class="ghost" id="cancel">Cancel</button>
      <button id="go">Add</button>
    </div>
  </div>
</div>

<div class="modal" id="cropModal" hidden>
  <div class="sheet wide">
    <h2>✂ Crop <span id="cropName"></span></h2>
    <div class="aspects">
      <button data-ar="" class="sel">Free</button>
      <button data-ar="16:9">16:9</button>
      <button data-ar="9:16">9:16</button>
      <button data-ar="1:1">1:1</button>
      <button data-ar="orig">Original</button>
    </div>
    <div id="cropStage">
      <div id="cropWrap">
        <img id="cropImg" alt="">
        <div id="cropBox">
          <i class="h nw" data-d="nw"></i><i class="h ne" data-d="ne"></i>
          <i class="h sw" data-d="sw"></i><i class="h se" data-d="se"></i>
        </div>
      </div>
    </div>
    <div class="crdims" id="cropDims"></div>
    <div class="acts">
      <button class="ghost" id="cropCancel">Cancel</button>
      <button id="cropApply">Apply crop</button>
    </div>
  </div>
</div>

<script>
const $=s=>document.querySelector(s);
const esc=s=>(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let state=null,timer=null,pending=[];

function setStatus(t,cls){const e=$('#status');e.textContent=t;e.className='pill '+(cls||'');}

async function load(){
  try{
    const r=await fetch('/api/state');
    state=await r.json();
    render();
    setStatus('Loaded '+state.categories.reduce((n,c)=>n+c.images.length,0)+' images','ok');
    if(location.hash==='#crop'){
      const c=state.categories.find(x=>x.images.length);
      if(c){openCrop(c.id,c.images[0]);history.replaceState(null,'',location.pathname);}
    }
  }catch(e){setStatus('Load failed: '+e.message,'bad');}
}
function schedule(){
  clearTimeout(timer);
  setStatus('saving…');
  timer=setTimeout(save,350);
}
async function save(){
  try{
    const r=await fetch('/api/save',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify(state)});
    const j=await r.json().catch(()=>({}));
    if(!r.ok) throw new Error(j.error||r.statusText);
    setStatus('Saved ✓ '+new Date().toLocaleTimeString(),'ok');
  }catch(e){
    setStatus('Error: '+e.message,'bad');
    if(confirm('Save failed ('+e.message+'). Reload last saved state from disk?')) load();
  }
}
function render(){
  const app=$('#app');
  app.innerHTML=state.categories.map(c=>{
    const cards=c.images.map((im,i)=>`
      <div class="card" data-id="${esc(im.id)}">
        <img loading="lazy" src="/bayan/wallpapers/${encodeURIComponent(c.id)}/${encodeURIComponent(im.file)}">
        <div class="body">
          <span class="file">${esc(im.file)} · <b>${esc(im.id)}</b></span>
          <input data-f="title" value="${esc(im.title)}" placeholder="Title" title="English">
          <input data-f="title_ar" class="ar" dir="rtl" value="${esc(im.title_ar)}" placeholder="العنوان بالعربية">
          <input data-f="title_ur" class="ur" dir="rtl" value="${esc(im.title_ur)}" placeholder="اردو عنوان">
          <div class="row">
            <select data-move>${state.categories.map(o=>
              `<option value="${esc(o.id)}"${o.id===c.id?' selected':''}>${esc(o.name)}</option>`).join('')}</select>
            <button data-act="up" title="Move up">↑</button>
            <button data-act="down" title="Move down">↓</button>
            <button data-act="crop" title="Crop">✂</button>
            <button data-act="del" class="danger" title="Delete">✕</button>
          </div>
        </div>
      </div>`).join('');
    return `<section class="cat" data-cat="${esc(c.id)}">
      <div class="cathead">
        <span class="badge">${esc(c.id)}</span>
        <input data-cf="name" value="${esc(c.name)}" placeholder="Name (en)">
        <input data-cf="name_ar" class="ar" dir="rtl" value="${esc(c.name_ar)}" placeholder="الاسم">
        <input data-cf="name_ur" class="ur" dir="rtl" value="${esc(c.name_ur)}" placeholder="اردو نام">
        <span class="badge">${c.images.length}</span>
      </div>
      <div class="grid">${cards||'<div class="empty">No images</div>'}</div>
      <div class="drop" data-drop="${esc(c.id)}">Drop images here to add to “${esc(c.name)}”</div>
    </section>`;
  }).join('');
}

function find(id){for(const c of state.categories){const i=c.images.findIndex(x=>x.id===id);
  if(i>=0)return{c,i,rec:c.images[i]};}return null;}

$('#app').addEventListener('input',e=>{
  const card=e.target.closest('.card');
  if(e.target.dataset.f&&card){find(card.dataset.id).rec[e.target.dataset.f]=e.target.value;schedule();}
  if(e.target.dataset.cf){const c=state.categories.find(x=>x.id===e.target.closest('.cat').dataset.cat);
    c[e.target.dataset.cf]=e.target.value;schedule();}
});
$('#app').addEventListener('change',e=>{
  if(!e.target.matches('select[data-move]'))return;
  const card=e.target.closest('.card'),f=find(card.dataset.id),to=e.target.value;
  if(f.c.id===to)return;
  f.c.images.splice(f.i,1);
  state.categories.find(x=>x.id===to).images.push(f.rec);
  render();schedule();
});
$('#app').addEventListener('click',e=>{
  const b=e.target.closest('button[data-act]');if(!b)return;
  const f=find(e.target.closest('.card').dataset.id);
  if(b.dataset.act==='crop'){openCrop(f.c.id,f.rec);return;}
  if(b.dataset.act==='up'&&f.i>0){const a=f.c.images;[a[f.i-1],a[f.i]]=[a[f.i],a[f.i-1]];}
  if(b.dataset.act==='down'&&f.i<f.c.images.length-1){const a=f.c.images;[a[f.i+1],a[f.i]]=[a[f.i],a[f.i+1]];}
  if(b.dataset.act==='del'){
    if(!confirm('Delete '+f.rec.file+' ? (git can restore it later)'))return;
    f.c.images.splice(f.i,1);
  }
  render();schedule();
});
$('#app').addEventListener('dragover',e=>{const d=e.target.closest('[data-drop]');if(d){e.preventDefault();d.classList.add('hot');}});
$('#app').addEventListener('dragleave',e=>{const d=e.target.closest('[data-drop]');if(d)d.classList.remove('hot');});
$('#app').addEventListener('drop',e=>{const d=e.target.closest('[data-drop]');if(!d)return;
  e.preventDefault();d.classList.remove('hot');openModal([...e.dataTransfer.files],d.dataset.drop);});

$('#catBtn').onclick=()=>{
  const n=prompt('New category name (English):');if(!n)return;
  const id=n.toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/^_|_$/g,'');
  if(!id||state.categories.some(c=>c.id===id))return alert('Invalid or duplicate id');
  state.categories.push({id,name:n,name_ar:'',name_ur:'',images:[]});
  render();schedule();
};
$('#optBtn').onclick=async()=>{
  if(!confirm('Re-compress images wider than 1080px or bigger than 400KB?'))return;
  setStatus('optimizing…');
  try{
    const r=await fetch('/api/optimize',{method:'POST'});
    const j=await r.json();
    if(!r.ok)throw new Error(j.error||r.statusText);
    alert(j.changed.length?j.changed.join('\n')+'\n\nsaved ~'+j.saved_kb+' KB':'Nothing to optimize');
    setStatus('Optimize done','ok');
  }catch(e){setStatus('Error: '+e.message,'bad');}
};
$('#reloadBtn').onclick=()=>{if(confirm('Discard unsaved changes and reload from disk?'))load();};

function openModal(files,cats){
  pending=files||[];
  $('#files').textContent=pending.length?pending.length+' image(s) selected':'';
  $('#mcat').innerHTML=state.categories.map(c=>`<option value="${esc(c.id)}"${
    (cats&&cats===c.id)?' selected':''}>${esc(c.name)}</option>`).join('');
  if(cats)$('#mcat').value=cats;
  $('#url').value='';$('#mtitle').value='';$('#mtitlear').value='';$('#mtitleur').value='';
  $('#modal').hidden=false;
}
$('#addBtn').onclick=()=>openModal([],'');
$('#cancel').onclick=()=>$('#modal').hidden=true;
$('#zone').onclick=()=>$('#file').click();
$('#file').onchange=e=>{pending=[...e.target.files];$('#files').textContent=pending.length+' image(s) selected';};
$('#zone').addEventListener('dragover',e=>{e.preventDefault();$('#zone').classList.add('hot');});
$('#zone').addEventListener('dragleave',()=>$('#zone').classList.remove('hot'));
$('#zone').addEventListener('drop',e=>{e.preventDefault();$('#zone').classList.remove('hot');
  pending=[...e.dataTransfer.files];$('#files').textContent=pending.length+' image(s) selected';});
document.addEventListener('paste',e=>{
  const fs=[...(e.clipboardData?.items||[])].filter(i=>i.type.startsWith('image/'))
    .map(i=>i.getAsFile()).filter(Boolean);
  if(fs.length){e.preventDefault();openModal(fs,'');}
});
$('#go').onclick=async()=>{
  const btn=$('#go');btn.disabled=true;btn.textContent='Uploading…';
  try{
    const fd=new FormData();
    pending.forEach(f=>fd.append('files',f,f.name));
    if($('#url').value.trim())fd.append('url',$('#url').value.trim());
    fd.append('category',$('#mcat').value);
    fd.append('title',$('#mtitle').value);
    fd.append('title_ar',$('#mtitlear').value);
    fd.append('title_ur',$('#mtitleur').value);
    const r=await fetch('/api/upload',{method:'POST',body:fd});
    const j=await r.json().catch(()=>({}));
    if(!r.ok)throw new Error(j.error||r.statusText);
    $('#modal').hidden=true;
    await load();
    setStatus('Added '+j.added.length+' image(s)','ok');
  }catch(e){alert('Upload failed: '+e.message);setStatus('Error: '+e.message,'bad');}
  btn.disabled=false;btn.textContent='Add';
};
// ---------------- crop tool
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const CR={cat:'',file:'',id:'',ratio:null,origRatio:null,box:{x:0,y:0,w:0,h:0},
          nat:{w:0,h:0},disp:{w:0,h:0},drag:null};
const cImg=$('#cropImg'),cBox=$('#cropBox'),cModal=$('#cropModal'),cWrap=$('#cropWrap');

function crRender(){
  const b=CR.box;
  cBox.style.left=b.x+'px'; cBox.style.top=b.y+'px';
  cBox.style.width=b.w+'px'; cBox.style.height=b.h+'px';
  const r=CR.disp.w?CR.nat.w/CR.disp.w:1;
  $('#cropDims').textContent='crop '+Math.round(b.w*r)+' × '+Math.round(b.h*r)+
    '  (original '+CR.nat.w+' × '+CR.nat.h+')';
}
function openCrop(cat,im){
  CR.cat=cat;CR.file=im.file;CR.id=im.id;CR.ratio=null;CR.drag=null;
  $('#cropName').textContent=im.file;
  document.querySelectorAll('.aspects button').forEach(b=>b.classList.toggle('sel',b.dataset.ar===''));
  cModal.hidden=false;
  cImg.onload=()=>{
    CR.nat={w:cImg.naturalWidth,h:cImg.naturalHeight};
    const r=cWrap.getBoundingClientRect();
    CR.disp={w:r.width,h:r.height};
    CR.origRatio=CR.nat.w/CR.nat.h;
    CR.box={x:r.width*.05,y:r.height*.05,w:r.width*.9,h:r.height*.9};
    crRender();
  };
  cImg.src='/bayan/wallpapers/'+encodeURIComponent(cat)+'/'+encodeURIComponent(im.file)+'?t='+Date.now();
}
document.querySelector('.aspects').addEventListener('click',e=>{
  const b=e.target.closest('button');if(!b)return;
  document.querySelectorAll('.aspects button').forEach(x=>x.classList.toggle('sel',x===b));
  const v=b.dataset.ar;
  CR.ratio = v===''?null : v==='orig'?CR.origRatio :
             (()=>{const[a,z]=v.split(':').map(Number);return a/z;})();
  if(CR.ratio){
    let w=CR.box.w,h=w/CR.ratio;
    if(h>CR.disp.h){h=CR.disp.h;w=h*CR.ratio;}
    if(w>CR.disp.w){w=CR.disp.w;h=w/CR.ratio;}
    CR.box={x:clamp(CR.box.x,0,CR.disp.w-w),y:clamp(CR.box.y,0,CR.disp.h-h),w,h};
    crRender();
  }
});
cBox.addEventListener('pointerdown',e=>{
  e.preventDefault();
  CR.drag={mode:e.target.dataset.d||'move',sx:e.clientX,sy:e.clientY,box:{...CR.box}};
  cBox.setPointerCapture(e.pointerId);
});
cBox.addEventListener('pointermove',e=>{
  if(!CR.drag)return;
  const d=CR.drag,dx=e.clientX-d.sx,dy=e.clientY-d.sy,M=CR.disp;
  if(d.mode==='move'){
    CR.box={...d.box,x:clamp(d.box.x+dx,0,M.w-d.box.w),y:clamp(d.box.y+dy,0,M.h-d.box.h)};
    crRender();return;
  }
  let x1=d.box.x,y1=d.box.y,x2=d.box.x+d.box.w,y2=d.box.y+d.box.h;
  if(d.mode.includes('w'))x1=clamp(d.box.x+dx,0,x2-24);
  if(d.mode.includes('e'))x2=clamp(d.box.x+d.box.w+dx,x1+24,M.w);
  if(d.mode.includes('n'))y1=clamp(d.box.y+dy,0,y2-24);
  if(d.mode.includes('s'))y2=clamp(d.box.y+d.box.h+dy,y1+24,M.h);
  if(CR.ratio){
    const west=d.mode.includes('w'),north=d.mode.includes('n'),
          pureV=d.mode==='n'||d.mode==='s';
    let w,h;
    if(pureV){h=y2-y1;w=h*CR.ratio;}else{w=x2-x1;h=w/CR.ratio;}
    if(pureV){
      const cx=(x1+x2)/2;
      if(w>M.w){w=M.w;h=w/CR.ratio;}
      x1=clamp(cx-w/2,0,M.w-w);x2=x1+w;
    }else{
      const fx=west?x2:x1,maxW=west?fx:M.w-fx;
      if(w>maxW){w=maxW;h=w/CR.ratio;}
      if(w<24){w=24;h=w/CR.ratio;}
      x1=west?fx-w:fx;x2=x1+w;
    }
    const fy=north?y2:y1,maxH=north?fy:M.h-fy;
    if(h>maxH){h=maxH;w=h*CR.ratio;}
    if(h<24){h=24;w=h*CR.ratio;}
    y1=north?fy-h:fy;y2=y1+h;
    if(x1<0){x1=0;x2=w;} if(y1<0){y1=0;y2=h;}
  }
  CR.box={x:x1,y:y1,w:x2-x1,h:y2-y1};
  crRender();
});
cBox.addEventListener('pointerup',()=>{if(CR.drag)CR.drag=null;});

// drag on the image to draw a new selection
cWrap.addEventListener('pointerdown',e=>{
  if(e.target.closest('#cropBox'))return;
  e.preventDefault();
  const r=cWrap.getBoundingClientRect();
  CR.drag={mode:'draw',x0:e.clientX-r.left,y0:e.clientY-r.top,box:{...CR.box}};
  cWrap.setPointerCapture(e.pointerId);
});
cWrap.addEventListener('pointermove',e=>{
  if(!CR.drag||CR.drag.mode!=='draw')return;
  const d=CR.drag,M=CR.disp,r=cWrap.getBoundingClientRect();
  const x=clamp(e.clientX-r.left,0,M.w),y=clamp(e.clientY-r.top,0,M.h);
  let x1=Math.min(d.x0,x),x2=Math.max(d.x0,x),y1=Math.min(d.y0,y),y2=Math.max(d.y0,y);
  if(CR.ratio){
    const dirX=x>=d.x0?1:-1,dirY=y>=d.y0?1:-1;
    let w=Math.abs(x-d.x0),h=Math.abs(y-d.y0);
    if(w/CR.ratio>=h){h=w/CR.ratio;}else{w=h*CR.ratio;}
    const aW=dirX>0?M.w-d.x0:d.x0,aH=dirY>0?M.h-d.y0:d.y0;
    if(w>aW){w=aW;h=w/CR.ratio;}
    if(h>aH){h=aH;w=h*CR.ratio;}
    x1=dirX>0?d.x0:d.x0-w;x2=x1+w;
    y1=dirY>0?d.y0:d.y0-h;y2=y1+h;
  }else if(x2-x1<8||y2-y1<8){return;}
  CR.box={x:x1,y:y1,w:x2-x1,h:y2-y1};
  crRender();
});
function crEndDraw(){
  if(CR.drag&&CR.drag.mode==='draw'){
    if(CR.box.w<16||CR.box.h<16)CR.box=CR.drag.box;  // ignore stray clicks
    crRender();
  }
  CR.drag=null;
}
cWrap.addEventListener('pointerup',crEndDraw);
cWrap.addEventListener('pointercancel',crEndDraw);
$('#cropCancel').onclick=()=>{cModal.hidden=true;};
$('#cropApply').onclick=()=>{
  const r=CR.disp.w?CR.nat.w/CR.disp.w:1;
  const sx=Math.round(CR.box.x*r),sy=Math.round(CR.box.y*r),
        sw=Math.max(1,Math.round(CR.box.w*r)),sh=Math.max(1,Math.round(CR.box.h*r));
  const c=document.createElement('canvas');c.width=sw;c.height=sh;
  const g=c.getContext('2d');
  g.fillStyle='#fff';g.fillRect(0,0,sw,sh);
  g.drawImage(cImg,sx,sy,sw,sh,0,0,sw,sh);
  c.toBlob(async b=>{
    if(!b)return alert('canvas export failed');
    const fd=new FormData();
    fd.append('category',CR.cat);fd.append('file',CR.file);
    fd.append('image',b,'crop.jpg');
    setStatus('cropping…');
    try{
      const resp=await fetch('/api/replace',{method:'POST',body:fd});
      const j=await resp.json().catch(()=>({}));
      if(!resp.ok)throw new Error(j.error||resp.statusText);
      cModal.hidden=true;
      await load();
      setStatus('Cropped '+CR.file+' ✓','ok');
    }catch(e){setStatus('Error: '+e.message,'bad');alert('Crop failed: '+e.message);}
  },'image/jpeg',0.92);
};

load();
</script>
</body>
</html>
"""


# ---------------------------------------------------------------- http
class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # quieter console
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > MAX_UPLOAD + 1_000_000:
            raise ValueError("payload too large")
        return self.rfile.read(n)

    def do_GET(self):
        path = urlparse(self.path).path
        if path in ("/", "/index.html"):
            body = HTML.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        if path == "/api/state":
            try:
                self._json(build_state())
            except Exception as e:  # noqa: BLE001
                self._json({"error": str(e)}, 500)
            return
        self._static(path)

    def _static(self, path):
        rel = unquote(path).lstrip("/")
        target = (ROOT / rel).resolve()
        if not str(target).startswith(str(ROOT.resolve())) or not target.is_file():
            self.send_error(404)
            return
        ctype = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        data = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            if path == "/api/save":
                state = json.loads(self._body().decode("utf-8"))
                with LOCK:
                    apply_state(state)
                self._json({"ok": True})
            elif path == "/api/upload":
                ctype = self.headers.get("Content-Type", "")
                fields, files = parse_multipart(self._body(), ctype)
                self._json(handle_upload(fields, files))
            elif path == "/api/replace":
                ctype = self.headers.get("Content-Type", "")
                fields, files = parse_multipart(self._body(), ctype)
                self._json(handle_replace(fields, files))
            elif path == "/api/optimize":
                self._json(handle_optimize())
            else:
                self._json({"error": "not found"}, 404)
        except json.JSONDecodeError as e:
            self._json({"error": f"bad json: {e}"}, 400)
        except ValueError as e:
            self._json({"error": str(e)}, 400)
        except Exception as e:  # noqa: BLE001
            self._json({"error": f"{type(e).__name__}: {e}"}, 500)


def main():
    global ROOT, IMAGES, JSONF
    ap = argparse.ArgumentParser(description="Bayan wallpaper dashboard")
    ap.add_argument("--root", default=str(ROOT), help="portfolio repo root")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-browser", action="store_true", help="don't open a browser tab")
    args = ap.parse_args()
    ROOT = Path(args.root).resolve()
    IMAGES = ROOT / "bayan" / "wallpapers"
    JSONF = ROOT / "bayan" / "wallpapers.json"
    if not IMAGES.exists():
        raise SystemExit(f"images folder not found: {IMAGES}")

    url = f"http://127.0.0.1:{args.port}"
    print(f"Bayan wallpaper dashboard → {url}")
    print(f"  root: {ROOT}")
    if not args.no_browser:
        try:
            import webbrowser

            webbrowser.open(url)
        except Exception:  # noqa: BLE001
            pass
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
