import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/custom_painters.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';

class DashboardScreen extends StatefulWidget {
  final Function(bool) onStressUpdate;
  const DashboardScreen({super.key, required this.onStressUpdate});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _trends;
  bool _loading = true;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void refresh() => _load();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final summary = await ApiService.getAnalyticsDashboardSummary();
      final trends = await ApiService.getAnalyticsWeeklyTrends();
      
      final stress = (summary['stress_score'] as num).toDouble();
      widget.onStressUpdate(stress > 75);

      if (mounted) {
        setState(() {
          _summary = summary;
          _trends = trends;
          _loading = false;
        });
        _animController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = e.toString(); });
        _animController.forward(from: 0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF4B5563);
    final trackColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6), strokeWidth: 2),
      );
    }

    if (_error != null || _summary == null || _trends == null) {
      return Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: textColor),
              const SizedBox(height: 16),
              Text('No Analytics Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
              const SizedBox(height: 8),
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
              ],
              Text('Submit your first daily log to generate insights.',
                style: TextStyle(color: textColor), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: _load,
                label: const Text('Refresh Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFF3B82F6).withOpacity(0.1),
                  foregroundColor: isDark ? Colors.white : const Color(0xFF3B82F6),
                  elevation: 0,
                  side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : const Color(0xFF3B82F6).withOpacity(0.2)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final s = _summary!;
    final t = _trends!;
    
    final stressScore = (s['stress_score'] ?? 0.0) as num;
    final wellnessScore = (s['wellness_score'] ?? 0) as num;
    final burnoutRisk = (s['burnout_risk'] ?? 0.0) as num;
    final triggers = (s['triggers'] ?? []) as List<dynamic>;

    final avgSleep = (s['avg_sleep'] ?? 0.0) as num;
    final avgMood = (s['avg_mood'] ?? 0.0) as num;
    final avgScreen = (s['avg_screen_time'] ?? 0.0) as num;

    final double stressValue = stressScore.toDouble();
    final double wellnessValue = wellnessScore.toDouble();
    final double burnoutValue = burnoutRisk.toDouble();
    
    final double avgSleepVal = avgSleep.toDouble();
    final double avgMoodVal = avgMood.toDouble();
    final double avgScreenVal = avgScreen.toDouble();

    final weeklySleep = ((t['sleep'] ?? []) as List).map((e) => (e as num?)?.toDouble() ?? 0.0).toList();
    final weeklyMood = ((t['mood'] ?? []) as List).map((e) => (e as num?)?.toDouble() ?? 0.0).toList();

    String riskLabel = "Low";
    if (stressValue > 75) riskLabel = "Critical";
    else if (stressValue > 50) riskLabel = "High";
    else if (stressValue > 25) riskLabel = "Moderate";

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF3B82F6),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100), // extra bottom padding for floating nav
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text('Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white.withOpacity(0.9) : primaryTextColor)),
              const SizedBox(height: 4),
              Text('Your cognitive digital twin analysis', style: TextStyle(color: textColor, fontSize: 13, letterSpacing: 0.5)),
              const SizedBox(height: 24),

              // Main Gauges (Wellness & Stress)
              Row(
                children: [
                   Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          Text('Wellness', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 100, height: 100,
                            child: CustomPaint(
                              painter: WellnessRingPainter(score: wellnessValue, trackColor: trackColor),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${wellnessValue.toInt()}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryTextColor)),
                                    Text('/100', style: TextStyle(fontSize: 10, color: textColor)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassContainer(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          Text('AI Stress', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5)),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 100, height: 100,
                            child: CustomPaint(
                              painter: StressGaugePainter(stressScore: stressValue, trackColor: trackColor),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('${stressValue.toInt()}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryTextColor)),
                                    Text(riskLabel, style: TextStyle(fontSize: 10, color: riskLabel == 'Critical' || riskLabel == 'High' ? const Color(0xFFEF4444) : textColor, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // KPI Grid (Sleep, Screen, Mood)
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72, // Increased height ratio to prevent overflow
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKpiCard('Sleep', '${avgSleepVal.toStringAsFixed(1)}h', Icons.bedtime_rounded, const Color(0xFF3B82F6), primaryTextColor, textColor),
                  _buildKpiCard('Screen', '${avgScreenVal.toStringAsFixed(1)}h', Icons.smartphone_rounded, const Color(0xFFEC4899), primaryTextColor, textColor),
                  _buildKpiCard('Mood', '${avgMoodVal.toStringAsFixed(1)}/10', Icons.sentiment_satisfied_rounded, const Color(0xFF10B981), primaryTextColor, textColor),
                ],
              ),

              const SizedBox(height: 24),
              
              // Burnout Risk Card
              GlassContainer(
                padding: const EdgeInsets.all(24),
                borderOpacity: burnoutValue > 60 ? 0.5 : 0.1,
                baseColor: burnoutValue > 60 ? const Color(0xFFF59E0B) : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Row(
                           children: [
                             Icon(Icons.local_fire_department_rounded, color: burnoutValue > 60 ? const Color(0xFFF59E0B) : textColor, size: 20),
                             const SizedBox(width: 8),
                             Text('Burnout Risk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                           ],
                         ),
                         Text('${burnoutValue.toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: burnoutValue > 60 ? const Color(0xFFF59E0B) : Colors.white)),
                       ],
                     ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 10)],
                          ),
                          child: LinearProgressIndicator(
                            value: burnoutValue / 100,
                            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(burnoutValue > 60 ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        burnoutValue > 60 ? 'High risk. Your cognitive load indicates significant strain. Consider stepping back.' : 'Your behavioral patterns are well-balanced and sustainable.',
                        style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
                      ),
                   ],
                 ),
               ),

               const SizedBox(height: 32),

               // Stress Triggers
               if (triggers.isNotEmpty) ...[
                 Text('Detected Patterns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
                 const SizedBox(height: 16),
                 ...triggers.map((t) => Padding(
                   padding: const EdgeInsets.only(bottom: 12),
                   child: GlassContainer(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                     baseColor: const Color(0xFFEF4444),
                     borderOpacity: 0.2,
                     child: Row(
                       children: [
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), shape: BoxShape.circle),
                           child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                         ),
                         const SizedBox(width: 16),
                         Expanded(child: Text(t, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87))),
                       ],
                     ),
                   ),
                 )),
                 const SizedBox(height: 24),
               ],

               Text('Trend Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
               const SizedBox(height: 16),

               if (weeklySleep.isNotEmpty && weeklySleep.any((val) => val > 0)) ...[
                 _buildChartCard('Sleep Duration (7 Days)', _buildBarChart(weeklySleep, const Color(0xFF3B82F6), isDark), primaryTextColor),
                 const SizedBox(height: 16),
                 _buildChartCard('Mood Fluctuation (7 Days)', _buildLineChart(weeklyMood, const Color(0xFF8B5CF6), isDark), primaryTextColor),
               ] else ...[
                 Center(
                   child: Padding(
                     padding: const EdgeInsets.all(24.0),
                     child: Text('Insufficient data for trend analysis', style: TextStyle(color: textColor)),
                   ),
                 ),
               ],
             ],
           ),
         ),
       ),
     );
   }

   Widget _buildKpiCard(String title, String value, IconData icon, Color accentColor, Color primaryText, Color secondaryText) {
     return GlassContainer(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), // Reduced horizontal padding
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Container(
             padding: const EdgeInsets.all(6), // Reduced padding
             decoration: BoxDecoration(
               color: accentColor.withOpacity(0.1),
               borderRadius: BorderRadius.circular(10),
             ),
             child: Icon(icon, color: accentColor, size: 18), // Smaller icon
           ),
           const Spacer(), // Use Spacer to push content
           Text(title, style: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w500)),
           const SizedBox(height: 2),
           FittedBox(
             fit: BoxFit.scaleDown,
             alignment: Alignment.centerLeft,
             child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryText, letterSpacing: -0.5)), // Smaller font
           ),
         ],
       ),
     );
   }

   Widget _buildChartCard(String title, Widget chart, Color primaryText) {
     return GlassContainer(
       padding: const EdgeInsets.all(20),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primaryText)),
           const SizedBox(height: 24),
           SizedBox(height: 160, child: chart),
         ],
       ),
     );
   }

   Widget _buildBarChart(List<double> data, Color color, bool isDark) {
     return BarChart(
       BarChartData(
         gridData: FlGridData(show: false),
         borderData: FlBorderData(show: false),
         titlesData: FlTitlesData(show: false),
         barGroups: data.asMap().entries.map((e) {
           return BarChartGroupData(x: e.key, barRods: [
             BarChartRodData(
               toY: e.value, width: 12,
               borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
               gradient: LinearGradient(
                 begin: Alignment.bottomCenter, end: Alignment.topCenter,
                 colors: [color.withOpacity(0.3), color],
               ),
               backDrawRodData: BackgroundBarChartRodData(
                 show: true, toY: 10, // Max mock boundary
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
         minY: 0, maxY: 10,
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
                 colors: [color.withOpacity(0.3), Colors.transparent],
               ),
             ),
           ),
         ],
       ),
     );
   }
 }
