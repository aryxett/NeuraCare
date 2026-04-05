import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'isDarkMode';
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark

  ThemeProvider({bool isDark = true}) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<ThemeProvider> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true (dark mode) if not set
    final isDark = prefs.getBool(_themePrefKey) ?? true;
    return ThemeProvider(isDark: isDark);
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> toggleTheme() async {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themePrefKey, isDarkMode);
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      // Soft light background
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      primaryColor: const Color(0xFF3B82F6),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF8B5CF6),
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme.apply(
              bodyColor: const Color(0xFF1F2937),
              displayColor: const Color(0xFF111827),
            ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1F2937),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9), // Clean frosted glass base
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Color(0xFF3B82F6),
        unselectedItemColor: Colors.black38,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF4B5563),
        size: 24,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      // Deep Navy background
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      // Muted calm primary
      primaryColor: const Color(0xFF3B82F6),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF8B5CF6),
        surface: Color(0xFF10192B),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white.withValues(alpha: 0.9),
              displayColor: Colors.white,
            ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent, // Handled by GlassContainer
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: _elevatedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Color(0xFF3B82F6),
        unselectedItemColor: Colors.white30,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white70,
        size: 24,
      ),
    );
  }

  static ElevatedButtonThemeData get _elevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        // Soft gradient effect when built, but solid fallback here
        backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        elevation: 10,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }

  static InputDecorationTheme get _inputDecorationTheme {
    final borderColor = Colors.white.withValues(alpha: 0.1);

    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
    );
  }
}
