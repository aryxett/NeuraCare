import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'dashboard_screen.dart';
import 'log_entry_screen.dart';
import 'insights_screen.dart';
import 'history_screen.dart';
import 'therapy_chat_screen.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _safeSpaceMode = false;

  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _insightsKey = GlobalKey<InsightsScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();

  Future<void> _logout() async {
    await ApiService.clearToken();
    widget.onLogout();
  }

  void _onDataSubmitted() {
    _dashboardKey.currentState?.refresh();
    _insightsKey.currentState?.refresh();
    _historyKey.currentState?.refresh();
    setState(() => _currentIndex = 0);
  }

  void _toggleSafeSpace(bool active) {
    if (_safeSpaceMode != active) {
      setState(() => _safeSpaceMode = active);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      final isDark = themeProvider.isDarkMode;

      // Custom theme-aware gradients
      LinearGradient bgGradient;
      if (_safeSpaceMode) {
        bgGradient = isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF064E3B)])
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF0FDF4), Color(0xFFD1FAE5)]); // Soft teal
      } else {
        bgGradient = isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B1220), Color(0xFF10192B)])
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                    Color(0xFFF0FDF4),
                    Color(0xFFDBEAFE)
                  ]); // Mint to subtle blue vibrant background
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(gradient: bgGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true, // Allows body to scroll under the floating nav bar
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: _safeSpaceMode
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : [
                                const Color(0xFF3B82F6),
                                const Color(0xFF8B5CF6)
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: (_safeSpaceMode
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF3B82F6))
                                .withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1),
                      ]),
                  child: Center(
                    child: Icon(
                        _safeSpaceMode
                            ? Icons.spa_rounded
                            : Icons.psychology_rounded,
                        size: 20,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(_safeSpaceMode ? 'Safe Space' : 'Cognify AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      letterSpacing: 0.5,
                      color: Theme.of(context).appBarTheme.foregroundColor ??
                          (isDark ? Colors.white : const Color(0xFF1F2937)),
                    )),
              ],
            ),
            actions: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: child.key == const ValueKey('dark')
                      ? Tween<double>(begin: 0.5, end: 1.0).animate(anim)
                      : Tween<double>(begin: 0.5, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: IconButton(
                  key: ValueKey(isDark ? 'dark' : 'light'),
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 20,
                    color: isDark ? Colors.amber : const Color(0xFF3B82F6),
                  ),
                  onPressed: () => themeProvider.toggleTheme(),
                  tooltip: 'Toggle Theme',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.rocket_launch_rounded,
                    size: 20, color: Color(0xFF3B82F6)),
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Seeding demo data...'),
                          duration: Duration(seconds: 1)),
                    );
                    await ApiService.seedDemoData();
                    _dashboardKey.currentState?.refresh();
                    _insightsKey.currentState?.refresh();
                    _historyKey.currentState?.refresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('🎉 7 days of mock data added!'),
                            backgroundColor: Color(0xFF10B981)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                tooltip: 'Generate Demo Data',
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20),
                onPressed: _logout,
                tooltip: 'Sign Out',
                color: isDark ? Colors.white70 : const Color(0xFF3B82F6),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              DashboardScreen(
                  key: _dashboardKey, onStressUpdate: _toggleSafeSpace),
              const TherapyChatScreen(),
              LogEntryScreen(onSubmitted: _onDataSubmitted),
              InsightsScreen(key: _insightsKey),
              HistoryScreen(key: _historyKey),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: GlassContainer(
                baseColor: isDark ? Colors.white : const Color(0xFFDBEAFE),
                padding: const EdgeInsets.symmetric(vertical: 8),
                borderRadius: 24,
                borderOpacity: 0.15,
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (i) => setState(() => _currentIndex = i),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: const Color(0xFF3B82F6),
                  unselectedItemColor: isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF6B7280).withOpacity(0.8),
                  showSelectedLabels: true,
                  showUnselectedLabels: false,
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard_rounded), label: 'Dash'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.add_circle_outline_rounded),
                        label: 'Log'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.auto_awesome_rounded),
                        label: 'Insights'),
                    BottomNavigationBarItem(
                        icon: Icon(Icons.bar_chart_rounded), label: 'History'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
