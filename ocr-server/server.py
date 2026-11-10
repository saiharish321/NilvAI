"""OCR server for Nilvai. Runs on the laptop; the phone app sends receipt photos here.

    uvicorn server:app --host 0.0.0.0 --port 8765
"""
import hmac
import os

from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

import ocr_core

# Shared secret: set OCR_TOKEN on the laptop and the same value in the app's Settings.
# Without it, anyone on the same network could use the server.
TOKEN = os.environ.get("OCR_TOKEN", "")
MAX_BYTES = 10 * 1024 * 1024
ALLOWED = (b"\xff\xd8\xff", b"\x89PNG", b"RIFF")  # jpeg, png, webp

app = FastAPI(title="Nilvai OCR")
# The app's WebView origin is http://localhost; allow it (and a desktop browser during testing).
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.get("/health")
def health():
    # No secrets here; the phone uses it to show online/offline.
    ok, models = ocr_core.ollama_ok()
    return {"ollama": ok, "model": ocr_core.MODEL, "model_pulled": any(m.startswith(ocr_core.MODEL) for m in models)}


def check_token(token: str | None):
    if TOKEN and not hmac.compare_digest(token or "", TOKEN):
        raise HTTPException(401, "wrong or missing token")


@app.post("/extract")
async def extract(file: UploadFile = File(...), mode: str = Form("full"),
                  x_nilvai_token: str | None = Header(default=None)):
    check_token(x_nilvai_token)
    data = await file.read(MAX_BYTES + 1)
    if not data:
        raise HTTPException(400, "empty file")
    if len(data) > MAX_BYTES:
        raise HTTPException(413, "image larger than 10 MB")
    if not data.startswith(ALLOWED):
        raise HTTPException(415, "only JPEG, PNG or WebP images")
    if mode not in ("full", "numbers"):
        raise HTTPException(400, "mode must be full or numbers")
    try:
        return ocr_core.extract(data, mode)
    except Exception as e:  # surface model or Ollama errors to the phone
        raise HTTPException(502, f"OCR failed: {e}")
