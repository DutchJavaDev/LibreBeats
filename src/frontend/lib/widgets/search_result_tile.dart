import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

class SearchTile extends StatelessWidget {
  final SearchResult search;

  const SearchTile({super.key, required this.search});

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final isActive = backgroundPlayer.currentBeat?.id == search.beat?.id;
    if (search.beatMix != null) {
      final beatMix = search.beatMix!;
      return Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                    sigmaX: 2.5, // Adjust horizontal blur strength
                    sigmaY: 2.5, // Adjust vertical blur strength
                    tileMode: TileMode.clamp),
                child: createCachedNetworkImage(
                  imageUrl: beatMix.thumbnailUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),

          // 3. Your original ListTile (transparent by default)
          ListTile(
            onTap: () => showBeatMixDialog(context, beatMix, backgroundPlayer),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              beatMix.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? const Color(0xFF1ED760)
                    : Colors
                        .white, // TODO need to check if the beat is part of the beatmix instead
              ),
            ),
            subtitle: Text(
              '${beatMix.trackCount} songs',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  color: ui.Color.fromARGB(255, 255, 255, 255),
                  fontWeight: FontWeight.bold),
            ),
            // trailing: IconButton(onPressed: (){
            //       // TODO Play 
            //     }, icon: const Icon(Icons.play_arrow, color: ui.Color.fromARGB(255, 29, 185, 84), size: 32)),
          ),
        ],
      );
    } else if (search.beat != null) {
      final beat = search.beat!;
      return ListTile(
        onTap: () {
          backgroundPlayer.playBeat(beat);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: createCachedNetworkImage(
          imageUrl: beat.album,
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
              style: const TextStyle(fontSize: 13, color: Color(0xFFA7A7A7)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.more_vert, color: Color(0xFFA7A7A7), size: 18),
          ],
        ),
      );
    } else {
      return const Center(
          child: Text(
        "No results found",
        style: TextStyle(color: Colors.white),
      ));
    }
  }
}
