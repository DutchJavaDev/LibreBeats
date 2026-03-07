import 'package:flutter/material.dart';
import 'package:librebeats/data/models.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../widgets/shared_widgets.dart';
import '../theme/app_theme.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, library, _) {
        final playlists = library.playlistsByLastPlayed;
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: LibreBeatsTheme.background,
              title: const Text('Library'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add, color: LibreBeatsTheme.textSecondary),
                  onPressed: () => _showCreateDialog(context, library),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: LibreBeatsTheme.textSecondary),
                  onPressed: () {},
                ),
              ],
            ),

            // Sort tabs
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _SortChip(label: 'Recently played', selected: true),
                    _SortChip(label: 'A–Z'),
                    _SortChip(label: 'My playlists'),
                    _SortChip(label: 'Server'),
                  ],
                ),
              ),
            ),

            // Playlist list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final pl = playlists[i];
                  return _PlaylistTile(
                    playlist: pl,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlist: pl),
                      ),
                    ),
                    onDelete: () => _confirmDelete(context, library, pl),
                    onEdit: () => _showEditDialog(context, library, pl),
                  );
                },
                childCount: playlists.length,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context, LibraryProvider library) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LibreBeatsTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: LibreBeatsTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: LibreBeatsTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                library.addPlaylist(ctrl.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(color: LibreBeatsTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, LibraryProvider library, Playlist pl) {
    final ctrl = TextEditingController(text: pl.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LibreBeatsTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Playlist', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: LibreBeatsTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: LibreBeatsTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              library.updatePlaylist(pl.id, name: ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: LibreBeatsTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, LibraryProvider library, Playlist pl) {
    if (pl.isServer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete server playlists'),
          backgroundColor: LibreBeatsTheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: LibreBeatsTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Playlist', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
        content: Text('Remove "${pl.name}"? This cannot be undone.',
            style: const TextStyle(color: LibreBeatsTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: LibreBeatsTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              library.removePlaylist(pl.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Cover
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: playlist.isServer
                      ? [const Color(0xFF1A2A3A), const Color(0xFF0D1520)]
                      : [const Color(0xFF2A1A1A), const Color(0xFF150D0D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(playlist.isServer ? '📡' : '🎵',
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(playlist.name,
                            style: const TextStyle(
                                color: LibreBeatsTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (playlist.isServer)
                        ChipTag(label: 'SERVER', color: const Color(0xFF1DB954)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${playlist.songCount} songs${playlist.lastPlayed != null ? " • " + _timeAgo(playlist.lastPlayed!) : ""}',
                    style: const TextStyle(color: LibreBeatsTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 18),
              color: LibreBeatsTheme.textSecondary,
              splashRadius: 20,
              onPressed: () => _showMenu(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
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
            if (!playlist.isServer) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: LibreBeatsTheme.textSecondary, size: 20),
                title: const Text('Edit', style: TextStyle(color: LibreBeatsTheme.textPrimary)),
                onTap: () { Navigator.pop(context); onEdit(); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); onDelete(); },
              ),
            ],
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _SortChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? LibreBeatsTheme.textPrimary : LibreBeatsTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? LibreBeatsTheme.background : LibreBeatsTheme.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}