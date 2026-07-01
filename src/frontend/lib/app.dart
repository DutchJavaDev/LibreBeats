import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/main_scaffold.dart';

class LiberatedBeatsApp extends StatelessWidget {
  const LiberatedBeatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liberated Beats',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const MainScaffold(),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF1ED760),
        onPrimary: Colors.black,
        secondary: Color(0xFF282828),
        onSecondary: Colors.white,
        surface: Color(0xFF121212),
        onSurface: Colors.white,
        surfaceContainerHighest: Color(0xFF282828),
        outline: Color(0x1AFFFFFF),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.black,
        indicatorColor: const Color(0xFF1ED760).withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF1ED760) : const Color(0xFFA7A7A7),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? const Color(0xFF1ED760) : const Color(0xFFA7A7A7),
          );
        }),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF1ED760)
              : const Color(0xFF3E3E3E),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1AFFFFFF),
        thickness: 1,
        space: 0,
      ),
    );
  }
}
