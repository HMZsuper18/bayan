import 'package:flutter/material.dart';

/// Centralized responsive spacing values.
///
/// Provides consistent, screen-aware padding and margins throughout the app.
/// On narrow phones (< 360px) spacing is tighter; on tablets (≥ 600px) it
/// widens to avoid cramped layouts.
class AppSpacing {
  AppSpacing._();

  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 32;
    if (w >= 600) return 24;
    if (w >= 400) return 16;
    return 12;
  }

  static double sectionSpacing(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 16;
    return 12;
  }

  static double cardSpacing(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 14;
    return 10;
  }

  static double cardInternalPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 20;
    return 16;
  }

  static double sliderWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 160;
    if (w >= 400) return 120;
    return 90;
  }
}
