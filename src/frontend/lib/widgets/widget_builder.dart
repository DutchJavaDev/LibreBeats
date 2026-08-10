import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/beatmix_view.dart';

/// Thumbnail loader. Placeholder is a flat surface (no spinner animating
/// inside every list tile); pass [showSpinner] for hero-sized slots where
/// a loading indicator earns its keep. [memCacheWidth] is the slot width
/// in logical pixels, scaled to device pixels to cap decode cost.
Widget createCachedNetworkImage({
  required String imageUrl,
  BoxFit? fit,
  double? width,
  double? height,
  bool showSpinner = false,
  int? memCacheWidth,
}) {
  // downloaded thumbnails are plain file paths, not urls
  if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
    final file = File(imageUrl);
    if (file.existsSync()) {
      return Image.file(file,
          fit: fit,
          width: width,
          height: height,
          // a file deleted between exists check and decode should show the
          // gradient fallback behind it, not crash the tile
          errorBuilder: (_, __, ___) => const SizedBox.shrink());
    }
  }

  // sample data has album titles in here instead of urls, dont try to load those
  final uri = Uri.tryParse(imageUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const SizedBox.shrink();
  }

  final pixelRatio = WidgetsBinding
          .instance.platformDispatcher.implicitView?.devicePixelRatio ??
      2.0;

  return CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit,
    width: width,
    height: height,
    memCacheWidth:
        memCacheWidth == null ? null : (memCacheWidth * pixelRatio).round(),
    placeholder: (context, url) {
      final placeholder =
          Theme.of(context).extension<LbTokens>()!.artworkPlaceholder;
      if (!showSpinner) return ColoredBox(color: placeholder);
      return ColoredBox(
        color: placeholder,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    },
    errorWidget: (context, error, stackTrace) => Icon(Icons.music_note,
        size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

void showBeatMixDialog(BuildContext context, BeatMix beatMix) {
  FocusScope.of(context).unfocus();
  SystemChannels.textInput.invokeMethod('TextInput.hide');
  final surface = Theme.of(context).colorScheme.surface;
  showDialog(
    context: context,
    // own messenger + scaffold, snackbars from the row hearts would end up
    // behind a fullscreen dialog otherwise
    builder: (context) => Dialog.fullscreen(
      backgroundColor: surface,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: surface,
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
    content: Text('${beat.title} removed from Liked Songs'),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () => likedProvider.toggleLike(beat),
    ),
  ));
}
