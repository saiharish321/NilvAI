"""Score OCR output against hand-typed labels. Compare several models in one table.

    python eval.py labels.csv qwen3vl4b.json qwen25vl7b.json numbers_only.json

labels.csv columns: file,line,item_te,item_en,qty_value,qty_unit,amount
(one row per receipt line, typed by hand from the photo).

Each line in the table for the report:
  line recall   share of true lines the model found
  amount acc    share of true lines whose rupee amount was read exactly (within Rs 0.5)
  qty acc       share of true lines whose quantity and unit were read correctly
  item sim      mean similarity of Telugu item text (0-100, rapidfuzz ratio)
  extra lines   lines the model invented, per receipt
  total match   share of receipts where the line amounts add up to the true total (within Rs 1)
  sec/receipt   mean model time per receipt
Item-to-catalogue match accuracy comes from the app's ocr_corrections.csv export (top_correct column).
"""
import csv
import json
import statistics
import sys
from collections import defaultdict

from rapidfuzz import fuzz

UNIT = {"kg": ("m", 1), "g": ("m", 0.001), "l": ("v", 1), "ml": ("v", 0.001)}


def base(v, u):
    d, k = UNIT.get((u or "").lower(), ("c", 1))
    return d, round(float(v or 0) * k, 4)


def align(truth, pred):
    """Greedy: pair each true line with the unused predicted line of best score (amount first, then text)."""
    used, pairs = set(), []
    for t in truth:
        best, bs = None, -1
        for j, p in enumerate(pred):
            if j in used:
                continue
            s = (60 if abs(p["amount"] - t["amount"]) < 0.5 else 0) + 0.4 * fuzz.ratio(p["item_text"], t["item_te"])
            if s > bs:
                best, bs = j, s
        if best is not None and bs >= 30:
            used.add(best)
            pairs.append((t, pred[best]))
        else:
            pairs.append((t, None))
    return pairs, len(pred) - len(used)


def main(labels_path, *result_paths):
    truth = defaultdict(list)
    for r in csv.DictReader(open(labels_path, encoding="utf-8-sig")):
        r["amount"] = float(r["amount"] or 0)
        truth[r["file"]].append(r)

    print("| model | mode | receipts | line recall | amount acc | qty acc | item sim | extra lines | total match | sec/receipt |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for path in result_paths:
        res = json.load(open(path, encoding="utf-8"))
        by_file = {r["file"]: r for r in res["receipts"]}
        n_true = found = amt = qty = 0
        sims, extras, totals, secs = [], [], [], []
        for f, tl in truth.items():
            r = by_file.get(f)
            if not r:
                continue
            pairs, extra = align(tl, r["lines"])
            extras.append(extra)
            secs.append(r.get("seconds", 0))
            for t, p in pairs:
                n_true += 1
                if p is None:
                    continue
                found += 1
                amt += abs(p["amount"] - t["amount"]) < 0.5
                qty += base(p["qty_value"], p["qty_unit"]) == base(t["qty_value"], t["qty_unit"])
                if t["item_te"]:
                    sims.append(fuzz.ratio(p["item_text"], t["item_te"]))
            totals.append(abs(sum(p["amount"] for p in r["lines"]) - sum(t["amount"] for t in tl)) < 1)
        if not n_true:
            print(f"| {path} | – | 0 | no labelled receipts matched |")
            continue
        pc = lambda x: f"{100 * x / n_true:.0f}%"
        print(f"| {res.get('model')} | {res.get('mode')} | {len(totals)} | {pc(found)} | {pc(amt)} | {pc(qty)} | "
              f"{statistics.mean(sims) if sims else 0:.0f} | {statistics.mean(extras):.1f} | "
              f"{100 * sum(totals) / len(totals):.0f}% | {statistics.mean(secs):.1f} |")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
