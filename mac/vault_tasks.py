#!/usr/bin/env python3
"""Đọc việc cần làm trong vault Obsidian, in ra JSON để gửi lên Apps Script.

Quy ước (CLAUDE.md mục 10 của vault):
    - [ ] Nội dung việc [due:: YYYY-MM-DD] [time:: HH:MM]
Hạn chót của dự án lấy từ property `due` trong frontmatter (type: project).
Bỏ qua: khối code, thư mục hệ thống/lưu trữ, note có status paused/done/archived.

Cách dùng:  python3 vault_tasks.py <đường-dẫn-vault>
"""
import json
import re
import sys
from datetime import datetime
from pathlib import Path

SKIP_DIRS = {".obsidian", ".trash", ".git", "90-system", "99-archive"}
SKIP_STATUS = {"paused", "done", "archived"}
MAX_TASKS = 30      # Apps Script chỉ lưu được khoảng 9 KB mỗi mục
MAX_TITLE = 80

TASK = re.compile(r"^\s*[-*+] \[ \] (.+?)\s*$")
DUE = re.compile(r"\[due::\s*(\d{4}-\d{2}-\d{2})\s*\]")
TIME = re.compile(r"\[time::\s*(\d{1,2}:\d{2})\s*\]")
FIELD = re.compile(r"\[[A-Za-z_]+::[^\]]*\]")
WIKI = re.compile(r"\[\[(?:[^\]|]*\|)?([^\]]+)\]\]")
MDLINK = re.compile(r"\[([^\]]+)\]\([^)]*\)")


def frontmatter(lines):
    """→ (dict các property đơn giản, chỉ số dòng bắt đầu nội dung)"""
    if not lines or lines[0].strip() != "---":
        return {}, 0
    meta = {}
    for i, line in enumerate(lines[1:], 1):
        if line.strip() == "---":
            return meta, i + 1
        if ":" in line and not line.startswith((" ", "\t", "-")):
            k, v = line.split(":", 1)
            meta[k.strip()] = v.strip().strip("\"'")
    return {}, 0


def clean(text):
    text = FIELD.sub("", text)
    text = WIKI.sub(r"\1", text)
    text = MDLINK.sub(r"\1", text)
    text = re.sub(r"[*_`]", "", text)
    text = re.sub(r"\s+", " ", text).strip(" .:-")
    return text if len(text) <= MAX_TITLE else text[:MAX_TITLE - 1].rstrip() + "…"


def collect(vault: Path):
    tasks = []
    for p in sorted(vault.rglob("*.md")):
        rel = p.relative_to(vault)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        try:
            lines = p.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        meta, body = frontmatter(lines)
        if meta.get("status", "").lower() in SKIP_STATUS:
            continue
        try:
            prio = int(meta.get("priority") or 2)
        except ValueError:
            prio = 2
        if meta.get("type") == "project" and re.fullmatch(r"\d{4}-\d{2}-\d{2}", meta.get("due", "")):
            tasks.append({"title": clean("Hạn dự án: " + p.stem), "due": meta["due"], "list": p.stem, "prio": 0})
        in_code = False
        for line in lines[body:]:
            if line.lstrip().startswith(("```", "~~~")):
                in_code = not in_code
                continue
            if in_code:
                continue
            m = TASK.match(line)
            if not m:
                continue
            raw = m.group(1)
            title = clean(raw)
            if not title:
                continue
            t = {"title": title, "list": p.stem, "prio": prio}
            due, tm = DUE.search(raw), TIME.search(raw)
            if due:
                t["due"] = due.group(1)
            if tm:
                t["time"] = tm.group(1).zfill(5)
            tasks.append(t)
    # việc có hạn trước (hạn gần nhất trước), rồi việc chưa có hạn theo ưu tiên của note
    tasks.sort(key=lambda t: (t.get("due") is None, t.get("due") or "", t.get("time") or "99:99", t["prio"], t["title"].lower()))
    total = len(tasks)
    dated = sum(1 for t in tasks if t.get("due"))
    for t in tasks:
        t.pop("prio", None)
    return {"tasks": tasks[:MAX_TASKS], "total": total, "dated": dated,
            "read_at": datetime.now().astimezone().isoformat(timespec="seconds")}


if __name__ == "__main__":
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_dir():
        sys.exit("Cách dùng: python3 vault_tasks.py <đường-dẫn-vault>")
    json.dump(collect(Path(sys.argv[1])), sys.stdout, ensure_ascii=False)
