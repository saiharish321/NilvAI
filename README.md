# Nilvai (నిల్వAI)

*Nilva* means stock in Telugu. Nilvai is an offline Android app for small grocery shops, in Telugu and English.
It replaces memory and handwritten slips with a price lookup, a simple sales and purchase log, stock counts,
and a weekly report that says whether the shop is earning its keep. Handwritten receipts are read by an
open-source vision model running on a laptop, and the owner confirms every line.

Built with Flutter for an IIM Ahmedabad BPGP Live Project, and released so that similar shops can use it.

## What it does

| Tab | For |
|---|---|
| **ధర Price** | Search by Telugu, English or romanised name ("kandi"). Every pack size and price. Cost and margin only in owner mode (🔒). |
| **అమ్మకం Sale** | Enter a bill at the counter, or a day's receipts after closing. |
| **రసీదు Bills** | Photograph handwritten bills. The laptop OCR server reads them; the owner checks each line before it is saved. |
| **సరుకు Stock** | Purchase invoices (with a flag for prepaid BigBasket "rescue" orders) and stock counts. |
| **లెక్క Report** | Inventory turns against the shop's break-even thresholds, top-earning items (ABC), capital vs margin by category, days of stock left, rescue orders, product trials. Each card says how many days of data it rests on. |
| **☰ More** | Catalogue, trials, decision rule, CSV export, backup and restore, settings. |

Data stays on the phone in a private SQLite database.

## Run it on your laptop and phone (Windows)

1. Install **Git**, **Android Studio** (with *Android SDK Command-line Tools*) and the **Flutter SDK**
   (docs.flutter.dev → Install → Windows → Android). Add `C:\src\flutter\bin` to PATH.
2. `flutter doctor --android-licenses`, then `flutter doctor`: Flutter and Android toolchain should be ✓.
3. On the phone: Developer options → USB debugging on. Plug in, accept. `flutter devices` lists it.
4. In this folder, once:
   ```powershell
   flutter create --org org.nilvai --project-name nilvai --platforms android .
   del test\widget_test.dart
   python tool\patch_android.py
   flutter pub get
   ```
5. Check and run:
   ```powershell
   flutter analyze
   flutter test
   flutter run            # installs a debug build on the phone; press r to reload after code changes
   ```
6. In the app: ☰ → Export & backup → **Import catalogue CSV** (or *Load sample catalogue*).

Commit the generated `android/` folder after step 4 so every build uses the same project.

## Release APK for the shop phone

GitHub Actions builds it on every push (`.github/workflows/android.yml`): audit, analyze, test, build.
The shop phone must get a build signed with the **release key**. Store it once in the repo's
Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `NILVAI_KEYSTORE_B64` | the keystore file, base64-encoded |
| `NILVAI_STORE_PASSWORD` | its password |

Push a tag (`git tag v0.2.0 && git push --tags`) to publish a release, then on the phone download `nilvai.apk`
from the release page and allow "Install unknown apps" for the browser.

Keep a safe copy of the keystore. If it is lost, updates cannot be installed over the existing app, and
uninstalling erases the shop's data. Back up from the app before any reinstall.

## Catalogue CSV format

```
category,name_en,name_te,brand,pack,cost,price,abc,supplier,credit_days
Pulses & Dals,Toor Dal,కందిపప్పు,Loose,1 kg,115,130,A,Local wholesaler,
```

One row per pack size. `assets/sample_catalogue.csv` has illustrative prices only.

## Receipt OCR

See [`ocr-server/README.md`](ocr-server/README.md): Ollama + Qwen3-VL 4B (Apache-2.0) on a laptop with a 4 GB GPU,
a small FastAPI server with a token, and a confirm screen on the phone. Google Colab can run larger models
for the accuracy evaluation.

## Stack

Flutter (Google, BSD-3). Packages: `sqflite`, `path`, `path_provider`, `share_plus`, `image_picker`,
`file_picker`, `http`, all widely used and open source. Search and Telugu transliteration are the app's
own code. OCR server: FastAPI, Ollama, Qwen3-VL.

## Security

See [SECURITY.md](SECURITY.md).

## Notes

- The thresholds in Settings (7.66 and 9.67 turns) come from one shop's cost base. Recompute for yours:
  required turns = (annual costs ÷ margin − annual costs) ÷ stock at cost.
- Written with AI assistance (Claude).

## Licence

MIT
