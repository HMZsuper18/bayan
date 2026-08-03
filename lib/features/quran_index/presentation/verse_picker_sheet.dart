import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/surah_model.dart';
import '../../../l10n/app_localizations.dart';

Future<int?> showVersePicker(BuildContext context, SurahModel surah) {
  final verseController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final completer = Completer<int?>();

  showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return PopScope(
        canPop: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            color: colors.surface,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.onSurface.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${AppLocalizations.of(ctx)!.surah} ${surah.name}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _AutoFocusField(
                                controller: verseController,
                                surah: surah,
                                formKey: formKey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 52,
                              width: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) return;
                                  final verseNumStr = verseController.text.trim();
                                  final verseNum = verseNumStr.isEmpty ? 1 : int.parse(verseNumStr);
                                  Navigator.of(ctx).pop(verseNum);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                ),
                                child: const Icon(Icons.check, size: 24),
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
        ),
      );
    },
  ).then((result) {
    completer.complete(result);
  }).whenComplete(() {
    if (!completer.isCompleted) completer.complete(null);
    verseController.dispose();
  });

  return completer.future;
}

class _AutoFocusField extends StatefulWidget {
  final TextEditingController controller;
  final SurahModel surah;
  final GlobalKey<FormState> formKey;

  const _AutoFocusField({
    required this.controller,
    required this.surah,
    required this.formKey,
  });

  @override
  State<_AutoFocusField> createState() => _AutoFocusFieldState();
}

class _AutoFocusFieldState extends State<_AutoFocusField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: AppLocalizations.of(context)!.verseNumberHint(widget.surah.versesCount.toString()),
        hintTextDirection: TextDirection.rtl,
        hintStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: colors.onSurface.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return null;
        final n = int.tryParse(v);
        if (n == null || n < 1 || n > widget.surah.versesCount) {
          return AppLocalizations.of(context)!.verseNumberError(widget.surah.versesCount.toString());
        }
        return null;
      },
    );
  }
}
