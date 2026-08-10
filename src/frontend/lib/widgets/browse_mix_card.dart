import 'package:flutter/material.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';

/// One playlist in the browse grid: the cover sharp and unobstructed,
/// title and count below it, a heart badge when the mix is in the library.
class BrowseMixCard extends StatelessWidget {
  final BeatMix mix;
  final bool liked;
  final VoidCallback onTap;

  /// Set when another playlist shares this title, names the server.
  final String? hostLabel;

  /// Cover fallback when there is no thumbnail (the mocked home sections),
  /// defaults to the flat artwork placeholder.
  final Gradient? fallbackArt;

  /// Replaces the "n songs" subtitle when set (e.g. "42 plays · 18 songs").
  final String? subtitleOverride;

  const BrowseMixCard({
    super.key,
    required this.mix,
    required this.onTap,
    this.liked = false,
    this.hostLabel,
    this.fallbackArt,
    this.subtitleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final subtitle = subtitleOverride ??
        (hostLabel == null
            ? '${mix.trackCount} songs'
            : '${mix.trackCount} songs · $hostLabel');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(LbRadius.card),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fallbackArt == null
                          ? tokens.artworkPlaceholder
                          : null,
                      gradient: fallbackArt,
                    ),
                    child: createCachedNetworkImage(
                      imageUrl: mix.thumbnailUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                    ),
                  ),
                ),
              ),
              if (liked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite,
                        size: 12, color: tokens.nowPlaying),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mix.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall!
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
