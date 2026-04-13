import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/api_service.dart';
import '../core/app_theme.dart';
import '../core/localization.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  InsightsScreenState createState() => InsightsScreenState();
}

class InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Map<String, dynamic>? _insightsData;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _trendsData;
  Map<String, dynamic>? _intelligenceData;
  Map<String, dynamic> _patternsData = {};
  Map<String, dynamic> _patternsCorrelations = {};
  bool _loading = true;
  String? _error;

  int _selectedTab = 0;

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
      final insightsData = await ApiService.getInsights();
      
      Map<String, dynamic>? dashData;
      Map<String, dynamic>? trendsData;
      try { dashData = await ApiService.getAnalyticsDashboardSummary(); } catch (_) {}
      try { trendsData = await ApiService.getAnalyticsWeeklyTrends(); } catch (_) {}

      Map<String, dynamic>? intelData;
      try { intelData = await ApiService.getBehavioralIntelligence(); } catch (_) {}

      Map<String, dynamic> patternsData = {};
      Map<String, dynamic> patternsCorr = {};
      try { patternsData = await ApiService.getLifePatterns(); } catch (_) {}
      try { patternsCorr = await ApiService.getAnalyticsCorrelations(); } catch (_) {}

      if (mounted) {
        setState(() { 
          _insightsData = insightsData;
          _dashboardData = dashData;
          _trendsData = trendsData;
          _intelligenceData = intelData;
          _patternsData = patternsData;
          _patternsCorrelations = patternsCorr;
          _loading = false; 
        });
        _animController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
        _animController.forward(from: 0.0);
      }
    }
  }

  Color _riskColor(String? risk) {
    switch ((risk ?? '').toLowerCase()) {
      case 'low': return AppTheme.accentGreen;
      case 'moderate': return AppTheme.accentAmber;
      case 'high': return AppTheme.accentRed;
      case 'critical': return Colors.redAccent;
      default: return AppTheme.accentBlue;
    }
  }
  
  String _stripEmoji(String text) {
    if (text.isEmpty) return text;
    if (text.runes.first > 1000) {
      return String.fromCharCodes(text.runes.skip(1)).trim();
    }
    return text.trim();
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return _buildLoadingSkeleton();

    if (_error != null || _insightsData == null) {
      return _buildEmptyState();
    }

    // ── Extract all data exactly as before ──
    final insightsRaw = List<String>.from(_insightsData!['insights'] ?? []);
    final recsRaw = List<String>.from(_insightsData!['recommendations'] ?? []);
    final insights = insightsRaw.map(_stripEmoji).toList();
    final recs = recsRaw.map(_stripEmoji).toList();
    final aiSummary = _stripEmoji(_insightsData!['summary'] ?? '');
    final stressScore = (_dashboardData?['stress_score'] as num?)?.toInt() ?? 0;
    final triggersRaw = List<dynamic>.from(_dashboardData?['triggers'] ?? []);
    final triggers = triggersRaw.map((t) => _stripEmoji(t.toString())).toList();
    
    final sleepList = List<num>.from(_trendsData?['sleep'] ?? []).map((e) => e.toDouble()).toList();
    final screenList = List<num>.from(_trendsData?['screen_time'] ?? []).map((e) => e.toDouble()).toList();
    final moodList = List<num>.from(_trendsData?['mood'] ?? []).map((e) => e.toDouble()).toList();

    // ── Behavioral analysis strings ──
    final sleepImpact = _calcSleepImpact(sleepList);
    final screenImpact = _calcScreenImpact(screenList);
    final moodImpact = _calcMoodImpact(moodList);

    // ── Risk scores ──
    final risk = _intelligenceData?['risk_scores'];
    final stability = (risk?['mental_stability'] as num?)?.toInt() ?? 0;
    final focus = (risk?['focus_score'] as num?)?.toInt() ?? 0;
    final burnoutRisk = risk?['burnout_risk'] ?? _insightsData!['overall_risk'] ?? 'Unknown';

    // ── Forecast ──
    final forecast = _intelligenceData?['stress_forecast'] as Map<String, dynamic>?;
    final forecastScore = (forecast?['predicted_score'] as num?)?.toInt() ?? stressScore;
    final forecastRisk = forecast?['risk_level'] as String? ?? burnoutRisk.toString();
    final forecastInsights = (forecast?['insights'] as List?)?.cast<String>() ?? [];
    final whatIf = forecast?['what_if'] as String? ?? '';

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => _load(),
        color: AppTheme.accentBlue,
        backgroundColor: AppTheme.bg(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──
                    Center(child: Text('Insights'.tr(context), style: AppTheme.headingLarge)),
                    SizedBox(height: 20),

                    // ── Top Summary Card ──
                    _buildSummaryCard(forecastScore, forecastRisk, stability, focus, burnoutRisk.toString()),
                    SizedBox(height: 16),

                    // ── Tab Bar ──
                    _buildTabBar(),
                    SizedBox(height: 16),

                    // ── Tab Content ──
                    if (_selectedTab == 0)
                      _buildForecastTab(forecastScore, forecastRisk, forecastInsights, whatIf)
                    else if (_selectedTab == 1)
                      _buildBehaviorTab(sleepImpact, screenImpact, moodImpact, stability, focus, burnoutRisk.toString())
                    else if (_selectedTab == 2)
                      _buildInsightsTab(insights, recs, aiSummary, triggers)
                    else
                      _buildWeeklyTab(sleepList, moodList, screenList),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  DATA HELPERS (unchanged logic, extracted)
  // ──────────────────────────────────────────────────────

  String _calcSleepImpact(List<double> sleepList) {
    if (sleepList.length < 2) return 'Not enough data to analyze sleep trends.';
    final latestSleep = sleepList.last;
    final avgSleep = sleepList.reduce((a, b) => a + b) / sleepList.length;
    final diff = (latestSleep - avgSleep).abs();
    if (latestSleep < avgSleep - 0.5) {
      return 'You slept ${diff.toStringAsFixed(1)} hours less than your weekly average, which may be contributing to higher stress.';
    } else if (latestSleep > avgSleep + 0.5) {
      return 'You slept ${diff.toStringAsFixed(1)} hours more than your weekly average. Great recovery!';
    }
    return 'Your sleep duration is perfectly consistent with your weekly average.';
  }

  String _calcScreenImpact(List<double> screenList) {
    if (screenList.length < 2) return 'Not enough data to analyze screen time.';
    final latestScreen = screenList.last;
    final avgScreen = screenList.reduce((a, b) => a + b) / screenList.length;
    if (avgScreen > 0) {
      final pct = ((latestScreen - avgScreen) / avgScreen * 100).round();
      if (pct > 10) return 'Your screen time increased by $pct% recently compared to your average.';
      if (pct < -10) return 'Your screen time decreased by ${pct.abs()}% recently. Good job disconnecting!';
      return 'Your screen time has remained stable compared to your weekly average.';
    }
    return 'Not enough data to analyze screen time.';
  }

  String _calcMoodImpact(List<double> moodList) {
    if (moodList.length < 3) return 'Not enough data to analyze mood stability.';
    final recentMoods = moodList.sublist(moodList.length - 3);
    double maxMood = recentMoods[0];
    double minMood = recentMoods[0];
    for (final m in recentMoods) {
      if (m > maxMood) maxMood = m;
      if (m < minMood) minMood = m;
    }
    final variance = maxMood - minMood;
    if (variance <= 1.5) return 'Your mood has remained highly stable over the last 3 days.';
    if (variance <= 3.0) return 'Your mood has been relatively stable, with minor fluctuations.';
    return 'Your mood has shown significant variability over the last 3 days.';
  }

  // ──────────────────────────────────────────────────────
  //  UI COMPONENTS
  // ──────────────────────────────────────────────────────

  Widget _buildSummaryCard(int stressScore, String risk, int stability, int focus, String burnout) {
    final rColor = _riskColor(risk);
    final burnColor = _riskColor(burnout);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Stress Tomorrow
              Expanded(child: _buildMetricBox(
                label: 'Stress Tomorrow'.tr(context),
                value: '$stressScore%',
                valueColor: rColor,
                badge: risk,
                badgeColor: rColor,
              )),
              SizedBox(width: 10),
              // Stability
              Expanded(child: _buildMetricBox(
                label: 'Stability'.tr(context),
                value: '$stability',
                valueColor: AppTheme.accentAmber,
              )),
              SizedBox(width: 10),
              // Focus
              Expanded(child: _buildMetricBox(
                label: 'Focus'.tr(context),
                value: '$focus',
                valueColor: AppTheme.accentAmber,
              )),
            ],
          ),
          SizedBox(height: 10),
          // Burnout banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: burnColor == AppTheme.accentGreen
                  ? AppTheme.accentGreen.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.08)
                  : burnColor == AppTheme.accentAmber
                      ? AppTheme.accentAmber.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.08)
                      : AppTheme.accentRed.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: burnColor, shape: BoxShape.circle),
                ),
                SizedBox(width: 8),
                Text('${"Burnout Risk".tr(context)}: ${burnout.toString().tr(context)}', style: GoogleFonts.dmSans(color: burnColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox({required String label, required String value, required Color valueColor, String? badge, Color? badgeColor}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.elevated(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.dmSans(color: AppTheme.textM(context), fontSize: 10, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(color: valueColor, fontSize: 22, fontWeight: FontWeight.bold, height: 1)),
          if (badge != null) ...[
            SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? valueColor).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge, style: GoogleFonts.dmSans(color: badgeColor ?? valueColor, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Forecast'.tr(context), 'Behavior'.tr(context), 'Insights'.tr(context), 'Weekly'.tr(context)];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final isActive = _selectedTab == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.accentBlue.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    e.value,
                    style: GoogleFonts.dmSans(
                      color: isActive ? AppTheme.accentPurple : AppTheme.textM(context),
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── TAB 0: Forecast ──
  Widget _buildForecastTab(int score, String risk, List<String> forecastInsights, String whatIf) {
    final rColor = _riskColor(risk);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score + risk badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$score%', style: GoogleFonts.outfit(color: AppTheme.textP(context), fontSize: 36, fontWeight: FontWeight.bold, height: 1)),
            SizedBox(width: 10),
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: rColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(risk.toString().tr(context), style: GoogleFonts.dmSans(color: rColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        SizedBox(height: 14),
        Divider(color: AppTheme.border(context), height: 1),
        SizedBox(height: 14),

        // Why this prediction
        if (forecastInsights.isNotEmpty) ...[
          Text('Why this prediction'.tr(context), style: GoogleFonts.outfit(color: AppTheme.textP(context), fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          ...forecastInsights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: AppTheme.accentPurple)),
                SizedBox(width: 12),
                Expanded(child: Text(insight, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 13, height: 1.4))),
              ],
            ),
          )),
          SizedBox(height: 14),
        ],

        // What If card
        if (whatIf.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.elevated(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_fix_high_rounded, color: AppTheme.accentPurple, size: 16),
                    SizedBox(width: 8),
                    Text('What if...'.tr(context), style: GoogleFonts.outfit(color: AppTheme.accentPurple, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: 8),
                Text(whatIf, style: GoogleFonts.dmSans(color: AppTheme.textP(context), fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
      ],
    );
  }

  // ── TAB 1: Behavior ──
  Widget _buildBehaviorTab(String sleepImpact, String screenImpact, String moodImpact, int stability, int focus, String burnout) {
    final drifts = List<Map<String, dynamic>>.from(_intelligenceData?['behavioral_drifts'] ?? []);
    final burnColor = _riskColor(burnout);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Behavioral Shifts ──
        if (drifts.isNotEmpty) ...[
          _buildSectionLabel('BEHAVIORAL SHIFTS'.tr(context)),
          SizedBox(height: 10),
          ...drifts.map((d) {
            final isUp = d['direction'] == 'up';
            final metric = d['metric']?.toString() ?? '';
            final insight = d['insight']?.toString() ?? '';
            final strength = d['data_strength']?.toString() ?? 'Low';
            final color = (metric == 'Screen Time' && isUp) || (metric == 'Sleep' && !isUp) || (metric == 'Mood' && !isUp)
                ? AppTheme.accentRed
                : AppTheme.accentGreen;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCardContainer(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 18),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(metric.tr(context), style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textP(context))),
                            const Spacer(),
                            _buildConfidenceBadge(strength)),
                          ]),
                          SizedBox(height: 4),
                          Text(insight, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 12, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 18),
        ],

        // ── Impact Cards ──
        _buildSectionLabel('BEHAVIORAL IMPACT'.tr(context)),
        SizedBox(height: 10),
        _buildBehaviorImpactCard(Icons.nightlight_round, 'Sleep Impact'.tr(context), sleepImpact, AppTheme.accentPurple),
        SizedBox(height: 10),
        _buildBehaviorImpactCard(Icons.phone_android_rounded, 'Screen Impact'.tr(context), screenImpact, AppTheme.accentBlue),
        SizedBox(height: 10),
        _buildBehaviorImpactCard(Icons.mood_rounded, 'Mood Stability'.tr(context), moodImpact, AppTheme.accentGreen),
        SizedBox(height: 18),

        // ── Risk Assessment Gauges ──
        _buildSectionLabel('RISK ASSESSMENT'.tr(context)),
        SizedBox(height: 10),
        _buildCardContainer(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildGauge('Stability'.tr(context), stability, stability >= 70 ? AppTheme.accentGreen : (stability >= 40 ? AppTheme.accentAmber : AppTheme.accentRed)),
                  _buildGauge('Focus'.tr(context), focus, focus >= 70 ? AppTheme.accentBlue : (focus >= 40 ? AppTheme.accentAmber : AppTheme.accentRed)),
                ],
              ),
              SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: burnColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: burnColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: burnColor, size: 16),
                    SizedBox(width: 6),
                    Text('${'Burnout Risk'.tr(context)}: ${burnout.tr(context)}', style: GoogleFonts.dmSans(color: burnColor, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── TAB 2: Insights ──
  Widget _buildInsightsTab(List<String> insights, List<String> recs, String aiSummary, List<String> triggers) {
    final correlations = List<Map<String, dynamic>>.from(_intelligenceData?['enhanced_correlations'] ?? []);
    final emerging = List<Map<String, dynamic>>.from(_intelligenceData?['emerging_patterns'] ?? []);
    final allSmartInsights = [...correlations, ...emerging].take(3).toList();

    // Interventions
    final interventions = List<Map<String, dynamic>>.from(_intelligenceData?['smart_interventions'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Smart Insights ──
        if (allSmartInsights.isNotEmpty) ...[
          _buildSectionLabel('SMART INSIGHTS'.tr(context)),
          SizedBox(height: 10),
          _buildCardContainer(
            child: Column(
              children: allSmartInsights.asMap().entries.map((entry) {
                final item = entry.value;
                final isEmerging = item['type'] == 'emerging';
                final title = item['title']?.toString() ?? '';
                final insight = item['insight']?.toString() ?? '';
                final strength = (item['data_strength'] ?? item['strength'] ?? 'Low').toString();
                final accentColor = isEmerging ? AppTheme.accentAmber : AppTheme.accentPurple;
                final isLast = entry.key == allSmartInsights.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                        child: Icon(isEmerging ? Icons.scatter_plot_rounded : Icons.link_rounded, color: accentColor, size: 14),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(child: Text(title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textP(context)))),
                              SizedBox(width: 6),
                              _buildConfidenceBadge(strength),
                            ]),
                            SizedBox(height: 3),
                            Text(insight, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 12, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 16),
        ],

        // ── Detected Patterns (moved from Dashboard) ──
        if (triggers.isNotEmpty) ...[
          _buildSectionLabel('DETECTED PATTERNS'.tr(context)),
          SizedBox(height: 10),
          _buildCardContainer(
            child: Column(
              children: triggers.asMap().entries.map((entry) {
                final isLast = entry.key == triggers.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: AppTheme.accentAmber)),
                      SizedBox(width: 12),
                      Expanded(child: Text(entry.value, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 13, height: 1.4))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 16),
        ],

        // ── AI Observations ──
        if (insights.isNotEmpty) ...[
          _buildSectionLabel('AI OBSERVATIONS'.tr(context)),
          SizedBox(height: 10),
          _buildCardContainer(
            child: Column(
              children: insights.map((item) {
                final isLast = item == insights.last;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: AppTheme.accentBlue)),
                      SizedBox(width: 12),
                      Expanded(child: Text(item, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 13, height: 1.4))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 16),
        ],

        // ── Suggestions ──
        if (interventions.isNotEmpty) ...[
          _buildSectionLabel('SUGGESTIONS'.tr(context)),
          SizedBox(height: 10),
          ...interventions.map((item) {
            final priority = item['priority']?.toString() ?? 'moderate';
            final color = priority == 'high' ? AppTheme.accentRed : AppTheme.accentAmber;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCardContainer(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.lightbulb_outline_rounded, color: color, size: 16),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text(item['suggestion']?.toString() ?? '', style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 13, height: 1.4))),
                  ],
                ),
              ),
            );
          }),
        ],

        // ── Recommendations ──
        if (recs.isNotEmpty) ...[
          _buildSectionLabel('RECOMMENDATIONS'.tr(context)),
          SizedBox(height: 10),
          _buildCardContainer(
            child: Column(
              children: recs.map((item) {
                final isLast = item == recs.last;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.accentGreen)),
                      SizedBox(width: 12),
                      Expanded(child: Text(item, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 13, height: 1.4))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // ── TAB 3: Weekly ──
  Widget _buildWeeklyTab(List<double> sleepList, List<double> moodList, List<double> screenList) {
    final avgSleep = sleepList.isNotEmpty ? (sleepList.reduce((a, b) => a + b) / sleepList.length).toStringAsFixed(1) : '--';
    final avgMood = moodList.isNotEmpty ? (moodList.reduce((a, b) => a + b) / moodList.length).toStringAsFixed(1) : '--';
    final avgScreen = screenList.isNotEmpty ? (screenList.reduce((a, b) => a + b) / screenList.length).toStringAsFixed(1) : '--';

    // Weekly summary from intelligence
    final summary = _intelligenceData?['weekly_summary'];
    final summaryText = summary?['summary']?.toString() ?? '';
    final moodTrend = summary?['mood_trend']?.toString() ?? 'stable';
    final sleepTrend = summary?['sleep_trend']?.toString() ?? 'stable';
    final screenTrend = summary?['screen_trend']?.toString() ?? 'stable';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Metric pills row ──
        Row(
          children: [
            Expanded(child: _buildPillMetric('Mood'.tr(context), avgMood, AppTheme.accentGreen)),
            SizedBox(width: 8),
            Expanded(child: _buildPillMetric('Sleep'.tr(context), '${avgSleep}h', AppTheme.accentBlue)),
            SizedBox(width: 8),
            Expanded(child: _buildPillMetric('Screen'.tr(context), '${avgScreen}h', AppTheme.accentPurple)),
          ],
        ),
        SizedBox(height: 16),

        // ── Trend chips ──
        if (summary != null && summary['has_data'] == true) ...[
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summaryText.isNotEmpty) ...[
                  Text(summaryText, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 13, height: 1.5)),
                  SizedBox(height: 14),
                ],
                Row(
                  children: [
                    Expanded(child: _buildTrendChip('Mood'.tr(context), moodTrend, false)),
                    SizedBox(width: 10),
                    Expanded(child: _buildTrendChip('Sleep'.tr(context), sleepTrend, false)),
                    SizedBox(width: 10),
                    Expanded(child: _buildTrendChip('Screen'.tr(context), screenTrend, true)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],

        // ── Life Patterns ──
        _buildSectionLabel('LIFE PATTERNS'.tr(context)),
        SizedBox(height: 10),
        ..._buildLifePatternsContent(),
      ],
    );
  }

  // ──────────────────────────────────────────────────────
  //  SHARED HELPERS
  // ──────────────────────────────────────────────────────

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(title, style: GoogleFonts.dmSans(color: AppTheme.textM(context), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
    );
  }

  Widget _buildConfidenceBadge(String strength) {
    final color = strength == 'High' || strength == 'Very Strong' || strength == 'Strong'
        ? AppTheme.accentGreen
        : strength == 'Moderate'
            ? AppTheme.accentAmber
            : AppTheme.textM(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(strength.toString().tr(context), style: GoogleFonts.dmSans(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildGauge(String label, int value, Color color) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 40,
          lineWidth: 6,
          percent: (value / 100).clamp(0.0, 1.0),
          animation: true,
          animationDuration: 1200,
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: color,
          backgroundColor: AppTheme.elevated(context),
          center: Text('$value', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ),
        SizedBox(height: 6),
        Text(label, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBehaviorImpactCard(IconData icon, String title, String desc, Color color) {
    return _buildCardContainer(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textP(context))),
                SizedBox(height: 3),
                Text(desc, style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.outfit(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(label, style: GoogleFonts.dmSans(color: AppTheme.textM(context), fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTrendChip(String label, String trend, bool inverted) {
    Color color;
    IconData icon;
    if (trend == 'improving') {
      color = inverted ? AppTheme.accentRed : AppTheme.accentGreen;
      icon = Icons.trending_up_rounded;
    } else if (trend == 'declining') {
      color = inverted ? AppTheme.accentGreen : AppTheme.accentRed;
      icon = Icons.trending_down_rounded;
    } else {
      color = AppTheme.accentBlue;
      icon = Icons.trending_flat_rounded;
    }

    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 14),
                SizedBox(width: 4),
                Text((trend[0].toUpperCase() + trend.substring(1)).tr(context), style: GoogleFonts.dmSans(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: GoogleFonts.dmSans(color: AppTheme.textM(context), fontSize: 10)),
      ],
    );
  }

  // ──────────────────────────────────────────────────────
  //  LIFE PATTERNS (ported content - unchanged logic)
  // ──────────────────────────────────────────────────────

  List<Widget> _buildLifePatternsContent() {
    final totalDays = _patternsData['total_days_analyzed'] ?? 0;
    final patterns = (_patternsData['patterns'] as List?) ?? [];

    if (patterns.isNotEmpty) {
      return _buildPatternCards(patterns);
    }

    if (totalDays < 3) {
      const minRequired = 5;
      return [
        _buildCardContainer(
          child: Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: AppTheme.accentPurple.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.insights_rounded, color: AppTheme.accentPurple, size: 24),
              ),
              SizedBox(height: 12),
              Text('Collecting Pattern Data'.tr(context), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textP(context))),
              SizedBox(height: 8),
              Text('Keep logging daily to discover long-term behavioral patterns.'.tr(context), style: AppTheme.mutedText, textAlign: TextAlign.center),
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalDays / minRequired,
                  backgroundColor: AppTheme.elevated(context),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentPurple),
                  minHeight: 4,
                ),
              ),
              SizedBox(height: 6),
              Text('$totalDays / $minRequired ${'days logged'.tr(context)}', style: AppTheme.mutedText),
            ],
          ),
        ),
      ];
    }

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
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: AppTheme.accentPurple)),
            SizedBox(width: 12),
            Expanded(child: Text(text, style: GoogleFonts.dmSans(color: AppTheme.textP(context), fontSize: 13, height: 1.4))),
          ],
        ),
      ));
    }

    if (bullets.isEmpty) {
      bullets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 5, color: AppTheme.accentPurple)),
            SizedBox(width: 12),
            Expanded(child: Text('We are starting to observe your behavioral trends contextually.'.tr(context), style: GoogleFonts.dmSans(color: AppTheme.textP(context), fontSize: 13, height: 1.4))),
          ],
        ),
      ));
    }

    return [
      _buildCardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppTheme.accentAmber, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('Early observations from your data.'.tr(context), style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textP(context)))),
              ],
            ),
            SizedBox(height: 12),
            ...bullets,
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildPatternCards(List<dynamic> patterns) {
    return patterns.asMap().entries.map<Widget>((entry) {
      final pattern = entry.value;
      final confidence = (pattern['confidence'] as num?)?.toDouble() ?? 0.0;
      final category = pattern['category']?.toString() ?? 'general';
      final dataPoints = pattern['data_points'] ?? 0;
      final dataStrength = pattern['data_strength']?.toString() ?? 'Low';

      Color catColor;
      IconData catIcon;
      switch (category) {
        case 'sleep': catColor = AppTheme.accentBlue; catIcon = Icons.nightlight_round; break;
        case 'screen_time': catColor = const Color(0xFFE040FB); catIcon = Icons.phone_android_rounded; break;
        case 'exercise': catColor = AppTheme.accentGreen; catIcon = Icons.fitness_center_rounded; break;
        case 'lifestyle': catColor = AppTheme.accentAmber; catIcon = Icons.calendar_today_rounded; break;
        default: catColor = AppTheme.accentPurple; catIcon = Icons.insights_rounded;
      }

      final confColor = confidence >= 0.7 ? AppTheme.accentGreen : (confidence >= 0.5 ? AppTheme.accentAmber : AppTheme.accentRed);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: catColor.withValues(alpha: confidence > 0.7 ? 0.3 : 0.1), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(catIcon, color: catColor, size: 16),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text(pattern['title']?.toString() ?? '', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textP(context)))),
                ],
              ),
              SizedBox(height: 10),
              Text(pattern['description']?.toString() ?? '', style: GoogleFonts.dmSans(color: AppTheme.textS(context), fontSize: 12, height: 1.4)),
              SizedBox(height: 12),
              Row(
                children: [
                  Text('Confidence'.tr(context), style: GoogleFonts.dmSans(color: AppTheme.textM(context), fontSize: 10, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('${(confidence * 100).toInt()}%', style: GoogleFonts.dmSans(color: confColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: confidence,
                  backgroundColor: AppTheme.elevated(context),
                  valueColor: AlwaysStoppedAnimation<Color>(confColor),
                  minHeight: 3,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  _buildConfidenceBadge(dataStrength),
                  const Spacer(),
                  Icon(Icons.data_usage_rounded, size: 10, color: AppTheme.textM(context)),
                  SizedBox(width: 3),
                  Text('$dataPoints ${'data points'.tr(context)}', style: GoogleFonts.dmSans(color: AppTheme.textM(context), fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ──────────────────────────────────────────────────────
  //  LOADING & EMPTY STATES
  // ──────────────────────────────────────────────────────

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Container(width: 120, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: AppTheme.card(context))),
          SizedBox(height: 6),
          Container(width: 180, height: 14, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppTheme.card(context))),
          SizedBox(height: 20),
          Container(width: double.infinity, height: 130, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: AppTheme.card(context))),
          SizedBox(height: 14),
          Container(width: double.infinity, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppTheme.card(context))),
          SizedBox(height: 14),
          for (int i = 0; i < 3; i++) ...[
            Container(width: double.infinity, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppTheme.card(context))),
            SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 48, color: AppTheme.textM(context).withValues(alpha: 0.4)),
              SizedBox(height: 16),
              Text('No Insights Yet'.tr(context), style: AppTheme.headingMedium),
              SizedBox(height: 8),
              Text('Log your daily data first to get personalized AI insights and recommendations.'.tr(context), style: AppTheme.mutedText, textAlign: TextAlign.center),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, size: 18),
                label: Text('Retry'.tr(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.15),
                  foregroundColor: AppTheme.accentBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
