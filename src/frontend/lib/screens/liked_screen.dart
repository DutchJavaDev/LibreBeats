import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
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
    final topInset = MediaQuery.of(context).padding.top;

    // the big play button mirrors the player whenever a liked beat is up
    final currentKey = backgroundPlayer.currentBeat?.key;
    final playingLiked =
        currentKey != null && beats.any((b) => b.key == currentKey);
    final shuffleOn = backgroundPlayer.shuffle;

    // header stays put, only the track list below scrolls
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF450AF5), Color(0xFF121212)],
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 160,
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 72),
              ),
              const SizedBox(height: 16),
              const Text(
                'Liked Songs',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                  likedProvider.count == 0
                      ? '0 songs'
                      : '${likedProvider.count} songs · '
                          '${formatTotalDuration(likedProvider.likedDuration)}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFA7A7A7))),
              const SizedBox(height: 16),
              Row(
                children: [
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const Spacer(),
                  FloatingActionButton(
                    backgroundColor: const Color(0xFF1ED760),
                    foregroundColor: Colors.black,
                    elevation: 4,
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
                    child: Icon(
                        playingLiked && backgroundPlayer.isPlaying
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
          child: beats.isEmpty
              ? const Center(
                  child: Text('Nothing liked yet, tap the heart on a playing song',
                      style: TextStyle(color: Color(0xFFA7A7A7))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
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
                      onTap: () => backgroundPlayer.playBeatMix(_asMix(beats), t),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
