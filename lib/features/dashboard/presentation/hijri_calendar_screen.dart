import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/hijri_date.dart';

class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  late final PageController _pageController;
  late int _currentYear;
  late int _currentMonth;
  late int _todayHijriYear;
  late int _todayHijriMonth;
  late int _todayHijriDay;

  static const int _minYear = 1420;
  static const int _maxYear = 1480;
  static const int _totalMonths = (_maxYear - _minYear + 1) * 12;

  static const List<String> _weekDaysAr = [
    'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت',
  ];

  static const List<String> _weekDaysEn = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
  ];

  static const List<String> _weekDaysUr = [
    'اتوار', 'پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ',
  ];

  int _monthToPage(int year, int month) {
    return (year - _minYear) * 12 + (month - 1);
  }

  void _pageToMonth(int page) {
    _currentYear = _minYear + page ~/ 12;
    _currentMonth = (page % 12) + 1;
  }

  @override
  void initState() {
    super.initState();
    final today = HijriDate.today();
    _todayHijriYear = today[0];
    _todayHijriMonth = today[1];
    _todayHijriDay = today[2];
    _currentYear = _todayHijriYear;
    _currentMonth = _todayHijriMonth;
    _pageController = PageController(
      initialPage: _monthToPage(_todayHijriYear, _todayHijriMonth),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToToday() {
    final targetPage = _monthToPage(_todayHijriYear, _todayHijriMonth);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.primaryGreenOf(context);
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;

    final weekDays = locale == 'ar'
        ? _weekDaysAr
        : locale == 'ur'
            ? _weekDaysUr
            : _weekDaysEn;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E2420) : AppColors.creamWhite,
      appBar: AppBar(
        title: Text(
          locale == 'ar' ? 'التقويم الهجري' : 'Hijri Calendar',
        ),
        actions: [
          TextButton(
            onPressed: _goToToday,
            child: Text(
              locale == 'ar' ? 'اليوم' : 'Today',
              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded),
                  onPressed: _pageController.hasClients && _pageController.page! > 0
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  color: accent,
                ),
                Text(
                  '${HijriDate.monthName(_currentMonth, locale: locale)} $_currentYear',
                  style: AppTextStyles.arabicTitle.copyWith(
                    color: colors.onSurface,
                    fontSize: 20,
                  ),
                ),
                IconButton(
                  icon: Icon(Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded),
                  onPressed: _pageController.hasClients && _pageController.page! < _totalMonths - 1
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  color: accent,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(7, (i) {
                final isFriday = i == 5;
                return Expanded(
                  child: Center(
                    child: Text(
                      weekDays[i],
                      style: AppTextStyles.englishBody.copyWith(
                        color: isFriday
                            ? accent
                            : colors.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: isFriday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _totalMonths,
              onPageChanged: (page) {
                setState(() => _pageToMonth(page));
              },
              itemBuilder: (context, page) {
                final year = _minYear + page ~/ 12;
                final month = (page % 12) + 1;
                return _buildMonthGrid(year, month, accent, colors, locale);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(
    int year,
    int month,
    Color accent,
    ColorScheme colors,
    String locale,
  ) {
    final daysInMonth = HijriDate.daysInHijriMonth(year, month);
    final gregorianFirst = HijriDate.toGregorian(year, month, 1);
    final firstWeekday = DateTime(gregorianFirst[0], gregorianFirst[1], gregorianFirst[2]).weekday % 7;
    final totalCells = firstWeekday + daysInMonth;

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNum = index - firstWeekday + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox();
        }

        final isToday = year == _todayHijriYear &&
            month == _todayHijriMonth &&
            dayNum == _todayHijriDay;
        final weekday = index % 7;
        final isFriday = weekday == 5;

        return Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isToday ? accent : null,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday
                      ? Colors.white
                      : isFriday
                          ? accent
                          : colors.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
