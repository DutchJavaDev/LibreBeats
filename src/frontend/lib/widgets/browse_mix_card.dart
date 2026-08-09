import 'package:flutter/material.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';

/// One playlist in the browse grid: the cover sharp and unobstructed,
/// title and count below it, a heart badge when the mix is in the library.
class BrowseMixCard extends StatelessWidget {
  final BeatMix mix;
  final bool liked;
  final VoidCallback onTap;

  /// Set when another playlist shares this title, names the server.
  final String? hostLabel;

  const BrowseMixCard({
    super.key,
    required this.mix,
    required this.onTap,
    this.liked = false,
    this.hostLabel,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = hostLabel == null
        ? '${mix.trackCount} songs'
        : '${mix.trackCount} songs · $hostLabel';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(
                    color: const Color(0xFF282828),
                    child: createCachedNetworkImage(
                      imageUrl: mix.thumbnailUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (liked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite,
                        size: 12, color: Color(0xFF1ED760)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mix.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFFA7A7A7)),
          ),
        ],
      ),
    );
  }
}
