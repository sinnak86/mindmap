import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF007AFF); // iOS Blue
  static const Color secondary = Color(0xFF34C759); // iOS Green
  static const Color background = Color(0xFFF2F2F7); // iOS system background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFFF3B30); // iOS Red

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: error,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white.withAlpha(200),
          foregroundColor: const Color(0xFF1C1C1E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black.withAlpha(13)),
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withAlpha(25)),
          ),
          filled: true,
          fillColor: const Color(0xFFF2F2F7),
        ),
      );

  static ThemeData get darkTheme => lightTheme;
}
