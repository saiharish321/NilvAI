# Nilvai: context for Claude Code

## What this is
Nilvai (నిల్వAI, "nilva" = stock in Telugu) is an offline Android app for one small grocery shop in a
Tier-4 town in Andhra Pradesh, built for an IIM Ahmedabad BPGP Live Project (strategy: should the shop
continue or reposition). It is graded as part of a management project, not as software:
**simple, working and actually used by the owner beats feature-rich.**

Owner and staff read Telugu; every label is bilingual (Telugu + English). Large text, big tap targets,
usable at the counter in under 10 seconds.

## Deadline
- Installed and in use on the owner's phone by **13 Nov 2026**. Presentations 21-22 and 28-29 Nov.
- Fallback if this Flutter app isn't ready: an earlier Capacitor/web build of the same app (separate repo copy).
  Prefer small, safe fixes over rewrites.

## Stack
Flutter, Material 3. Packages: sqflite, path, path_provider, share_plus (^11, `SharePlus.instance.share(ShareParams(...))`),
image_picker, file_picker, http, flex_color_scheme (^8.4; the theme is FlexScheme.blueWhale with teal accents
instead of orange, in `nilvaiTheme()` in `lib/widgets.dart`; 9.x needs the separate material_ui package and does
not build with our Flutter SDK). Search and Telugu transliteration are our own code in `lib/logic.dart`
(no fuzzy-search library). Do not add packages unless essential; if you must, use widely used ones.

## Layout
- `lib/logic.dart`: pure functions (₹ formatting, Telugu→Latin, pack sizes, CSV, turns, ABC, OCR matching). Unit-tested.
- `lib/db.dart`: SQLite schema and queries. `lib/state.dart`: catalogue index, settings, owner mode, search.
- `lib/screens/`: lookup (Price), sale, receipts (OCR queue + confirm), stock (purchase, count), dashboard (Report), more.
- `test/logic_test.dart`: keep passing. Add tests for any logic you change.
- `tool/patch_android.py`: applies app ID `org.nilvai.app`, INTERNET permission, cleartext to the laptop, and
  release signing from env vars to the `flutter create` output. Re-run after regenerating `android/`.
- `ocr-server/`: Python FastAPI + Ollama (Qwen3-VL 4B) server that runs on the laptop; see its README.

## Commands
```
flutter analyze        # must have no errors (infos are fine)
flutter test
flutter run            # on the USB-connected phone
flutter build apk --release
```

## Domain rules that must not change
- Required inventory turns: **7.66** (covers cash costs and owner wage) and **9.67** (also imputed rent).
  Turns = COGS / average stock at cost, annualised; COGS = opening stock + purchases − closing stock between
  two stock counts. Logged sales give only a cross-check.
- Every computed report card shows "based on N days of data".
- Exit/closing the shop is not an option anywhere in the app; options are continue, reposition, rice focus.
- OCR: nothing is saved until the owner confirms each line. Numbers read more reliably than Telugu handwriting.

## Privacy and security (strict)
- Never commit real shop data: `item_master.csv`, receipt photos, `results*.json`, `labels*.csv`, exports.
- Never commit keystores or passwords. Release signing uses GitHub secrets NILVAI_KEYSTORE_B64 and NILVAI_STORE_PASSWORD.
- The only Android permission is INTERNET. Do not add camera/storage permissions (photos come through the system picker).
- Never name the town in code, docs or commit messages.
- Ask before each file edit (don't auto-accept edits in this IDE).

## Disclosure
The app is built with AI assistance (Claude); keep that line in README.
