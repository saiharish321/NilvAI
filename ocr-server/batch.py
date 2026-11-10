"""Read a folder of receipt photos and write results.json for the app's "Import results file".

    python batch.py photos/ --out results.json [--mode numbers] [--model qwen2.5vl:7b]

Use this when the phone cannot reach the laptop: the owner shares photos over WhatsApp,
you run this, and send results.json back.
"""
import argparse
import json
import pathlib
import sys

import ocr_core

ap = argparse.ArgumentParser()
ap.add_argument("folder")
ap.add_argument("--out", default="results.json")
ap.add_argument("--mode", default="full", choices=["full", "numbers"])
ap.add_argument("--model", default=None)
a = ap.parse_args()

files = sorted(p for p in pathlib.Path(a.folder).iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"})
receipts = []
for i, p in enumerate(files, 1):
    try:
        r = ocr_core.extract(p.read_bytes(), a.mode, a.model)
        r["file"] = p.name
        receipts.append(r)
        print(f"[{i}/{len(files)}] {p.name}: {len(r['lines'])} lines, {r['seconds']}s", file=sys.stderr)
    except Exception as e:
        print(f"[{i}/{len(files)}] {p.name}: FAILED {e}", file=sys.stderr)
        receipts.append({"file": p.name, "lines": [], "error": str(e)})

json.dump({"model": a.model or ocr_core.MODEL, "mode": a.mode, "receipts": receipts},
          open(a.out, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"wrote {a.out}", file=sys.stderr)
