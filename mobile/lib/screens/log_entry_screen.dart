import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';

class LogEntryScreen extends StatefulWidget {
  final VoidCallback? onSubmitted;
  const LogEntryScreen({super.key, this.onSubmitted});

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> with SingleTickerProviderStateMixin {
  double _sleepHours = 7.0;
  double _screenTime = 5.0;
  int _mood = 6;
  bool _exercise = false;
  
  bool _loading = false;
  Map<String, dynamic>? _result;

  bool _fitbitConnected = false;
  bool _fitbitLoading = false;
  bool _fitbitDataLoaded = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _tryLoadFitbitData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _tryLoadFitbitData() async {
    setState(() => _fitbitLoading = true);
    try {
      final data = await ApiService.getFitbitDailyData();
      if (data['connected'] == true) {
        if (mounted) {
          setState(() {
            _fitbitConnected = true;
            _fitbitDataLoaded = true;
            if (data['sleep_hours'] != null && (data['sleep_hours'] as num) > 0) {
              _sleepHours = (data['sleep_hours'] as num).toDouble();
            }
            _exercise = data['exercise'] ?? false;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fitbitLoading = false);
    }
  }

  Future<void> _connectFitbit() async {
    try {
      final authUrl = await ApiService.getFitbitAuthUrl();
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _showCodePasteDialog();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Fitbit login page')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fitbit Error: $e')));
    }
  }

  void _showCodePasteDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Paste Fitbit Code', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Copy the full URL from the browser address bar after authorizing.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://www.google.com/?code=...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                border: const OutlineInputBorder(), // Keep a default border
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2))),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final val = codeController.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(ctx);
              _exchangeCode(val);
            },
            child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _exchangeCode(String input) async {
    if (input.isEmpty) return;
    if (input.contains('fitbit.com/oauth2/authorize')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ You pasted the login URL. Paste the localhost URL instead.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _fitbitLoading = true);
    try {
      String code = input;
      if (input.contains('code=')) {
        final uri = Uri.parse(input.startsWith('http') ? input : 'http://$input');
        code = uri.queryParameters['code'] ?? input;
      }
      await ApiService.exchangeFitbitCode(code);
      setState(() => _fitbitConnected = true);
      await _tryLoadFitbitData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Fitbit connected successfully!'), backgroundColor: Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _fitbitLoading = false);
    }
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _result = null; });
    try {
      final me = await ApiService.getMe();
      final userId = me['user_id'] as int;
      await ApiService.submitPhase2DailyLog(userId: userId, sleepHours: _sleepHours, screenTime: _screenTime, mood: _mood, exercise: _exercise);
      final preds = await ApiService.getPredictions(limit: 1);
      
      if (preds.isNotEmpty) {
        final latestPred = preds.first;
        setState(() {
          _result = {
            'stress_score': latestPred['stress_score'],
            'risk_level': latestPred['risk_level'],
            'message': latestPred['insights'] ?? 'Data recorded successfully',
          };
        });
      }
      widget.onSubmitted?.call();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'Low': return const Color(0xFF10B981);
      case 'Moderate': return const Color(0xFFF59E0B);
      case 'High': return const Color(0xFFEF4444);
      case 'Critical': return const Color(0xFFFCA5A5);
      default: return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF4B5563);
    final trackColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final thumbColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final baseIconColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100), // padding for floating nav
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Log', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryTextColor.withOpacity(0.9))),
            const SizedBox(height: 4),
            Text('Record your metrics for cognitive analysis', style: TextStyle(color: secondaryTextColor, fontSize: 13, letterSpacing: 0.5)),
            const SizedBox(height: 24),

            // Fitbit Connection Card
            GlassContainer(
              padding: const EdgeInsets.all(16),
              baseColor: _fitbitConnected ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
              borderOpacity: 0.3,
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Icon(Icons.watch_rounded, color: Colors.white, size: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fitbitConnected ? 'Fitbit Connected' : 'Connect Fitbit',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fitbitConnected
                              ? (_fitbitDataLoaded ? 'Metrics auto-filled securely' : 'Syncing data...')
                              : 'Auto-fill sleep & exercise data',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!_fitbitConnected)
                    _fitbitLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : TextButton(
                            onPressed: _connectFitbit,
                            style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), foregroundColor: Colors.white),
                            child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: _tryLoadFitbitData,
                      tooltip: 'Refresh Fitbit Data',
                    ),
                ],
              ),
            ),

            if (_fitbitDataLoaded) ...[
              const SizedBox(height: 8),
              Center(child: Text('Fitbit values pre-filled. Adjust manually if needed.', style: TextStyle(color: secondaryTextColor, fontSize: 11))),
            ],
            const SizedBox(height: 16),

            // Sleep Slider
            GlassContainer(
              padding: const EdgeInsets.all(20),
              borderOpacity: 0.1,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.bedtime_rounded, color: Color(0xFF3B82F6), size: 18),
                        const SizedBox(width: 8),
                        Text('Sleep Duration', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
                      ]),
                      Text('${_sleepHours.toStringAsFixed(1)}h', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6), fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF3B82F6),
                      inactiveTrackColor: trackColor,
                      thumbColor: thumbColor,
                      overlayColor: const Color(0xFF3B82F6).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _sleepHours, min: 0, max: 12, divisions: 24,
                      onChanged: (v) => setState(() => _sleepHours = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Screen Time Slider
            GlassContainer(
              padding: const EdgeInsets.all(20),
              borderOpacity: 0.1,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.smartphone_rounded, color: Color(0xFFEC4899), size: 18),
                        const SizedBox(width: 8),
                        Text('Screen Time', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
                      ]),
                      Text('${_screenTime.toStringAsFixed(1)}h', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEC4899), fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFEC4899),
                      inactiveTrackColor: trackColor,
                      thumbColor: thumbColor,
                      overlayColor: const Color(0xFFEC4899).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _screenTime, min: 0, max: 16, divisions: 32,
                      onChanged: (v) => setState(() => _screenTime = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mood Selector
            GlassContainer(
              padding: const EdgeInsets.all(20),
              borderOpacity: 0.1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.sentiment_satisfied_rounded, color: Color(0xFF8B5CF6), size: 18),
                        const SizedBox(width: 8),
                        Text('Mood Rating', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
                      ]),
                      Text('$_mood/10', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (i) {
                      // Map 5 buttons to 1-10 scale (2, 4, 6, 8, 10)
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
                            color: selected ? const Color(0xFF8B5CF6).withOpacity(0.2) : trackColor,
                            border: Border.all(color: selected ? const Color(0xFF8B5CF6) : Colors.transparent, width: 2),
                            boxShadow: selected ? [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 10)] : [],
                          ),
                          child: Icon(iconData, color: selected ? const Color(0xFF8B5CF6) : secondaryTextColor, size: 28),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Exercise Toggle
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              borderOpacity: 0.1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.fitness_center_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text('Physical Activity', style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor)),
                  ]),
                  Switch(
                    value: _exercise,
                    activeColor: const Color(0xFF10B981),
                    activeTrackColor: const Color(0xFF10B981).withOpacity(0.3),
                    inactiveThumbColor: trackColor,
                    inactiveTrackColor: trackColor.withOpacity(0.05),
                    onChanged: (v) => setState(() => _exercise = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: const Color(0xFF3B82F6).withOpacity(0.5),
                ),
                child: _loading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Analyze Patterns', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),

            // Result Card
            if (_result != null) ...[
              const SizedBox(height: 32),
              GlassContainer(
                padding: const EdgeInsets.all(24),
                baseColor: _riskColor(_result!['risk_level']),
                borderOpacity: 0.3,
                child: Column(
                  children: [
                    const Text('AI Prediction Model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 24),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: _riskColor(_result!['risk_level']).withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
                          ),
                          child: CircularProgressIndicator(
                            value: (_result!['stress_score'] as num).toDouble() / 100,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            color: _riskColor(_result!['risk_level']),
                            strokeWidth: 8,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(_result!['stress_score'] as num).toStringAsFixed(0)}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _riskColor(_result!['risk_level']))),
                            Text('Score', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _riskColor(_result!['risk_level']).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _riskColor(_result!['risk_level']).withOpacity(0.5)),
                      ),
                      child: Text('Risk: ${_result!['risk_level']}', style: TextStyle(color: _riskColor(_result!['risk_level']), fontWeight: FontWeight.w600)),
                    ),
                    if (_result!['message'] != null) ...[
                      const SizedBox(height: 16),
                      Text(_result!['message'], style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.5), textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
