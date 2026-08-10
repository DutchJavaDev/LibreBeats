import 'package:flutter/material.dart';

/// Corner radius scale. Everything round in the app uses one of these.
abstract final class LbRadius {
  /// List artwork up to ~64px.
  static const double art = 8;

  /// Search field, grid covers, mini player.
  static const double card = 12;

  /// Cards, big covers, dialogs, sheets.
  static const double hero = 16;
}

/// Brand tokens that have no ColorScheme slot: the icon-bar greens, the
/// gradients built from them and the status colours. One const instance per
/// mode, resolved through `Theme.of(context).extension<LbTokens>()!`.
class LbTokens extends ThemeExtension<LbTokens> {
  /// Tint for the playing track: left edge bar, equalizer, active
  /// shuffle/repeat/heart, armed sleep timer.
  final Color nowPlaying;

  /// Fill for primary actions: pills, the play circle, progress bars and
  /// the nav underline.
  final Gradient brandGradient;

  /// The rule under every screen title.
  final Gradient titleRule;

  /// The five icon bars, left to right, for [LbEmblem] and [BarGlyph].
  final List<Color> emblemBars;

  /// Downloading / connecting states.
  final Color warning;

  /// Healthy-server states.
  final Color success;

  /// Backing behind artwork while it loads or when it is missing.
  final Color artworkPlaceholder;

  /// Background of destructive icon boxes (settings delete).
  final Color dangerContainer;

  const LbTokens({
    required this.nowPlaying,
    required this.brandGradient,
    required this.titleRule,
    required this.emblemBars,
    required this.warning,
    required this.success,
    required this.artworkPlaceholder,
    required this.dangerContainer,
  });

  static const dark = LbTokens(
    nowPlaying: Color(0xFF24E068),
    brandGradient: LinearGradient(
      colors: [Color(0xFF1EC85C), Color(0xFF24E068)],
    ),
    titleRule: LinearGradient(
      colors: [Color(0xFF1EC85C), Color(0xFFEDFFF4), Color(0xFF1EC85C)],
    ),
    emblemBars: [
      Color(0xFF1EC85C),
      Color(0xFF24E068),
      Color(0xFFEDFFF4),
      Color(0xFF24E068),
      Color(0xFF1ECA5D),
    ],
    warning: Color(0xFFE8C32E),
    success: Color(0xFF57C982),
    artworkPlaceholder: Color(0xFF1E1F1E),
    dangerContainer: Color(0xFF2A1215),
  );

  static const light = LbTokens(
    nowPlaying: Color(0xFF0F9C46),
    brandGradient: LinearGradient(
      colors: [Color(0xFF0F9C46), Color(0xFF1EC85C)],
    ),
    titleRule: LinearGradient(
      colors: [Color(0xFF0F9C46), Color(0xFF7ED8A5), Color(0xFF0F9C46)],
    ),
    emblemBars: [
      Color(0xFF128F44),
      Color(0xFF17AE52),
      Color(0xFFB9EBCD),
      Color(0xFF17AE52),
      Color(0xFF139045),
    ],
    warning: Color(0xFF8F6E00),
    success: Color(0xFF2E7D4F),
    artworkPlaceholder: Color(0xFFDEE6E0),
    dangerContainer: Color(0xFFFBE4E2),
  );

  @override
  LbTokens copyWith({
    Color? nowPlaying,
    Gradient? brandGradient,
    Gradient? titleRule,
    List<Color>? emblemBars,
    Color? warning,
    Color? success,
    Color? artworkPlaceholder,
    Color? dangerContainer,
  }) {
    return LbTokens(
      nowPlaying: nowPlaying ?? this.nowPlaying,
      brandGradient: brandGradient ?? this.brandGradient,
      titleRule: titleRule ?? this.titleRule,
      emblemBars: emblemBars ?? this.emblemBars,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      artworkPlaceholder: artworkPlaceholder ?? this.artworkPlaceholder,
      dangerContainer: dangerContainer ?? this.dangerContainer,
    );
  }

  @override
  LbTokens lerp(LbTokens? other, double t) {
    if (other == null) return this;
    return LbTokens(
      nowPlaying: Color.lerp(nowPlaying, other.nowPlaying, t)!,
      brandGradient: Gradient.lerp(brandGradient, other.brandGradient, t)!,
      titleRule: Gradient.lerp(titleRule, other.titleRule, t)!,
      emblemBars: [
        for (var i = 0; i < emblemBars.length; i++)
          Color.lerp(emblemBars[i], other.emblemBars[i], t)!,
      ],
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      artworkPlaceholder:
          Color.lerp(artworkPlaceholder, other.artworkPlaceholder, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
    );
  }
}
