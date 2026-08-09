import 'package:flutter/material.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

import 'full_player.dart';

/// Compact player docked above the bottom navigation bar. Invisible until a
/// track has been played. Tapping it opens the [FullPlayer] sheet.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final track = backgroundPlayer.currentBeat;
    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ChangeNotifierProvider.value(
            value: backgroundPlayer,
            child: const FullPlayer(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: LinearProgressIndicator(
                value: backgroundPlayer.progress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF1ED760)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: track.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: createCachedNetworkImage(
                      imageUrl: track.localArtPath ?? track.thumbnailUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFA7A7A7)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 26,
                    icon: Icon(
                        backgroundPlayer.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white),
                    onPressed: backgroundPlayer.togglePlay,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 26,
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: () => backgroundPlayer.skipToNext(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
