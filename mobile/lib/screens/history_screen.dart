import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  HistoryScreenState createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
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
      final trends = await ApiService.getAnalyticsWeeklyTrends();
      if (mounted) {
        setState(() { _trends = trends; _loading = false; });
        _animController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF4B5563);

    final sleep = (_trends?['sleep'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final mood = (_trends?['mood'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    final screenTime = (_trends?['screen_time'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];

    if (sleep.isEmpty) {
      return Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_rounded, size: 48, color: secondaryTextColor),
              const SizedBox(height: 16),
              Text('No History Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
              const SizedBox(height: 8),
              Text('Start logging daily data to see your wellness trends over time.',
                style: TextStyle(color: secondaryTextColor), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: const Color(0xFF3B82F6),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
        physics: const AlwaysScrollableScrollPhysics(),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryTextColor.withOpacity(0.9))),
              const SizedBox(height: 4),
              Text('Your weekly cognitive patterns', style: TextStyle(color: secondaryTextColor, fontSize: 13, letterSpacing: 0.5)),
              const SizedBox(height: 32),

              _buildChartCard('Sleep Duration', Icons.bedtime_rounded, _buildBarChart(sleep, const Color(0xFF3B82F6), isDark), 0, const Color(0xFF3B82F6), primaryTextColor),
              const SizedBox(height: 16),
              _buildChartCard('Mood Fluctuation', Icons.sentiment_satisfied_rounded, _buildLineChart(mood, const Color(0xFF8B5CF6), isDark), 1, const Color(0xFF8B5CF6), primaryTextColor),
              const SizedBox(height: 16),
              _buildChartCard('Screen Time', Icons.smartphone_rounded, _buildLineChart(screenTime, const Color(0xFFEC4899), isDark), 2, const Color(0xFFEC4899), primaryTextColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, IconData icon, Widget chart, int index, Color color, Color primaryTextColor) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              borderOpacity: 0.15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: primaryTextColor)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(height: 180, child: chart),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarChart(List<double> data, Color color, bool isDark) {
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
              toY: e.value, width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [color.withOpacity(0.4), color],
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true, toY: 12,
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart(List<double> data, Color color, bool isDark) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                radius: 4, color: color, strokeColor: isDark ? const Color(0xFF0B1220) : Colors.white, strokeWidth: 2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [color.withOpacity(0.2), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
