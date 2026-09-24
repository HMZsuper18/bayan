import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/settings_service.dart';
import '../../../services/adhan_notification_service.dart';
import '../../../services/app_icon_service.dart';
import '../../../services/ayah_widget_service.dart';
import '../../../services/dhikr_widget_service.dart';
import '../../../core/utils/prayer_time_calculator.dart';
import '../../../app.dart';
import 'about_page.dart';
import 'feedback_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _quranFontSize = 22;
  double _uiFontSize = 14;
  bool _isDark = false;
  String _mushafLayout = 'surahs';
  String _uiLanguage = 'ar';
  String _tafseerLanguage = 'ar';
  String _translationLanguage = 'en';
  String _prayerCalculationMethod = 'auto';
  bool _adhanEnabled = false;
  int _adhanReminderMinutes = 10;
  static const _channel = MethodChannel('com.hamzah.bayan/adhan_notifications');

  @override
  void initState() {
    super.initState();
    _quranFontSize = SettingsService.fontSize;
    _uiFontSize = SettingsService.uiFontSize;
    _isDark = SettingsService.isDarkMode;
    _mushafLayout = SettingsService.mushafLayout;
    _uiLanguage = SettingsService.uiLanguage;
    _tafseerLanguage = SettingsService.tafseerLanguage;
    _translationLanguage = SettingsService.translationLanguage;
    _prayerCalculationMethod = SettingsService.prayerCalculationMethod;
    _adhanEnabled = SettingsService.adhanEnabled;
    _adhanReminderMinutes = SettingsService.adhanReminderMinutes;
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isNotificationsEnabled');
      if (enabled == false && _adhanEnabled) {
        setState(() {
          _adhanEnabled = false;
          SettingsService.adhanEnabled = false;
        });
      }
    } on MissingPluginException {
      // Channel not available on this platform
    } on PlatformException {
      // Ignore on unsupported platforms
    }
  }

  Future<void> _toggleAdhanNotifications(bool value) async {
    if (value) {
      try {
        final enabled = await _channel.invokeMethod<bool>('isNotificationsEnabled');
        if (enabled == false) {
          if (!mounted) return;
          _showNotificationPermissionDialog();
          return;
        }
      } on PlatformException {
        // Proceed anyway on unsupported platforms
      }
      try {
        final canExact = await _channel.invokeMethod<bool>('canScheduleExactAlarms');
        if (canExact == false) {
          await _channel.invokeMethod('requestExactAlarmPermission');
        }
      } on PlatformException {
        // Ignore
      }
    }
    setState(() {
      _adhanEnabled = value;
      SettingsService.adhanEnabled = value;
    });
    _scheduleAdhan();
  }

  void _showNotificationPermissionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adhanNotifications),
        content: Text(l10n.notificationPermissionRequired),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openAppSettings();
            },
            child: Text(l10n.openSettings),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException {
      // Ignore
    }
  }

  void _onQuranFontSizeChanged(double value) {
    setState(() {
      _quranFontSize = value;
      SettingsService.fontSize = value;
    });
  }

  void _onUiFontSizeChanged(double value) {
    setState(() {
      _uiFontSize = value;
      SettingsService.uiFontSize = value;
    });
    App.of(context)?.rebuild();
  }

  void _toggleTheme() {
    App.of(context)?.toggleTheme();
    setState(() {
      _isDark = !_isDark;
    });
  }

  String _prayerMethodLabel(AppLocalizations l10n) {
    switch (_prayerCalculationMethod) {
      case 'auto': return l10n.autoDetect;
      case 'ummAlQura': return l10n.ummAlQura;
      case 'muslimWorldLeague': return l10n.muslimWorldLeague;
      case 'egyptian': return l10n.egyptian;
      case 'isna': return l10n.isna;
      case 'karachi': return l10n.karachi;
      default: return l10n.autoDetect;
    }
  }

  void _showCalculationMethodPicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          opacity: 1.8,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.calculationMethod,
                      style: AppTextStyles.arabicTitle.copyWith(
                        color: AppColors.primaryGreenOf(context),
                      ),
                    ),
                  ),
                  const Divider(height: 0),
                  _calcMethodTile(ctx, 'auto', l10n.autoDetect),
                  _calcMethodTile(ctx, 'ummAlQura', l10n.ummAlQura),
                  _calcMethodTile(ctx, 'muslimWorldLeague', l10n.muslimWorldLeague),
                  _calcMethodTile(ctx, 'egyptian', l10n.egyptian),
                  _calcMethodTile(ctx, 'isna', l10n.isna),
                  _calcMethodTile(ctx, 'karachi', l10n.karachi),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calcMethodTile(BuildContext ctx, String value, String label) {
    final selected = _prayerCalculationMethod == value;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreenOf(context))
          : null,
      onTap: () {
        setState(() {
          _prayerCalculationMethod = value;
          SettingsService.prayerCalculationMethod = value;
        });
        Navigator.pop(ctx);
      },
    );
  }

  void _showReminderPicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          opacity: 1.8,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.reminderBefore,
                      style: AppTextStyles.arabicTitle.copyWith(
                        color: AppColors.primaryGreenOf(context),
                      ),
                    ),
                  ),
                  const Divider(height: 0),
                  _reminderTile(ctx, 5, '5 ${l10n.minutes}'),
                  _reminderTile(ctx, 10, '10 ${l10n.minutes}'),
                  _reminderTile(ctx, 15, '15 ${l10n.minutes}'),
                  _reminderTile(ctx, 30, '30 ${l10n.minutes}'),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _reminderTile(BuildContext ctx, int minutes, String label) {
    final selected = _adhanReminderMinutes == minutes;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreenOf(context))
          : null,
      onTap: () {
        setState(() {
          _adhanReminderMinutes = minutes;
          SettingsService.adhanReminderMinutes = minutes;
        });
        Navigator.pop(ctx);
        _scheduleAdhan();
      },
    );
  }

  Future<void> _scheduleAdhan() async {
    final lat = SettingsService.latitude;
    final lng = SettingsService.longitude;
    final saved = SettingsService.prayerCalculationMethod;
    final method = saved == 'auto'
        ? PrayerTimeCalculator.detectMethod(lat, lng)
        : PrayerTimeCalculator.methodFromKey(saved);
    final times = PrayerTimeCalculator.calculate(
      latitude: lat,
      longitude: lng,
      method: method,
    );
    final prayerData = times
        .where((t) => t.name != 'Sunrise')
        .map((t) => {
              'name': t.name.toLowerCase(),
              'hour': t.time.hour,
              'minute': t.time.minute,
            })
        .toList();
    if (_adhanEnabled) {
      await AdhanNotificationService.instance.scheduleNotifications(
        prayerTimes: prayerData,
        reminderMinutes: _adhanReminderMinutes,
      );
    } else {
      await AdhanNotificationService.instance.cancelAll();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassBackground(
      child: Scaffold(
        appBar: AppBar(
          leading: GlassContainer(
            borderRadius: 20,
            blur: 6,
            opacity: 0.08,
            padding: EdgeInsets.zero,
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          title: Text(l10n.settings),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildSection(
              title: l10n.reading,
              children: [
                ListTile(
                  leading: Icon(Icons.text_fields, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.quranFontSize),
                  subtitle: Text('$_quranFontSize'),
                  trailing: SizedBox(
                    width: 120,
                    child: Slider(
                      value: _quranFontSize,
                      min: 16,
                      max: 72,
                      divisions: 14,
                      activeColor: AppColors.primaryGreenOf(context),
                      onChanged: _onQuranFontSizeChanged,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GlassContainer(
                    borderRadius: 12,
                    blur: 6,
                    opacity: 0.1,
                    padding: EdgeInsets.all(
                        (_quranFontSize * 0.3).clamp(12.0, 32.0)),
                    child: Center(
                      child: MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(1.0)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.arabicVerse.copyWith(
                              fontSize: _quranFontSize,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.font_download_outlined, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.uiFontSize),
                  subtitle: Text('$_uiFontSize'),
                  trailing: SizedBox(
                    width: 120,
                    child: Slider(
                      value: _uiFontSize,
                      min: 11,
                      max: 39,
                      divisions: 28,
                      activeColor: AppColors.primaryGreenOf(context),
                      onChanged: _onUiFontSizeChanged,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GlassContainer(
                    borderRadius: 12,
                    blur: 6,
                    opacity: 0.1,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l10n.demoTitle,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            l10n.demoSubtitle,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.chrome_reader_mode, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.mushafLayout),
                  subtitle: Text(
                    _mushafLayout == 'pages' ? l10n.pageView : l10n.surahView,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLayoutPicker(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSection(
              title: l10n.appearance,
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.dark_mode, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.darkMode),
                  subtitle: Text(_isDark ? l10n.enabled : l10n.disabled),
                  value: _isDark,
                  onChanged: (_) => _toggleTheme(),
                ),
                ListTile(
                  leading: Icon(Icons.palette_outlined, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.appIconDescription),
                  subtitle: Text(AppIconService.instance.currentVariant),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showIconPicker(l10n),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSection(
              title: l10n.notifications,
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.notifications_active, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.adhanNotifications),
                  subtitle: Text(_adhanEnabled ? l10n.enabled : l10n.disabled),
                  value: _adhanEnabled,
                  onChanged: (value) => _toggleAdhanNotifications(value),
                ),
                if (_adhanEnabled)
                  ListTile(
                    leading: Icon(Icons.timer, color: AppColors.primaryGreenOf(context)),
                    title: Text(l10n.reminderBefore),
                    subtitle: Text('$_adhanReminderMinutes ${l10n.minutes}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showReminderPicker(),
                  ),
                ListTile(
                  leading: Icon(Icons.access_time, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.calculationMethod),
                  subtitle: Text(_prayerMethodLabel(l10n)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCalculationMethodPicker(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSection(
              title: l10n.language,
              children: [
                ListTile(
                  leading: Icon(Icons.language, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.uiLanguage),
                  subtitle: Text(
                    _uiLanguage == 'en'
                        ? l10n.english
                        : _uiLanguage == 'ur'
                            ? l10n.urdu
                            : l10n.arabic,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showUILangPicker(),
                ),
                ListTile(
                  leading: Icon(Icons.subject, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.translationLanguage),
                  subtitle: Text(
                    _translationLanguage == 'ar'
                        ? l10n.disable
                        : _translationLanguage == 'en'
                            ? l10n.english
                            : l10n.urdu,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTranslationLangPicker(),
                ),
                ListTile(
                  leading: Icon(Icons.notes, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.tafseerLanguage),
                  subtitle: Text(
                    _tafseerLanguage == 'ar' ? l10n.arabic : l10n.english,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTafseerLangPicker(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSection(
              title: l10n.about,
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.aboutApp),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutPage()),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.feedback_outlined, color: AppColors.primaryGreenOf(context)),
                  title: Text(l10n.feedbackTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeedbackPage()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          opacity: 1.8,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.appIcon,
                      style: AppTextStyles.arabicTitle.copyWith(
                        color: AppColors.primaryGreenOf(context),
                      ),
                    ),
                  ),
                  const Divider(height: 0),
                  _iconTile(ctx, 'Classic', l10n.iconClassic),
                  _iconTile(ctx, 'Emerald', l10n.iconEmerald),
                  _iconTile(ctx, 'Midnight', l10n.iconMidnight),
                  _iconTile(ctx, 'Gold', l10n.iconGold),
                  _iconTile(ctx, 'Royal', l10n.iconRoyal),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconTile(BuildContext ctx, String variant, String label) {
    final selected = AppIconService.instance.currentVariant == variant;
    return ListTile(
      leading: Icon(
        variant == 'Classic' ? Icons.home_rounded
            : variant == 'Emerald' ? Icons.diamond_rounded
            : variant == 'Midnight' ? Icons.dark_mode_rounded
            : variant == 'Gold' ? Icons.star_rounded
            : Icons.workspace_premium_rounded,
        color: selected ? AppColors.primaryGreenOf(context) : null,
      ),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreenOf(context))
          : null,
      onTap: () async {
        final needsDockHelp = await AppIconService.instance.switchIcon(variant);
        if (!ctx.mounted || !mounted) return;
        setState(() {});
        Navigator.pop(ctx);
        // Show the glass dialog before finalize so the activity stays alive
        // (finalize may relaunch through the new alias). Only MIUI/HyperOS
        // returns true, and only when the alias state actually changed.
        if (needsDockHelp && mounted) {
          await _showDockIconHelp();
        }
        await AppIconService.instance.finalizeSwitch();
      },
    );
  }

  Future<void> _showDockIconHelp() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: GlassContainer(
            borderRadius: 20,
            blur: 12,
            opacity: 1.8,
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.dockIconHelpTitle,
                      style: AppTextStyles.arabicTitle.copyWith(
                        fontSize: 18,
                        color: AppColors.primaryGreenOf(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.dockIconHelpBody,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        height: 1.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.85),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            MaterialLocalizations.of(ctx).cancelButtonLabel,
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            AppIconService.instance.openLauncherSettings();
                          },
                          child: Text(
                            l10n.openSettings,
                            style: TextStyle(
                              color: AppColors.primaryGreenOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return GlassContainer(
      borderRadius: 16,
      blur: 8,
      opacity: 0.08,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: AppTextStyles.arabicTitle.copyWith(
                  fontSize: 16,
                  color: AppColors.primaryGreenOf(context),
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLayoutPicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          opacity: 1.8,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.chooseLayout,
                      style: AppTextStyles.arabicTitle.copyWith(
                        color: AppColors.primaryGreenOf(context),
                      ),
                    ),
                  ),
                  const Divider(height: 0),
                  _layoutTile(ctx, 'surahs', l10n.surahView, ''),
                  _layoutTile(ctx, 'pages', l10n.pageView, ''),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUILangPicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          opacity: 1.8,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.chooseLanguage,
                      style: AppTextStyles.arabicTitle.copyWith(
                        color: AppColors.primaryGreenOf(context),
                      ),
                    ),
                  ),
                  const Divider(height: 0),
                  _langTile(ctx, 'ar', l10n.arabic),
                  _langTile(ctx, 'en', l10n.english),
                  _langTile(ctx, 'ur', l10n.urdu),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTafseerLangPicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          opacity: 1.8,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.tafseerLanguage,
                      style: AppTextStyles.arabicTitle.copyWith(
                        color: AppColors.primaryGreenOf(context),
                      ),
                    ),
                  ),
                  const Divider(height: 0),
                  _tafseerLangTile(ctx, 'ar', l10n.arabic),
                  _tafseerLangTile(ctx, 'en', l10n.english),
                  _tafseerSoonTile(l10n.urdu, l10n.soon),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTranslationLangPicker() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          opacity: 1.8,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.translationLanguage,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: AppColors.primaryGreenOf(context),
                    ),
                  ),
                ),
                const Divider(height: 0),
                _translationLangTile(ctx, 'ar', l10n.disable),
                _translationLangTile(ctx, 'en', l10n.english),
                _translationLangTile(ctx, 'ur', l10n.urdu),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _translationLangTile(BuildContext ctx, String code, String label) {
    final selected = _translationLanguage == code;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreenOf(context))
          : null,
      onTap: () {
        setState(() {
          _translationLanguage = code;
          SettingsService.translationLanguage = code;
        });
        // Home-screen adhkar + ayah widgets show the same translation as the card.
        DhikrWidgetService.refresh();
        AyahWidgetService.refresh();
        Navigator.pop(ctx);
      },
    );
  }

  Widget _tafseerSoonTile(String label, String soon) {
    return ListTile(
      title: Text(label),
      subtitle:
          Text(soon, style: TextStyle(color: AppColors.textSecondary)),
      enabled: false,
      leading:
          Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 18),
    );
  }

  Widget _tafseerLangTile(
      BuildContext ctx, String code, String label) {
    final selected = _tafseerLanguage == code;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreenOf(context))
          : null,
      onTap: () {
        setState(() {
          _tafseerLanguage = code;
          SettingsService.tafseerLanguage = code;
        });
        Navigator.pop(ctx);
      },
    );
  }

  Widget _langTile(BuildContext ctx, String code, String label) {
    final selected = _uiLanguage == code;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreenOf(context))
          : null,
      onTap: () {
        setState(() {
          _uiLanguage = code;
          SettingsService.uiLanguage = code;
        });
        Navigator.pop(ctx);
        App.of(context)?.rebuild();
      },
    );
  }

  Widget _layoutTile(
    BuildContext ctx,
    String value,
    String title,
    String subtitle,
  ) {
    final selected = _mushafLayout == value;
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreenOf(context))
          : null,
      onTap: () {
        setState(() {
          _mushafLayout = value;
          SettingsService.mushafLayout = value;
        });
        Navigator.pop(ctx);
      },
    );
  }
}
