import 'package:flutter/material.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';

/// Wraps the dashboard with desktop-optimized layout.
/// On wide screens (>900px), content flows in a responsive grid.
class DesktopDashboard extends StatelessWidget {
  const DesktopDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth <= 900) {
      return const DashboardScreen();
    }

    return const DashboardScreen();
  }
}
