import 'package:flutter/material.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';

import '../models/beat_models.dart';

/// Reusable list row for a beat. Shows the artwork (gradient fallback),
/// title, owning playlist (artist when unknown) and duration. The playing
/// row gets a left edge bar and a small equalizer instead of a tinted
/// title.
class BeatTile extends StatelessWidget {
  final Beat beat;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;

  /// Shows the on-disk glyph next to the duration.
  final bool downloaded;

  /// Liked state for the trailing heart, null hides the heart entirely.
  final bool? liked;

  /// Tap on the heart. Only used when [liked] is set.
  final VoidCallback? onLike;

  const BeatTile({
    super.key,
    required this.beat,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
    this.downloaded = false,
    this.liked,
    this.onLike,
  });

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;

    final tile = ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: beat.color,
          borderRadius: BorderRadius.circular(LbRadius.art),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LbRadius.art),
          child: createCachedNetworkImage(
            imageUrl: beat.localArtPath ?? beat.thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: 48,
          ),
        ),
      ),
      title: Text(
        beat.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isActive
            ? theme.textTheme.titleSmall!
                .copyWith(fontWeight: FontWeight.w700)
            : theme.textTheme.titleSmall,
      ),
      // empty when it would only repeat the title, the model guards that
      subtitle: beat.subtitle.isEmpty
          ? null
          : Text(
              beat.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            PlayingBarsIndicator(playing: isPlaying),
            const SizedBox(width: 10),
          ],
          if (liked != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              iconSize: 18,
              onPressed: onLike,
              icon: Icon(
                liked! ? Icons.favorite : Icons.favorite_border,
                color: liked!
                    ? tokens.nowPlaying
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (downloaded) ...[
            Icon(Icons.download_done,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            _format(beat.duration),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );

    if (!isActive) return tile;
    // the playing row's left edge bar
    return Stack(
      children: [
        tile,
        Positioned(
          left: 0,
          top: 12,
          bottom: 12,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: tokens.nowPlaying,
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(2)),
            ),
          ),
        ),
      ],
    );
  }
}
