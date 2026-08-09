import 'package:flutter/material.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.onOpenLiked});

  /// Set by the scaffold, switches to the liked tab.
  final VoidCallback? onOpenLiked;

  Future<void> _confirmRemoveMix(
      BuildContext context, LikedProvider likedProvider, LikedMix mix) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove ${mix.title}?',
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
            'Its downloads get deleted from this device. Songs you also '
            'liked individually stay.',
            style: TextStyle(color: Color(0xFFA7A7A7), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFE8453C))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // toggling a liked key is the unlike path
      await likedProvider.toggleLikeMix(likedProvider.mixFor(mix));
    }
  }

  @override
  Widget build(BuildContext context) {
    final likedProvider = context.watch<LikedProvider>();
    final topInset = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        // Header.
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Library',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                Material(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: const CircleBorder(),
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        // Filter chips.
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: SizedBox.shrink(),
          ),
        ),
        // Liked Songs entry.
        SliverToBoxAdapter(
          child: ListTile(
            onTap: () => onOpenLiked?.call(),
            leading: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF450AF5), Color(0xFFC4EFD9)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 24),
            ),
            title: const Text(
              'Liked Songs',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Playlist · ${likedProvider.count} songs',
              style: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 12),
            ),
          ),
        ),
        // Liked beatmixes, tap plays, long press removes.
        if (likedProvider.likedMixes.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 35),
              child: Center(
                child: Text(
                    'No liked playlists yet, tap the heart on a playlist in search',
                    style: TextStyle(color: Color(0xFFA7A7A7))),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final mix = likedProvider.likedMixes[i];
                final localArt = likedProvider.mixArtFor(mix);
                return ListTile(
                  onTap: () =>
                      showBeatMixDialog(context, likedProvider.mixFor(mix)),
                  onLongPress: () =>
                      _confirmRemoveMix(context, likedProvider, mix),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: ColoredBox(
                        color: const Color(0xFF282828),
                        child: createCachedNetworkImage(
                          imageUrl: localArt ?? mix.thumbnailUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    mix.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: mix.complete
                      ? Text(
                          'Playlist · ${mix.beats.length} songs',
                          style: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 12),
                        )
                      : Text(
                          'Playlist · ${mix.downloadedCount} of ${mix.beats.length} downloaded',
                          style: const TextStyle(color: Color(0xFFE8C32E), fontSize: 12),
                        ),
                );
              },
              childCount: likedProvider.likedMixes.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
