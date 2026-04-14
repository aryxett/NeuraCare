import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/api_service.dart';
import '../core/app_theme.dart';
import '../core/localization.dart';
import 'log_entry_screen.dart';
import 'meditation_screen.dart';
import '../models/daily_article.dart';
import '../models/daily_routine.dart';
import 'daily_article_screen.dart';
import 'dart:ui';

class DashboardScreen extends StatefulWidget {
  final Function(bool) onStressUpdate;
  final VoidCallback? onLogSubmitted;

  const DashboardScreen({
    super.key,
    required this.onStressUpdate,
    this.onLogSubmitted,
  });

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _trends;
  bool _loading = true;
  bool _hasCheckedInMood = true;
  bool _submittingMood = false;
  String? _selectedMood;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void refresh() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await ApiService.getAnalyticsDashboardSummary();
      final trends = await ApiService.getAnalyticsWeeklyTrends();
      final moodStatus = await ApiService.getMoodCheckInStatus();

      final stress = (summary['stress_score'] as num).toDouble();
      widget.onStressUpdate(stress > 75);

      if (mounted) {
        setState(() {
          _summary = summary;
          _trends = trends;
          _hasCheckedInMood = moodStatus['has_checked_in_today'] == true;
          _loading = false;
        });
        _animController.forward(from: 0.0);

        // Show daily mood pop up automatically if false (Disabled for now)
        // if (!_hasCheckedInMood) {
        //   WidgetsBinding.instance.addPostFrameCallback((_) {
        //     _showDailyMoodPopup();
        //   });
        // }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
        _animController.forward(from: 0.0);
      }
    }
  }

  void _showDailyMoodPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppTheme.card(context),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Daily Check-in',
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textP(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'How are you feeling right now?',
                style: AppTheme.labelText,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  'Calm',
                  'Confident',
                  'Sad',
                  'Tired',
                  'Energetic',
                  'Anxious'
                ].map((mood) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _onMoodSelected(mood);
                    },
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.bg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.border(context), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        mood,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textP(context),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMoodSelected(String value) async {
    setState(() => _selectedMood = value);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _submittingMood = true);

    try {
      await ApiService.submitMoodCheckIn(value);
      if (mounted) {
        setState(() {
          _hasCheckedInMood = true;
          _submittingMood = false;
          _selectedMood = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Thank you for checking in!', style: AppTheme.bodyText),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submittingMood = false;
          _selectedMood = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return _buildShimmerLoading();

    if (_error != null || _summary == null || _trends == null) {
      return _buildErrorState();
    }

    final s = _summary!;

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

    String riskLabel = "Low";
    if (stressValue > 75) {
      riskLabel = "Critical";
    } else if (stressValue > 50) {
      riskLabel = "High";
    } else if (stressValue > 25) {
      riskLabel = "Moderate";
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accentBlue,
      backgroundColor: AppTheme.bg(context),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // ── What's New Banner (Mood Tracker) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildWhatsNewBanner(),
              ),
            ),

            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview'.tr(context), style: AppTheme.headingLarge),
                    SizedBox(height: 4),
                    Text(
                      'Your cognitive digital twin analysis'.tr(context),
                      style: AppTheme.labelText,
                    ),
                  ],
                ),
              ),
            ),

            // ── Section 1: Wellness + Stress rings ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildRingCard(
                        label: 'Wellness'.tr(context),
                        value: wellnessValue,
                        maxValue: 100,
                        centerText: '${wellnessValue.toInt()}',
                        subText: '/100',
                        progressColor: AppTheme.accentBlue,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _buildRingCard(
                        label: 'AI Stress'.tr(context),
                        value: stressValue,
                        maxValue: 100,
                        centerText: '${stressValue.toInt()}%',
                        subText: riskLabel.tr(context),
                        progressColor: _stressColor(stressValue),
                        subTextColor: _stressColor(stressValue),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Section 2: Quick Stats ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                        child: _buildQuickStatCard(
                      icon: Icons.nightlight_round,
                      iconColor: AppTheme.accentBlue,
                      value: '${avgSleepVal.toStringAsFixed(1)}h',
                      label: 'Sleep'.tr(context),
                    )),
                    SizedBox(width: 10),
                    Expanded(
                        child: _buildQuickStatCard(
                      icon: Icons.phone_android_rounded,
                      iconColor: AppTheme.accentPurple,
                      value: '${avgScreenVal.toStringAsFixed(1)}h',
                      label: 'Screen'.tr(context),
                    )),
                    SizedBox(width: 10),
                    Expanded(
                        child: _buildQuickStatCard(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      iconColor: AppTheme.accentGreen,
                      value: avgMoodVal.toStringAsFixed(1),
                      label: 'Mood'.tr(context),
                    )),
                  ],
                ),
              ),
            ),

            // ── Section 3: Burnout Risk ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _buildBurnoutCard(burnoutValue),
              ),
            ),

            // ── Section 4: Daily Plan ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: _buildDailyPlan(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  UI HELPERS
  // ──────────────────────────────────────────────────────────────────

  Widget _buildDailyPlan() {
    final isDark = AppTheme.isDark(context);
    final routines = DailyRoutinePool.getTodayRoutines();

    final List<Widget> planItems = [
      // ── Section Header ──
      Row(
        children: [
          Text('My plan'.tr(context),
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textP(context))),
          const Spacer(),
          Icon(Icons.auto_awesome_rounded,
              color: AppTheme.accentPurple, size: 24),
        ],
      ),
      const SizedBox(height: 20),

      // ── Morning ──
      _buildPlanTimeTitle(
          'Morning'.tr(context), Icons.wb_twilight_rounded, AppTheme.accentBlue,
          isFirst: true),
      _buildPlanItemRowFromRoutine(routines['morning']!),
      Builder(builder: (context) {
        final todayArticle = DailyArticle.today;
        return _buildPlanItemRow(
          tag: 'Articles'.tr(context),
          tagIcon: Icons.article_outlined,
          tagColor: Colors.greenAccent,
          title: todayArticle.title.tr(context),
          subtitle: todayArticle.readTime.tr(context),
          gradientColors: isDark
              ? [
                  const Color(0xFF064E3B).withValues(alpha: 0.5),
                  const Color(0xFF0F172A)
                ]
              : [Colors.green.shade50, Colors.blue.shade50],
          bgIcon: Icons.menu_book_rounded,
          bgIconColor: Colors.greenAccent.withValues(alpha: 0.2),
          imageUrl: todayArticle.imageUrl,
          isLastInSection: true,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DailyArticleScreen(article: todayArticle))),
        );
      }),

      // ── Day ──
      _buildPlanTimeTitle(
          'Day'.tr(context), Icons.light_mode_outlined, Colors.amberAccent),
      _buildPlanItemRowFromRoutine(routines['day']!, isLastInSection: true),

      // ── Evening ──
      _buildPlanTimeTitle('Evening'.tr(context), Icons.nights_stay_outlined,
          Colors.indigoAccent),
      _buildPlanItemRowFromRoutine(routines['evening']!),
      _buildPlanItemRow(
        tag: 'Sleep Sounds'.tr(context), tagIcon: Icons.music_note_rounded,
        tagColor: Colors.pinkAccent,
        title: 'Deep Sleep Binaural'.tr(context),
        subtitle: 'Unwind and relax'.tr(context),
        gradientColors: isDark
            ? [
                const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                const Color(0xFF4A044E)
              ]
            : [Colors.pink.shade50, Colors.purple.shade50],
        bgIcon: Icons.headphones_rounded,
        bgIconColor: Colors.pinkAccent.withValues(alpha: 0.15),
        imageUrl:
            'https://images.unsplash.com/photo-1518104593124-ac2e82a5eb9d?q=80&w=600&auto=format&fit=crop', // Pink abstract neon
        isVeryLast: true,
      ),
    ];

    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 600),
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(child: widget),
          ),
          children: planItems,
        ),
      ),
    );
  }

  Widget _buildPlanItemRowFromRoutine(RoutineItem item,
      {bool isLastInSection = false}) {
    return _buildPlanItemRow(
      tag: item.tag.tr(context),
      tagIcon: item.tagIcon,
      tagColor: item.tagColor,
      title: item.title.tr(context),
      subtitle: item.subtitle.tr(context),
      gradientColors: item.gradientColors,
      bgIcon: item.tagIcon,
      bgIconColor: item.tagColor.withValues(alpha: 0.15),
      imageUrl: item.imageUrl,
      isLastInSection: isLastInSection,
      onTap: () {
        if (item.type == 'meditation') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MeditationScreen(mood: _currentMoodLabel)));
        }
      },
    );
  }

  Widget _buildPlanTimeTitle(String title, IconData icon, Color color,
      {bool isFirst = false}) {
    final isDark = AppTheme.isDark(context);
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.15);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Line extending downwards only (no upward connection to previous section)
                Positioned(
                  top: 16,
                  bottom: 0,
                  width: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: lineColor.withValues(alpha: 0.5),
                      boxShadow: [
                        BoxShadow(color: lineColor.withValues(alpha: 0.2), blurRadius: 4, spreadRadius: 1)
                      ]
                    )
                  ),
                ),
                // Section Icon
                Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Icon(icon, size: 20, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(title,
                style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textS(context))),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanItemRow({
    required String tag,
    required IconData tagIcon,
    required Color tagColor,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required IconData bgIcon,
    required Color bgIconColor,
    String? assetPath,
    String? imageUrl,
    bool isLastInSection = false,
    bool isVeryLast = false,
    VoidCallback? onTap,
  }) {
    final isDark = AppTheme.isDark(context);
    final lineColor =
        tagColor.withValues(alpha: 0.6); // Glowing line uses tag color!
    // Should we show the line below the circle?
    final bool showLineBelow = !isLastInSection && !isVeryLast;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline
          SizedBox(
            width: 28,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Line from top to circle (always present)
                Positioned(
                  top: 0,
                  height: 48,
                  width: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: lineColor,
                      boxShadow: [
                        BoxShadow(color: lineColor.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)
                      ]
                    ),
                  ),
                ),
                // Line from circle to bottom (only if not last in section)
                if (showLineBelow)
                  Positioned(
                    top: 54,
                    bottom: 0,
                    width: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: lineColor,
                        boxShadow: [
                          BoxShadow(color: lineColor.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)
                        ]
                      ),
                    ),
                  ),

                // Circle marker (Sleek professional style)
                Positioned(
                  top: 42,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tagColor, width: 3),
                      color: AppTheme.bg(context),
                      boxShadow: [
                        BoxShadow(
                            color: tagColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 0)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Plan Card (Premium Glassmorphic)
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1), width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Stack(
                      children: [
                        // Subtle BG Icon
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Icon(bgIcon, size: 100, color: bgIconColor),
                        ),

                        // Beautiful floating image mask
                        if (assetPath != null || imageUrl != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            top: 0,
                            child: ShaderMask(
                              shaderCallback: (rect) {
                                return const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [Colors.transparent, Colors.black],
                                  stops: [0.0, 0.4],
                                ).createShader(rect);
                              },
                              blendMode: BlendMode.dstIn,
                              child: assetPath != null
                                  ? Image.asset(assetPath,
                                      width: 150,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.centerRight)
                                  : Image.network(imageUrl!,
                                      width: 150,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.centerRight),
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // Fix for intrinsic height overflow
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tagColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: tagColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(tagIcon, size: 12, color: tagColor),
                                    const SizedBox(width: 4),
                                    Text(tag,
                                        style: GoogleFonts.dmSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: tagColor,
                                            letterSpacing: 0.5)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.45,
                                child: Text(title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textP(context))),
                              ),
                              const SizedBox(height: 4),
                              Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: AppTheme.textS(context)
                                          .withValues(alpha: 0.9))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _currentMoodLabel {
    final mood = _summary?['mood'];
    if (mood == null) return 'Calm';
    if (mood is String && mood.isNotEmpty) return mood;
    if (mood is num) {
      if (mood >= 8) return 'Happy';
      if (mood >= 6) return 'Calm';
      if (mood >= 4) return 'Neutral';
      if (mood >= 2) return 'Sad';
      return 'Anxiety';
    }
    return 'Calm';
  }

  String _stripEmoji(String text) {
    if (text.isEmpty) return text;
    text = text.trim();
    if (text.runes.isNotEmpty && text.runes.first > 1000) {
      return String.fromCharCodes(text.runes.skip(1)).trim();
    }
    return text;
  }

  Color _stressColor(double v) {
    if (v > 60) return AppTheme.accentRed;
    if (v > 30) return AppTheme.accentAmber;
    return AppTheme.accentGreen;
  }

  // ── Ring Card ──
  Widget _buildRingCard({
    required String label,
    required double value,
    required double maxValue,
    required String centerText,
    required String subText,
    required Color progressColor,
    Color? subTextColor,
  }) {
    final percent = (value / maxValue).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        children: [
          Text(label, style: AppTheme.labelText),
          SizedBox(height: 16),
          CircularPercentIndicator(
            radius: 52,
            lineWidth: 8,
            percent: percent,
            animation: true,
            animationDuration: 900,
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: progressColor,
            backgroundColor: AppTheme.elevated(context),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  centerText,
                  style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textP(context)),
                ),
                Text(
                  subText,
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: subTextColor ?? AppTheme.textS(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Stat Card ──
  Widget _buildQuickStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textP(context)),
          ),
          SizedBox(height: 2),
          Text(label, style: AppTheme.mutedText),
        ],
      ),
    );
  }

  // ── Burnout Card ──
  Widget _buildBurnoutCard(double burnoutValue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Burnout Risk'.tr(context),
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textP(context))),
              Text('${burnoutValue.toInt()}%',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentBlue)),
            ],
          ),
          SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (burnoutValue / 100).clamp(0.0, 1.0),
              backgroundColor: AppTheme.elevated(context),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
              minHeight: 6,
            ),
          ),
          SizedBox(height: 12),
          Text(
            burnoutValue > 60
                ? 'High risk detected. Consider reducing cognitive load.'
                    .tr(context)
                : 'Your behavioral patterns look well-balanced.'.tr(context),
            style: AppTheme.mutedText.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Pattern Card ──
  Widget _buildPatternCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_rounded,
                color: AppTheme.accentAmber, size: 16),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(text, style: AppTheme.bodyText.copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ── What's New Banner ──
  Widget _buildWhatsNewBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star_outline_rounded,
                color: AppTheme.accentAmber, size: 20),
            SizedBox(width: 8),
            Text('What\'s new'.tr(context),
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textP(context))),
          ],
        ),
        SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => LogEntryScreen(onSubmitted: () {
                            _load();
                            widget.onLogSubmitted?.call();
                          })));
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF13192B)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context), width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.umbrella_rounded,
                              color: const Color(0xFFC084FC), size: 16),
                          SizedBox(width: 8),
                          Text('Mood tracker'.tr(context),
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFC084FC))),
                          SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC084FC)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Beta',
                                style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFC084FC))),
                          )
                        ],
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textS(context), size: 20),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text('Check in with your mood'.tr(context),
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textP(context))),
                  SizedBox(height: 4),
                  Text(
                    'Increase emotional awareness by tracking your moods'
                        .tr(context),
                    style: AppTheme.mutedText.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shimmer Loading State ──
  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          _shimmerBox(width: 140, height: 28),
          SizedBox(height: 6),
          _shimmerBox(width: 220, height: 14),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 180)),
              SizedBox(width: 14),
              Expanded(child: _shimmerBox(height: 180)),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 90)),
              SizedBox(width: 10),
              Expanded(child: _shimmerBox(height: 90)),
              SizedBox(width: 10),
              Expanded(child: _shimmerBox(height: 90)),
            ],
          ),
          SizedBox(height: 14),
          _shimmerBox(height: 120),
          SizedBox(height: 24),
          _shimmerBox(width: 160, height: 18),
          SizedBox(height: 12),
          _shimmerBox(height: 56),
          SizedBox(height: 10),
          _shimmerBox(height: 56),
        ],
      ),
    );
  }

  Widget _shimmerBox({double? width, double height = 60}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
    );
  }

  // ── Error / Empty State ──
  Widget _buildErrorState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppTheme.textM(context)),
              SizedBox(height: 16),
              Text('No Analytics Data'.tr(context),
                  style: AppTheme.headingMedium),
              SizedBox(height: 8),
              if (_error != null) ...[
                Text(
                  '${'Error'.tr(context)}: $_error',
                  style: AppTheme.mutedText.copyWith(color: AppTheme.accentRed),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
              ],
              Text(
                'Submit your first daily log to generate insights.'.tr(context),
                style: AppTheme.mutedText,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh_rounded, size: 18),
                onPressed: _load,
                label: Text('Refresh Data'.tr(context)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.12),
                  foregroundColor: AppTheme.accentBlue,
                  elevation: 0,
                  side: BorderSide(
                      color: AppTheme.accentBlue.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Removed _GlowingLinePainter as it's been replaced with sleek Container styling
