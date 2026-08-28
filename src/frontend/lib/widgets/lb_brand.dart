import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/lb_tokens.dart';

/// The gradient rule under every screen title.
class BrandRule extends StatelessWidget {
  const BrandRule({super.key, this.width = 52});

  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LbTokens>()!;
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        gradient: tokens.titleRule,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Static three-bar glyph leading every section header.
class BarGlyph extends StatelessWidget {
  const BarGlyph({super.key, this.height = 12});

  final double height;

  @override
  Widget build(BuildContext context) {
    final bars = Theme.of(context).extension<LbTokens>()!.emblemBars;
    Widget bar(double factor, Color color) => Container(
          width: 3,
          height: height * factor,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        bar(0.58, bars[0]),
        bar(1.0, bars[1]),
        bar(0.75, bars[2]),
      ],
    );
  }
}

/// Section header used on every screen: bar glyph + sentence-case title,
/// optional trailing widget (count, button).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding});

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          const BarGlyph(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Three-bar equalizer marking the playing track. Animates only while
/// [playing]; frozen at mid heights when paused. At most one visible per
/// list, so the single AnimationController is cheap.
class PlayingBarsIndicator extends StatefulWidget {
  const PlayingBarsIndicator({
    super.key,
    required this.playing,
    this.size = 14,
    this.color,
  });

  final bool playing;
  final double size;
  final Color? color;

  @override
  State<PlayingBarsIndicator> createState() => _PlayingBarsIndicatorState();
}

class _PlayingBarsIndicatorState extends State<PlayingBarsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(PlayingBarsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? Theme.of(context).extension<LbTokens>()!.nowPlaying;
    final barWidth = widget.size / 5;
    return Semantics(
      label: 'Now playing',
      child: RepaintBoundary(
        child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            double level(double phase) => widget.playing
                ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * (t + phase)))
                : 0.55;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final phase in const [0.0, 0.33, 0.66])
                  Container(
                    width: barWidth,
                    height: widget.size * level(phase),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }
}

/// The five icon bars in a rounded dark tile. Replaces the purple liked
/// tile and hero; also the About row icon and empty states.
class LbEmblem extends StatelessWidget {
  const LbEmblem({super.key, required this.size, this.showHeart = false});

  final double size;
  final bool showHeart;

  static const _factors = [0.27, 0.42, 0.53, 0.42, 0.27];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final barWidth = size / 15;
    final badge = size * 0.32;

    final tile = Container(
      width: size,
      height: size,
      alignment: const Alignment(0, 0.45),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: barWidth * 0.75,
        children: [
          for (var i = 0; i < _factors.length; i++)
            Container(
              width: barWidth,
              height: size * _factors[i],
              decoration: BoxDecoration(
                color: tokens.emblemBars[i],
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            ),
        ],
      ),
    );

    if (!showHeart) return tile;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          top: -badge * 0.22,
          right: -badge * 0.22,
          child: Container(
            width: badge,
            height: badge,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite,
              size: badge * 0.55,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Primary action pill with the brand gradient fill. Secondaries stay
/// OutlinedButton (themed pills).
class GradientPillButton extends StatelessWidget {
  const GradientPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: ShapeDecoration(
              gradient: tokens.brandGradient,
              shape: const StadiumBorder(),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onPressed,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: theme.colorScheme.onPrimary),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge!
                          .copyWith(color: theme.colorScheme.onPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selected-state nav icon: the icon with a small gradient underline.
/// Used as [NavigationDestination.selectedIcon]; colors come from the
/// navigation bar theme, the underline from the brand gradient.
class NavUnderlineIcon extends StatelessWidget {
  const NavUnderlineIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LbTokens>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(height: 3),
        Container(
          width: 14,
          height: 2.5,
          decoration: BoxDecoration(
            gradient: tokens.brandGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
