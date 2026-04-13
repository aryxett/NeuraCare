import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../core/app_theme.dart';
import '../core/localization.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Map<String, dynamic>? _trends;
  bool _loading = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void refresh() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trends = await ApiService.getWeeklyTrends();
      if (mounted) {
        setState(() { _trends = trends; _loading = false; });
        _animController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _animController.forward(from: 0.0);
      }
    }
  }

  // ══════════════════════════════════════════════════════
  /// Build arrays for the last 7 calendar days (today-6 → today).
  /// Returns { 'labels': [...], 'sleep': [...], 'mood': [...], 'screen': [...] }
  Map<String, dynamic> _buildLast7Days(Map<String, dynamic> trends) {
    final now = DateTime.now();
    final labels = <String>[];
    final sleepArr = <double>[];
    final moodArr = <double>[];
    final screenArr = <double>[];

    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Build a lookup from date-string → index in raw arrays
    final rawDates = (trends['dates'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rawSleep = (trends['sleep'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final rawMood = (trends['mood'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final rawScreen = (trends['screen_time'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];

    final dateMap = <String, int>{};
    for (int i = 0; i < rawDates.length; i++) {
      dateMap[rawDates[i]] = i;
    }

    // For each of the last 7 days
    for (int d = 6; d >= 0; d--) {
      final day = now.subtract(Duration(days: d));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      labels.add(weekDays[day.weekday - 1]);

      if (dateMap.containsKey(key)) {
        final idx = dateMap[key]!;
        sleepArr.add(idx < rawSleep.length ? rawSleep[idx] : 0);
        moodArr.add(idx < rawMood.length ? rawMood[idx] : 0);
        screenArr.add(idx < rawScreen.length ? rawScreen[idx] : 0);
      } else {
        sleepArr.add(0);
        moodArr.add(0);
        screenArr.add(0);
      }
    }

    return {
      'labels': labels,
      'sleep': sleepArr,
      'mood': moodArr,
      'screen': screenArr,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2));
    }

    final rawSleep = (_trends?['sleep'] as List?) ?? [];

    if (rawSleep.isEmpty) {
      return _buildEmptyState();
    }

    final chartData = _buildLast7Days(_trends!);
    final dayLabels = chartData['labels'] as List<String>;
    final sleep = chartData['sleep'] as List<double>;
    final mood = chartData['mood'] as List<double>;
    final screenTime = chartData['screen'] as List<double>;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => _load(),
        color: AppTheme.accentBlue,
        backgroundColor: AppTheme.bg(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 20),
        physics: const AlwaysScrollableScrollPhysics(),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Center(child: Text('History'.tr(context), style: AppTheme.headingLarge)),
              SizedBox(height: 28),

              // ── Sleep BarChart ──
              _buildChartCard(
                title: 'Sleep Duration'.tr(context),
                icon: Icons.nightlight_round,
                iconColor: AppTheme.accentBlue,
                chart: _buildSleepBarChart(sleep, dayLabels),
                index: 0,
              ),
              SizedBox(height: 14),

              // ── Mood LineChart ──
              _buildChartCard(
                title: 'Mood Fluctuation'.tr(context),
                icon: Icons.sentiment_satisfied_rounded,
                iconColor: AppTheme.accentPurple,
                chart: _buildMoodLineChart(mood, dayLabels),
                index: 1,
              ),
              SizedBox(height: 14),

              // ── Screen Time LineChart ──
              _buildChartCard(
                title: 'Screen Time'.tr(context),
                icon: Icons.phone_android_rounded,
                iconColor: AppTheme.accentPurple,
                chart: _buildScreenTimeLineChart(screenTime, dayLabels),
                index: 2,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  UI HELPERS
  // ──────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: AppTheme.textM(context).withValues(alpha: 0.4)),
            SizedBox(height: 16),
            Text('No History Yet'.tr(context), style: AppTheme.headingMedium),
            SizedBox(height: 8),
            Text(
              'Start logging daily data to see your\nwellness trends over time.'.tr(context),
              style: AppTheme.mutedText,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget chart,
    required int index,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border(context), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: iconColor, size: 16),
                      ),
                      SizedBox(width: 10),
                      Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textP(context))),
                    ],
                  ),
                  SizedBox(height: 20),
                  SizedBox(height: 180, child: chart),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Sleep Bar Chart ──
  Widget _buildSleepBarChart(List<double> data, List<String> dayLabels) {
    if (data.isEmpty) {
      return Center(child: Text('Not enough data yet', style: AppTheme.mutedText));
    }

    return BarChart(
      BarChartData(
        maxY: 12,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 3,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border(context), strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 3,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('${value.toInt()}h', style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textM(context))),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= dayLabels.length) return SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(dayLabels[i], style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textM(context))),
                );
              },
            ),
          ),
        ),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
              toY: e.value,
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              color: AppTheme.accentBlue,
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 12,
                color: AppTheme.elevated(context),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  // ── Mood Line Chart ──
  Widget _buildMoodLineChart(List<double> data, List<String> dayLabels) {
    if (data.isEmpty) {
      return Center(child: Text('Not enough data yet', style: AppTheme.mutedText));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border(context), strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 2,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textM(context))),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= dayLabels.length) return SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(dayLabels[i], style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textM(context))),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: AppTheme.accentPurple,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: AppTheme.accentPurple,
                strokeColor: AppTheme.card(context),
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.accentPurple.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  // ── Screen Time Line Chart ──
  Widget _buildScreenTimeLineChart(List<double> data, List<String> dayLabels) {
    if (data.isEmpty) {
      return Center(child: Text('Not enough data yet', style: AppTheme.mutedText));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 16,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 4,
          getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border(context), strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 4,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}h', style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textM(context))),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= dayLabels.length) return SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(dayLabels[i], style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.textM(context))),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: AppTheme.accentPurple,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: AppTheme.accentPurple,
                strokeColor: AppTheme.card(context),
                strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.accentPurple.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
