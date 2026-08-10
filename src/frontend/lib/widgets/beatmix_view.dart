import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/beat_tile.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

/// Fullscreen view of a beatmix: cover, counts, the shuffle/heart/play row
/// and the track list. Same grammar as the liked screen, the play button
/// mirrors the player whenever this mix is the queue.
class BeatMixView extends StatelessWidget {
  final BeatMix beatMix;

  const BeatMixView({super.key, required this.beatMix});

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final likedProvider = context.watch<LikedProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = theme.extension<LbTokens>()!;

    final beats = beatMix.beats ?? const <Beat>[];
    final playable = [
      for (final b in beats)
        if (b.isPlayable) b
    ];
    final total = beats.fold(Duration.zero, (sum, b) => sum + b.duration);

    final isLiked = likedProvider.isMixLiked(beatMix.key);
    LikedMix? record;
    for (final m in likedProvider.likedMixes) {
      if (m.key == beatMix.key) record = m;
    }

    final currentKey = backgroundPlayer.currentBeat?.key;
    final playingThis =
        currentKey != null && beats.any((b) => b.key == currentKey);
    final shuffleOn = backgroundPlayer.shuffle;

    return Column(
      children: [
        // header stays put, only the track list below scrolls
        Container(
          padding: EdgeInsets.fromLTRB(
              16, MediaQuery.of(context).padding.top + 8, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorScheme.surfaceContainerHighest, colorScheme.surface],
            ),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(LbRadius.hero),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(LbRadius.hero),
                  child: ColoredBox(
                    color: tokens.artworkPlaceholder,
                    child: createCachedNetworkImage(
                      imageUrl: beatMix.thumbnailUrl,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      showSpinner: true,
                      memCacheWidth: 160,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                beatMix.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: theme.textTheme.bodySmall,
                  children: [
                    TextSpan(
                        text:
                            '${beats.length} songs · ${formatTotalDuration(total)}'),
                    if (record != null && !record.complete)
                      TextSpan(
                          text:
                              ' · ${record.downloadedCount} of ${record.beats.length} downloaded',
                          style: theme.textTheme.bodySmall!
                              .copyWith(color: tokens.warning)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: playable.isEmpty
                        ? null
                        : () {
                            if (playingThis) {
                              backgroundPlayer.toggleShuffle();
                              return;
                            }
                            if (!backgroundPlayer.shuffle) {
                              backgroundPlayer.toggleShuffle();
                            }
                            backgroundPlayer.playBeatMix(beatMix,
                                playable[Random().nextInt(playable.length)]);
                          },
                    icon: const Icon(Icons.shuffle),
                    label: Text(shuffleOn ? 'Shuffle on' : 'Shuffle'),
                    // active tint on top of the themed stadium outline
                    style: shuffleOn
                        ? OutlinedButton.styleFrom(
                            foregroundColor: tokens.nowPlaying,
                            side: BorderSide(color: tokens.nowPlaying))
                        : null,
                  ),
                  const SizedBox(width: 4),
                  // likes the whole mix, downloads it and puts it in the library
                  IconButton(
                    onPressed: () => likedProvider.toggleLikeMix(beatMix),
                    icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked
                            ? tokens.nowPlaying
                            : colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  GradientPillButton(
                    label: playingThis && backgroundPlayer.isPlaying
                        ? 'Pause'
                        : 'Play',
                    icon: playingThis && backgroundPlayer.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    onPressed: playable.isEmpty
                        ? null
                        : () {
                            if (playingThis) {
                              backgroundPlayer.togglePlay();
                              return;
                            }
                            backgroundPlayer.playBeatMix(
                                beatMix, playable.first);
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: beats.length,
            addAutomaticKeepAlives: false,
            itemBuilder: (context, i) {
              final beat = beats[i];
              final isActive = currentKey == beat.key;
              return BeatTile(
                beat: beat,
                isActive: isActive,
                isPlaying: isActive && backgroundPlayer.isPlaying,
                downloaded: likedProvider.isDownloaded(beat.key),
                liked: likedProvider.isLiked(beat.key),
                onLike: () => toggleBeatLike(context, likedProvider, beat),
                onTap: () => backgroundPlayer.playBeatMix(beatMix, beat),
              );
            },
          ),
        ),
      ],
    );
  }
}
