import 'package:flutter/material.dart';
import 'package:librebeats/data/models.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/shared_widgets.dart';
import '../theme/app_theme.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: LibreBeatsTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: playlist.isServer
                            ? [const Color(0xFF1A2A3A), LibreBeatsTheme.background]
                            : [const Color(0xFF3A1A1A), LibreBeatsTheme.background],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: LibreBeatsTheme.surface,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 30,
                                offset: const Offset(0, 10))
                          ],
                        ),
                        child: Center(
                          child: Text(playlist.isServer ? '📡' : '🎵',
                              style: const TextStyle(fontSize: 60)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(playlist.name,
                          style: const TextStyle(
                              color: LibreBeatsTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text('${playlist.songCount} songs',
                          style: const TextStyle(
                              color: LibreBeatsTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Play controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AccentButton(
                      label: 'Play',
                      icon: Icons.play_arrow_rounded,
                      onTap: playlist.songs.isEmpty
                          ? null
                          : () => player.playSong(
                                playlist.songs.first,
                                playlist: playlist,
                                queue: playlist.songs,
                              ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AccentButton(
                      label: 'Shuffle',
                      icon: Icons.shuffle_rounded,
                      outlined: true,
                      onTap: playlist.songs.isEmpty
                          ? null
                          : () {
                              final shuffled = [...playlist.songs]..shuffle();
                              player.playSong(shuffled.first,
                                  playlist: playlist, queue: shuffled);
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Song list
          if (playlist.songs.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.queue_music, color: LibreBeatsTheme.textDim, size: 48),
                    SizedBox(height: 12),
                    Text('No songs yet',
                        style: TextStyle(color: LibreBeatsTheme.textSecondary, fontSize: 15)),
                    SizedBox(height: 6),
                    Text('Search for songs and add them here.',
                        style: TextStyle(color: LibreBeatsTheme.textDim, fontSize: 13)),
                  ],
                ),
              ),
            ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final song = playlist.songs[i];
                return SongTile(
                  song: song,
                  onTap: () => player.playSong(song, playlist: playlist, queue: playlist.songs),
                  onMore: () => _showSongOptions(context, song),
                );
              },
              childCount: playlist.songs.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showSongOptions(BuildContext context, Song song) {
    final library = context.read<LibraryProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: LibreBeatsTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!playlist.isServer)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                title: const Text('Remove from playlist', style: TextStyle(color: Colors.red)),
                onTap: () {
                  library.removeSongFromPlaylist(playlist.id, song.id);
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: LibreBeatsTheme.textSecondary, size: 20),
              title: const Text('Add to another playlist', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.share, color: LibreBeatsTheme.textSecondary, size: 20),
              title: const Text('Share', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}