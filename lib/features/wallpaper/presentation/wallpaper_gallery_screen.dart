import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/models/wallpaper_model.dart';
import '../../../data/repositories/wallpaper_repository.dart';
import '../../../services/wallpaper_service.dart';
import '../bloc/wallpaper_bloc.dart';
import 'wallpaper_crop_screen.dart';

class WallpaperGalleryScreen extends StatelessWidget {
  const WallpaperGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          WallpaperBloc(repository: WallpaperRepository())
            ..add(const LoadWallpapers()),
      child: const WallpaperGalleryView(),
    );
  }
}

class WallpaperGalleryView extends StatefulWidget {
  const WallpaperGalleryView({super.key});

  @override
  State<WallpaperGalleryView> createState() => _WallpaperGalleryViewState();
}

class _WallpaperGalleryViewState extends State<WallpaperGalleryView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
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
          title: Text(l10n.wallpaperGallery),
        ),
        body: BlocBuilder<WallpaperBloc, WallpaperState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off,
                      size: 48,
                      color: AppColors.primaryGreenOf(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.wallpaperLoadError,
                      style: AppTextStyles.englishBody,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.read<WallpaperBloc>().add(
                        const LoadWallpapers(),
                      ),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            }

            final categories = state.categories;
            if (categories.isEmpty) {
              return Center(
                child: Text(l10n.noResults, style: AppTextStyles.englishBody),
              );
            }

            final selected = state.selectedCategory ?? categories.first;

            return Column(
              children: [
                // Category tabs
                SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      for (final c in categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _categoryChip(context, l10n, lang, state, c),
                        ),
                    ],
                  ),
                ),
                // Image count / description
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${selected.images.length} ${l10n.wallpapers}',
                          style: AppTextStyles.englishBody.copyWith(
                            color: AppColors.primaryGreenOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: selected.images.length,
                    itemBuilder: (context, index) {
                      final wallpaper = selected.images[index];
                      final repo = WallpaperRepository();
                      final fullUrl = repo.resolveUrl(wallpaper.url);
                      return _wallpaperCard(
                        context,
                        l10n,
                        lang,
                        wallpaper,
                        fullUrl,
                        index,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _categoryChip(
    BuildContext context,
    AppLocalizations l10n,
    String lang,
    WallpaperState state,
    WallpaperCategory category,
  ) {
    final isSelected = state.selectedCategoryId == category.id;
    final color = AppColors.primaryGreenOf(context);
    final label = category.localizedName(lang);

    return GestureDetector(
      onTap: () =>
          context.read<WallpaperBloc>().add(SelectCategory(category.id)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              height: 1.4,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _wallpaperCard(
    BuildContext context,
    AppLocalizations l10n,
    String lang,
    Wallpaper wallpaper,
    String fullUrl,
    int index,
  ) {
    final color = AppColors.primaryGreenOf(context);
    final title = wallpaper.localizedTitle(lang);
    return GestureDetector(
      onTap: () => _showPreview(context, l10n, fullUrl, title),
      child: GlassContainer(
        borderRadius: 14,
        blur: 8,
        opacity: 0.1,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Image.network(
                  fullUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: color,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.05),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                title,
                style: AppTextStyles.englishBody.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showPreview(
    BuildContext context,
    AppLocalizations l10n,
    String url,
    String title,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: GlassContainer(
          borderRadius: 20,
          blur: 12,
          opacity: 1.8,
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview: device-screen shaped window = exactly what will be set
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                        ),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio:
                                MediaQuery.of(ctx).size.width /
                                MediaQuery.of(ctx).size.height,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                        child: const Icon(
                                          Icons.error_outline,
                                          size: 48,
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.phone_android,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.onYourScreen,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: AppTextStyles.arabicTitle.copyWith(
                        fontSize: 16,
                        color: AppColors.primaryGreenOf(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              context: ctx,
                              icon: Icons.wallpaper,
                              label: l10n.setAsWallpaper,
                              color: AppColors.primaryGreenOf(context),
                              onTap: () async {
                                Navigator.pop(ctx);
                                await _downloadAndSet(context, url, title);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionButton(
                              context: ctx,
                              icon: Icons.download,
                              label: l10n.downloadWallpaper,
                              color: AppColors.primaryGreenOf(context),
                              onTap: () async {
                                Navigator.pop(ctx);
                                await _downloadOnly(context, url);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassContainer(
      borderRadius: 12,
      blur: 6,
      opacity: 0.1,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Downloads the image, then opens the screen-ratio crop step.
  /// Returns after the crop screen decides: set (true), failed (false),
  /// or cancelled (null — no snackbar).
  Future<void> _downloadAndSet(
    BuildContext context,
    String url,
    String title,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.downloadingWallpaper)));
    try {
      final path = await WallpaperService.instance.downloadImage(url);
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => WallpaperCropScreen(imagePath: path, title: title),
        ),
      );
      if (result == null || !context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result ? l10n.wallpaperSetSuccess : l10n.wallpaperSetFailed,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.wallpaperSetFailed)),
        );
      }
    }
  }

  Future<void> _downloadOnly(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.downloadingWallpaper)));
    try {
      await WallpaperService.instance.downloadImage(url);
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.wallpaperDownloaded)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.wallpaperSetFailed)),
        );
      }
    }
  }

}
