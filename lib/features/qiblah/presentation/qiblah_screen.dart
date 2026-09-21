import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/qiblah_calculator.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../data/database/settings_service.dart';
import '../../../l10n/app_localizations.dart';

class QiblahScreen extends StatefulWidget {
  const QiblahScreen({super.key});

  @override
  State<QiblahScreen> createState() => _QiblahScreenState();
}

class _QiblahScreenState extends State<QiblahScreen>
    with SingleTickerProviderStateMixin {
  double? _bearing;
  String? _error;
  bool _loading = true;
  StreamSubscription? _compassSub;

  late AnimationController _compassAnim;
  double _displayHeading = 0;
  double _filteredHeading = 0;
  bool _hasReceivedHeading = false;

  static const _kFilterAlpha = 0.25;
  static const _kMinAngularUpdate = 0.3;

  @override
  void initState() {
    super.initState();
    _compassAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _initCompass();
    _determinePosition();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _compassAnim.dispose();
    super.dispose();
  }

  double _normalizeAngle(double angle) {
    angle = angle % 360;
    if (angle < 0) angle += 360;
    return angle;
  }

  double _shortestAngleDiff(double from, double to) {
    var diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  void _initCompass() {
    final events = FlutterCompass.events;
    if (events == null) return;
    _compassSub = events.listen((event) {
      if (!mounted) return;

      final rawHeading = event.heading ?? 0;

      if (!_hasReceivedHeading) {
        _filteredHeading = rawHeading;
        _displayHeading = rawHeading;
        _hasReceivedHeading = true;
      } else {
        final diff = _shortestAngleDiff(_filteredHeading, rawHeading);
        _filteredHeading = _normalizeAngle(
          _filteredHeading + diff * _kFilterAlpha,
        );
      }

      final target = _filteredHeading;
      final visualDiff = _shortestAngleDiff(_displayHeading, target);
      if (visualDiff.abs() < _kMinAngularUpdate) return;

      final anim = Tween<double>(
        begin: _displayHeading,
        end: _displayHeading + visualDiff,
      ).animate(CurvedAnimation(
        parent: _compassAnim,
        curve: Curves.easeOutCubic,
      ));

      anim.addListener(() {
        if (!mounted) return;
        setState(() {
          _displayHeading = anim.value;
        });
      });

      _compassAnim.forward(from: 0);
    });
  }

  Future<void> _determinePosition() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Try cached location first for instant display
    final hasCachedLocation = SettingsService.lastLocationUpdate != null;
    if (hasCachedLocation) {
      final cachedLat = SettingsService.latitude;
      final cachedLng = SettingsService.longitude;
      final bearing = QiblahCalculator.calculate(cachedLat, cachedLng);
      setState(() {
        _bearing = bearing;
        _loading = false;
      });
    }

    // Then refresh with fresh GPS in the background
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (_bearing == null) {
          setState(() {
            _error = 'Location services are disabled.';
            _loading = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (_bearing == null) {
            setState(() {
              _error = 'Location permission denied.';
              _loading = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (_bearing == null) {
          setState(() {
            _error = 'Location permission permanently denied.';
            _loading = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final bearing = QiblahCalculator.calculate(
        position.latitude,
        position.longitude,
      );

      SettingsService.latitude = position.latitude;
      SettingsService.longitude = position.longitude;

      setState(() {
        _bearing = bearing;
        _loading = false;
      });
    } catch (e) {
      if (_bearing == null) {
        setState(() {
          _error = 'Failed to get location: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final accent = AppColors.primaryGreenOf(context);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.qiblah),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: _loading
              ? CircularProgressIndicator(color: accent)
              : _error != null
                  ? _buildError(colors, accent)
                  : _buildCompass(colors, accent, l10n),
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme colors, Color accent) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: GlassContainer(
        borderRadius: 20,
        blur: 12,
        opacity: 0.1,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: accent, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.englishBody.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _determinePosition,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompass(ColorScheme colors, Color accent, AppLocalizations l10n) {
    final bearing = _bearing!;
    final cardinal = QiblahCalculator.bearingToCardinal(bearing);
    final heading = _displayHeading;
    final qiblahAngle = bearing - heading;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            l10n.qiblahDirection,
            style: AppTextStyles.arabicTitle.copyWith(
              color: colors.onSurface,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${bearing.toStringAsFixed(1)}° $cardinal',
            style: AppTextStyles.englishBody.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Compass circle
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surface.withValues(alpha: 0.1),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    // Cardinal directions - rotate with device heading
                    Transform.rotate(
                      angle: -heading * pi / 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildCardinalLabel('N', -90, colors, accent, isQiblah: false),
                          _buildCardinalLabel('E', 0, colors, accent, isQiblah: false),
                          _buildCardinalLabel('S', 90, colors, accent, isQiblah: false),
                          _buildCardinalLabel('W', 180, colors, accent, isQiblah: false),
                        ],
                      ),
                    ),
                    // Qiblah arrow - points to Qiblah relative to device heading
                    Transform.rotate(
                      angle: qiblahAngle * pi / 180,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.navigation_rounded,
                            color: accent,
                            size: 48,
                          ),
                          Container(
                            width: 4,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accent,
                                  accent.withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Center dot
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    ),
                    // Kaaba icon at the Qiblah direction
                    Transform.rotate(
                      angle: qiblahAngle * pi / 180,
                      child: const Align(
                        alignment: Alignment(0, -1),
                        child: Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('🕋', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GlassContainer(
            borderRadius: 16,
            blur: 8,
            opacity: 0.08,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.qiblahInfo,
                      style: AppTextStyles.englishBody.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCardinalLabel(String label, double angle, ColorScheme colors, Color accent, {required bool isQiblah}) {
    final radians = angle * pi / 180;
    final radius = 120.0;
    final x = radius * cos(radians);
    final y = radius * sin(radians);

    return Transform.translate(
      offset: Offset(x, y),
      child: Text(
        label,
        style: TextStyle(
          color: isQiblah ? accent : colors.onSurface.withValues(alpha: 0.5),
          fontWeight: isQiblah ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }
}
