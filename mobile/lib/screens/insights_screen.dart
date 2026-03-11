import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../widgets/glass_container.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  InsightsScreenState createState() => InsightsScreenState();
}

class InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _insightsData;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _trendsData;
  bool _loading = true;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
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
    setState(() { _loading = true; _error = null; });
    try {
      final futures = await Future.wait([
        ApiService.getInsights(),
        ApiService.getDashboardSummary(),
        ApiService.getWeeklyTrends(),
      ]);

      if (mounted) {
        setState(() { 
          _insightsData = futures[0];
          _dashboardData = futures[1];
          _trendsData = futures[2];
          _loading = false; 
        });
        _animController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low': return const Color(0xFF10B981);
      case 'moderate': return const Color(0xFFF59E0B);
      case 'high': return const Color(0xFFEF4444);
      case 'critical': return const Color(0xFFFCA5A5);
      default: return const Color(0xFF3B82F6);
    }
  }
  
  String _stripEmoji(String text) {
    if (text.isEmpty) return text;
    // Remove the leading emoji character if backend provided one
    if (text.runes.first > 1000) {
      return String.fromCharCodes(text.runes.skip(1)).trim();
    }
    return text.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)));
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF4B5563);
    final cardColor = isDark ? Colors.white.withOpacity(0.04) : Colors.white;

    if (_error != null || _insightsData == null) {
      return Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 48, color: secondaryTextColor),
                const SizedBox(height: 16),
                Text('No Insights Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
                const SizedBox(height: 8),
                Text('Log your daily data first to get personalized AI insights and recommendations.',
                  style: TextStyle(color: secondaryTextColor), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    foregroundColor: primaryTextColor,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final risk = _insightsData!['overall_risk'] ?? 'Unknown';
    final insightsRaw = List<String>.from(_insightsData!['insights'] ?? []);
    final recsRaw = List<String>.from(_insightsData!['recommendations'] ?? []);
    
    // Clean emojis from backend strings
    final insights = insightsRaw.map(_stripEmoji).toList();
    final recs = recsRaw.map(_stripEmoji).toList();

    final aiSummary = _stripEmoji(_insightsData!['summary'] ?? '');
    
    final stressScore = (_dashboardData?['stress_score'] as num?)?.toInt() ?? 0;
    
    // Calculate simple behavioral insights based on trends vs average
    final sleepList = List<num>.from(_trendsData?['sleep'] ?? []).map((e) => e.toDouble()).toList();
    final screenList = List<num>.from(_trendsData?['screen_time'] ?? []).map((e) => e.toDouble()).toList();
    final moodList = List<num>.from(_trendsData?['mood'] ?? []).map((e) => e.toDouble()).toList();

    String sleepImpact = "Not enough data to analyze sleep trends.";
    if (sleepList.length >= 2) {
      final latestSleep = sleepList.last;
      final avgSleep = sleepList.reduce((a, b) => a + b) / sleepList.length;
      final diff = (latestSleep - avgSleep).abs();
      if (latestSleep < avgSleep - 0.5) {
        sleepImpact = "You slept ${diff.toStringAsFixed(1)} hours less than your weekly average, which may be contributing to higher stress.";
      } else if (latestSleep > avgSleep + 0.5) {
        sleepImpact = "You slept ${diff.toStringAsFixed(1)} hours more than your weekly average. Great recovery!";
      } else {
        sleepImpact = "Your sleep duration is perfectly consistent with your weekly average.";
      }
    }

    String screenImpact = "Not enough data to analyze screen time.";
    if (screenList.length >= 2) {
      final latestScreen = screenList.last;
      final avgScreen = screenList.reduce((a, b) => a + b) / screenList.length;
      if (avgScreen > 0) {
        final pct = ((latestScreen - avgScreen) / avgScreen * 100).round();
        if (pct > 10) {
          screenImpact = "Your screen time increased by $pct% recently compared to your average.";
        } else if (pct < -10) {
          screenImpact = "Your screen time decreased by ${pct.abs()}% recently. Good job disconnecting!";
        } else {
          screenImpact = "Your screen time has remained stable compared to your weekly average.";
        }
      }
    }

    String moodImpact = "Not enough data to analyze mood stability.";
    if (moodList.length >= 3) {
      final recentMoods = moodList.sublist(moodList.length - 3);
      final variance = recentMoods.reduce((math.max)) - recentMoods.reduce((math.min));
      if (variance <= 1.5) {
        moodImpact = "Your mood has remained highly stable over the last 3 days.";
      } else if (variance <= 3) {
        moodImpact = "Your mood has been relatively stable, with minor fluctuations.";
      } else {
        moodImpact = "Your mood has shown significant variability over the last 3 days.";
      }
    }

    return RefreshIndicator(
      onRefresh: () async => _load(),
      color: const Color(0xFF3B82F6),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnimatedItem(
              0,
              Text('Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryTextColor.withOpacity(0.9))),
            ),
            const SizedBox(height: 4),
            _buildAnimatedItem(
              1,
              Text('Cognitive digital twin insights', style: TextStyle(color: secondaryTextColor, fontSize: 13, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 32),

            // Section 1: Mental State Overview
            _buildAnimatedItem(
              2,
              _buildSectionHeader('Mental State', Icons.psychology_outlined, primaryTextColor),
            ),
            const SizedBox(height: 16),
            _buildAnimatedItem(
              3,
              _buildMentalStateCard(stressScore, risk, sleepImpact, isDark, primaryTextColor, secondaryTextColor, cardColor),
            ),
            const SizedBox(height: 32),

            // Section 2: Behavioral Insights
            _buildAnimatedItem(
              4,
              _buildSectionHeader('Behavioral Insights', Icons.insights_rounded, primaryTextColor),
            ),
            const SizedBox(height: 16),
            _buildAnimatedItem(
              5,
              SizedBox(
                height: 195, // Increased height to prevent bottom shadow clipping
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  children: [
                    _buildBehaviorCard('Sleep Impact', Icons.bedtime_rounded, const Color(0xFF8B5CF6), sleepImpact, cardColor, primaryTextColor, secondaryTextColor),
                    const SizedBox(width: 16),
                    _buildBehaviorCard('Screen Impact', Icons.smartphone_rounded, const Color(0xFF3B82F6), screenImpact, cardColor, primaryTextColor, secondaryTextColor),
                    const SizedBox(width: 16),
                    _buildBehaviorCard('Mood Stability', Icons.mood_rounded, const Color(0xFF10B981), moodImpact, cardColor, primaryTextColor, secondaryTextColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Section 3: AI Observations
            if (insights.isNotEmpty) ...[
              _buildAnimatedItem(
                6,
                _buildSectionHeader('AI Observations', Icons.auto_awesome_rounded, primaryTextColor),
              ),
              const SizedBox(height: 16),
              _buildAnimatedItem(
                7,
                _buildListCard(insights, Icons.circle, const Color(0xFF3B82F6), 6.0, cardColor, primaryTextColor, secondaryTextColor),
              ),
              const SizedBox(height: 32),
            ],

            // Section 4: AI Recommendations
            if (recs.isNotEmpty) ...[
              _buildAnimatedItem(
                8,
                _buildSectionHeader('Recommendations', Icons.check_circle_outline_rounded, primaryTextColor),
              ),
              const SizedBox(height: 16),
              _buildAnimatedItem(
                9,
                _buildListCard(recs, Icons.adjust_rounded, const Color(0xFF10B981), 16.0, cardColor, primaryTextColor, secondaryTextColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildMentalStateCard(int score, String risk, String summaryText, bool isDark, Color primary, Color secondary, Color cardColor) {
    final riskColor = _riskColor(risk);
    
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      baseColor: cardColor,
      borderOpacity: isDark ? 0.1 : 0.05,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Animated Circular Gauge
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: score.toDouble()),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return SizedBox(
                    width: 120, height: 120, // Increased size
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1.0,
                          backgroundColor: Colors.transparent,
                          color: riskColor.withOpacity(0.1),
                          strokeWidth: 8, // Thinner stroke
                        ),
                        CircularProgressIndicator(
                          value: value / 100,
                          backgroundColor: Colors.transparent,
                          color: riskColor,
                          strokeWidth: 8, // Thinner stroke
                          strokeCap: StrokeCap.round,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(value.toInt().toString(), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: riskColor, height: 1.0)),
                            const SizedBox(height: 4),
                            Text('Stress', style: TextStyle(fontSize: 13, color: secondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Trend Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: riskColor.withOpacity(0.3)),
                        ),
                        child: Text('$risk Risk', style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 12),
                      Text("Your stress level is $risk and relatively stable compared to the past week.", 
                        style: TextStyle(color: secondary, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorCard(String title, IconData icon, Color accent, String description, Color cardBg, Color primary, Color secondary) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(bottom: 8), // Shadow breathing room
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: primary))),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Text(description, style: TextStyle(color: secondary, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(List<String> items, IconData icon, Color iconColor, double iconSize, Color cardBg, Color primary, Color secondary) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      baseColor: cardBg,
      borderOpacity: Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.05,
      child: Column(
        children: items.map((item) {
          final isLast = item == items.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(icon, size: iconSize, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(item, style: TextStyle(color: secondary, fontSize: 14, height: 1.5)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0.0, 0.1 + (index * 0.05)), end: Offset.zero)
            .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}
