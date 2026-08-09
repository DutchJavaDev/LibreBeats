import 'package:flutter/material.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';

import '../models/beat_models.dart';

/// Reusable list row for a beat. Shows the artwork (gradient fallback),
/// title, artist and duration; when [isActive] it overlays a play/pause
/// glyph on the art and tints the title green.
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: beat.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: createCachedNetworkImage(
              imageUrl: beat.localArtPath ?? beat.thumbnailUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          if (isActive)
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        beat.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF1ED760) : Colors.white,
        ),
      ),
      // ingest stores the title as artist too, repeating it says nothing
      subtitle: beat.artist.isEmpty || beat.artist == beat.title
          ? null
          : Text(
              beat.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (liked != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
              iconSize: 18,
              onPressed: onLike,
              icon: Icon(
                liked! ? Icons.favorite : Icons.favorite_border,
                color: liked!
                    ? const Color(0xFF1ED760)
                    : const Color(0xFFA7A7A7),
              ),
            ),
          if (downloaded) ...[
            const Icon(Icons.download_done, size: 14, color: Color(0xFFA7A7A7)),
            const SizedBox(width: 6),
          ],
          Text(
            _format(beat.duration),
            style: const TextStyle(fontSize: 13, color: Color(0xFFA7A7A7)),
          ),
        ],
      ),
    );
  }
}
