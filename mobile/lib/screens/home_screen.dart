import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'dashboard_screen.dart';
import 'log_entry_screen.dart';
import 'insights_screen.dart';
import 'life_patterns_screen.dart';
import 'history_screen.dart';
import 'therapy_chat_screen.dart';
import 'profile_screen.dart';
import '../services/api_service.dart';
import '../services/usage_tracker_service.dart';
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
  String _userName = '';
  String? _avatarBase64;

  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _insightsKey = GlobalKey<InsightsScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();

  @override
  void initState() {
    super.initState();
    _initUsageTracking();
    _loadUserName();
  }

  Future<void> _initUsageTracking() async {
    // Phase 5: Silent Behavioral Automation
    try {
      final usage = await UsageTrackerService.getDailyUsageCategories();
      if (usage.isNotEmpty) {
        await ApiService.syncDailyUsageStats(
          usage['social_time'] ?? 0.0,
          usage['entertainment_time'] ?? 0.0,
          usage['productivity_time'] ?? 0.0,
          usage['screen_time'] ?? 0.0,
        );
      }
    } catch (_) {
      // Fails silently, no UI interruption
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    widget.onLogout();
  }

  Future<void> _loadUserName() async {
    try {
      // Try cached first for instant display
      final cached = await ApiService.getCachedUser();
      if (cached != null && mounted) {
        setState(() {
          _userName = cached['name'] ?? '';
          if (cached['profile_metadata'] != null) {
            _avatarBase64 = cached['profile_metadata']['avatar_base64'];
          }
        });
      }
      // Then refresh from API
      final data = await ApiService.getMe();
      await ApiService.saveUserLocally(data);
      if (mounted) {
        setState(() {
          _userName = data['name'] ?? '';
          if (data['profile_metadata'] != null) {
            _avatarBase64 = data['profile_metadata']['avatar_base64'];
          }
        });
      }
    } catch (_) {}
  }

  void _openProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(onLogout: _logout),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) => _loadUserName()); // Refresh name after returning
  }

  void _onDataSubmitted() {
    _dashboardKey.currentState?.refresh();
    _insightsKey.currentState?.refresh();
    _historyKey.currentState?.refresh();
  }

  void _toggleSafeSpace(bool active) {
    // Disabled: always keep the normal Cognify AI theme
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
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9)
                  ]); // Faded clean background
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
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _openProfile,
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                    image: _avatarBase64 != null && _avatarBase64!.isNotEmpty
                        ? DecorationImage(
                            image: MemoryImage(base64Decode(_avatarBase64!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _avatarBase64 != null && _avatarBase64!.isNotEmpty
                      ? null
                      : Center(
                          child: Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
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
                baseColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                borderRadius: 24,
                borderOpacity: 0.15,
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (i) {
                    setState(() => _currentIndex = i);
                    if (i == 0) _dashboardKey.currentState?.refresh();
                    if (i == 3) _insightsKey.currentState?.refresh();
                    if (i == 4) _historyKey.currentState?.refresh();
                  },
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
