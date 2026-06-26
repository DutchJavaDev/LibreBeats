import 'package:flutter/material.dart';

import '../models/track.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    const filters = ['Playlists', 'Albums', 'Artists', 'Downloaded'];

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
                  color: Colors.white.withOpacity(0.1),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
        // Filter chips.
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final f in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        f,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      selected: false,
                      onSelected: (_) {},
                      backgroundColor: const Color(0xFF282828),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide.none,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Liked Songs entry.
        SliverToBoxAdapter(
          child: ListTile(
            onTap: () {},
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
            subtitle: const Text(
              'Playlist · 847 songs',
              style: TextStyle(color: Color(0xFFA7A7A7), fontSize: 12),
            ),
          ),
        ),
        // Playlist list.
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final pl = samplePlaylists[i];
              return ListTile(
                leading: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF282828),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.queue_music, color: Color(0xFFA7A7A7), size: 24),
                ),
                title: Text(
                  pl.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Playlist · ${pl.trackCount} songs',
                  style: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 12),
                ),
              );
            },
            childCount: samplePlaylists.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
