# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## Project overview

**Bayan (بيان)** is an offline Quranic study app for Android built with Flutter. It combines the printed Mushaf with a camera-based page scanner (OCR) so users can read, listen, and study directly from the page they are on. Quranic text, tafseer, translations, qira'at, and recitations are stored locally (Hive); no backend is required.

- **License:** GPLv3 (see [LICENSE](LICENSE))
- **Package / applicationId:** `com.hamzah.bayan`
- **State management:** `flutter_bloc` + `equatable`
- **Local DB:** Hive (codegen via `build_runner`)

## Commands

```bash
flutter pub get                                  # fetch dependencies
flutter gen-l10n                                 # regenerate localizations
dart run build_runner build --delete-conflicting-outputs  # regenerate Hive models
flutter analyze                                  # lint / static analysis (MUST pass)
flutter test                                     # run tests
flutter run                                      # run on device/emulator
flutter build apk --release                      # release build (currently debug-signed)
```

Always run `flutter analyze` after making changes. Do not commit code that introduces analyzer warnings.

## Architecture & conventions

Feature-first layout with BLoC. **Never** deviate from this structure.

```
lib/
├── core/          # constants, theme, utils, shared widgets
├── data/          # database, models, repositories, seed data
├── features/      # dashboard, mushaf, quran_index, reciters_store, settings, splash
│   ├── bloc/      #   <feature>_event.dart / <feature>_state.dart / <feature>_bloc.dart
│   └── presentation/  # screens and feature widgets
├── services/      # cross-cutting singletons (audio, OCR, downloads, prayer times, ...)
├── l10n/          # app_en.arb (template), app_ar.arb, app_ur.arb
├── app.dart       # AppState: theme, UI font scale, locale
└── main.dart      # bootstrap: HiveService -> SettingsService -> DefaultReciterService
```

Rules:

- **One feature, one folder** under `lib/features/<name>/`. All its screens, widgets, and BLoC code live inside it.
- **Repositories, not direct Hive access.** Widgets and BLoCs depend on `lib/data/repositories/`, never on boxes directly.
- **Singletons for cross-cutting concerns** (`lib/services/`). Expose `Stream`s for anything that updates live UI (playback, downloads).
- **No comments unless they explain non-obvious intent.** Prefer descriptive names.
- **Arabic-first UX.** UI defaults to Arabic; always keep Arabic/English/Urdu string keys in sync (see Localization).
- **Do not add new third-party dependencies** without checking existing `pubspec.yaml` first; reuse what is already available.
- The app suppresses Flutter error widgets (`ErrorWidget.builder`). Do not reintroduce noisy error UI.

## Startup flow

`lib/main.dart` (order matters):

1. `HiveService.init()` — open boxes: `surahs`, `verses`, `reciters`, `tafseer`, `qiraat`, `translations`
2. `SettingsService.init()` — load settings box
3. `DefaultReciterService.init()` — resolve default reciter
4. `runApp(App())` — post-frame: `SeedData.seedAll()` (loads `assets/data/quran.json` via `compute`), then `PrayerTimesWidgetService.refresh()`

## Data layer

- Hive boxes are opened in `lib/data/database/hive_service.dart`.
- Seed data lives in `assets/data/quran.json` (~10 MB) and `assets/data/surahs.json`, loaded by `lib/data/database/seed_data.dart` off the UI thread.
- Navigation indices (surah / juz' / hizb first-page and page-lookup maps) are in `lib/data/database/quran_index.dart`.
- Models use Hive typeAdapters; edit the model, then regenerate with `dart run build_runner build --delete-conflicting-outputs`.

## Quran rendering

Custom renderer in `lib/core/utils/`. It is tuned for Quranic orthography (NFC normalization, diacritic reordering, PUA glyph substitution, `ui.Paragraph`/`ui.Picture` caching). If you change text handling, preserve:

- `quran_render_config.dart` — font selection + OpenType features
- `quran_text_normalizer.dart` — normalization + cache
- `quran_ayah_renderer.dart` — RTL paragraph rendering
- `quran_pua_substitution.dart` — QCF4 PUA glyph mapping

## Localization

- `l10n.yaml` → template `lib/l10n/app_en.arb`, output `app_localizations.dart`.
- Supported locales: **en, ar, ur**.
- UI language, tafseer language, and translation language are configured **independently** in Settings.
- After editing any `.arb` file, run `flutter gen-l10n`. Keep the three arb files in sync.

## Known issues / gotchas

- **`assets/qcf4/` is not registered in `pubspec.yaml`** despite being used by page-mode Mushaf. Register it under `flutter.assets` before shipping.
- **Release builds sign with debug keys** (`android/app/build.gradle.kts` has a TODO). Add a real `signingConfig` before release.
- `analysis_options.yaml` excludes `prompt/**`, a directory that no longer exists. Harmless; can be removed.
- No `test/` directory yet. Tests are welcome contributions.

## Verification before finishing

1. `flutter analyze` — no new warnings/errors.
2. `flutter test` — all tests pass (add tests for new behavior).
3. If you touched `.arb` files or models, confirm generated files are regenerated and committed.
4. If you touched rendering, manually verify Arabic diacritics render correctly on device.
