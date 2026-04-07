import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'dashboard_screen.dart';
import 'log_entry_screen.dart';
import 'insights_screen.dart';
import 'history_screen.dart';
import 'therapy_chat_screen.dart';
import 'profile_screen.dart';
import '../services/api_service.dart';
import '../services/usage_tracker_service.dart';
import '../widgets/glass_container.dart';
import '../core/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<int> _initializedTabs = {0};
  final bool _safeSpaceMode = false;
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
    _preloadOtherTabs();
  }

  void _preloadOtherTabs() async {
    // Stagger loading to prevent frame drops in UI
    final tabsToPreload = [3, 4, 1, 2]; // Priority: Insights, History, Chat, Logs
    for (int i = 0; i < tabsToPreload.length; i++) {
      await Future.delayed(const Duration(milliseconds: 800)); // Load 1 tab every 0.8s
      if (mounted && !_initializedTabs.contains(tabsToPreload[i])) {
        setState(() {
          _initializedTabs.add(tabsToPreload[i]);
        });
      }
    }
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
    // Disabled: always keep the normal NeuraCare theme
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 16) return 'Good Afternoon';
    if (hour >= 16 && hour < 20) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

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
            centerTitle: false,
            titleSpacing: 16.0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(fontFamily: 'DM Sans', fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                ),
                SizedBox(height: 1), // Tiny gap
                Text(
                  _userName.isNotEmpty ? _userName.split(' ').first.trim() : 'there',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textP(context), height: 1.1, letterSpacing: -0.3),
                ),
              ],
            ),
            actions: [
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
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
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
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _initializedTabs.contains(0) ? DashboardScreen(key: _dashboardKey, onStressUpdate: _toggleSafeSpace) : const SizedBox.shrink(),
              _initializedTabs.contains(1) ? const TherapyChatScreen() : const SizedBox.shrink(),
              _initializedTabs.contains(2) ? LogEntryScreen(onSubmitted: _onDataSubmitted) : const SizedBox.shrink(),
              _initializedTabs.contains(3) ? InsightsScreen(key: _insightsKey) : const SizedBox.shrink(),
              _initializedTabs.contains(4) ? HistoryScreen(key: _historyKey) : const SizedBox.shrink(),
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
                    setState(() {
                      _currentIndex = i;
                      _initializedTabs.add(i);
                    });
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: const Color(0xFF3B82F6),
                  unselectedItemColor: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF6B7280).withValues(alpha: 0.8),
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
