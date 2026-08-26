import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/hive_service.dart';
import '../../../data/database/quran_index.dart';
import '../../../data/models/surah_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../mushaf/presentation/mushaf_navigation.dart';
import 'verse_picker_sheet.dart';

class QuranIndexScreen extends StatefulWidget {
  const QuranIndexScreen({super.key});

  @override
  State<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends State<QuranIndexScreen> {
  late List<SurahModel> _surahs;
  final _idx = QuranIndexService.instance;

  @override
  void initState() {
    super.initState();
    _surahs = HiveService.getAllSurahs();
    _surahs.sort((a, b) => a.id.compareTo(b.id));
  }

  void _navigateToSurah(int surahId, {int verseNumber = 1}) {
    MushafNavigation.openOnNextFrame(
      context,
      MushafNavigation.forSurah(
        surahId,
        verseNumber: verseNumber == 1 ? null : verseNumber,
      ),
    );
  }

  Future<void> _showVersePicker(SurahModel surah) async {
    final verseNum = await showVersePicker(context, surah);
    if (verseNum != null) {
      _navigateToSurah(surah.id, verseNumber: verseNum);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final isRtl = locale == 'ar' || locale == 'ur';
    final colors = Theme.of(context).colorScheme;
    return GlassBackground(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GlassContainer(
            borderRadius: 20,
            blur: 6,
            opacity: 0.08,
            padding: EdgeInsets.zero,
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          title: Text(
            l10n.indexTitle,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: _surahs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: _surahs.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildJuzSection(colors);
                  if (index == 1) return _buildHizbSection(colors);
                  final surah = _surahs[index - 2];
                  return _SurahTile(
                    surah: surah,
                    page: _idx.getSurahPage(surah.id),
                    colors: colors,
                    isRtl: isRtl,
                    onTap: () => _navigateToSurah(surah.id),
                    onLongPress: () => _showVersePicker(surah),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildJuzSection(ColorScheme colors) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Text(
              l10n.juzs,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final juzNum = i + 1;
                return _JuzHizbChip(
                  label: '${l10n.juz} $juzNum',
                  colors: colors,
                  onTap: () {
                    final target = _idx.navigateToJuz(juzNum);
                    if (target != null) {
                      MushafNavigation.open(
                        context,
                        MushafNavigation.forTarget(target),
                        replace: true,
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHizbSection(ColorScheme colors) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Text(
              l10n.hizbs,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 60,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final hizbNum = i + 1;
                return _JuzHizbChip(
                  label: '${l10n.hizb} $hizbNum',
                  colors: colors,
                  onTap: () {
                    final target = _idx.navigateToHizb(hizbNum);
                    if (target != null) {
                      MushafNavigation.open(
                        context,
                        MushafNavigation.forTarget(target),
                        replace: true,
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JuzHizbChip extends StatelessWidget {
  final String label;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _JuzHizbChip({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final SurahModel surah;
  final int page;
  final ColorScheme colors;
  final bool isRtl;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SurahTile({
    required this.surah,
    required this.page,
    required this.colors,
    required this.isRtl,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final revelationLabel = surah.revelationType == 'Makkah'
        ? l10n.makkah
        : l10n.madinah;
    final displayName = isRtl ? surah.name : surah.englishName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassContainer(
        borderRadius: 14,
        blur: 6,
        opacity: 0.06,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${surah.id}',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Directionality(
                          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                          child: Text(
                            '$displayName ($revelationLabel)',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${l10n.page} $page',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_left, size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
