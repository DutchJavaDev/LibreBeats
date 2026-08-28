import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liberated_beats/data/liked_store.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.onOpenLiked});

  /// Set by the scaffold, switches to the liked tab.
  final VoidCallback? onOpenLiked;

  Future<void> _confirmRemoveMix(
      BuildContext context, LikedProvider likedProvider, LikedMix mix) async {
    final error = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${mix.title}?'),
        content: const Text(
            'Its downloads get deleted from this device. Songs you also '
            'liked individually stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: error),
            child: const Text('Remove'),
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
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final topInset = MediaQuery.of(context).padding.top;

    // pull down re-checks the files and retries stuck downloads
    return RefreshIndicator(
      onRefresh: likedProvider.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Library', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  const BrandRule(),
                ],
              ),
            ),
          ),
          // Shuffle all, one queue over every downloaded mix track.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  GradientPillButton(
                    label: 'Shuffle all playlists',
                    icon: Icons.shuffle,
                    onPressed: !likedProvider.hasDownloadedMixBeats
                        ? null
                        : () async {
                            final player =
                                context.read<BackgroundAudioProvider>();
                            final mix = likedProvider.shuffleAllMix();
                            final beats = mix?.beats;
                            if (beats == null || beats.isEmpty) return;
                            if (!player.shuffle) player.toggleShuffle();
                            // starting on the playing beat would pause it
                            // instead, pick around it
                            final current = player.currentBeat?.key;
                            final pool =
                                beats.where((b) => b.key != current).toList();
                            final candidates = pool.isEmpty ? beats : pool;
                            final beat =
                                candidates[Random().nextInt(candidates.length)];
                            final played = await player.playBeatMix(mix!, beat);
                            if (!played && context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text('${beat.title} is unavailable'),
                              ));
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
          // Liked Songs entry.
          SliverToBoxAdapter(
            child: ListTile(
              onTap: () => onOpenLiked?.call(),
              leading: const LbEmblem(size: 52, showHeart: true),
              title: const Text('Liked Songs'),
              subtitle: Text('Playlist · ${likedProvider.count} songs'),
            ),
          ),
          // Liked beatmixes, tap plays, long press removes.
          if (likedProvider.likedMixes.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 35),
                child: Center(
                  child: Text(
                      'No liked playlists yet, tap the heart on a playlist in search',
                      style: theme.textTheme.bodyMedium),
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
                      borderRadius: BorderRadius.circular(LbRadius.art),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: ColoredBox(
                          color: tokens.artworkPlaceholder,
                          child: createCachedNetworkImage(
                            imageUrl: localArt ?? mix.thumbnailUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            memCacheWidth: 52,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      mix.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: mix.complete
                        ? Text('Playlist · ${mix.beats.length} songs')
                        : Text(
                            'Playlist · ${mix.downloadedCount} of ${mix.beats.length} downloaded',
                            style: theme.textTheme.bodySmall!
                                .copyWith(color: tokens.warning),
                          ),
                  );
                },
                childCount: likedProvider.likedMixes.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
