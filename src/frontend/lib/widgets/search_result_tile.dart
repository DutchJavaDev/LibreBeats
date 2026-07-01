import 'package:flutter/material.dart';
import 'package:liberated_beats/models/beat_models.dart';

class SearchTile extends StatelessWidget {
  final SearchResult search;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onTap;

  const SearchTile(
      {super.key,
      required this.onTap,
      required this.search,
      required this.isActive,
      required this.isPlaying});

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {

    if(search.beatMix != null){
      final beatMix = search.beatMix!;
      return ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Image.network(
          beatMix.thumbnailUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
        ),
        title: Text(
          beatMix.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF1ED760) : Colors.white,
          ),
        ),
        subtitle: Text(
          '${beatMix.trackCount} tracks',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
        ),
        trailing: const Icon(Icons.more_vert, color: Color(0xFFA7A7A7), size: 18),
      );
    }
    else if (search.beat != null) {
      final beat = search.beat!;
      return ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Image.network(
          beat.album,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
        ),
        title: Text(
          beat.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF1ED760) : Colors.white,
          ),
        ),
        subtitle: Text(
          beat.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _format(beat.duration),
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFFA7A7A7)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.more_vert, color: Color(0xFFA7A7A7), size: 18),
          ],
        ),
      );
    }
    else
    {
      return Center(child: Text("No results found", style: TextStyle(color: Colors.white),));
    }


    // return ListTile(
    //   onTap: onTap,
    //   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    //   leading: Stack(
    //     children: [
    //       Container(
    //         width: 48,
    //         height: 48,
    //         alignment: Alignment.center,
    //         decoration: BoxDecoration(
    //           gradient: beat.color,
    //           borderRadius: BorderRadius.circular(8),
    //         ),
    //         child: Text(
    //           beat.title.isNotEmpty ? beat.title[0] : '?',
    //           style: const TextStyle(
    //               fontWeight: FontWeight.bold, color: Colors.white),
    //         ),
    //       ),
    //       if (isActive && !isBeatMix)
    //         Positioned.fill(
    //           child: Container(
    //             alignment: Alignment.center,
    //             decoration: BoxDecoration(
    //               color: Colors.black.withValues(alpha: 0.45),
    //               borderRadius: BorderRadius.circular(8),
    //             ),
    //             child: Icon(
    //               isPlaying ? Icons.pause : Icons.play_arrow,
    //               color: Colors.white,
    //               size: 22,
    //             ),
    //           ),
    //         ),
    //     ],
    //   ),
    //   title: Text(
    //     beat.title,
    //     maxLines: 1,
    //     overflow: TextOverflow.ellipsis,
    //     style: TextStyle(
    //       fontSize: 14,
    //       fontWeight: FontWeight.w600,
    //       color: isActive ? const Color(0xFF1ED760) : Colors.white,
    //     ),
    //   ),
    //   subtitle: Text(
    //     beat.artist,
    //     maxLines: 1,
    //     overflow: TextOverflow.ellipsis,
    //     style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
    //   ),
    //   trailing: Row(
    //     mainAxisSize: MainAxisSize.min,
    //     children: [
    //       Text(
    //         _format(beat.duration),
    //         style: const TextStyle(fontSize: 13, color: Color(0xFFA7A7A7)),
    //       ),
    //       const SizedBox(width: 4),
    //       const Icon(Icons.more_vert, color: Color(0xFFA7A7A7), size: 18),
    //     ],
    //   ),
    // );
  }
}
