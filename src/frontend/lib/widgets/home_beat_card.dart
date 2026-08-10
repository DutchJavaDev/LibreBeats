import 'package:flutter/material.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';

/// Square carousel card for a beat: artwork (gradient fallback) with title
/// and subtitle below. The playing card gets a small equalizer badge on
/// its artwork instead of a tinted title. Extracted from the home history
/// row so other carousels can reuse it.
class HomeBeatCard extends StatelessWidget {
  const HomeBeatCard({
    super.key,
    required this.beat,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
    this.subtitle,
  });

  final Beat beat;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;

  /// Overrides the default subtitle (the beat's playlist, artist fallback).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = subtitle ?? beat.subtitle;

    return SizedBox(
      width: 108,
      child: InkWell(
        borderRadius: BorderRadius.circular(LbRadius.card),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 108,
                  height: 108,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: beat.color,
                    borderRadius: BorderRadius.circular(LbRadius.card),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(LbRadius.card),
                    child: createCachedNetworkImage(
                      imageUrl: beat.localArtPath ?? beat.thumbnailUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: 108,
                    ),
                  ),
                ),
                if (isActive)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: PlayingBarsIndicator(
                          playing: isPlaying, size: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              beat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (line.isNotEmpty && line != beat.title)
              Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
