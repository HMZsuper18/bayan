import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('ur'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Bayan'**
  String get appName;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bayan'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @quranFontSize.
  ///
  /// In en, this message translates to:
  /// **'Quran Font Size'**
  String get quranFontSize;

  /// No description provided for @uiFontSize.
  ///
  /// In en, this message translates to:
  /// **'UI Font Size'**
  String get uiFontSize;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @mushafLayout.
  ///
  /// In en, this message translates to:
  /// **'Mushaf Layout'**
  String get mushafLayout;

  /// No description provided for @surahView.
  ///
  /// In en, this message translates to:
  /// **'Surah View'**
  String get surahView;

  /// No description provided for @pageView.
  ///
  /// In en, this message translates to:
  /// **'Page View'**
  String get pageView;

  /// No description provided for @uiLanguage.
  ///
  /// In en, this message translates to:
  /// **'UI Language'**
  String get uiLanguage;

  /// No description provided for @tafseerLanguage.
  ///
  /// In en, this message translates to:
  /// **'Tafseer Language'**
  String get tafseerLanguage;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Currently Unavailable'**
  String get unavailable;

  /// No description provided for @splashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your Qur\\u0027anic study companion'**
  String get splashSubtitle;

  /// No description provided for @recitations.
  ///
  /// In en, this message translates to:
  /// **'Recitations'**
  String get recitations;

  /// No description provided for @prayerTimes.
  ///
  /// In en, this message translates to:
  /// **'Prayer Times'**
  String get prayerTimes;

  /// No description provided for @updateLocation.
  ///
  /// In en, this message translates to:
  /// **'Update Location'**
  String get updateLocation;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get scanning;

  /// No description provided for @ocrProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing OCR...'**
  String get ocrProcessing;

  /// No description provided for @verses.
  ///
  /// In en, this message translates to:
  /// **'Verses'**
  String get verses;

  /// No description provided for @surah.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get surah;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// No description provided for @verse.
  ///
  /// In en, this message translates to:
  /// **'Verse'**
  String get verse;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @urdu.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get urdu;

  /// No description provided for @chooseLayout.
  ///
  /// In en, this message translates to:
  /// **'Choose Layout'**
  String get chooseLayout;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get chooseLanguage;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About Bayan'**
  String get aboutApp;

  /// No description provided for @aboutDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get aboutDeveloper;

  /// No description provided for @aboutEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get aboutEmail;

  /// No description provided for @aboutPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get aboutPortfolio;

  /// No description provided for @aboutRepository.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get aboutRepository;

  /// No description provided for @aboutOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get aboutOpenFailed;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get version;

  /// No description provided for @demoTitle.
  ///
  /// In en, this message translates to:
  /// **'UI Text Sample'**
  String get demoTitle;

  /// No description provided for @demoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is an example of the font size in menus and titles'**
  String get demoSubtitle;

  /// No description provided for @makkah.
  ///
  /// In en, this message translates to:
  /// **'Makki'**
  String get makkah;

  /// No description provided for @madinah.
  ///
  /// In en, this message translates to:
  /// **'Madani'**
  String get madinah;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a surah by name...'**
  String get searchHint;

  /// No description provided for @startReading.
  ///
  /// In en, this message translates to:
  /// **'Mushaf: Start Reading'**
  String get startReading;

  /// No description provided for @primaryActionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse the Holy Quran with tafseer and recitations'**
  String get primaryActionSubtitle;

  /// No description provided for @startButton.
  ///
  /// In en, this message translates to:
  /// **'Start Now'**
  String get startButton;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @tafseer.
  ///
  /// In en, this message translates to:
  /// **'Tafseer'**
  String get tafseer;

  /// No description provided for @qiraat.
  ///
  /// In en, this message translates to:
  /// **'Qiraat'**
  String get qiraat;

  /// No description provided for @asbabNuzul.
  ///
  /// In en, this message translates to:
  /// **'Asbab al-Nuzul'**
  String get asbabNuzul;

  /// No description provided for @fajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get fajr;

  /// No description provided for @dhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get dhuhr;

  /// No description provided for @asr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get asr;

  /// No description provided for @maghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get maghrib;

  /// No description provided for @isha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get isha;

  /// No description provided for @noCamera.
  ///
  /// In en, this message translates to:
  /// **'No Camera Available'**
  String get noCamera;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera Error:'**
  String get cameraError;

  /// No description provided for @imageDecodeError.
  ///
  /// In en, this message translates to:
  /// **'Failed to decode image'**
  String get imageDecodeError;

  /// No description provided for @pageNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'Page number not recognized'**
  String get pageNotRecognized;

  /// No description provided for @invalidPageNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number:'**
  String get invalidPageNumber;

  /// No description provided for @ocrError.
  ///
  /// In en, this message translates to:
  /// **'Recognition error:'**
  String get ocrError;

  /// No description provided for @scanPageNumber.
  ///
  /// In en, this message translates to:
  /// **'Scan Page Number'**
  String get scanPageNumber;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to Page'**
  String get goToPage;

  /// No description provided for @cameraRationaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Why the camera?'**
  String get cameraRationaleTitle;

  /// No description provided for @cameraRationaleBody.
  ///
  /// In en, this message translates to:
  /// **'Bayan scans the printed page number on the mushaf page you are reading so it can jump straight to that page. Images are processed on your device and are never uploaded.'**
  String get cameraRationaleBody;

  /// No description provided for @cameraRationaleContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get cameraRationaleContinue;

  /// No description provided for @splashVerse.
  ///
  /// In en, this message translates to:
  /// **'هَٰذَا بَيَانٌ لِّلنَّاسِ وَهُدًى وَمَوْعِظَةٌ لِّلْمُتَّقِينَ'**
  String get splashVerse;

  /// No description provided for @splashSurahRef.
  ///
  /// In en, this message translates to:
  /// **'Aal-e-Imran (138)'**
  String get splashSurahRef;

  /// No description provided for @juz.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get juz;

  /// No description provided for @hizb.
  ///
  /// In en, this message translates to:
  /// **'Hizb'**
  String get hizb;

  /// No description provided for @startsAtPage.
  ///
  /// In en, this message translates to:
  /// **'Starts at Page'**
  String get startsAtPage;

  /// No description provided for @chapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter'**
  String get chapter;

  /// No description provided for @indexTitle.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get indexTitle;

  /// No description provided for @juzs.
  ///
  /// In en, this message translates to:
  /// **'Juzs'**
  String get juzs;

  /// No description provided for @hizbs.
  ///
  /// In en, this message translates to:
  /// **'Hizbs'**
  String get hizbs;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// No description provided for @translationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translation Language'**
  String get translationLanguage;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @recitersStore.
  ///
  /// In en, this message translates to:
  /// **'Reciters Store'**
  String get recitersStore;

  /// No description provided for @addReciter.
  ///
  /// In en, this message translates to:
  /// **'Add Reciter'**
  String get addReciter;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @reciterCategoryMakkahMadinah.
  ///
  /// In en, this message translates to:
  /// **'Makkah & Madinah Imams'**
  String get reciterCategoryMakkahMadinah;

  /// No description provided for @reciterCategoryClassicEgyptian.
  ///
  /// In en, this message translates to:
  /// **'Classic Egyptian Reciters'**
  String get reciterCategoryClassicEgyptian;

  /// No description provided for @reciterCategoryHadrFast.
  ///
  /// In en, this message translates to:
  /// **'Hadr / Fast Recitation'**
  String get reciterCategoryHadrFast;

  /// No description provided for @reciterName_mishary.
  ///
  /// In en, this message translates to:
  /// **'Mishary Rashid Alafasy'**
  String get reciterName_mishary;

  /// No description provided for @reciterName_sudais.
  ///
  /// In en, this message translates to:
  /// **'Abdul Rahman Al-Sudais'**
  String get reciterName_sudais;

  /// No description provided for @reciterName_shuraim.
  ///
  /// In en, this message translates to:
  /// **'Saud Al-Shuraim'**
  String get reciterName_shuraim;

  /// No description provided for @reciterName_muaiqly.
  ///
  /// In en, this message translates to:
  /// **'Maher Al-Muaiqly'**
  String get reciterName_muaiqly;

  /// No description provided for @reciterName_dosari.
  ///
  /// In en, this message translates to:
  /// **'Yasser Al-Dosari'**
  String get reciterName_dosari;

  /// No description provided for @reciterName_ajmi.
  ///
  /// In en, this message translates to:
  /// **'Ahmed ibn Ali Al-Ajmi'**
  String get reciterName_ajmi;

  /// No description provided for @reciterName_ghamdi.
  ///
  /// In en, this message translates to:
  /// **'Saad Al-Ghamdi'**
  String get reciterName_ghamdi;

  /// No description provided for @reciterName_huthaify.
  ///
  /// In en, this message translates to:
  /// **'Ali Al-Huthaify'**
  String get reciterName_huthaify;

  /// No description provided for @reciterName_abdulbasit.
  ///
  /// In en, this message translates to:
  /// **'Abdul Basit Abdul Samad'**
  String get reciterName_abdulbasit;

  /// No description provided for @reciterName_husary.
  ///
  /// In en, this message translates to:
  /// **'Mahmoud Khalil Al-Husary'**
  String get reciterName_husary;

  /// No description provided for @reciterName_minshawi.
  ///
  /// In en, this message translates to:
  /// **'Mohamed Siddiq El-Minshawi'**
  String get reciterName_minshawi;

  /// No description provided for @reciterName_banna.
  ///
  /// In en, this message translates to:
  /// **'Mahmoud Ali Al-Banna'**
  String get reciterName_banna;

  /// No description provided for @reciterName_shatri.
  ///
  /// In en, this message translates to:
  /// **'Abu Bakr Ash-Shatri'**
  String get reciterName_shatri;

  /// No description provided for @reciterName_rifai.
  ///
  /// In en, this message translates to:
  /// **'Hani Ar-Rifai'**
  String get reciterName_rifai;

  /// No description provided for @reciterName_qasim.
  ///
  /// In en, this message translates to:
  /// **'Abdul Mohsen Al-Qasim'**
  String get reciterName_qasim;

  /// No description provided for @reciterName_fares.
  ///
  /// In en, this message translates to:
  /// **'Fares Abbad'**
  String get reciterName_fares;

  /// No description provided for @reciterName_tunaiji.
  ///
  /// In en, this message translates to:
  /// **'Khalifa Al-Tunaiji'**
  String get reciterName_tunaiji;

  /// No description provided for @reciterBio_mishary.
  ///
  /// In en, this message translates to:
  /// **'Kuwaiti reciter and imam, renowned for his soulful murattal recitation. He is an imam and khatib at the Grand Mosque in Kuwait.'**
  String get reciterBio_mishary;

  /// No description provided for @reciterBio_sudais.
  ///
  /// In en, this message translates to:
  /// **'Prominent Saudi qari and Imam of Masjid al-Haram in Makkah, known for his melodious and powerful recitation.'**
  String get reciterBio_sudais;

  /// No description provided for @reciterBio_shuraim.
  ///
  /// In en, this message translates to:
  /// **'Saudi qari and Imam of Masjid al-Haram, also a professor of fiqh, known for his distinct, clear recitation.'**
  String get reciterBio_shuraim;

  /// No description provided for @reciterBio_muaiqly.
  ///
  /// In en, this message translates to:
  /// **'Saudi imam and qari, Imam of the Grand Mosque in Makkah, recognized for his calm and beautiful recitation.'**
  String get reciterBio_muaiqly;

  /// No description provided for @reciterBio_dosari.
  ///
  /// In en, this message translates to:
  /// **'Saudi qari and imam, Imam and khatib at the Grand Mosque in Makkah, admired for his powerful recitation.'**
  String get reciterBio_dosari;

  /// No description provided for @reciterBio_ajmi.
  ///
  /// In en, this message translates to:
  /// **'Saudi qari, celebrated for his heartfelt and emotional recitation, especially during the night prayers of Ramadan.'**
  String get reciterBio_ajmi;

  /// No description provided for @reciterBio_ghamdi.
  ///
  /// In en, this message translates to:
  /// **'Saudi qari, known for his soft, gentle recitation. Former imam at the Prophet\'s Mosque in Madinah.'**
  String get reciterBio_ghamdi;

  /// No description provided for @reciterBio_huthaify.
  ///
  /// In en, this message translates to:
  /// **'Saudi qari and Imam of the Prophet\'s Mosque in Madinah, distinguished by his deep, moving recitation.'**
  String get reciterBio_huthaify;

  /// No description provided for @reciterBio_abdulbasit.
  ///
  /// In en, this message translates to:
  /// **'One of the greatest Egyptian reciters of all time, famous for his impeccable murattal and mujawwad recitations.'**
  String get reciterBio_abdulbasit;

  /// No description provided for @reciterBio_husary.
  ///
  /// In en, this message translates to:
  /// **'Renowned Egyptian qari, the first to record the complete Quran for radio, praised for his accuracy.'**
  String get reciterBio_husary;

  /// No description provided for @reciterBio_minshawi.
  ///
  /// In en, this message translates to:
  /// **'Legendary Egyptian qari, celebrated for his tearful and deeply moving recitation.'**
  String get reciterBio_minshawi;

  /// No description provided for @reciterBio_banna.
  ///
  /// In en, this message translates to:
  /// **'Egyptian qari known for his fast yet precise recitation, loved across the Muslim world.'**
  String get reciterBio_banna;

  /// No description provided for @reciterBio_shatri.
  ///
  /// In en, this message translates to:
  /// **'Saudi qari and former imam of the Grand Mosque in Makkah, known for his clear, soulful murattal recitation.'**
  String get reciterBio_shatri;

  /// No description provided for @reciterBio_rifai.
  ///
  /// In en, this message translates to:
  /// **'Egyptian qari, celebrated for his clear, powerful recitation and admired by millions across the Arab world.'**
  String get reciterBio_rifai;

  /// No description provided for @reciterBio_qasim.
  ///
  /// In en, this message translates to:
  /// **'Saudi imam and qari, Imam and khatib of the Prophet\'s Mosque in Madinah, known for his calm, measured recitation.'**
  String get reciterBio_qasim;

  /// No description provided for @reciterBio_fares.
  ///
  /// In en, this message translates to:
  /// **'Yemeni qari known for his fast yet precise recitation, popular across the Arab world.'**
  String get reciterBio_fares;

  /// No description provided for @reciterBio_tunaiji.
  ///
  /// In en, this message translates to:
  /// **'Qatari imam and qari, renowned for his melodious recitation of the Quran in Taraweeh prayers.'**
  String get reciterBio_tunaiji;

  /// No description provided for @playVerse.
  ///
  /// In en, this message translates to:
  /// **'Play Verse'**
  String get playVerse;

  /// No description provided for @playFromHere.
  ///
  /// In en, this message translates to:
  /// **'Play from here to end'**
  String get playFromHere;

  /// No description provided for @playFullSurah.
  ///
  /// In en, this message translates to:
  /// **'To the Surah End'**
  String get playFullSurah;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @noReciterDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Download a reciter first'**
  String get noReciterDownloaded;

  /// No description provided for @surahLabel.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get surahLabel;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @defaultReciter.
  ///
  /// In en, this message translates to:
  /// **'Default Reciter'**
  String get defaultReciter;

  /// No description provided for @playSingleVerse.
  ///
  /// In en, this message translates to:
  /// **'Play Verse'**
  String get playSingleVerse;

  /// No description provided for @playFromVerseToEndOfSurah.
  ///
  /// In en, this message translates to:
  /// **'Play to End of Surah'**
  String get playFromVerseToEndOfSurah;

  /// No description provided for @defaultReciterSet.
  ///
  /// In en, this message translates to:
  /// **'Default reciter set'**
  String get defaultReciterSet;

  /// No description provided for @selectReciter.
  ///
  /// In en, this message translates to:
  /// **'Select Reciter'**
  String get selectReciter;

  /// No description provided for @reciter.
  ///
  /// In en, this message translates to:
  /// **'Reciter'**
  String get reciter;

  /// No description provided for @mushaf.
  ///
  /// In en, this message translates to:
  /// **'Mushaf'**
  String get mushaf;

  /// No description provided for @surahOptions.
  ///
  /// In en, this message translates to:
  /// **'Surah Options'**
  String get surahOptions;

  /// No description provided for @playFullSurahFromStart.
  ///
  /// In en, this message translates to:
  /// **'Play Full Surah'**
  String get playFullSurahFromStart;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download {name}'**
  String downloadFailed(Object name);

  /// No description provided for @downloadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Download incomplete for {name}. Please retry.'**
  String downloadIncomplete(Object name);

  /// No description provided for @betaLabel.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get betaLabel;

  /// No description provided for @verseNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Verse number (1 - {max})'**
  String verseNumberHint(Object max);

  /// No description provided for @translation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translation;

  /// No description provided for @verseNumberError.
  ///
  /// In en, this message translates to:
  /// **'Enter a number between 1 and {max}'**
  String verseNumberError(Object max);

  /// No description provided for @azkar.
  ///
  /// In en, this message translates to:
  /// **'Azkar'**
  String get azkar;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get always;

  /// No description provided for @morningAzkar.
  ///
  /// In en, this message translates to:
  /// **'Morning Adhkar'**
  String get morningAzkar;

  /// No description provided for @eveningAzkar.
  ///
  /// In en, this message translates to:
  /// **'Evening Adhkar'**
  String get eveningAzkar;

  /// No description provided for @suratAlKahf.
  ///
  /// In en, this message translates to:
  /// **'Surat Al-Kahf'**
  String get suratAlKahf;

  /// No description provided for @generalAzkar.
  ///
  /// In en, this message translates to:
  /// **'Azkar & Duas'**
  String get generalAzkar;

  /// No description provided for @readSuratAlKahf.
  ///
  /// In en, this message translates to:
  /// **'Read Surat Al-Kahf'**
  String get readSuratAlKahf;

  /// No description provided for @ayahOfTheWeek.
  ///
  /// In en, this message translates to:
  /// **'Ayah of the Week'**
  String get ayahOfTheWeek;

  /// No description provided for @ayahOfTheWeekAd.
  ///
  /// In en, this message translates to:
  /// **'This is the Ayah of the Week in Bayan — try it!'**
  String get ayahOfTheWeekAd;

  /// No description provided for @shareAyah.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAyah;

  /// No description provided for @openInMushaf.
  ///
  /// In en, this message translates to:
  /// **'Open in Mushaf'**
  String get openInMushaf;

  /// No description provided for @shareAzkar.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAzkar;

  /// No description provided for @azkarShareAd.
  ///
  /// In en, this message translates to:
  /// **'This adhkar is from the Bayan app — try it!'**
  String get azkarShareAd;

  /// No description provided for @nextPrayer.
  ///
  /// In en, this message translates to:
  /// **'Next Prayer'**
  String get nextPrayer;

  /// No description provided for @adhan.
  ///
  /// In en, this message translates to:
  /// **'Adhan'**
  String get adhan;

  /// No description provided for @iqamah.
  ///
  /// In en, this message translates to:
  /// **'Iqamah'**
  String get iqamah;

  /// No description provided for @prayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get prayer;

  /// No description provided for @dailyDhikr.
  ///
  /// In en, this message translates to:
  /// **'Adhkar & Supplications'**
  String get dailyDhikr;

  /// No description provided for @adhanCountdown.
  ///
  /// In en, this message translates to:
  /// **'Adhan in {time}'**
  String adhanCountdown(Object time);

  /// No description provided for @iqamahCountdown.
  ///
  /// In en, this message translates to:
  /// **'Iqamah in {time}'**
  String iqamahCountdown(Object time);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get addBookmark;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet — tap the bookmark icon on any ayah'**
  String get noBookmarks;

  /// No description provided for @jumpToVerse.
  ///
  /// In en, this message translates to:
  /// **'Go to the verse being recited'**
  String get jumpToVerse;

  /// No description provided for @calculationMethod.
  ///
  /// In en, this message translates to:
  /// **'Prayer Calculation Method'**
  String get calculationMethod;

  /// No description provided for @autoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto (based on location)'**
  String get autoDetect;

  /// No description provided for @ummAlQura.
  ///
  /// In en, this message translates to:
  /// **'Umm Al-Qura'**
  String get ummAlQura;

  /// No description provided for @muslimWorldLeague.
  ///
  /// In en, this message translates to:
  /// **'Muslim World League'**
  String get muslimWorldLeague;

  /// No description provided for @egyptian.
  ///
  /// In en, this message translates to:
  /// **'Egyptian'**
  String get egyptian;

  /// No description provided for @isna.
  ///
  /// In en, this message translates to:
  /// **'ISNA'**
  String get isna;

  /// No description provided for @karachi.
  ///
  /// In en, this message translates to:
  /// **'Karachi'**
  String get karachi;

  /// No description provided for @iqamahDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Default iqamah times — actual times may vary by mosque'**
  String get iqamahDisclaimer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
