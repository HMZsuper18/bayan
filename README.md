# بيان — Bayan

<p align="center">
  <img src="assets/images/logo.svg" alt="Bayan icon" width="160" />
</p>

> هَٰذَا بَيَانٌ لِّلنَّاسِ وَهُدًى وَمَوْعِظَةٌ لِّلْمُتَّقِينَ
>
> *"This is a clear statement to mankind, a guidance and instruction for those conscious of Allah."* — Surah Aal-e-Imran, 3:138

**Bayan** is a Quranic study app for Android that works fully offline. It pairs the printed Mushaf with a built-in page scanner (OCR), so you can read, listen, and study directly from the page you're on.

- **Platform:** Android 7.0+ (minSdk 24, targetSdk 36), arm64-v8a + armeabi-v7a
- **Language:** Flutter (Dart), Material 3
- **Version:** 1.0.0
- **License:** [GPLv3](#license)

---

## Contents

- [Features](#features)
- [Getting the app](#getting-the-app)
- [For developers](#for-developers)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [License](#license)

---

## Features

### 📖 Complete offline Mushaf
- All 114 surahs and 6,236 verses are bundled with the app and stored locally in Hive — no internet needed to read the Quran.
- Two reading modes:
  - **Text mode** — clean Arabic text with full diacritics, rendered with a custom RTL text pipeline and the AmiriQuran / Uthmanic fonts.
  - **Page mode** — the same text reflowed per printed-Mushaf page boundaries (604 pages), navigable by page like the physical book.
- Navigate by **surah**, **juz'**, or **hizb** from the index.
- Search surahs by number, page, Arabic name, or English name.

### 🔍 Page scanner (OCR)
- Point your camera at any page of a printed Mushaf — offline OCR (Tesseract, `ara.traineddata`) reads the page number from Arabic-Indic digits and jumps you to that exact page.
- No network calls, no scanning service — everything runs on your device.

### 🔊 Recitations & Tafseer
- Listen to recitations from famous reciters (Makkah & Madinah Imams, classic Egyptian reciters, and *hadr*/*fast* styles).
- Download recitations for offline playback with live download progress and a reciters store.
- Tap any verse to open a detail panel with:
  - **Tafseer** (commentary), fully offline
  - **Translations** in your language
  - **Qira'at** (variant readings)
  - **Recitation** controls — single verse, verse-to-end, or the whole surah.

### 🕌 Daily companions
- **Prayer times** with iqamah gaps, auto-detected from your location (defaults to Makkah; silently refreshes every few days).
- **Azkar** — morning, evening, and general supplications, time-aware and offline.
- **Ayah of the Week** — a deterministic verse that changes every Monday, works offline, and can be shared.
- **Home-screen widget** on Android showing today's prayer times.

### ⚙️ Personalization
- Three fully independent languages: **UI** (Arabic, English, Urdu), **tafseer**, and **translation**.
- Adjust Quran font size and UI font size.
- Light/dark theme with a distinctive glass-morphism design.
- Choose the Mushaf layout (pages vs surahs).

---

## Getting the app

Bayan is an **Android** app:

- **GitHub Releases** — download the latest APK from the [Releases](https://github.com/HMZsuper18/bayan/releases) page, then enable "Install unknown apps" for your file manager and install it.
- **Google Play** — Bayan is being prepared for the Play Store; once published, install it directly from Play.

---

# For developers

This section is for people who want to build, run, and contribute to Bayan.

## Requirements

- **Flutter** stable channel (project metadata tracks a recent stable revision)
- **Dart** SDK `^3.11.5`
- **Android SDK** with Android Studio or a command-line toolchain
- **Java 17** for the Android Gradle build (newer JDKs, e.g. 25, are unsupported by Gradle 8.14 / AGP 8.11)
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

# Build a release APK (arm64-v8a + armeabi-v7a, obfuscated)
export JAVA_HOME=~/.local/share/java/jdk-17.0.20+8
flutter build apk --release --target-platform android-arm,android-arm64 \
  --obfuscate --split-debug-info=build/debug-info

# Build a Play Store App Bundle (~56 MB)
flutter build appbundle --target-platform android-arm,android-arm64 \
  --obfuscate --split-debug-info=build/debug-info
```

Build artifacts land in `build/app/outputs/`. The AAB splits per-ABI on Play, so a device downloads only ~11–19 MB and installs ~40–45 MB.

> Release builds are signed with the release key (`android/key.properties` → `android/app/bayan-release.keystore`, both gitignored). Keep the keystore and password safe — Play Store updates must be signed with the same key. A backup lives in `important/` (gitignored).

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
- `quran_pua_substitution.dart` — Private Use Area glyph mapping for the text renderer

> `assets/qcf4/` (page fonts + per-page layout JSON, ~113 MB) exists in the repo but is **not used by any code** — the page view renders text reflowed per printed-page boundaries with the standard fonts. It is deliberately **not registered** in `pubspec.yaml` to keep installs small. If an exact printed-page layout mode is ever added, ship it as an optional on-demand download instead.

## Localization

Localization uses Flutter's gen-l10n with a custom `l10n.yaml`:

- `lib/l10n/app_en.arb` (template), `app_ar.arb`, `app_ur.arb`
- Regenerate with `flutter gen-l10n`
- UI language, tafseer language, and translation language are configured **independently** in settings

## Linting & testing

```bash
flutter analyze
flutter test
```

The project uses `flutter_lints`. `test/` currently has a minimal smoke test; more tests are welcome contributions.

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
- **carousel_slider, share_plus, flutter_svg, url_launcher** — misc UI/UX
- **intl + gen-l10n** — localization (en, ar, ur)

---

## Project structure

```
bayan/
├── android/            # Android app + home-screen widget provider (Kotlin)
├── assets/
│   ├── data/           # quran.json, surahs.json (seed data)
│   ├── fonts/          # Uthmanic, AmiriQuran, Tajawal
│   ├── images/         # logo (reciter avatars are initials, not photos)
│   ├── tessdata/       # Tesseract ara.traineddata
│   └── qcf4/           # unused page fonts + layout JSON (not shipped; see above)
├── important/          # gitignored release-key backup (never commit)
├── lib/
│   ├── core/           # constants, theme, utils, widgets
│   ├── data/           # database, models, repositories
│   ├── features/       # dashboard, mushaf, quran_index, reciters_store, settings, splash
│   ├── services/       # audio, downloads, OCR, prayer times, ...
│   ├── l10n/           # en / ar / ur
│   ├── app.dart
│   └── main.dart
├── l10n.yaml
└── pubspec.yaml
```

---

## License

Copyright © 2026 Hamzah

This project is licensed under the **GNU General Public License v3.0**. You may use, study, modify, and redistribute it, provided any derivative works are also licensed under GPLv3 and made available with their source code.

See [LICENSE](LICENSE) for the full text.

**Disclaimer:** This is an unofficial, independent study tool. It is not affiliated with, endorsed by, or connected to any official Quran publication or organization. Quranic text and recitations are provided for personal study; please respect the copyrights of the underlying sources.