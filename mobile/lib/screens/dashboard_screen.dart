import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/api_service.dart';
import '../core/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final Function(bool) onStressUpdate;
  const DashboardScreen({super.key, required this.onStressUpdate});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _error = e.toString(); });
        _animController.forward(from: 0.0);
      }
    }
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
            content: Text('Thank you for checking in!', style: AppTheme.bodyText),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _submittingMood = false; _selectedMood = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.accentRed),
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
      backgroundColor: AppTheme.bgPrimary,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // ── Mood Check-In ──
            if (!_hasCheckedInMood)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildMoodCheckInCard(),
                ),
              ),

            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview', style: AppTheme.headingLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Your cognitive digital twin analysis',
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
                        label: 'Wellness',
                        value: wellnessValue,
                        maxValue: 100,
                        centerText: '${wellnessValue.toInt()}',
                        subText: '/100',
                        progressColor: AppTheme.accentBlue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildRingCard(
                        label: 'AI Stress',
                        value: stressValue,
                        maxValue: 100,
                        centerText: '${stressValue.toInt()}%',
                        subText: riskLabel,
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
                    Expanded(child: _buildQuickStatCard(
                      icon: Icons.nightlight_round,
                      iconColor: AppTheme.accentBlue,
                      value: '${avgSleepVal.toStringAsFixed(1)}h',
                      label: 'Sleep',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _buildQuickStatCard(
                      icon: Icons.phone_android_rounded,
                      iconColor: AppTheme.accentPurple,
                      value: '${avgScreenVal.toStringAsFixed(1)}h',
                      label: 'Screen',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _buildQuickStatCard(
                      icon: Icons.sentiment_satisfied_alt_rounded,
                      iconColor: AppTheme.accentGreen,
                      value: avgMoodVal.toStringAsFixed(1),
                      label: 'Avg Mood',
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

            // ── Section 4: Detected Patterns ──
            if (triggers.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text('Detected Patterns', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ),
              ),
            if (triggers.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPatternCard(triggers[index].toString()),
                    childCount: triggers.length,
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  //  UI HELPERS
  // ──────────────────────────────────────────────────────────────────

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
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Text(label, style: AppTheme.labelText),
          const SizedBox(height: 16),
          CircularPercentIndicator(
            radius: 52,
            lineWidth: 8,
            percent: percent,
            animation: true,
            animationDuration: 900,
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: progressColor,
            backgroundColor: AppTheme.bgElevated,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  centerText,
                  style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text(
                  subText,
                  style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: subTextColor ?? AppTheme.textSecondary),
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
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.mutedText),
        ],
      ),
    );
  }

  // ── Burnout Card ──
  Widget _buildBurnoutCard(double burnoutValue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Burnout Risk', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              Text('${burnoutValue.toInt()}%', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.accentBlue)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (burnoutValue / 100).clamp(0.0, 1.0),
              backgroundColor: AppTheme.bgElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            burnoutValue > 60
                ? 'High risk detected. Consider reducing cognitive load.'
                : 'Your behavioral patterns look well-balanced.',
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
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_rounded, color: AppTheme.accentAmber, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text, style: AppTheme.bodyText.copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ── Mood Check-In Card ──
  Widget _buildMoodCheckInCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: AppTheme.accentBlue, size: 16),
              ),
              const SizedBox(width: 10),
              Text('How are you feeling today?', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          if (_submittingMood)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Submitting...', style: TextStyle(color: AppTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final chipWidth = (constraints.maxWidth - 12) / 3;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMoodChip('calm', 'Calm', AppTheme.accentGreen, chipWidth),
                    _buildMoodChip('happy', 'Happy', AppTheme.accentBlue, chipWidth),
                    _buildMoodChip('motivated', 'Motivated', AppTheme.accentPurple, chipWidth),
                    _buildMoodChip('neutral', 'Neutral', AppTheme.textSecondary, chipWidth),
                    _buildMoodChip('stressed', 'Stressed', AppTheme.accentRed, chipWidth),
                    _buildMoodChip('tired', 'Tired', AppTheme.accentAmber, chipWidth),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMoodChip(String value, String label, Color color, double chipWidth) {
    final isSelected = _selectedMood == value;

    return SizedBox(
      width: chipWidth,
      height: 36,
      child: AnimatedScale(
        scale: isSelected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.2),
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _submittingMood ? null : () => _onMoodSelected(value),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: isSelected ? color : color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shimmer Loading State ──
  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _shimmerBox(width: 140, height: 28),
          const SizedBox(height: 6),
          _shimmerBox(width: 220, height: 14),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 180)),
              const SizedBox(width: 14),
              Expanded(child: _shimmerBox(height: 180)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _shimmerBox(height: 90)),
              const SizedBox(width: 10),
              Expanded(child: _shimmerBox(height: 90)),
              const SizedBox(width: 10),
              Expanded(child: _shimmerBox(height: 90)),
            ],
          ),
          const SizedBox(height: 14),
          _shimmerBox(height: 120),
          const SizedBox(height: 24),
          _shimmerBox(width: 160, height: 18),
          const SizedBox(height: 12),
          _shimmerBox(height: 56),
          const SizedBox(height: 10),
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
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
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
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text('No Analytics Data', style: AppTheme.headingMedium),
              const SizedBox(height: 8),
              if (_error != null) ...[
                Text(
                  'Error: $_error',
                  style: AppTheme.mutedText.copyWith(color: AppTheme.accentRed),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Submit your first daily log to generate insights.',
                style: AppTheme.mutedText,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: _load,
                label: const Text('Refresh Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.12),
                  foregroundColor: AppTheme.accentBlue,
                  elevation: 0,
                  side: BorderSide(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
