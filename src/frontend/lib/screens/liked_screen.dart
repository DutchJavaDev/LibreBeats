import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:provider/provider.dart';

import '../models/beat_models.dart';
import '../widgets/beat_tile.dart';
import '../widgets/widget_builder.dart';

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  // liked beats play as one queue, downloaded ones from disk
  BeatMix _asMix(List<Beat> beats) => BeatMix(
        id: 0,
        sourceId: 'liked',
        title: 'Liked Songs',
        thumbnailUrl: '',
        trackCount: beats.length,
        beats: beats,
      );

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final likedProvider = context.watch<LikedProvider>();
    final beats = [
      for (final record in likedProvider.liked) likedProvider.beatFor(record)
    ];
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final topInset = MediaQuery.of(context).padding.top;

    // the play pill mirrors the player whenever a liked beat is up
    final currentKey = backgroundPlayer.currentBeat?.key;
    final playingLiked =
        currentKey != null && beats.any((b) => b.key == currentKey);
    final shuffleOn = backgroundPlayer.shuffle;

    final stats = likedProvider.count == 0
        ? '0 songs'
        : '${likedProvider.count} songs · '
            '${formatTotalDuration(likedProvider.likedDuration)} · on this device';

    // header stays put, only the track list below scrolls
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LbEmblem(size: 74, showHeart: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Liked Songs',
                            style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 5),
                        const BrandRule(width: 44),
                        const SizedBox(height: 5),
                        Text(stats, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  GradientPillButton(
                    label: playingLiked && backgroundPlayer.isPlaying
                        ? 'Pause'
                        : 'Play',
                    icon: playingLiked && backgroundPlayer.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    onPressed: beats.isEmpty
                        ? null
                        : () {
                            if (playingLiked) {
                              backgroundPlayer.togglePlay();
                              return;
                            }
                            backgroundPlayer.playBeatMix(
                                _asMix(beats), beats.first);
                          },
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: beats.isEmpty
                        ? null
                        : () {
                            // playing already: just flip the mode, otherwise
                            // start a shuffled run through the liked list
                            if (playingLiked) {
                              backgroundPlayer.toggleShuffle();
                              return;
                            }
                            if (!backgroundPlayer.shuffle) {
                              backgroundPlayer.toggleShuffle();
                            }
                            backgroundPlayer.playBeatMix(_asMix(beats),
                                beats[Random().nextInt(beats.length)]);
                          },
                    style: shuffleOn
                        ? OutlinedButton.styleFrom(
                            foregroundColor: tokens.nowPlaying,
                            side: BorderSide(color: tokens.nowPlaying),
                          )
                        : null,
                    icon: const Icon(Icons.shuffle, size: 16),
                    label: Text(shuffleOn ? 'Shuffle on' : 'Shuffle'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        Expanded(
          child: beats.isEmpty
              ? Center(
                  child: Text(
                      'Nothing liked yet, tap the heart on a playing song',
                      style: theme.textTheme.bodyMedium),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  itemCount: beats.length,
                  itemBuilder: (context, i) {
                    final t = beats[i];
                    final isActive = backgroundPlayer.currentBeat?.key == t.key;
                    return BeatTile(
                      beat: t,
                      isActive: isActive,
                      isPlaying: isActive && backgroundPlayer.isPlaying,
                      downloaded: likedProvider.isDownloaded(t.key),
                      // always filled here, tapping it un-likes with an undo
                      liked: true,
                      onLike: () => toggleBeatLike(context, likedProvider, t),
                      // whole list as the queue, like a beatmix, so skip
                      // next/previous walks through the liked songs
                      onTap: () =>
                          backgroundPlayer.playBeatMix(_asMix(beats), t),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
