import 'package:flutter/material.dart';
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
  Map<String, dynamic>? _radarData;
  Map<String, dynamic>? _correlationsData;
  Map<String, dynamic>? _intelligenceData;
  Map<String, dynamic> _patternsData = {};
  Map<String, dynamic> _patternsCorrelations = {};
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
      // Always fetch insights; dashboard + trends are optional enrichment
      final insightsData = await ApiService.getInsights();
      
      Map<String, dynamic>? dashData;
      Map<String, dynamic>? trendsData;
      Map<String, dynamic>? radarData;
      try {
        dashData = await ApiService.getAnalyticsDashboardSummary();
      } catch (_) { /* Dashboard data is optional enrichment */ }
      try {
        trendsData = await ApiService.getAnalyticsWeeklyTrends();
      } catch (_) { /* Trends data is optional enrichment */ }
      try {
        radarData = await ApiService.getMentalStateRadar();
      } catch (_) { /* Radar data is optional enrichment */ }

      Map<String, dynamic>? intelData;
      try {
        intelData = await ApiService.getBehavioralIntelligence();
      } catch (_) { /* Intelligence data is optional enrichment */ }

      // Life Patterns data (merged from LifePatternsScreen)
      Map<String, dynamic> patternsData = {};
      Map<String, dynamic> patternsCorr = {};
      try {
        patternsData = await ApiService.getLifePatterns();
      } catch (_) {}
      try {
        patternsCorr = await ApiService.getAnalyticsCorrelations();
      } catch (_) {}

      if (mounted) {
        setState(() { 
          _insightsData = insightsData;
          _dashboardData = dashData;
          _trendsData = trendsData;
          _radarData = radarData;
          _intelligenceData = intelData;
          _patternsData = patternsData;
          _patternsCorrelations = patternsCorr;
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
      double maxMood = recentMoods[0];
      double minMood = recentMoods[0];
      for (final m in recentMoods) {
        if (m > maxMood) maxMood = m;
        if (m < minMood) minMood = m;
      }
      final variance = maxMood - minMood;
      if (variance <= 1.5) {
        moodImpact = "Your mood has remained highly stable over the last 3 days.";
      } else if (variance <= 3.0) {
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

            // ══════════════════════════════════════════════════════════════
            // Phase 5: Cognitive Stress Simulator (Forecast) - VERY TOP
            // ══════════════════════════════════════════════════════════════
            if (_intelligenceData != null) ...[
              ..._buildStressForecastSection(isDark, primaryTextColor, secondaryTextColor, cardColor),
            ],

            // Section 1: Mental State Overview
            if (_radarData != null && _radarData!['has_data'] == true) ...[
              _buildAnimatedItem(
                2,
                _buildSectionHeader('Mental State Radar', Icons.radar_rounded, primaryTextColor),
              ),
              const SizedBox(height: 16),
              _buildAnimatedItem(
                3,
                _buildMentalStateRadarCard(_radarData!, isDark, primaryTextColor, secondaryTextColor, cardColor),
              ),
              const SizedBox(height: 32),
            ],

            // Section 2: Behavioral Insights
            _buildAnimatedItem(
              4,
              _buildSectionHeader('Behavioral Insights', Icons.insights_rounded, primaryTextColor),
            ),
            const SizedBox(height: 16),
            _buildAnimatedItem(
              5,
              SizedBox(
                height: 220, // Increased height significantly for text breathing room
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

            // ══════════════════════════════════════════
            // Section 5: Intelligence — Risk Scores (F1)
            // ══════════════════════════════════════════
            if (_intelligenceData != null) ...[
              ..._buildRiskScoresSection(isDark, primaryTextColor, secondaryTextColor, cardColor),
              const SizedBox(height: 32),

              // Section 6: Behavioral Drift Alerts (F4)
              ..._buildDriftAlertsSection(isDark, primaryTextColor, secondaryTextColor, cardColor),

              // Section 7: Smart Insights Feed (F2 + F3)
              ..._buildSmartInsightsSection(isDark, primaryTextColor, secondaryTextColor, cardColor),

              // Section 8: Smart Interventions (F6)
              ..._buildInterventionsSection(isDark, primaryTextColor, secondaryTextColor, cardColor),

              // Section 9: Weekly Summary (F7)
              ..._buildWeeklySummarySection(isDark, primaryTextColor, secondaryTextColor, cardColor),
            ],

            // ══════════════════════════════════════════════════════
            // LIFE PATTERNS SECTION (merged from Patterns tab)
            // ══════════════════════════════════════════════════════
            const SizedBox(height: 16),
            _buildAnimatedItem(25, Divider(color: secondaryTextColor.withOpacity(0.15), thickness: 1)),
            const SizedBox(height: 24),
            _buildAnimatedItem(26, Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.psychology_rounded, color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Life Patterns', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTextColor)),
                    const SizedBox(height: 2),
                    Text(
                      _patternsData['message'] ?? 'Long-term behavioral trends',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ],
            )),
            const SizedBox(height: 20),
            ..._buildLifePatternsContent(isDark, primaryTextColor, secondaryTextColor, cardColor),
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

  Widget _buildMentalStateRadarCard(Map<String, dynamic> radarData, bool isDark, Color primary, Color secondary, Color cardColor) {
    final int stabilityIndex = radarData['mental_stability_index'] ?? 0;
    final String burnoutRisk = radarData['burnout_risk_level'] ?? 'Unknown';
    final String moodStability = radarData['mood_stability'] ?? 'Unknown';
    
    final riskColor = _riskColor(burnoutRisk);
    final stabilityColor = stabilityIndex >= 70 ? const Color(0xFF10B981) : (stabilityIndex >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    
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
                tween: Tween<double>(begin: 0.0, end: stabilityIndex.toDouble()),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return SizedBox(
                    width: 120, height: 120, // Increased size
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: 1.0,
                            backgroundColor: Colors.transparent,
                            color: stabilityColor.withOpacity(0.15), // slightly more visible track
                            strokeWidth: 8,
                          ),
                        ),
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: value / 100,
                            backgroundColor: Colors.transparent,
                            color: stabilityColor,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${value.toInt()}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: stabilityColor, height: 1.0)),
                            const SizedBox(height: 4),
                            Text('Index', style: TextStyle(fontSize: 13, color: secondary, fontWeight: FontWeight.w500)),
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
                        child: Text('$burnoutRisk Risk', style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 12),
                      Text("Your stress level is $burnoutRisk and relatively stable compared to the past week.", 
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

  // ════════════════════════════════════════════════════════
  // Section 5: Risk Scores (F1)
  // ════════════════════════════════════════════════════════
  List<Widget> _buildRiskScoresSection(bool isDark, Color primary, Color secondary, Color cardColor) {
    final risk = _intelligenceData?['risk_scores'];
    if (risk == null || risk['has_data'] != true) return [];

    final stability = (risk['mental_stability'] as num?)?.toInt() ?? 50;
    final focus = (risk['focus_score'] as num?)?.toInt() ?? 50;
    final burnout = risk['burnout_risk'] ?? 'Unknown';

    final stabilityColor = stability >= 70 ? const Color(0xFF10B981) : (stability >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    final focusColor = focus >= 70 ? const Color(0xFF3B82F6) : (focus >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    final burnoutColor = _riskColor(burnout);

    return [
      _buildAnimatedItem(10, _buildSectionHeader('Risk Assessment', Icons.shield_rounded, primary)),
      const SizedBox(height: 16),
      _buildAnimatedItem(11, GlassContainer(
        padding: const EdgeInsets.all(24),
        baseColor: cardColor,
        borderOpacity: isDark ? 0.1 : 0.05,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildGaugeColumn('Stability', stability, stabilityColor, secondary)),
                const SizedBox(width: 16),
                Expanded(child: _buildGaugeColumn('Focus', focus, focusColor, secondary)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: burnoutColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: burnoutColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department_rounded, color: burnoutColor, size: 18),
                  const SizedBox(width: 8),
                  Text('Burnout Risk: $burnout', style: TextStyle(color: burnoutColor, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      )),
    ];
  }

  Widget _buildGaugeColumn(String label, int value, Color color, Color secondary) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) {
            return SizedBox(
              width: 80, height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(child: CircularProgressIndicator(
                    value: 1.0, backgroundColor: Colors.transparent,
                    color: color.withOpacity(0.15), strokeWidth: 6,
                  )),
                  SizedBox.expand(child: CircularProgressIndicator(
                    value: val / 100, backgroundColor: Colors.transparent,
                    color: color, strokeWidth: 6, strokeCap: StrokeCap.round,
                  )),
                  Text('${val.toInt()}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: secondary, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // Section 6: Behavioral Drift Alerts (F4)
  // ════════════════════════════════════════════════════════
  List<Widget> _buildDriftAlertsSection(bool isDark, Color primary, Color secondary, Color cardColor) {
    final drifts = List<Map<String, dynamic>>.from(_intelligenceData?['behavioral_drifts'] ?? []);
    if (drifts.isEmpty) return [];

    return [
      _buildAnimatedItem(12, _buildSectionHeader('Behavioral Shifts', Icons.trending_up_rounded, primary)),
      const SizedBox(height: 16),
      ...drifts.asMap().entries.map((entry) {
        final d = entry.value;
        final isUp = d['direction'] == 'up';
        final metric = d['metric'] ?? '';
        final insight = d['insight'] ?? '';
        final pct = (d['change_pct'] as num?)?.abs() ?? 0;
        final color = (metric == 'Screen Time' && isUp) || (metric == 'Sleep' && !isUp) || (metric == 'Mood' && !isUp)
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981);
        final strength = d['data_strength'] ?? 'Low';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAnimatedItem(13 + entry.key, GlassContainer(
            padding: const EdgeInsets.all(16),
            baseColor: cardColor,
            borderOpacity: isDark ? 0.1 : 0.05,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(metric, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: primary)),
                          const Spacer(),
                          _buildConfidenceBadge(strength),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(insight, style: TextStyle(color: secondary, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        );
      }),
      const SizedBox(height: 32),
    ];
  }

  // ════════════════════════════════════════════════════════
  // Section 7: Smart Insights Feed (F2 + F3)
  // ════════════════════════════════════════════════════════
  List<Widget> _buildSmartInsightsSection(bool isDark, Color primary, Color secondary, Color cardColor) {
    final correlations = List<Map<String, dynamic>>.from(_intelligenceData?['enhanced_correlations'] ?? []);
    final emerging = List<Map<String, dynamic>>.from(_intelligenceData?['emerging_patterns'] ?? []);

    final allInsights = [...correlations, ...emerging];
    if (allInsights.isEmpty) return [];

    return [
      _buildAnimatedItem(16, _buildSectionHeader('Smart Insights', Icons.psychology_rounded, primary)),
      const SizedBox(height: 16),
      _buildAnimatedItem(17, GlassContainer(
        padding: const EdgeInsets.all(20),
        baseColor: cardColor,
        borderOpacity: isDark ? 0.1 : 0.05,
        child: Column(
          children: allInsights.asMap().entries.map((entry) {
            final item = entry.value;
            final isEmerging = item['type'] == 'emerging';
            final title = item['title'] ?? '';
            final insight = item['insight'] ?? '';
            final strength = item['data_strength'] ?? item['strength'] ?? 'Low';
            final accentColor = isEmerging ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);
            final isLast = entry.key == allInsights.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Icon(
                      isEmerging ? Icons.scatter_plot_rounded : Icons.link_rounded,
                      color: accentColor, size: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primary)),
                            const SizedBox(width: 8),
                            _buildConfidenceBadge(strength),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(insight, style: TextStyle(color: secondary, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      )),
      const SizedBox(height: 32),
    ];
  }

  // ════════════════════════════════════════════════════════
  // Section 8: Smart Interventions (F6)
  // ════════════════════════════════════════════════════════
  List<Widget> _buildInterventionsSection(bool isDark, Color primary, Color secondary, Color cardColor) {
    final interventions = List<Map<String, dynamic>>.from(_intelligenceData?['smart_interventions'] ?? []);
    if (interventions.isEmpty) return [];

    return [
      _buildAnimatedItem(18, _buildSectionHeader('Suggestions', Icons.lightbulb_rounded, primary)),
      const SizedBox(height: 16),
      ...interventions.asMap().entries.map((entry) {
        final item = entry.value;
        final priority = item['priority'] ?? 'moderate';
        final color = priority == 'high' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAnimatedItem(19 + entry.key, GlassContainer(
            padding: const EdgeInsets.all(16),
            baseColor: cardColor,
            borderOpacity: isDark ? 0.1 : 0.05,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.lightbulb_outline_rounded, color: color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item['suggestion'] ?? '', style: TextStyle(color: secondary, fontSize: 13, height: 1.4))),
              ],
            ),
          )),
        );
      }),
      const SizedBox(height: 32),
    ];
  }

  // ════════════════════════════════════════════════════════
  // Section 9: Weekly Summary (F7)
  // ════════════════════════════════════════════════════════
  List<Widget> _buildWeeklySummarySection(bool isDark, Color primary, Color secondary, Color cardColor) {
    final summary = _intelligenceData?['weekly_summary'];
    if (summary == null || summary['has_data'] != true) return [];

    final moodTrend = summary['mood_trend'] ?? 'stable';
    final sleepTrend = summary['sleep_trend'] ?? 'stable';
    final screenTrend = summary['screen_trend'] ?? 'stable';
    final strength = summary['data_strength'] ?? 'Low';

    Color trendColor(String trend, bool inverted) {
      if (trend == 'improving') return inverted ? const Color(0xFFEF4444) : const Color(0xFF10B981);
      if (trend == 'declining') return inverted ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      return const Color(0xFF3B82F6);
    }

    IconData trendIcon(String trend) {
      if (trend == 'improving') return Icons.trending_up_rounded;
      if (trend == 'declining') return Icons.trending_down_rounded;
      return Icons.trending_flat_rounded;
    }

    return [
      _buildAnimatedItem(22, _buildSectionHeader('Weekly Summary', Icons.date_range_rounded, primary)),
      const SizedBox(height: 16),
      _buildAnimatedItem(23, GlassContainer(
        padding: const EdgeInsets.all(20),
        baseColor: cardColor,
        borderOpacity: isDark ? 0.1 : 0.05,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(summary['summary'] ?? '', style: TextStyle(color: secondary, fontSize: 13, height: 1.5))),
                const SizedBox(width: 8),
                _buildConfidenceBadge(strength),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTrendChip('Mood', moodTrend, trendColor(moodTrend, false), trendIcon(moodTrend)),
                _buildTrendChip('Sleep', sleepTrend, trendColor(sleepTrend, false), trendIcon(sleepTrend)),
                _buildTrendChip('Screen', screenTrend, trendColor(screenTrend, true), trendIcon(screenTrend)),
              ],
            ),
          ],
        ),
      )),
    ];
  }

  Widget _buildTrendChip(String label, String trend, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(trend[0].toUpperCase() + trend.substring(1), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }

  Widget _buildConfidenceBadge(String strength) {
    final color = strength == 'High' ? const Color(0xFF10B981)
        : strength == 'Moderate' ? const Color(0xFFF59E0B)
        : const Color(0xFF6B7280);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(strength, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Life Patterns Content (ported from LifePatternsScreen)
  // ══════════════════════════════════════════════════════════════
  List<Widget> _buildLifePatternsContent(bool isDark, Color primaryText, Color secondaryText, Color cardColor) {
    final totalDays = _patternsData['total_days_analyzed'] ?? 0;
    final patterns = (_patternsData['patterns'] as List?) ?? [];

    // Level 1: Strong patterns exist
    if (patterns.isNotEmpty) {
      return _buildPatternCards(patterns, isDark, primaryText, secondaryText);
    }

    // Fallback: < 3 days
    if (totalDays < 3) {
      final minRequired = 5;
      return [
        _buildAnimatedItem(27, GlassContainer(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.insights_rounded, color: Color(0xFF8B5CF6), size: 28),
              ),
              const SizedBox(height: 16),
              Text('Collecting Pattern Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText)),
              const SizedBox(height: 10),
              Text(
                'Keep logging daily to discover long-term behavioral patterns.',
                style: TextStyle(color: secondaryText, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: totalDays / minRequired,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 6),
              Text('$totalDays / $minRequired days logged', style: TextStyle(color: secondaryText, fontSize: 11)),
            ],
          ),
        )),
      ];
    }

    // Levels 2 & 3: Emerging correlations (>= 3 days, no strong patterns)
    final corrList = (_patternsCorrelations['correlations'] as List?) ?? [];
    List<Widget> bullets = [];
    for (var corr in corrList) {
      if (corr['title'] == 'Insufficient Data' || corr['title'] == 'No Strong Correlations Yet') continue;
      final title = corr['title'] as String;
      final conf = corr['confidence_level'] as String;
      String text = corr['explanation'];

      if (title.contains('Sleep & Mood')) {
        text = conf == 'High' || conf == 'Moderate'
            ? 'Your sleep and mood show a moderate relationship'
            : 'Lower sleep may be affecting your mood';
      } else if (title.contains('Screen Time')) {
        text = conf == 'High' || conf == 'Moderate'
            ? 'Higher screen time shows a mild correlation with stress'
            : 'Screen time shows a slight association with stress';
      } else if (title.contains('Activity')) {
        text = conf == 'High' || conf == 'Moderate'
            ? 'Physical activity shows a moderate positive correlation with mood'
            : 'Your mood appears more stable on days with better physical activity';
      }

      bullets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: const Color(0xFF8B5CF6))),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: primaryText, fontSize: 13, height: 1.4))),
          ],
        ),
      ));
    }

    if (bullets.isEmpty) {
      bullets.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: const Color(0xFF8B5CF6))),
            const SizedBox(width: 12),
            Expanded(child: Text('We are starting to observe your behavioral trends contextually.', style: TextStyle(color: primaryText, fontSize: 13, height: 1.4))),
          ],
        ),
      ));
    }

    return [
      _buildAnimatedItem(27, GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: const Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('No strong patterns yet, but here are some early observations.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryText)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...bullets,
          ],
        ),
      )),
    ];
  }

  List<Widget> _buildPatternCards(List<dynamic> patterns, bool isDark, Color primaryText, Color secondaryText) {
    return patterns.asMap().entries.map<Widget>((entry) {
      final pattern = entry.value;
      final confidence = (pattern['confidence'] as num?)?.toDouble() ?? 0.0;
      final category = pattern['category'] ?? 'general';
      final dataPoints = pattern['data_points'] ?? 0;
      final dataStrength = pattern['data_strength'] ?? 'Low';

      Color catColor;
      IconData catIcon;
      switch (category) {
        case 'sleep': catColor = const Color(0xFF3B82F6); catIcon = Icons.bedtime_rounded; break;
        case 'screen_time': catColor = const Color(0xFFEC4899); catIcon = Icons.smartphone_rounded; break;
        case 'exercise': catColor = const Color(0xFF10B981); catIcon = Icons.fitness_center_rounded; break;
        case 'lifestyle': catColor = const Color(0xFFF59E0B); catIcon = Icons.calendar_today_rounded; break;
        default: catColor = const Color(0xFF8B5CF6); catIcon = Icons.insights_rounded;
      }

      final confColor = confidence >= 0.7 ? const Color(0xFF10B981) : (confidence >= 0.5 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
      Color strengthColor;
      switch (dataStrength) {
        case 'Very Strong': strengthColor = const Color(0xFF10B981); break;
        case 'Strong': strengthColor = const Color(0xFF3B82F6); break;
        case 'Moderate': strengthColor = const Color(0xFFF59E0B); break;
        default: strengthColor = const Color(0xFFEF4444);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _buildAnimatedItem(27 + entry.key, GlassContainer(
          padding: const EdgeInsets.all(18),
          borderOpacity: confidence > 0.7 ? 0.3 : 0.1,
          baseColor: catColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: catColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                    child: Icon(catIcon, color: catColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(pattern['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryText))),
                ],
              ),
              const SizedBox(height: 12),
              Text(pattern['description'] ?? '', style: TextStyle(color: secondaryText, fontSize: 13, height: 1.5)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Confidence', style: TextStyle(color: secondaryText, fontSize: 10, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('${(confidence * 100).toInt()}%', style: TextStyle(color: confColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: confidence,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(confColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: strengthColor.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
                    child: Text('$dataStrength evidence', style: TextStyle(color: strengthColor, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Icon(Icons.data_usage_rounded, size: 11, color: secondaryText),
                  const SizedBox(width: 3),
                  Text('$dataPoints data points', style: TextStyle(color: secondaryText, fontSize: 10)),
                ],
              ),
            ],
          ),
        )),
      );
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════
  // Phase 5: Cognitive Stress Simulator (Forecast)
  // ══════════════════════════════════════════════════════════════
  List<Widget> _buildStressForecastSection(bool isDark, Color primaryText, Color secondaryText, Color cardColor) {
    if (_intelligenceData == null) return [];
    
    final forecast = _intelligenceData!['stress_forecast'] as Map<String, dynamic>?;
    if (forecast == null) return [];
    
    final bool hasData = forecast['has_data'] ?? false;

    if (!hasData) {
      return [
        _buildAnimatedItem(
          10,
          _buildSectionHeader('Stress Forecast', Icons.timeline_rounded, primaryText),
        ),
        const SizedBox(height: 16),
        _buildAnimatedItem(11, GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.hourglass_empty_rounded, color: secondaryText, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  forecast['message'] ?? 'Collecting enough data to generate accurate stress predictions.',
                  style: TextStyle(color: secondaryText, fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 32),
      ];
    }

    final score = forecast['predicted_score'] as int? ?? 0;
    final riskLevel = forecast['risk_level'] as String? ?? 'Unknown';
    final confPct = forecast['confidence_pct'] as int? ?? 0;
    final confStr = forecast['confidence'] as String? ?? 'Low';
    final insights = (forecast['insights'] as List?)?.cast<String>() ?? [];
    final whatIf = forecast['what_if'] as String? ?? '';

    Color riskColor;
    switch (riskLevel) {
      case 'Low': riskColor = const Color(0xFF10B981); break;
      case 'Moderate': riskColor = const Color(0xFFF59E0B); break;
      case 'High': riskColor = const Color(0xFFEF4444); break;
      default: riskColor = secondaryText;
    }

    return [
      _buildAnimatedItem(10, _buildSectionHeader('Stress Forecast', Icons.timeline_rounded, primaryText)),
      const SizedBox(height: 16),
      
      _buildAnimatedItem(11, GlassContainer(
        padding: const EdgeInsets.all(24),
        borderOpacity: 0.15,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Score + Confidence
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Predicted Stress Tomorrow', style: TextStyle(color: secondaryText, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$score%', style: TextStyle(color: primaryText, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: riskColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                          child: Text(riskLevel, style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Confidence: $confPct%', style: TextStyle(color: secondaryText, fontSize: 11)),
                    const SizedBox(height: 6),
                    _buildConfidenceBadge(confStr),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            Divider(color: secondaryText.withOpacity(0.15), thickness: 1),
            const SizedBox(height: 16),
            
            // Bullet Insights
            if (insights.isNotEmpty) ...[
              Text('Why this prediction:', style: TextStyle(color: primaryText, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: const Color(0xFFC084FC))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(insight, style: TextStyle(color: secondaryText, fontSize: 13, height: 1.4))),
                  ],
                ),
              )),
              const SizedBox(height: 16),
            ],
            
            // What If Scenario
            if (whatIf.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF3B82F6), size: 16),
                        const SizedBox(width: 8),
                        Text('What if...', style: TextStyle(color: const Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      whatIf,
                      style: TextStyle(color: primaryText, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      )),
      const SizedBox(height: 32),
    ];
  }
}
