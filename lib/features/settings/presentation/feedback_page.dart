import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/responsive_spacing.dart';
import '../../../core/widgets/glass_container.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const String _accessKey = 'f9d5ff4e-b48a-4982-aa65-7a2f313065f4';

  final _messageController = TextEditingController();
  final _otherTypeController = TextEditingController();
  String? _selectedCategory;
  bool _isSubmitting = false;
  String? _categoryError;
  String? _messageError;
  String? _submitError;

  @override
  void dispose() {
    _messageController.dispose();
    _otherTypeController.dispose();
    super.dispose();
  }

  String _categoryLabel(String value, AppLocalizations l10n) {
    return switch (value) {
      'bug' => l10n.feedbackCategoryBug,
      'suggestion' => l10n.feedbackCategorySuggestion,
      'other' => l10n.feedbackCategoryOther,
      _ => value,
    };
  }

  void _showCategoryPicker() {
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
                    l10n.feedbackCategory,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: AppColors.primaryGreenOf(context),
                    ),
                  ),
                ),
                const Divider(height: 0),
                _categoryTile(ctx, 'bug', l10n.feedbackCategoryBug),
                _categoryTile(
                    ctx, 'suggestion', l10n.feedbackCategorySuggestion),
                _categoryTile(ctx, 'other', l10n.feedbackCategoryOther),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(BuildContext ctx, String value, String label) {
    final selected = _selectedCategory == value;
    final onSurface = Theme.of(ctx).colorScheme.onSurface;
    return ListTile(
      title: Text(label, style: TextStyle(color: onSurface)),
      trailing: selected
          ? Icon(Icons.check, color: AppColors.primaryGreenOf(context))
          : null,
      onTap: () {
        setState(() {
          _selectedCategory = value;
          _categoryError = null;
        });
        Navigator.pop(ctx);
      },
    );
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final message = _messageController.text.trim();
    bool hasError = false;

    if (_selectedCategory == null) {
      setState(() => _categoryError = l10n.feedbackCategoryRequired);
      hasError = true;
    }

    if (_selectedCategory == 'other' &&
        _otherTypeController.text.trim().isEmpty) {
      setState(() => _categoryError = l10n.feedbackSpecifyType);
      hasError = true;
    }

    if (message.isEmpty) {
      setState(() => _messageError = l10n.feedbackEmpty);
      hasError = true;
    }

    if (hasError) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final category = _selectedCategory!;
    final categoryDisplay = category == 'other'
        ? '${_categoryLabel(category, l10n)}: ${_otherTypeController.text.trim()}'
        : _categoryLabel(category, l10n);

    try {
      await Dio().post(
        'https://api.web3forms.com/submit',
        data: {
          'access_key': _accessKey,
          'subject': '[Bayan App] $categoryDisplay',
          'from_name': 'Bayan App Feedback',
          'category': categoryDisplay,
          'message': message,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() => _submitError = l10n.feedbackError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
          title: Text(l10n.feedbackTitle),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.horizontalPadding(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    GlassContainer(
                      borderRadius: 20,
                      blur: 10,
                      opacity: 0.15,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryGreenOf(context).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.category_rounded,
                            color: AppColors.primaryGreenOf(context),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          l10n.feedbackCategory,
                          style: AppTextStyles.englishBody.copyWith(
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                        subtitle: Text(
                          _selectedCategory != null
                              ? _categoryLabel(_selectedCategory!, l10n)
                              : '',
                          style: AppTextStyles.englishBody.copyWith(
                            color: AppColors.primaryGreenOf(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                        ),
                        onTap: _showCategoryPicker,
                      ),
                    ),
                    if (_categoryError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 16),
                        child: Text(
                          _categoryError!,
                          style: AppTextStyles.englishBody.copyWith(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (_selectedCategory == 'other') ...[
                      const SizedBox(height: 12),
                      GlassContainer(
                        borderRadius: 20,
                        blur: 10,
                        opacity: 0.15,
                        padding: const EdgeInsets.all(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: TextField(
                            controller: _otherTypeController,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (_categoryError != null) {
                                setState(() => _categoryError = null);
                              }
                            },
                            style: AppTextStyles.tafseerText.copyWith(
                              color: onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.feedbackSpecifyType,
                              hintStyle: AppTextStyles.englishBody.copyWith(
                                color: onSurface.withValues(alpha: 0.4),
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    GlassContainer(
                      borderRadius: 20,
                      blur: 10,
                      opacity: 0.15,
                      padding: const EdgeInsets.all(4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _messageController,
                          maxLines: 6,
                          minLines: 5,
                          textInputAction: TextInputAction.newline,
                          onChanged: (_) {
                            if (_messageError != null) {
                              setState(() => _messageError = null);
                            }
                          },
                          style: AppTextStyles.tafseerText.copyWith(
                            color: onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.feedbackHint,
                            hintStyle: AppTextStyles.englishBody.copyWith(
                              color: onSurface.withValues(alpha: 0.4),
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_messageError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 16),
                        child: Text(
                          _messageError!,
                          style: AppTextStyles.englishBody.copyWith(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_submitError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _submitError!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.englishBody.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.horizontalPadding(context),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(
                                0,
                                0,
                                Directionality.of(context) == TextDirection.rtl
                                    ? -1.0
                                    : 1.0),
                          child: const Icon(Icons.send_rounded, size: 20),
                        ),
                  label: Text(l10n.feedbackSubmit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreenOf(context),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
