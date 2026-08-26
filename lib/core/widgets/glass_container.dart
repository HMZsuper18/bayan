import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassConfig {
  static bool enableBlur = false;

  GlassConfig._();
}

class _GlassSurface extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final Color backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Decoration? foregroundDecoration;

  const _GlassSurface({
    required this.child,
    required this.borderRadius,
    required this.backgroundColor,
    this.border,
    this.boxShadow,
    this.foregroundDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: boxShadow,
      ),
      foregroundDecoration: foregroundDecoration,
      child: child,
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;
  final Decoration? foregroundDecoration;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;

  const GlassContainer({
    super.key,
    this.child,
    this.borderRadius = 16,
    this.blur = 8,
    this.opacity = 0.12,
    this.padding,
    this.margin,
    this.tint,
    this.border,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTint = tint ?? (isDark ? AppColors.darkBg : Colors.white);
    final effectiveOpacity = tint != null ? opacity : (isDark ? 0.25 : 0.15);
    final defaultBorder = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.35),
      width: 0.8,
    );
    final shadows = boxShadow ??
        [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];

    final surface = _GlassSurface(
      borderRadius: borderRadius,
      backgroundColor: effectiveTint.withValues(alpha: effectiveOpacity),
      border: border ?? defaultBorder,
      boxShadow: shadows,
      foregroundDecoration: foregroundDecoration,
      child: child,
    );

    if (!GlassConfig.enableBlur) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          clipBehavior: clipBehavior,
          child: surface,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: surface,
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  const GlassCard({
    super.key,
    this.child,
    this.borderRadius = 16,
    this.blur = 8,
    this.opacity = 0.12,
    this.padding,
    this.margin,
    this.tint,
    this.border,
    this.boxShadow,
    this.onTap,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(
      borderRadius: borderRadius,
      blur: blur,
      opacity: opacity,
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      tint: tint,
      border: border,
      boxShadow: boxShadow,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

class GlassBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GlassBackground({
    super.key,
    required this.child,
    this.colors,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColors = colors ??
        (isDark
            ? [const Color(0xFF0A1F1A), const Color(0xFF061210)]
            : [AppColors.creamWhite, AppColors.surfaceGreen]);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: defaultColors,
          begin: begin,
          end: end,
        ),
      ),
      child: child,
    );
  }
}

