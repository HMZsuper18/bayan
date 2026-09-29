<p align="center">
  <img src="assets/images/logo.svg" alt="Bayan" width="160" />
</p>

<h1 align="center">Bayan</h1>

<p align="center">
  A Quranic study app with offline OCR, Tafseer and recitations.
</p>

Bayan (بيان) is a Flutter application for reading, listening to and studying the
Quran. It renders mushaf pages from a bundled text corpus, recognises printed
pages with on-device OCR, streams and downloads recitations, and keeps prayer
times, adhan alerts and a Hijri calendar close at hand. It runs fully offline
once content is downloaded.

- **Version:** 1.8.0
- **License:** see [LICENSE](LICENSE)

## Features

### Reading and study
- **Mushaf reader** with page viewer, surah navigation, adaptive Quran text
  rendering (Uthmanic and AmiriQuran fonts, PUA glyph substitution and text
  normalisation) and bookmarks.
- **OCR page scanner** using an on-device Tesseract engine with the bundled
  Arabic model — point the camera at a printed mushaf page and jump to it.
- **Quran index** with surah and verse pickers.
- **Tafseer and translation** with a selectable language.
- **Azkar and dhikr** controller with a share sheet.

### Audio
- **Reciters store** for browsing and downloading reciters.
- **Hybrid download manager** with a persistent queue, progress reporting and
  background playback through a shared Dart engine.
- **Mini player** and a recitations tray on the dashboard.

### Prayer and time
- **Prayer times** calculated on device (location or manual), with Hanafi and
  standard Asr methods, plus sunrise.
- **Adhan notifications** with a configurable reminder offset, scheduled on
  boot and after app updates.
- **Qiblah compass** using the device magnetometer.
- **Hijri calendar**.

### Home screen (Android)
Five app widgets — Prayer Times, Ayah of the Week, Dhikr, OCR and
Recitations — with compact and banner size tiers, day/night backgrounds and
broadcast playback controls that work without opening the app.

### Personalisation
- **Five launcher icon variants:** Classic, Emerald, Midnight, Gold, Royal,
  switched through activity aliases without restarting the app.
- **Wallpapers gallery:** browse the published catalogue, preview an image,
  crop it to the screen aspect and apply it to the home or lock screen.
- Light and dark theme, adjustable UI font size, and English, Arabic or Urdu
  interface language.

## Platforms

| Target | Status |
|---|---|
| Android | Primary target, release APK and AAB builds |
| iOS | Project present |

## Project structure

```
lib/
  main.dart              entry point: Hive, settings, icon sync, adhan reschedule
  app.dart               MaterialApp, theme, locale and text scaling
  core/
    constants/           app-wide constants
    theme/               colours, text styles, light and dark themes
    utils/               prayer time calculator, Hijri date, Qiblah, Quran
                         text pipeline, responsive spacing, reciter helpers
    widgets/             desktop shell and dashboard, glass container,
                         mini player, reciter avatar
  data/
    database/            Hive boxes, Quran index, seed data, settings service
    models/              Hive-persisted models (generated `.g.dart` parts)
    repositories/        Quran and wallpaper data sources
  features/
    dashboard/           home screen, prayer times, azkar, ayah of the week
    mushaf/              reader, page viewer, scanner, render widgets
    qiblah/              compass screen
    quran_index/         surah and verse navigation
    reciters_store/      reciter browsing and downloads
    settings/            settings, about and feedback
    splash/              launch screen
    wallpaper/           gallery, crop screen, bloc and crop math domain
  services/              static service classes (notifications, downloads,
                         playback, OCR, widget refresh, app icon, wallpaper)
  l10n/                  ARB sources and generated localizations
android/                 manifest, Kotlin bridges, receivers, widgets, icons
test/                    unit tests
```

## Architecture

- **State management** — `flutter_bloc`. Each feature that needs it owns a
  `bloc/` directory with `*_bloc.dart`, `*_event.dart` and `*_state.dart`
  joined by `part of`. Events are `Equatable` subclasses.
- **Persistence** — Hive. `HiveService` opens the boxes, `SettingsService`
  stores user preferences as key/value strings, and models carry generated
  adapters.
- **Native boundary** — Kotlin method channels registered in
  `MainActivity.configureFlutterEngine`: download manager, adhan notifications,
  app icon switching and wallpapers. Widgets, boot handling and package
  replacement are served by dedicated receivers and `AppWidgetProvider`
  implementations.
- **Rendering** — the Quran text pipeline lives in `lib/core/utils`:
  normalisation, PUA substitution and page layout are pure functions, kept
  independent of widgets so they can be tested directly.

## Getting started

```bash
flutter pub get
flutter run
```

Release build:

```bash
flutter build apk --release
```

Verification:

```bash
flutter analyze
flutter test
```

Localization and generated code:

```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
```

`flutter gen-l10n` regenerates `lib/l10n/app_localizations*.dart` from the
`.arb` files; run it after editing any string. `build_runner` is only needed
when a Hive model in `lib/data/models/` changes.

## Localization

Three locales, defined in `l10n.yaml` with `app_en.arb` as the template:

| Locale | File |
|---|---|
| English | `lib/l10n/app_en.arb` |
| Arabic | `lib/l10n/app_ar.arb` |
| Urdu | `lib/l10n/app_ur.arb` |

The selected language is stored in `SettingsService` and applied at runtime
without a restart.

## Assets

| Asset | Purpose |
|---|---|
| `assets/images/logo.svg` | Application logo |
| `assets/data/quran.json` | Quran text corpus |
| `assets/data/surahs.json` | Surah metadata |
| `assets/fonts/` | Uthmanic, AmiriQuran and Tajawal |
| `assets/tessdata/` | Arabic Tesseract model for OCR |

## Testing

```bash
flutter test
```

Tests cover the pure logic that is easy to get wrong: the notification locale
resolution (`test/notification_locale_test.dart`) verifies that the ongoing
download notification follows the system language and falls back to the
in-app language when the device locale is unsupported.

