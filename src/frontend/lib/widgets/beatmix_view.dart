import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/widgets/beat_tile.dart';
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF282828), Color(0xFF121212)],
            ),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ColoredBox(
                    color: const Color(0xFF282828),
                    child: createCachedNetworkImage(
                      imageUrl: beatMix.thumbnailUrl,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
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
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
                  children: [
                    TextSpan(
                        text:
                            '${beats.length} songs · ${formatTotalDuration(total)}'),
                    if (record != null && !record.complete)
                      TextSpan(
                          text:
                              ' · ${record.downloadedCount} of ${record.beats.length} downloaded',
                          style: const TextStyle(color: Color(0xFFE8C32E))),
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
                    icon: Icon(Icons.shuffle,
                        color: shuffleOn ? const Color(0xFF1ED760) : Colors.white),
                    label: Text(shuffleOn ? 'Shuffle on' : 'Shuffle',
                        style: TextStyle(
                            color: shuffleOn
                                ? const Color(0xFF1ED760)
                                : Colors.white)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: shuffleOn
                              ? const Color(0xFF1ED760)
                              : const Color(0x4DFFFFFF)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // likes the whole mix, downloads it and puts it in the library
                  IconButton(
                    onPressed: () => likedProvider.toggleLikeMix(beatMix),
                    icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked
                            ? const Color(0xFF1ED760)
                            : const Color(0xFFA7A7A7)),
                  ),
                  const Spacer(),
                  FloatingActionButton(
                    backgroundColor: const Color(0xFF1ED760),
                    foregroundColor: Colors.black,
                    elevation: 4,
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
                    child: Icon(
                        playingThis && backgroundPlayer.isPlaying
                            ? Icons.pause
                            : Icons.play_arrow,
                        size: 32),
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
