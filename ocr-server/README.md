# Receipt OCR server

Runs on a laptop. The phone sends receipt photos; an open-weights vision model reads item, quantity and amount;
the phone matches each line to the catalogue and the owner confirms it. Nothing is saved without confirmation.

## Model choice for a 4 GB GPU

| Model (Ollama tag) | Licence | Fits 4 GB VRAM | Role |
|---|---|---|---|
| `qwen3-vl:4b` | Apache-2.0 | Yes, mostly on GPU | **Default.** Newer and about as accurate as Qwen2.5-VL 7B on OCR at half the size. |
| `qwen3-vl:2b` | Apache-2.0 | Yes, fully | Fallback if 4B is slow or runs out of memory. |
| `qwen2.5vl:7b` | Apache-2.0 | No, spills to RAM | Comparison run for the evaluation table. Expect it to be several times slower. |
| `qwen2.5vl:3b` | Qwen Research licence | Yes | Avoid: not an open-source licence. |

Change the model with the `OCR_MODEL` environment variable. Check licences on each model card before relying on this table.

If Telugu item names come back poor, switch the app to **☰ → Settings → OCR server → Numbers only**. The model then
reads only quantities and amounts, and the app suggests items by price. Numbers read far more reliably than handwriting.

## Setup on Windows 11

1. Install Ollama from ollama.com, then in PowerShell:
   ```powershell
   ollama pull qwen3-vl:4b
   ```
2. Install Python 3.12 from python.org (tick "Add to PATH"). In this folder:
   ```powershell
   py -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
   ```
3. Pick a token (any long random text) and start the server:
   ```powershell
   $env:OCR_TOKEN = "choose-a-long-random-phrase"
   uvicorn server:app --host 0.0.0.0 --port 8765
   ```
   Enter the same token in the app: **☰ → Settings → Server token**.
   Check http://localhost:8765/health shows `"model_pulled": true`.
4. Allow the phone through Windows Firewall (PowerShell as administrator), once:
   ```powershell
   New-NetFirewallRule -DisplayName "Nilvai OCR" -Direction Inbound -LocalPort 8765 -Protocol TCP -Action Allow -Profile Private
   ```
   Make sure the Wi-Fi network is set to **Private** in Windows settings.
5. Find the laptop address with `ipconfig` (IPv4, e.g. 192.168.1.23). In the app: **☰ → Settings → Server address** =
   `http://192.168.1.23:8765`. The Bills tab shows 🟢 when it can reach the server.

Security: keep Ollama on its default address (127.0.0.1). Do **not** set `OLLAMA_HOST=0.0.0.0`; only this server
needs to reach it. Keep Ollama updated, since older versions had published security fixes. Model files (GGUF) are
weights only and don't run code.

Check `ollama ps` while a receipt is processing: it should say mostly GPU. Close games or other GPU apps first.

## When the phone and laptop are in different places

- **Tailscale** (open-source core; fully open server option: Headscale): install on the laptop and the phone,
  sign in to the same account, then use the laptop's `100.x.y.z` address in the app.
- **No connection at all:** the owner shares the receipt photos by WhatsApp. Save them to a folder, then
  ```powershell
  python batch.py photos --out results.json
  ```
  Send `results.json` back; the owner taps **Bills tab → Import results** and confirms each line.
  Keep the WhatsApp file names unchanged so results attach to the right photos.

## Evaluation for the report

1. Pick 20 to 30 receipts. Type the true lines into `labels.csv`:
   ```
   file,line,item_te,item_en,qty_value,qty_unit,amount
   IMG-001.jpg,1,కందిపప్పు,toor dal,500,g,65
   ```
2. Run each model and mode over the same folder:
   ```powershell
   python batch.py photos --out r_qwen3vl4b.json
   python batch.py photos --out r_numbers.json --mode numbers
   python batch.py photos --out r_qwen25vl7b.json --model qwen2.5vl:7b
   python eval.py labels.csv r_qwen3vl4b.json r_numbers.json r_qwen25vl7b.json
   ```
3. `eval.py` prints a table: line recall, amount accuracy, quantity accuracy, Telugu text similarity,
   invented lines, total match rate, seconds per receipt.
4. Catalogue match accuracy comes from the app: **☰ → Export & backup → Export CSVs → ocr_corrections.csv**, column `top_correct`
   (1 when the app's first suggestion was what the owner confirmed).

The labelled photos and results contain real shop data. They are git-ignored; keep them out of the public repo.
