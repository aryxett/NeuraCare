import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../core/app_theme.dart';
import '../providers/google_fit_provider.dart';

class LogEntryScreen extends StatefulWidget {
  final VoidCallback? onSubmitted;
  const LogEntryScreen({super.key, this.onSubmitted});

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  double _sleepHours = 7.0;
  double _screenTime = 5.0;
  int _mood = 6;
  bool _exercise = false;
  bool _sleepAutoFilled = false;
  bool _loading = false;
  Map<String, dynamic>? _result;



  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    // Auto-fill sleep from Google Fit if connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoFillSleep();
    });
  }

  void _tryAutoFillSleep() {
    final fitProvider = context.read<GoogleFitProvider>();
    if (fitProvider.isConnected && fitProvider.sleepHours > 0) {
      setState(() {
        _sleepHours = fitProvider.sleepHours;
        _sleepAutoFilled = true;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }



  Future<void> _submit() async {
    setState(() { _loading = true; _result = null; });
    try {
      final liveResult = await ApiService.submitDailyData(
        sleepHours: _sleepHours,
        screenTime: _screenTime,
        mood: _mood,
        exercise: _exercise,
      );
      
      setState(() {
        _result = {
          'stress_score': liveResult['stress_score'],
          'risk_level': liveResult['risk_level'],
          'message': liveResult['message'] ?? 'Analysis complete',
        };
      });
      widget.onSubmitted?.call();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'Low': return AppTheme.accentGreen;
      case 'Moderate': return AppTheme.accentAmber;
      case 'High': return AppTheme.accentRed;
      case 'Critical': return const Color(0xFFFCA5A5);
      default: return AppTheme.accentBlue;
    }
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Text('Daily Log', style: AppTheme.headingLarge),
            const SizedBox(height: 4),
            Text('Record your metrics for cognitive analysis', style: AppTheme.labelText),
            const SizedBox(height: 24),



            // ── Google Fit sleep auto-fill badge ──
            if (_sleepAutoFilled)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3DD68C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3DD68C).withValues(alpha: 0.3), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.watch_outlined, color: Color(0xFF3DD68C), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sleep auto-filled from Google Fit • ${_sleepHours.toStringAsFixed(1)}h',
                        style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF3DD68C)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _sleepAutoFilled = false),
                      child: const Icon(Icons.close, color: Color(0xFF3DD68C), size: 14),
                    ),
                  ],
                ),
              ),

            // ── Sleep Slider ──
            _buildSliderCard(
              icon: Icons.nightlight_round,
              iconColor: AppTheme.accentBlue,
              label: 'Sleep Duration',
              value: _sleepHours,
              displayValue: '${_sleepHours.toStringAsFixed(1)}h',
              valueColor: AppTheme.accentBlue,
              min: 0,
              max: 12,
              divisions: 24,
              activeColor: AppTheme.accentBlue,
              onChanged: (v) => setState(() {
                _sleepHours = v;
                _sleepAutoFilled = false; // user overrode auto-fill
              }),
            ),
            const SizedBox(height: 12),

            // ── Screen Time Slider ──
            _buildSliderCard(
              icon: Icons.phone_android_rounded,
              iconColor: const Color(0xFFE040FB),
              label: 'Screen Time',
              value: _screenTime,
              displayValue: '${_screenTime.toStringAsFixed(1)}h',
              valueColor: const Color(0xFFE040FB),
              min: 0,
              max: 16,
              divisions: 32,
              activeColor: const Color(0xFFE040FB),
              onChanged: (v) => setState(() => _screenTime = v),
            ),
            const SizedBox(height: 12),

            // ── Mood Picker ──
            _buildMoodCard(),
            const SizedBox(height: 12),

            // ── Exercise Toggle ──
            _buildExerciseToggle(),
            const SizedBox(height: 28),

            // ── Analyze Button ──
            _buildAnalyzeButton(),

            // ── Result Card ──
            if (_result != null) ...[
              const SizedBox(height: 28),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  //  UI HELPERS
  // ──────────────────────────────────────────────────────




  Widget _buildSliderCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double value,
    required String displayValue,
    required Color valueColor,
    required double min,
    required double max,
    required int divisions,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(label, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
              ]),
              Text(displayValue, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: valueColor, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: activeColor,
              inactiveTrackColor: AppTheme.bgElevated,
              thumbColor: Colors.white,
              overlayColor: Colors.transparent,
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value, min: min, max: max, divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.sentiment_satisfied_rounded, color: AppTheme.accentPurple, size: 18),
                const SizedBox(width: 8),
                Text('Mood Rating', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
              ]),
              Text('$_mood/10', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.accentGreen, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final val = (i + 1) * 2;
              final selected = _mood == val || _mood == val - 1;
              IconData iconData;
              switch(i) {
                case 0: iconData = Icons.sentiment_very_dissatisfied_rounded; break;
                case 1: iconData = Icons.sentiment_dissatisfied_rounded; break;
                case 2: iconData = Icons.sentiment_neutral_rounded; break;
                case 3: iconData = Icons.sentiment_satisfied_rounded; break;
                default: iconData = Icons.sentiment_very_satisfied_rounded; break;
              }

              return GestureDetector(
                onTap: () => setState(() => _mood = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppTheme.accentPurple.withValues(alpha: 0.15) : AppTheme.bgElevated,
                    border: Border.all(
                      color: selected ? AppTheme.accentPurple : Colors.transparent,
                      width: selected ? 2 : 0,
                    ),
                  ),
                  child: Icon(iconData, color: selected ? AppTheme.accentPurple : AppTheme.textSecondary, size: 28),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Icon(Icons.fitness_center_rounded, color: AppTheme.accentGreen, size: 18),
            const SizedBox(width: 8),
            Text('Physical Activity', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
          ]),
          Switch(
            value: _exercise,
            activeThumbColor: AppTheme.accentGreen,
            activeTrackColor: AppTheme.accentGreen.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textMuted,
            inactiveTrackColor: AppTheme.bgElevated,
            onChanged: (v) => setState(() => _exercise = v),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentBlue,
          disabledBackgroundColor: AppTheme.accentBlue.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text('Analyze Patterns', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildResultCard() {
    final score = (_result!['stress_score'] as num?)?.toDouble() ?? 0.0;
    final riskLevel = _result!['risk_level']?.toString() ?? 'Unknown';
    final message = _result!['message']?.toString() ?? '';
    final rColor = _riskColor(riskLevel);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        children: [
          Text('AI Prediction Model', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 22),
          CircularPercentIndicator(
            radius: 58,
            lineWidth: 8,
            percent: (score / 100).clamp(0.0, 1.0),
            animation: true,
            animationDuration: 900,
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: rColor,
            backgroundColor: AppTheme.bgCard,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  score.toStringAsFixed(0),
                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: rColor),
                ),
                Text('Score', style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: rColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: rColor.withValues(alpha: 0.4)),
            ),
            child: Text('Risk: $riskLevel', style: GoogleFonts.dmSans(color: rColor, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(message, style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary, height: 1.5), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
