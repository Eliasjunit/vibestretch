#!/usr/bin/env python3
"""Check one translation against the English source: python3 site-src/check_translation.py de"""
import json, re, sys
from pathlib import Path
d = Path(__file__).resolve().parent / "content"
en = json.loads((d / "en.json").read_text(encoding="utf-8"))
errors = []
for code in sys.argv[1:]:
    raw = (d / f"{code}.json").read_text(encoding="utf-8")
    t = json.loads(raw)
    if chr(0x2014) in raw: errors.append(f"{code}: contains an em dash")
    if set(t["ui"]) != set(en["ui"]): errors.append(f"{code}: ui keys differ")
    if set(t["pages"]) != set(en["pages"]): errors.append(f"{code}: page keys differ")
    if set(t["settings_rows"]) != set(en["settings_rows"]): errors.append(f"{code}: settings_rows differ")
    if len(t["settings_head"]) != 3: errors.append(f"{code}: settings_head needs 3 items")
    for slug, e in en["pages"].items():
        p = t["pages"].get(slug, {})
        for k in ("nav", "title", "description", "h1", "lead"):
            if not p.get(k): errors.append(f"{code}/{slug}: missing {k}")
        if len(p.get("blocks", [])) != len(e["blocks"]): errors.append(f"{code}/{slug}: block count differs"); continue
        for b, eb in zip(p["blocks"], e["blocks"]):
            if set(b) != set(eb): errors.append(f"{code}/{slug}: block type differs {list(b)} vs {list(eb)}")
            elif "code" in b and b["code"] != eb["code"]: errors.append(f"{code}/{slug}: code key changed")
            elif "table" in b and b["table"] != eb["table"]: errors.append(f"{code}/{slug}: table key changed")
            for k in ("ul", "ol"):
                if k in b and len(b[k]) != len(eb[k]): errors.append(f"{code}/{slug}: {k} length differs")
            for k in ("p", "h2"):
                if k in b and sorted(re.findall(r"\(@([a-z0-9-]+)\)", b[k])) != sorted(re.findall(r"\(@([a-z0-9-]+)\)", eb[k])):
                    errors.append(f"{code}/{slug}: internal links differ in {k}")
        if len(p.get("faq", [])) != len(e.get("faq", [])): errors.append(f"{code}/{slug}: faq count differs")
    titles = [p["title"] for p in t["pages"].values()]; descs = [p["description"] for p in t["pages"].values()]
    if len(set(titles)) != len(titles) or len(set(descs)) != len(descs): errors.append(f"{code}: titles or descriptions not unique")
print("\n".join(errors) if errors else "OK " + " ".join(sys.argv[1:]))
sys.exit(1 if errors else 0)
