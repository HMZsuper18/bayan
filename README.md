# بيان — Bayan

> هَٰذَا بَيَانٌ لِّلنَّاسِ وَهُدًى وَمَوْعِظَةٌ لِّلْمُتَّقِينَ
>
> *"This is a clear statement to mankind, a guidance and instruction for those conscious of Allah."* — Surah Aal-e-Imran, 3:138

**Bayan** is a Quranic study app for Android that works fully offline. It pairs the printed Mushaf with a built-in page scanner (OCR), so you can read, listen, and study directly from the page you're on — without a Quran translation app in your other hand.

- **Platform:** Android (minSdk from Flutter defaults, arm64-v8a + armeabi-v7a)
- **Language:** Flutter (Dart), Material 3
- **Version:** 1.0.0+1
- **License:** [GPLv3](#license)

---

## Contents

- [Features](#features)
- [Getting the app](#getting-the-app)
- [For developers](#for-developers)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Localization](#localization)
- [License](#license)

---

## Features

### 📖 Complete offline Mushaf
- All 114 surahs and 6,236 verses are bundled with the app and stored locally in Hive — no internet needed to read the Quran.
- Two rendering modes:
  - **Text mode** — clean Arabic text with diacritics, rendered with a custom RTL text pipeline and the AmiriQuran / Uthmanic fonts.
  - **Page mode** — full Madani-page layouts (QCF4) with the Uthmanic script, exactly like the printed Mushaf.
- Navigate by **surah**, **juz'**, or **hizb** from the index.

### 🔍 Page scanner (OCR)
- Point your camera at any page of a printed Mushaf — offline OCR (Tesseract, `ara.traineddata`) reads the page number from Arabic-Indic digits and jumps you to that exact page.
- No network calls, no scanning service — everything runs on your device.

### 🔊 Recitations & Tafseer
- Listen to recitations from famous reciters (Makkah & Madinah Imams, classic Egyptian reciters, and *hadr*/*fast* styles).
- Download recitations for offline playback with live download progress.
- Tap any verse to open a detail panel with:
  - **Tafseer** (commentary), fully offline
  - **Translations** in your language
  - **Qira'at** (variant readings)
  - **Recitation** controls — single verse, verse-to-end, or the whole surah.

### 🕌 Daily companions
- **Prayer times** with iqamah gaps, auto-detected from your location (defaults to Makkah).
- **Azkar** — morning, evening, and situational supplications, time-aware and offline.
- **Ayah of the Week** — a deterministic verse that changes every Monday, works offline, and can be shared.
- **Home-screen widget** on Android showing today's prayer times.

### ⚙️ Personalization
- Three fully independent languages: **UI** (Arabic, English, Urdu), **tafseer**, and **translation**.
- Adjust Quran font size and UI font size.
- Light/dark theme with a distinctive glass-morphism design.

---

## Getting the app

Bayan is currently distributed as an **Android app**. To install it:

1. Build the APK yourself (see the [developer section](#build-from-source)) — release builds are currently signed with debug keys.
2. Enable "Install unknown apps" for your browser/file manager, then install the APK.

> Note: Bayan is not yet published to the Google Play Store.

---

# For developers

This section is for people who want to build, run, and contribute to Bayan.

## Requirements

- **Flutter** stable channel (project metadata tracks a recent stable revision)
- **Dart** SDK `^3.11.5`
- **Android SDK** with Android Studio or a command-line toolchain
- Java 17 (used by the Android Gradle build)
- An Android device or emulator

## Build from source

```bash
# Fetch dependencies
flutter pub get

# Generate localization and codegen files
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device
flutter run

# Build a release APK
flutter build apk --release
```

Build artifacts land in `build/app/outputs/`.

> The Gradle file includes a TODO: release builds currently sign with **debug keys** and should be given a proper `signingConfig` before distribution.

## Architecture

The app follows a **feature-first architecture** with a **BLoC** state-management pattern:

```
lib/
├── core/          # Constants, theme, utilities, shared widgets
├── data/          # Hive boxes, models, repositories, seed data
├── features/      # One folder per feature (dashboard, mushaf, ...)
│   ├── bloc/      #   events / states / bloc
│   └── presentation/  #   screens and widgets
├── services/      # Cross-cutting singleton services
├── l10n/          # Localization (arb files + generated Dart)
├── app.dart       # Root widget (AppState)
└── main.dart      # Bootstrap
```

Key conventions:

- **Feature-first**: everything for a feature lives under `lib/features/<name>/`.
- **BLoC**: each feature uses the `flutter_bloc` package with `equatable` events/states.
- **Repository pattern**: `lib/data/repositories/quran_repository.dart` is a thin facade over `HiveService` + `QuranIndexService`; widgets talk to repositories, not to Hive directly.
- **Singleton services** in `lib/services/` handle audio playback, downloads, OCR, prayer times, etc., and expose `Stream`s for live UI updates.

### Startup flow (`lib/main.dart`)

1. `HiveService.init()` — opens the Hive boxes
2. `SettingsService.init()` — loads user settings
3. `DefaultReciterService.init()` — resolves the default reciter
4. `runApp(App())` — the app seeds its data post-frame (`SeedData.seedAll()`) and refreshes the home-screen widget

## Data & storage

- **Hive** is the local database. Boxes: `surahs`, `verses`, `reciters`, `tafseer`, `qiraat`, `translations`, plus a `settings` box.
- **Seed data** is loaded from `assets/data/quran.json` (~10 MB) and `assets/data/surahs.json` via `compute()` (off the UI thread) in `lib/data/database/seed_data.dart`.
- **Index maps** (`lib/data/database/quran_index.dart`) power surah / juz' / hizb navigation and page lookups.
- **Models** in `lib/data/models/` use Hive's codegen (`*.g.dart` is generated with `build_runner`).

## Services at a glance

| Service | File | What it does |
|---|---|---|
| Audio playback | `lib/services/audio_playback_service.dart` | `just_audio` singleton; verse / verse-to-end / full-surah modes |
| Reciter downloads | `lib/services/reciter_store_service.dart` | Dio-based downloads with concurrency cap; progress streams |
| Ayah of the week | `lib/services/ayah_of_week_service.dart` | Deterministic weekly verse (ISO week + FNV-1a hash), changes Mondays, offline |
| Default reciter | `lib/services/default_reciter_service.dart` | Validates and remembers the default reciter |
| Page-number OCR | `lib/services/page_number_ocr_service.dart` | Tesseract OCR of Arabic-Indic page digits |
| Prayer times widget | `lib/services/prayer_times_widget_service.dart` | Home-screen widget data provider |

## Quran rendering pipeline

The text renderer in `lib/core/utils/` is custom-built for Quranic orthography:

- `quran_render_config.dart` — font selection (AmiriQuran primary, Uthmanic fallback) and OpenType features
- `quran_text_normalizer.dart` — NFC normalization, diacritic reordering, orphaned-mark fixes, display caching
- `quran_ayah_renderer.dart` — custom `ui.Paragraph` / `ui.Picture` caching for fast RTL rendering
- `quran_pua_substitution.dart` — Private Use Area glyph mapping for the QCF4 page fonts

The **page mode** uses the QCF4 fonts and per-page layout JSON in `assets/qcf4/` (not yet registered in `pubspec.yaml` — see the note below).

> ⚠️ `assets/qcf4/` (page fonts, `pages/page-XXX.json` layouts, fingerprints) is used by the page-view Mushaf but is **not registered** in `pubspec.yaml`. Make sure it is listed under `flutter.assets` before shipping.

## Localization

Localization uses Flutter's gen-l10n with a custom `l10n.yaml`:

- `lib/l10n/app_en.arb` (template), `app_ar.arb`, `app_ur.arb`
- Regenerate with `flutter gen-l10n`
- UI language, tafseer language, and translation language are configured **independently** in settings

## Linting & analysis

```bash
flutter analyze
```

The project uses `flutter_lints`. `analysis_options.yaml` currently excludes `prompt/**` (a leftover reference to a directory that is no longer present) — it can be removed when convenient.

## Testing

Add widget/unit tests under `test/`. Run them with:

```bash
flutter test
```

> There is no test directory yet; tests are welcome contributions.

## Contributing

1. Fork the repository and create a feature branch.
2. Follow the [architecture](#architecture) and code conventions above.
3. Run `flutter analyze` and the test suite before opening a pull request.
4. Keep GPLv3 license headers on new files where appropriate.

---

## Tech stack

- **Flutter / Dart** — UI framework
- **flutter_bloc + equatable** — state management
- **Hive + hive_flutter** — local database
- **just_audio** — recitation playback
- **flutter_tesseract_ocr + image** — offline page-number OCR
- **dio** — recitation downloads
- **geolocator + geocoding** — prayer-time location
- **home_widget** — Android home-screen prayer-times widget
- **carousel_slider, share_plus, flutter_svg** — misc UI/UX
- **intl + gen-l10n** — localization (en, ar, ur)

---

## Project structure

```
bayan/
├── android/            # Android app + home-screen widget provider (Kotlin)
├── assets/
│   ├── data/           # quran.json, surahs.json (seed data)
│   ├── fonts/          # Uthmanic, AmiriQuran, Tajawal
│   ├── images/         # logo + reciter portraits (shuyukh/)
│   ├── tessdata/       # Tesseract ara.traineddata
│   └── qcf4/           # page fonts + layout JSON (page-mode Mushaf)
├── images/             # root-level proof images (not shipped)
├── lib/
│   ├── core/           # constants, theme, utils, widgets
│   ├── data/           # database, models, repositories
│   ├── features/       # dashboard, mushaf, quran_index, reciters_store, settings, splash
│   ├── services/       # 6 singleton services
│   ├── l10n/           # en / ar / ur
│   ├── app.dart
│   └── main.dart
├── android/ios/web     # platform scaffolding
├── l10n.yaml
└── pubspec.yaml
```

---

## License

Copyright © 2026 Hamzah

This project is licensed under the **GNU General Public License v3.0**. You may use, study, modify, and redistribute it, provided any derivative works are also licensed under GPLv3 and made available with their source code.

See [LICENSE](LICENSE) for the full text.

**Disclaimer:** This is an unofficial, independent study tool. It is not affiliated with, endorsed by, or connected to any official Quran publication or organization. Quranic text and recitations are provided for personal study; please respect the copyrights of the underlying sources.
