import 'package:flutter/material.dart';

class LibreBeatsTheme {
// Core palette
static const Color background = Color(0xFF0A0F0A);
static const Color surface = Color(0xFF111611);
static const Color surfaceVariant = Color(0xFF181F18);
static const Color card = Color(0xFF0F140F);
static const Color border = Color(0xFF263026);

// Accent (deep emerald)
static const Color accent = Color(0xFF1DB954);
static const Color accentDim = Color(0x221DB954);
static const Color accentGlow = Color(0x441DB954);

// Text
static const Color textPrimary = Color(0xFFE6EEE6);
static const Color textSecondary = Color(0xFF8C968C);
static const Color textDim = Color(0xFF566156);

// Status
static const Color online = Color(0xFF1DB954);
static const Color offline = Color(0xFF7A847A);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: accent,
          surface: surface,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF121212),
          selectedItemColor: textPrimary,
          unselectedItemColor: textDim,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 10),
        ),
        cardTheme: CardThemeData(
          color: card,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 22),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
          labelSmall: TextStyle(color: textDim, fontSize: 11),
        ),
        dividerTheme: const DividerThemeData(color: border, thickness: 1),
        iconTheme: const IconThemeData(color: textSecondary),
        splashColor: accentDim,
        highlightColor: Colors.transparent,
      );
}