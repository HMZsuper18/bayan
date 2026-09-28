# AGENTS.md

Guidance for AI agents and new contributors working in this repository.

## What this is

Bayan (بيان) — a Flutter Quranic study app: mushaf reader, on-device OCR,
recitations, prayer times, adhan notifications, Qiblah, home-screen widgets
and a wallpapers gallery. Version `1.8.0+8`, Dart SDK `^3.11.5`.

Platforms present: `android/`, `ios/`, `linux/`, plus an independent GNOME
Shell extension under `gnome/bayan@bayan/`. There is no `web/`, `windows/` or
`macos/` directory.

## Commands

```bash
flutter pub get                                  # dependencies
flutter run                                       # dev run
flutter analyze                                   # lints (see baseline below)
flutter test                                      # unit tests
flutter build apk --release                       # release APK
flutter gen-l10n                                  # regenerate lib/l10n/app_localizations*.dart
dart run build_runner build --delete-conflicting-outputs   # regenerate *.g.dart
```

Run `flutter analyze` and `flutter test` before considering any change done.

**Baseline:** `flutter analyze` reports **4 infos, 0 errors, 0 warnings**
after a clean build. The four are `deprecated_member_use` on `scale` in
`lib/features/mushaf/presentation/mushaf_screen.dart`, two `empty_catches` in
`lib/services/app_icon_service.dart`, and one `use_build_context_synchronously`
in `lib/features/settings/presentation/settings_screen.dart`. All four are
pre-existing; do not "fix" them as a side effect of unrelated work.

`flutter test` runs **7 tests in 1 file** (`test/wallpaper_crop_math_test.dart`).

## Conventions

### State management — flutter_bloc, `part of`

Features that need state own a `bloc/` directory with three files:

```
lib/features/<name>/bloc/<name>_bloc.dart      # class extends Bloc, handler methods
lib/features/<name>/bloc/<name>_event.dart     # part of '<name>_bloc.dart'
lib/features/<name>/bloc/<name>_state.dart     # part of '<name>_bloc.dart'
```

Existing blocs: `dashboard`, `mushaf`, `wallpaper`. Events extend
`Equatable`. The bloc file declares the `part` directives — never add them to
the event/state files.

### Services — static classes with an `init()`

`lib/services/` and `lib/data/database/` hold **static** classes, not
instances. They are initialised in order in `lib/main.dart`:

```dart
await HiveService.init();
await SettingsService.init();
await DefaultReciterService.init();
AppIconService.instance.init();
AdhanNotificationService.instance.rescheduleFromSettings();
```

Adding a service that needs start-up work means adding a line here. Anything
reading Hive must run after `HiveService.init()`.

### Layers

- `lib/core/` — cross-cutting: theme, constants, pure utilities, shared widgets.
  Quran text processing (normalisation, PUA substitution, page layout) lives in
  `lib/core/utils/` and is deliberately free of widget imports so it stays
  testable.
- `lib/data/` — Hive boxes, models, repositories.
- `lib/features/<name>/` — `bloc/`, `domain/` (pure logic), `presentation/`.
- `lib/services/` — platform-facing behaviour (notifications, downloads,
  playback, OCR, widget refresh).

Prefer putting new logic in `core/utils` or `domain/` rather than in a widget.

### Localization

- Sources: `lib/l10n/app_en.arb` (template), `app_ar.arb`, `app_ur.arb`.
- Config: `l10n.yaml`; `generate: true` is set in `pubspec.yaml`.
- After editing any string run `flutter gen-l10n`. Never hand-edit
  `app_localizations*.dart` — they are generated and will be overwritten.
- Access strings only as `l10n.<key>`. Before adding a key, grep for an
  existing one: there are strings in the ARB files that are already unused.

### Native side (Kotlin)

Channels are registered in `MainActivity.configureFlutterEngine`, which
**does** call `super`:

| channel | bridge class | methods |
|---|---|---|
| `com.hamzah.bayan/download_manager` | `DownloadManagerBridge` | `handle` |
| `com.hamzah.bayan/adhan_notifications` | `AdhanNotificationBridge` | `handle` |
| `com.hamzah.bayan/wallpaper` | `WallpaperBridge` | `setWallpaper`, `syncPrayerTimes` |
| `com.hamzah.bayan/app_icon` | inline `when` | `switchIcon` |

New methods on `WallpaperBridge` go inside its `when (call.method)` block;
keep it free of unused imports.

Manifest wiring in `android/app/src/main/AndroidManifest.xml`:
- 5 widget receivers (`Ayah`, `Dhikr`, `Ocr`, `PrayerTimes`, `Recitations`),
  each paired with `res/xml/<name>_widget_info.xml`
- `BootReceiver` and `PackageReplacedReceiver`
- 5 activity-aliases (`IconAliasClassic/Emerald/Midnight/Gold/Royal`) mapped
  from `IconSwitcher.kt` — adding an icon variant means an alias **and** an
  entry in that map **and** a `mipmap-anydpi-v26/ic_launcher_<name>.xml`
- `android:permission="android.permission.SET_WALLPAPER"` is required by the
  wallpapers gallery; do not remove it.

## Assets

Declared in `pubspec.yaml` under `flutter: assets:`: `assets/images/`,
`assets/data/`, `assets/fonts/`, `assets/tessdata/`,
`assets/tessdata_config.json`. Adding a file under one of those directories is
enough — no pubspec edit needed for siblings.

`assets/images/` contains exactly one file, `logo.svg`.

Launcher icons: the default adaptive icon is
`res/mipmap-anydpi-v26/ic_launcher.xml` referencing `@mipmap/ic_launcher_*`.
Before deleting any drawable, grep the whole `android/` tree — orphans are not
tolerated but neither is a broken icon.

## Things that bite

- **`flutter gen-l10n` is required** after any `.arb` edit, or
  `app_localizations*.dart` goes stale and `l10n.<key>` stops resolving.
- **`build_runner`** is required after changing any model in
  `lib/data/models/` — the `.g.dart` adapters are committed.
- **`analysis_options.yaml` excludes** `android/`, `ios/`, `linux/`, `web/`,
  `windows/`, `macos/`, `prompt/**` and `build/**`. Kotlin and platform
  code get no Dart lint coverage; check those by building.
- **`android/app/src/main/assets/` is empty and must stay empty** — assets
  belong in the Flutter `assets/` tree so `rootBundle` can read them.
- **`important/` is gitignored** and holds the release keystore. It must
  never be committed; `.gitignore` line 52 enforces this.
- **`tool/wallpaper_dashboard.py` is a dev tool**, not part of the app
  bundle. It edits the wallpaper catalogue in a separate repository and
  expects to be run from that working tree.
- The GNOME extension is a separate JavaScript codebase with its own schema
  and lifecycle. Flutter changes never affect it.

## Scope discipline

Keep a change inside the feature you were asked to touch. Do not reformat
unrelated files, do not regenerate the l10n outputs when you did not edit the
ARB sources, and do not commit unless explicitly asked.

## Verifying a change

```bash
flutter gen-l10n && flutter pub get
flutter analyze        # expect 4 infos, 0 errors
flutter test           # expect 7 tests passing
flutter build apk --release
```

For manifest or Kotlin changes, additionally confirm the APK still contains
the expected entries:

```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -c assets/
```
