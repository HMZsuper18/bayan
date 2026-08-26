import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/database/hive_service.dart';
import '../../../../data/models/bookmark_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/bookmark_service.dart';
import '../mushaf_navigation.dart';

/// Shows the user's bookmarked verses. Tapping one closes the sheet and opens
/// the mushaf at that verse (highlighting it via the target-verse flow).
Future<void> showBookmarksSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const BookmarksSheet(),
  );
}

class BookmarksSheet extends StatelessWidget {
  const BookmarksSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    final sheetBody = Container(
      decoration: BoxDecoration(
        color: GlassConfig.enableBlur
            ? (colors.brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.25))
            : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(Icons.bookmark_rounded, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.bookmarks,
                  style: AppTextStyles.arabicTitle.copyWith(
                    fontSize: 16,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<BookmarkModel>>(
              stream: BookmarkService.instance.stream,
              initialData: BookmarkService.instance.bookmarks,
              builder: (context, snapshot) {
                final bookmarks =
                    snapshot.data ?? const <BookmarkModel>[];
                if (bookmarks.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noBookmarks,
                      style: AppTextStyles.englishBody.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    return _BookmarkTile(bookmark: bookmarks[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    return FractionallySizedBox(
      heightFactor: 0.75,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassConfig.enableBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: sheetBody,
              )
            : sheetBody,
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final BookmarkModel bookmark;

  const _BookmarkTile({required this.bookmark});

  void _open(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop();
    MushafNavigation.open(
      navigator.context,
      MushafNavigation.forVerse(
        surahId: bookmark.surahId,
        verseNumber: bookmark.verseNumber,
        page: bookmark.page,
        verseId: bookmark.verseId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final surah = HiveService.surahsBox.get(bookmark.surahId);
    final surahName = isRtl ? surah?.name ?? '' : surah?.englishName ?? '';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.menu_book_rounded,
          color: AppColors.primaryGreen,
          size: 20,
        ),
      ),
      title: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Text(
          surahName,
          style: AppTextStyles.arabicTitle.copyWith(
            fontSize: 14,
            color: colors.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Text(
        '${l10n.verse} ${bookmark.verseNumber} • ${l10n.page} ${bookmark.page}',
        style: AppTextStyles.englishBody.copyWith(
          fontSize: 11,
          color: colors.onSurface.withValues(alpha: 0.6),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        color: colors.onSurface.withValues(alpha: 0.5),
        onPressed: () => BookmarkService.instance.remove(bookmark.verseId),
      ),
      onTap: () => _open(context),
    );
  }
}