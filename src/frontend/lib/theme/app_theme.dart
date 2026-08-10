import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lb_tokens.dart';

/// The two app themes, derived from the launcher icon: bar greens
/// #1EC85C/#24E068, mint #EDFFF4 and the #171717 -> #0E0E0E background.
/// Built once — screens read everything through Theme.of(context).
abstract final class AppTheme {
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF24E068),
    onPrimary: Color(0xFF00210E),
    primaryContainer: Color(0xFF124A28),
    onPrimaryContainer: Color(0xFFA9F5C4),
    secondary: Color(0xFF7FCB9C),
    onSecondary: Color(0xFF06301A),
    secondaryContainer: Color(0xFF1B3B29),
    onSecondaryContainer: Color(0xFFC2EAD1),
    tertiary: Color(0xFFA8E8C3),
    onTertiary: Color(0xFF0A2E1C),
    tertiaryContainer: Color(0xFF234636),
    onTertiaryContainer: Color(0xFFD8F7E4),
    // the red the app already used everywhere, now with a real slot
    error: Color(0xFFE8453C),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF4A130E),
    onErrorContainer: Color(0xFFFFDAD5),
    surface: Color(0xFF0E0E0E),
    onSurface: Color(0xFFEDFFF4),
    surfaceDim: Color(0xFF0A0A0A),
    surfaceBright: Color(0xFF2C2C2C),
    surfaceContainerLowest: Color(0xFF090909),
    surfaceContainerLow: Color(0xFF141414),
    surfaceContainer: Color(0xFF171717),
    surfaceContainerHigh: Color(0xFF1E1F1E),
    surfaceContainerHighest: Color(0xFF262726),
    onSurfaceVariant: Color(0xFFA5B2A9),
    outline: Color(0xFF3A403C),
    outlineVariant: Color(0xFF252B27),
    inverseSurface: Color(0xFFEDFFF4),
    onInverseSurface: Color(0xFF171D18),
    inversePrimary: Color(0xFF0F9C46),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    // #1EC85C darkened so text and fills pass 4.5:1 on light surfaces
    primary: Color(0xFF0F9C46),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBFF2D2),
    onPrimaryContainer: Color(0xFF063018),
    secondary: Color(0xFF3E6B50),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFC9E9D5),
    onSecondaryContainer: Color(0xFF12301E),
    tertiary: Color(0xFF2C6A4C),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD2F2E0),
    onTertiaryContainer: Color(0xFF0B2B1D),
    error: Color(0xFFC62D24),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD5),
    onErrorContainer: Color(0xFF3D0905),
    surface: Color(0xFFF6FBF7),
    onSurface: Color(0xFF161D18),
    surfaceDim: Color(0xFFD7DFD9),
    surfaceBright: Color(0xFFF6FBF7),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0F6F1),
    surfaceContainer: Color(0xFFEAF1EC),
    surfaceContainerHigh: Color(0xFFE4ECE6),
    surfaceContainerHighest: Color(0xFFDEE6E0),
    onSurfaceVariant: Color(0xFF414944),
    outline: Color(0xFF717A73),
    outlineVariant: Color(0xFFC1CAC3),
    inverseSurface: Color(0xFF2B322D),
    onInverseSurface: Color(0xFFEDF2EE),
    inversePrimary: Color(0xFF24E068),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static final ThemeData dark = _build(darkScheme, LbTokens.dark);
  static final ThemeData light = _build(lightScheme, LbTokens.light);

  /// One type scale for the whole app, Plus Jakarta Sans in the five bundled
  /// weights (400/500/600/700/800). No screen defines its own TextStyle.
  static TextTheme _textTheme(ColorScheme scheme) {
    final base = GoogleFonts.plusJakartaSansTextTheme(
      Typography.material2021(platform: TargetPlatform.android)
          .englishLike
          .apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
            decorationColor: scheme.onSurface,
          ),
    );
    return base.copyWith(
      // screen titles, always followed by a BrandRule
      headlineMedium: base.headlineMedium!.copyWith(
          fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
      // hero titles: beatmix view, full player track
      titleLarge: base.titleLarge!
          .copyWith(fontSize: 20, fontWeight: FontWeight.w800),
      // section headers via SectionHeader
      titleMedium: base.titleMedium!
          .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      // tile and row titles
      titleSmall: base.titleSmall!
          .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge!
          .copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium!.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant),
      bodySmall: base.bodySmall!.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant),
      // buttons and pills
      labelLarge: base.labelLarge!
          .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium!
          .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
      // nav labels, grid captions, the Preview chip
      labelSmall: base.labelSmall!.copyWith(
          fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.2),
    );
  }

  static ThemeData _build(ColorScheme scheme, LbTokens tokens) {
    final textTheme = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [tokens],
      textTheme: textTheme,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        // the active tab is marked by a gradient underline in its
        // selectedIcon (lb_brand.dart), not by the M3 pill
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall!.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LbRadius.hero),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintStyle:
            textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LbRadius.card),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LbRadius.card),
          borderSide: BorderSide(color: scheme.primary),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LbRadius.card),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.18),
        thumbColor: scheme.onSurface,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle:
            textTheme.bodyMedium!.copyWith(color: scheme.onSurface),
        actionTextColor: scheme.primary,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LbRadius.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LbRadius.hero),
        ),
        titleTextStyle: textTheme.titleLarge!
            .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle:
            textTheme.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(LbRadius.hero)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.onSurface.withValues(alpha: 0.3),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
          visualDensity: VisualDensity.compact,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHighest),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
