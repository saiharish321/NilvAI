"""Receipt extraction with an open-weights vision model served by Ollama.

Shared by server.py (phone sends photos) and batch.py (a folder of photos -> results.json).
"""
import base64
import io
import json
import os
import re
import time

import httpx
from PIL import Image, ImageOps

OLLAMA = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
MODEL = os.environ.get("OCR_MODEL", "qwen3-vl:4b")
MAX_SIDE = int(os.environ.get("OCR_MAX_SIDE", "1600"))

SCHEMA = {
    "type": "object",
    "properties": {
        "lines": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "item_text": {"type": "string"},
                    "item_en": {"type": "string"},
                    "qty_value": {"type": "number"},
                    "qty_unit": {"type": "string"},
                    "amount": {"type": "number"},
                },
                "required": ["item_text", "qty_value", "qty_unit", "amount"],
            },
        },
        "total": {"type": ["number", "null"]},
    },
    "required": ["lines"],
}

PROMPT_FULL = """This is a handwritten bill from a small grocery shop in Andhra Pradesh, India.
Item names are mostly in Telugu script. Each line has an item, a quantity and an amount in rupees.
Read every item line, top to bottom. For each line return:
- item_text: the item name exactly as written (Telugu script if written in Telugu)
- item_en: your best English name for the grocery item (e.g. toor dal, sugar, sunflower oil), or "" if unsure
- qty_value: the number in the quantity (e.g. 250 for "250 గ్రా", 2 for "2 కి", 1 if no quantity is written)
- qty_unit: one of kg, g, l, ml, pcs (కి/కిలో = kg, గ్రా = g, లీ = l)
- amount: the rupee amount for that line, as a number
Also return total if a total is written at the bottom, else null.
Do not invent lines. Skip dates, shop names and signatures. Return JSON only."""

PROMPT_NUMBERS = """This is a handwritten bill from a small grocery shop. Ignore the item names.
For every item line, top to bottom, return qty_value, qty_unit (kg, g, l, ml or pcs) and amount (rupees).
Set item_text and item_en to "". Return total if written, else null. Return JSON only."""


def prepare(image_bytes: bytes) -> str:
    img = ImageOps.exif_transpose(Image.open(io.BytesIO(image_bytes))).convert("RGB")
    img.thumbnail((MAX_SIDE, MAX_SIDE))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=88)
    return base64.b64encode(buf.getvalue()).decode()


def parse(text: str) -> dict:
    text = re.sub(r"<think>.*?</think>", "", text, flags=re.S)
    text = text.replace("```json", "").replace("```", "").strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", text, flags=re.S)
        data = json.loads(m.group(0)) if m else {"lines": []}
    lines = []
    for l in data.get("lines", []):
        lines.append({
            "item_text": str(l.get("item_text", "")).strip(),
            "item_en": str(l.get("item_en", "")).strip(),
            "qty_value": _num(l.get("qty_value")),
            "qty_unit": str(l.get("qty_unit", "")).strip().lower(),
            "amount": _num(l.get("amount")),
        })
    return {"lines": lines, "total": _num(data.get("total")) if data.get("total") is not None else None}


def _num(v):
    try:
        return float(str(v).replace(",", "").replace("₹", "").strip())
    except (TypeError, ValueError):
        return 0.0


def extract(image_bytes: bytes, mode: str = "full", model: str | None = None) -> dict:
    model = model or MODEL
    t0 = time.time()
    payload = {
        "model": model,
        "stream": False,
        "format": SCHEMA,
        "options": {"temperature": 0, "num_ctx": 8192},
        "messages": [{
            "role": "user",
            "content": PROMPT_NUMBERS if mode == "numbers" else PROMPT_FULL,
            "images": [prepare(image_bytes)],
        }],
    }
    r = httpx.post(f"{OLLAMA}/api/chat", json=payload, timeout=600)
    r.raise_for_status()
    out = parse(r.json()["message"]["content"])
    out.update({"seconds": round(time.time() - t0, 2), "model": model, "mode": mode})
    return out


def ollama_ok() -> tuple[bool, list[str]]:
    try:
        r = httpx.get(f"{OLLAMA}/api/tags", timeout=3)
        return True, [m["name"] for m in r.json().get("models", [])]
    except Exception:
        return False, []
