import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/player_provider.dart';
import 'package:liberated_beats/widgets/track_tile.dart';
import 'package:provider/provider.dart';

CachedNetworkImage createCachedNetworkImage({
  required String imageUrl,
  BoxFit? fit,
  double? width,
  double? height,
}) {
  return CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit,
    width: width,
    height: height,
    placeholder: (context, url) =>
        const Center(child: CircularProgressIndicator()),
    errorWidget: (context, error, stackTrace) => const Icon(Icons.error),
  );
}

void showBeatMixDialog(BuildContext context, BeatMix beatMix) {
  FocusScope.of(context).unfocus();
  SystemChannels.textInput.invokeMethod('TextInput.hide');

  final player = context.read<PlayerProvider>();

  showDialog(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: RepaintBoundary(
        child: Column(
          children: [
            AppBar(
              title: Text(beatMix.title),
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: beatMix.beats?.length ?? 0,
                // Performance boost for the list inside the dialog
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemBuilder: (BuildContext context, int index) {
                  final beat = beatMix.beats![index];
                  return RepaintBoundary(
                    child: TrackTile(
                      beat: beat,
                      isActive: false, // Won't work since modal does not have a setState()
                      isPlaying: false,// Won't work since modal does not have a setState()
                      onTap: () {
                        player.playTrack(beat);
                      },
                    ),
                  );
                },
                separatorBuilder: (BuildContext context, int index) =>
                    const Divider(),
              ),
            ),
            SizedBox(
              height: 80, // adjust as needed
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    iconSize: 32,
                    color: const Color(0xFFA7A7A7),
                  ),
                  IconButton(
                    onPressed: () {
                      player.setBeats(beatMix.beats!);
                      player.playTrack(beatMix.beats![0]);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    iconSize: 48,
                    color: const Color(0xFFA7A7A7),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border),
                    iconSize: 32,
                    color: const Color(0xFFA7A7A7),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    ),
  );
}
