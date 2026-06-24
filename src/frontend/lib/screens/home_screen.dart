import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../providers/player_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final topInset = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        // 1. Header with greeting + quick-picks grid.
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A3A2A), Color(0xFF121212)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.5,
                  ),
                  itemCount: sampleTracks.length.clamp(0, 6),
                  itemBuilder: (context, i) {
                    final t = sampleTracks[i];
                    final isActive = player.currentTrack?.id == t.id;
                    return Material(
                      color: Colors.white.withOpacity(isActive ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => player.playTrack(t),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: t.color,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                              ),
                              child: Text(
                                t.title.isNotEmpty ? t.title[0] : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // 2. Recently played header.
        SliverToBoxAdapter(child: _sectionHeader('Recently played')),
        // 3. Horizontal albums row.
        SliverToBoxAdapter(
          child: SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sampleAlbums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final album = sampleAlbums[i];
                return SizedBox(
                  width: 140,
                  child: AlbumCard(
                    album: album,
                    onPlay: () {
                      final track = sampleTracks.firstWhere(
                        (t) => t.album == album.title,
                        orElse: () => sampleTracks[0],
                      );
                      player.playTrack(track);
                    },
                  ),
                );
              },
            ),
          ),
        ),
        // 4. Liked songs header.
        SliverToBoxAdapter(child: _sectionHeader('Liked songs')),
        // 5. Track list.
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final t = sampleTracks[i];
              final isActive = player.currentTrack?.id == t.id;
              return TrackTile(
                track: t,
                isActive: isActive,
                isPlaying: isActive && player.isPlaying,
                onTap: () => player.playTrack(t),
              );
            },
            childCount: sampleTracks.length,
          ),
        ),
        // 6. Trailing spacer.
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const Text('Show all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA7A7A7))),
        ],
      ),
    );
  }
}
