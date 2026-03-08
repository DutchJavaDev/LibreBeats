// TODO Implement this library.import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/shared_widgets.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<LibraryProvider, PlayerProvider>(
      builder: (context, library, player, _) {
        return CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              pinned: false,
              backgroundColor: LibreBeatsTheme.background,
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: LibreBeatsTheme.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('LibreBeats',
                      style: TextStyle(
                          color: LibreBeatsTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_off_rounded, color: LibreBeatsTheme.textSecondary),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Quick Filter Chips
            // SliverToBoxAdapter(
            //   child: SingleChildScrollView(
            //     scrollDirection: Axis.horizontal,
            //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            //     child: Row(
            //       children: [
            //         _FilterChip(label: 'All', selected: true),
            //         _FilterChip(label: 'Music'),
            //         _FilterChip(label: 'Podcasts'),
            //         _FilterChip(label: 'Mixes'),
            //       ],
            //     ),
            //   ),
            // ),

            // Last Played Banner
            if (library.lastPlayedSong != null)
              SliverToBoxAdapter(
                child: _LastPlayedBanner(
                  song: library.lastPlayedSong!,
                  playlist: library.lastPlayedPlaylist,
                  onTap: () => player.playSong(
                    library.lastPlayedSong!,
                    playlist: library.lastPlayedPlaylist,
                  ),
                ),
              ),

            // Recently Played Playlists (grid)
            if (library.playlistsByLastPlayed.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Recently Played'),
                      _RecentGrid(library: library, player: player),
                    ],
                  ),
                ),

            // Your Playlists
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Your Playlists', actionLabel: 'See all'),
                  SizedBox(
                    height: 190,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: library.userPlaylists.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, i) {
                        final pl = library.userPlaylists[i];
                        return PlaylistCard(
                          playlist: pl,
                          onTap: () {},
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Server Playlists
            if (library.serverPlaylists.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'From Your Servers'),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: library.serverPlaylists.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, i) {
                          final pl = library.serverPlaylists[i];
                          return PlaylistCard(playlist: pl, onTap: () {});
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Suggestions (from server mix)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Suggested',
                    actionLabel: 'Refresh',
                  ),
                  _SuggestionNote(),
                  ...library.suggestions.take(4).map((song) => SongTile(
                        song: song,
                        onTap: () => player.playSong(song),
                        onMore: () => _showSongMenu(context, song, library),
                      )),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSongMenu(BuildContext context, song, LibraryProvider library) {
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
            ListTile(
              leading: const Icon(Icons.playlist_add, color: LibreBeatsTheme.textSecondary),
              title: const Text('Add to playlist', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylist(context, song, library);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: LibreBeatsTheme.textSecondary),
              title: const Text('Share', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylist(BuildContext context, song, LibraryProvider library) {
    showModalBottomSheet(
      context: context,
      backgroundColor: LibreBeatsTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add to playlist',
                style: TextStyle(
                    color: LibreBeatsTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...library.userPlaylists.map((pl) => ListTile(
                  leading: const Icon(Icons.queue_music, color: LibreBeatsTheme.textSecondary),
                  title: Text(pl.name, style: const TextStyle(color: LibreBeatsTheme.textPrimary)),
                  subtitle: Text('${pl.songCount} songs', style: const TextStyle(color: LibreBeatsTheme.textSecondary, fontSize: 11)),
                  onTap: () {
                    library.addSongToPlaylist(pl.id, song);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added to ${pl.name}'),
                        backgroundColor: LibreBeatsTheme.surface,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _FilterChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? LibreBeatsTheme.textPrimary : LibreBeatsTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? LibreBeatsTheme.background : LibreBeatsTheme.textSecondary,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _LastPlayedBanner extends StatelessWidget {
  final song;
  final playlist;
  final VoidCallback onTap;
  const _LastPlayedBanner({required this.song, this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              LibreBeatsTheme.accent.withOpacity(0.25),
              LibreBeatsTheme.accent.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LibreBeatsTheme.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: LibreBeatsTheme.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Text('🎵', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LAST PLAYED',
                      style: TextStyle(
                          color: LibreBeatsTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text(song.title,
                      style: const TextStyle(
                          color: LibreBeatsTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(song.artist,
                      style: const TextStyle(
                          color: LibreBeatsTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: LibreBeatsTheme.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentGrid extends StatelessWidget {
  final LibraryProvider library;
  final PlayerProvider player;
  const _RecentGrid({required this.library, required this.player});

  @override
  Widget build(BuildContext context) {
    final recent = library.playlistsByLastPlayed.take(4).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: recent.length,
        itemBuilder: (_, i) {
          final pl = recent[i];
          return GestureDetector(
            onTap: () {
              if (pl.songs.isNotEmpty) {
                player.playSong(pl.songs.first, playlist: pl, queue: pl.songs);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: LibreBeatsTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    decoration: BoxDecoration(
                      color: pl.isServer
                          ? const Color(0xFF1A2A3A)
                          : const Color(0xFF2A1A1A),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    ),
                    child: Center(
                      child: Text(pl.isServer ? '📡' : '🎵',
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(pl.name,
                        style: const TextStyle(
                            color: LibreBeatsTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SuggestionNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: LibreBeatsTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: LibreBeatsTheme.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: LibreBeatsTheme.textSecondary, size: 15),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Suggestions are pulled from your connected server libraries and local playlists.',
                style: TextStyle(color: LibreBeatsTheme.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}