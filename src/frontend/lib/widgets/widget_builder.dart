import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/widgets/beatmix_view.dart';

Widget createCachedNetworkImage({
  required String imageUrl,
  BoxFit? fit,
  double? width,
  double? height,
}) {
  // downloaded thumbnails are plain file paths, not urls
  if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
    final file = File(imageUrl);
    if (file.existsSync()) {
      return Image.file(file, fit: fit, width: width, height: height);
    }
  }

  // sample data has album titles in here instead of urls, dont try to load those
  final uri = Uri.tryParse(imageUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const SizedBox.shrink();
  }

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
  showDialog(
    context: context,
    // own messenger + scaffold, snackbars from the row hearts would end up
    // behind a fullscreen dialog otherwise
    builder: (context) => Dialog.fullscreen(
      backgroundColor: const Color(0xFF121212),
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: BeatMixView(beatMix: beatMix),
        ),
      ),
    ),
  );
}

/// "1h 48m" under an hour just "48m", used by the mix view and liked screen.
String formatTotalDuration(Duration d) => d.inHours > 0
    ? '${d.inHours}h ${d.inMinutes.remainder(60)}m'
    : '${d.inMinutes}m';

/// Row heart handler: liking is silent (the heart fills), un-liking offers
/// an undo which re-likes and re-downloads.
void toggleBeatLike(
    BuildContext context, LikedProvider likedProvider, Beat beat) {
  final wasLiked = likedProvider.isLiked(beat.key);
  unawaited(likedProvider.toggleLike(beat));
  if (!wasLiked) return;

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: const Color(0xFF282828),
    content: Text('${beat.title} removed from Liked Songs',
        style: const TextStyle(color: Colors.white)),
    action: SnackBarAction(
      label: 'Undo',
      textColor: const Color(0xFF1ED760),
      onPressed: () => likedProvider.toggleLike(beat),
    ),
  ));
}
