import 'package:flutter/material.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
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

    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;

    return Semantics(
      button: true,
      label: 'Open player',
      child: GestureDetector(
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
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(LbRadius.card),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: track.color,
                        borderRadius: BorderRadius.circular(LbRadius.art),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(LbRadius.art),
                        child: createCachedNetworkImage(
                          imageUrl: track.localArtPath ?? track.thumbnailUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          memCacheWidth: 42,
                        ),
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
                            style: theme.textTheme.titleSmall,
                          ),
                          // owning playlist when known, artist otherwise,
                          // nothing when that would repeat the title
                          if (track.subtitle.isNotEmpty)
                            Text(
                              track.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      iconSize: 26,
                      tooltip: backgroundPlayer.isPlaying ? 'Pause' : 'Play',
                      icon: Icon(backgroundPlayer.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow),
                      onPressed: backgroundPlayer.togglePlay,
                    ),
                    IconButton(
                      iconSize: 26,
                      tooltip: 'Next',
                      icon: const Icon(Icons.skip_next),
                      onPressed: () => backgroundPlayer.skipToNext(),
                    ),
                  ],
                ),
              ),
              // rounded gradient progress bar inside the card bottom,
              // only this bar rebuilds on a position tick
              ValueListenableBuilder<double>(
                valueListenable: backgroundPlayer.progressListenable,
                builder: (context, progress, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(9, 0, 9, 7),
                  child: SizedBox(
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: tokens.brandGradient,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const SizedBox(height: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
