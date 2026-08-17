import 'package:flutter/material.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/widgets/beat_tile.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

/// Absolute player indices in the order playback walks them, the shuffled
/// walk while shuffle is on. Indices that do not fit the queue fall back
/// to the plain order, a wrong order beats a crash.
List<int> playbackOrder(
    int length, List<int> shuffleIndices, bool shuffleEnabled) {
  final identity = List.generate(length, (i) => i);
  if (!shuffleEnabled) return identity;
  if (shuffleIndices.length != length) return identity;
  for (final i in shuffleIndices) {
    if (i < 0 || i >= length) return identity;
  }
  return List.of(shuffleIndices);
}

/// Tall bottom sheet with the queue in playback order. Tapping a row
/// jumps there without touching the queue itself, the current row toggles
/// play/pause. Opened from the full player.
void showQueueSheet(BuildContext context, BackgroundAudioProvider player) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: player,
      child: const _QueueSheet(),
    ),
  );
}

class _QueueSheet extends StatefulWidget {
  const _QueueSheet();

  @override
  State<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends State<_QueueSheet> {
  // itemExtent pins every row to the m3 two-line tile height BeatTile
  // renders at, so the auto-scroll target is plain row arithmetic
  static const _rowExtent = 72.0;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // scrolling needs a laid-out viewport, so after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Lands the current song two rows from the top, clamped to the edges.
  void _jumpToCurrent() {
    if (!mounted || !_scroll.hasClients) return;
    final player = context.read<BackgroundAudioProvider>();
    final beats = player.queueBeats;
    final order = playbackOrder(
        beats.length, player.shuffleIndices, player.shuffleEnabled);
    final key = player.currentBeat?.key;
    final row = order.indexWhere((i) => beats[i].key == key);
    if (row < 0) return;
    final target = ((row - 2) * _rowExtent)
        .clamp(0.0, _scroll.position.maxScrollExtent)
        .toDouble();
    _scroll.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<BackgroundAudioProvider>();
    final likedProvider = context.watch<LikedProvider>();

    final beats = player.queueBeats;
    // recomputed each build so a shuffle toggle re-sorts the open sheet
    final order = playbackOrder(
        beats.length, player.shuffleIndices, player.shuffleEnabled);
    final currentKey = player.currentBeat?.key;

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.queue_music_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Queue', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text('${beats.length} songs',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: beats.isEmpty
                  ? Center(
                      child: Text('Nothing queued',
                          style: theme.textTheme.bodyMedium))
                  : ListView.builder(
                      controller: _scroll,
                      itemExtent: _rowExtent,
                      itemCount: order.length,
                      addAutomaticKeepAlives: false,
                      itemBuilder: (context, i) {
                        final abs = order[i];
                        final beat = beats[abs];
                        final isActive = beat.key == currentKey;
                        return BeatTile(
                          beat: beat,
                          isActive: isActive,
                          isPlaying: isActive && player.isPlaying,
                          liked: likedProvider.isLiked(beat.key),
                          onLike: () => toggleBeatLike(context, likedProvider, beat),
                          onTap: () async {
                            if (isActive) {
                              await player.togglePlay();
                              return;
                            }
                            await player.skipToQueueItem(abs);
                            // audible when the player sat paused
                            if (!player.isPlaying) await player.togglePlay();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
