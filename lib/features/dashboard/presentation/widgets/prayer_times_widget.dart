import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/models/prayer_time_model.dart';

String _prayerName(AppLocalizations l10n, String name) {
  switch (name) {
    case 'Fajr': return l10n.fajr;
    case 'Dhuhr': return l10n.dhuhr;
    case 'Asr': return l10n.asr;
    case 'Maghrib': return l10n.maghrib;
    case 'Isha': return l10n.isha;
    default: return name;
  }
}

/// Minutes between the adhan and the iqamah for each prayer. Maghrib is kept
/// short (performed right after sunset); Fajr gets the longest window so
/// worshippers can reach the mosque in time for the morning prayer.
int iqamahGapMinutes(String prayerName) {
  switch (prayerName) {
    case 'Fajr': return 20;
    case 'Dhuhr': return 10;
    case 'Asr': return 10;
    case 'Maghrib': return 5;
    case 'Isha': return 10;
    default: return 10;
  }
}

/// 12-hour clock time with a localized AM/PM marker (م / ص in Arabic).
String _localizedTime(BuildContext context, DateTime t) {
  final lang = Localizations.localeOf(context).languageCode;
  final hour = t.hour > 12 ? t.hour - 12 : t.hour;
  final minute = t.minute.toString().padLeft(2, '0');
  final isPm = t.hour >= 12;
  final period = lang == 'ar'
      ? (isPm ? 'م' : 'ص')
      : lang == 'ur'
          ? (isPm ? 'ش' : 'ص')
          : (isPm ? 'PM' : 'AM');
  return '$hour:$minute $period';
}

/// Countdown as MM:SS once under an hour, HH:MM:SS otherwise — e.g. "03:41".
String _formatCountdown(Duration d) {
  if (d.inSeconds < 0) d = Duration.zero;
  String two(int v) => v.toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
  return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}

/// The prayer currently in focus: the one whose adhan→iqamah window contains
/// [now], otherwise the first upcoming one (rolling to tomorrow's Fajr). Kept
/// in sync with the hero card's next-event logic.
String _activePrayerName(List<PrayerTimeModel> prayerTimes, DateTime now) {
  final prayers = prayerTimes.where((p) => p.name != 'Sunrise').toList();
  for (final p in prayers) {
    final iqamah = p.time.add(Duration(minutes: iqamahGapMinutes(p.name)));
    if (iqamah.isAfter(now)) return p.name;
  }
  return prayers.isNotEmpty ? prayers.first.name : '';
}

/// A liquid-glass island wrapping the location action: a frosted, blurred
/// circular button with a generous 44px touch target so it is easy to press.
class _LocationGlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool locating;

  const _LocationGlassButton({
    this.onPressed,
    this.locating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppLocalizations.of(context)!.updateLocation,
      child: GlassContainer(
        borderRadius: 22,
        blur: 14,
        opacity: 0.16,
        width: 44,
        height: 44,
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.35),
        ),
        child: locating
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primaryGreen,
                ),
              )
            : IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(
                  Icons.my_location,
                  color: AppColors.primaryGreen,
                ),
                onPressed: onPressed,
              ),
      ),
    );
  }
}

/// SECTION 1 — Prayer Times. The visual anchor of the home screen: a deep teal
/// hero countdown card (next prayer, live countdown, adhan→iqamah progress,
/// azan/iqamah times) followed by a slim horizontal schedule of all five
/// prayers with the current one highlighted.
class PrayerTimesWidget extends StatefulWidget {
  final List<PrayerTimeModel> prayerTimes;
  final VoidCallback? onLocationTap;
  final bool locating;

  const PrayerTimesWidget({
    super.key,
    required this.prayerTimes,
    this.onLocationTap,
    this.locating = false,
  });

  @override
  State<PrayerTimesWidget> createState() => _PrayerTimesWidgetState();
}

class _PrayerTimesWidgetState extends State<PrayerTimesWidget> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassContainer(
      borderRadius: 16,
      blur: 8,
      opacity: 0.12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: AppColors.primaryGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                l10n.prayerTimes,
                style: AppTextStyles.arabicTitle.copyWith(
                  fontSize: 16,
                  color: AppColors.primaryGreen,
                ),
              ),
              const Spacer(),
              _LocationGlassButton(
                locating: widget.locating,
                onPressed: widget.onLocationTap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NextPrayerSection(
            prayerTimes: widget.prayerTimes,
            now: _now,
          ),
          const SizedBox(height: 12),
          _PrayerScheduleBar(
            prayerTimes: widget.prayerTimes,
            now: _now,
          ),
        ],
      ),
    );
  }
}

/// A single prayer with its adhan and iqamah instants.
class _PrayerEvent {
  final PrayerTimeModel prayer;
  final DateTime adhan;
  final DateTime iqamah;

  _PrayerEvent(this.prayer, this.adhan, this.iqamah);
}

/// Hero countdown block: next prayer title + adhan time on top, a large
/// countdown with the adhan→iqamah progress bar in the middle, and the Azan /
/// Iqamah times side by side at the bottom.
class _NextPrayerSection extends StatelessWidget {
  final List<PrayerTimeModel> prayerTimes;
  final DateTime now;

  const _NextPrayerSection({
    required this.prayerTimes,
    required this.now,
  });

  static const _accent = Color(0xFFFFD9A0);

  List<_PrayerEvent> get _todayEvents {
    return prayerTimes
        .where((p) => p.name != 'Sunrise')
        .map((p) {
          final gap = Duration(minutes: iqamahGapMinutes(p.name));
          return _PrayerEvent(p, p.time, p.time.add(gap));
        })
        .toList();
  }

  /// The next event whose iqamah is still ahead. When the day is over, rolls
  /// over to tomorrow's Fajr.
  _PrayerEvent _computeNext(DateTime now, List<_PrayerEvent> events) {
    for (final e in events) {
      if (e.iqamah.isAfter(now)) return e;
    }
    final fajr = events.firstWhere((e) => e.prayer.name == 'Fajr');
    return _PrayerEvent(
      fajr.prayer,
      fajr.adhan.add(const Duration(days: 1)),
      fajr.iqamah.add(const Duration(days: 1)),
    );
  }

  /// Fraction of the adhan → iqamah window that has elapsed. Before the adhan
  /// this is 0; once only 3 of 10 minutes remain the bar is 70% full.
  double _progress(DateTime now, _PrayerEvent next) {
    final total = next.iqamah.difference(next.adhan);
    if (total.inMilliseconds <= 0) return 1.0;
    final elapsed = now.difference(next.adhan);
    return (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final events = _todayEvents;
    if (events.isEmpty) return const SizedBox.shrink();

    final next = _computeNext(now, events);
    final adhanRemaining = next.adhan.difference(now);
    final iqamahRemaining = next.iqamah.difference(now);
    final inIqamahWindow =
        adhanRemaining.inSeconds <= 0 && iqamahRemaining.inSeconds > 0;

    final countdown = _formatCountdown(
      inIqamahWindow ? iqamahRemaining : adhanRemaining,
    );
    final bigLabel = inIqamahWindow
        ? l10n.iqamahCountdown(countdown)
        : l10n.adhanCountdown(countdown);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B2E), Color(0xFF00674F), Color(0xFF008A6A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: next prayer name + adhan time (e.g. "المغرب - 7:03 م").
          Row(
            children: [
              const Icon(Icons.alarm_rounded, size: 18, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _prayerName(l10n, next.prayer.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _localizedTime(context, next.adhan),
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Center: large countdown + progress bar directly underneath.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              bigLabel,
              key: ValueKey(inIqamahWindow),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: inIqamahWindow ? _accent : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2.5),
            child: LinearProgressIndicator(
              value: _progress(now, next),
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: _accent,
            ),
          ),
          const SizedBox(height: 16),

          // Bottom: Azan time and Iqamah time side by side.
          Row(
            children: [
              Expanded(
                child: _TimeColumn(
                  label: l10n.adhan,
                  time: _localizedTime(context, next.adhan),
                  highlight: !inIqamahWindow,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _TimeColumn(
                  label: l10n.iqamah,
                  time: _localizedTime(context, next.iqamah),
                  highlight: inIqamahWindow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small label + time pair used for the Adhan / Iqamah columns.
class _TimeColumn extends StatelessWidget {
  final String label;
  final String time;
  final bool highlight;

  const _TimeColumn({
    required this.label,
    required this.time,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: highlight ? 0.95 : 0.6),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          time,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: highlight ? _NextPrayerSection._accent : Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Slim horizontal bar with all five prayers; the current (next) one gets an
/// accent marker on top so the schedule is scannable at a glance.
class _PrayerScheduleBar extends StatelessWidget {
  final List<PrayerTimeModel> prayerTimes;
  final DateTime now;

  const _PrayerScheduleBar({
    required this.prayerTimes,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final prayers = prayerTimes.where((p) => p.name != 'Sunrise').toList();
    if (prayers.isEmpty) return const SizedBox.shrink();

    final nextName = _activePrayerName(prayerTimes, now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final p in prayers) ...[
            Expanded(
              child: _ScheduleItem(
                name: _prayerName(l10n, p.name),
                time: _localizedTime(context, p.time),
                active: p.name == nextName,
              ),
            ),
            if (p != prayers.last)
              Container(
                width: 1,
                height: 24,
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final String name;
  final String time;
  final bool active;

  const _ScheduleItem({
    required this.name,
    required this.time,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (active)
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          const SizedBox(height: 3),
        const SizedBox(height: 6),
        Text(
          name,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? AppColors.primaryGreen
                : colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? AppColors.primaryGreen
                : colors.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
