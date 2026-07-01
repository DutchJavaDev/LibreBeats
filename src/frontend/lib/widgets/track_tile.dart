import 'package:flutter/material.dart';

import '../models/beat_models.dart';

/// Reusable list row for a track. Shows the gradient "art", title, artist and
/// duration; when [isActive] it overlays a play/pause glyph on the art and
/// tints the title green.
class TrackTile extends StatelessWidget {
  final Beat track;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;

  const TrackTile({
    super.key,
    required this.track,
    required this.isActive,
    required this.isPlaying,
    required this.onTap,
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
              gradient: track.color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              track.title.isNotEmpty ? track.title[0] : '?',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF1ED760) : Colors.white,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _format(track.duration),
            style: const TextStyle(fontSize: 13, color: Color(0xFFA7A7A7)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.more_vert, color: Color(0xFFA7A7A7), size: 18),
        ],
      ),
    );
  }
}
