import 'package:flutter/material.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:provider/provider.dart';

import '../models/beat_models.dart';
import '../providers/player_provider.dart';
import '../widgets/track_tile.dart';

class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final topInset = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        // Hero header.
        SliverToBoxAdapter(
          child: Container(
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
                const Text('847 songs', style: TextStyle(fontSize: 13, color: Color(0xFFA7A7A7))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.shuffle, color: Colors.white),
                      label: const Text('Shuffle', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x4DFFFFFF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const Spacer(),
                    FloatingActionButton(
                      backgroundColor: const Color(0xFF1ED760),
                      foregroundColor: Colors.black,
                      elevation: 4,
                      onPressed: () => backgroundPlayer.playBeat(sampleTracks[0]),
                      child: const Icon(Icons.play_arrow, size: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Track list.
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final t = sampleTracks[i];
              final isActive = backgroundPlayer.currentTrack?.id == t.id;
              return TrackTile(
                beat: t,
                isActive: isActive,
                isPlaying: isActive && backgroundPlayer.isPlaying,
                onTap: () => backgroundPlayer.playBeat(t),
              );
            },
            childCount: sampleTracks.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
