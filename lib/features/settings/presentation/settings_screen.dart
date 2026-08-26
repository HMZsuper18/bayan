import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/settings_service.dart';
import '../../../app.dart';
import 'about_page.dart';

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
  int _currentPage = 0;

  final _pageController = PageController();

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

  @override
  void dispose() {
    _pageController.dispose();
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
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildReadingSection(l10n),
                  _buildLanguageSection(l10n),
                ],
              ),
            ),
            _buildPageIndicator(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }

  Widget _buildReadingSection(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          title: l10n.reading,
          children: [
            ListTile(
              leading: Icon(
                Icons.text_fields,
                color: AppColors.primaryGreen,
              ),
              title: Text(l10n.quranFontSize),
              subtitle: Text('$_quranFontSize'),
              trailing: SizedBox(
                width: 120,
                child: Slider(
                  value: _quranFontSize,
                  min: 16,
                  max: 72,
                  divisions: 14,
                  activeColor: AppColors.primaryGreen,
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
              leading: Icon(
                Icons.font_download_outlined,
                color: AppColors.primaryGreen,
              ),
              title: Text(l10n.uiFontSize),
              subtitle: Text('$_uiFontSize'),
              trailing: SizedBox(
                width: 120,
                child: Slider(
                  value: _uiFontSize,
                  min: 11,
                  max: 39,
                  divisions: 28,
                  activeColor: AppColors.primaryGreen,
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
            SwitchListTile(
              secondary: Icon(
                Icons.dark_mode,
                color: AppColors.primaryGreen,
              ),
              title: Text(l10n.darkMode),
              subtitle: Text(_isDark ? l10n.enabled : l10n.disabled),
              value: _isDark,
              onChanged: (_) => _toggleTheme(),
            ),
            ListTile(
              leading: Icon(
                Icons.chrome_reader_mode,
                color: AppColors.primaryGreen,
              ),
              title: Text(l10n.mushafLayout),
              subtitle: Text(
                _mushafLayout == 'pages' ? l10n.pageView : l10n.surahView,
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _showLayoutPicker(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageSection(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          title: l10n.language,
          children: [
            ListTile(
              leading: Icon(Icons.language, color: AppColors.primaryGreen),
              title: Text(l10n.uiLanguage),
              subtitle: Text(
                _uiLanguage == 'en'
                    ? l10n.english
                    : _uiLanguage == 'ur'
                        ? l10n.urdu
                        : l10n.arabic,
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _showUILangPicker(),
            ),
            ListTile(
              leading:
                  Icon(Icons.subject, color: AppColors.primaryGreen),
              title: Text(l10n.translationLanguage),
              subtitle: Text(
                _translationLanguage == 'ar'
                    ? l10n.disable
                    : _translationLanguage == 'en'
                        ? l10n.english
                        : l10n.urdu,
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _showTranslationLangPicker(),
            ),
            ListTile(
              leading: Icon(Icons.notes, color: AppColors.primaryGreen),
              title: Text(l10n.tafseerLanguage),
              subtitle: Text(
                _tafseerLanguage == 'ar' ? l10n.arabic : l10n.english,
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _showTafseerLangPicker(),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.info_outline, color: AppColors.primaryGreen),
              title: Text(l10n.aboutApp),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutPage()),
              ),
            ),
          ],
        ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: AppTextStyles.arabicTitle.copyWith(
                fontSize: 16,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
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
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.chooseLayout,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: AppColors.primaryGreen,
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
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.chooseLanguage,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: AppColors.primaryGreen,
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
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.tafseerLanguage,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: AppColors.primaryGreen,
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
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.translationLanguage,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: AppColors.primaryGreen,
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
    );
  }

  Widget _translationLangTile(BuildContext ctx, String code, String label) {
    final selected = _translationLanguage == code;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreen)
          : null,
      onTap: () {
        setState(() {
          _translationLanguage = code;
          SettingsService.translationLanguage = code;
        });
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
          ? Icon(Icons.check, color: AppColors.primaryGreen)
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
          ? Icon(Icons.check, color: AppColors.primaryGreen)
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
          ? Icon(Icons.check, color: AppColors.primaryGreen)
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
