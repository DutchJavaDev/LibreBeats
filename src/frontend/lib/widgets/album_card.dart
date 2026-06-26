import 'package:flutter/material.dart';

import '../models/track.dart';

/// Album tile with a gradient cover, the title's first letter, and a green
/// play button anchored bottom-right.
class AlbumCard extends StatefulWidget {
  final Album album;
  final VoidCallback onPlay;

  const AlbumCard({super.key, required this.album, required this.onPlay});

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  // Intended for desktop/web hover affordance — declared but never read.
  // ignore: unused_field
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final album = widget.album;
    return GestureDetector(
      onTap: widget.onPlay,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: album.color,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      album.title.isNotEmpty ? album.title[0] : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Material(
                    color: const Color(0xFF1ED760),
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onPlay,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Icon(Icons.play_arrow, color: Colors.black, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              '${album.year} · ${album.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFFA7A7A7)),
            ),
          ],
        ),
      ),
    );
  }
}
