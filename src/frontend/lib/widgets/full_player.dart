import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/sleep_timer_sheet.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

/// Full-screen "now playing" sheet, opened from the [MiniPlayer]. Drag down
/// to dismiss. The heart likes the current beat, which also downloads it
/// for offline playback. The moon arms the sleep timer.
class FullPlayer extends StatefulWidget {
  const FullPlayer({super.key});

  @override
  State<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<FullPlayer> {
  String _format(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final likedProvider = context.watch<LikedProvider>();
    final track = backgroundPlayer.currentBeat;

    if (track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<LbTokens>()!;
    final liked = likedProvider.isLiked(track.key);
    final dimmed = scheme.onSurfaceVariant.withValues(alpha: 0.5);

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(LbRadius.hero)),
          ),
          child: Stack(
            children: [
              // Tinted backdrop derived from the track's gradient.
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: track.color,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(LbRadius.hero)),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Grabber handle.
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header row.
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          // no menu behind it yet, dimmed until there is
                          IconButton(
                            icon: Icon(Icons.more_horiz, color: dimmed),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Artwork — subtly shrinks when paused.
                      AnimatedScale(
                        scale: backgroundPlayer.isPlaying ? 1.0 : 0.92,
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: double.infinity,
                          height: 280,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: track.color,
                            borderRadius:
                                BorderRadius.circular(LbRadius.hero),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 32,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(LbRadius.hero),
                            child: createCachedNetworkImage(
                              imageUrl:
                                  track.localArtPath ?? track.thumbnailUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Title + like.
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge,
                                ),
                                // the owning playlist when known, artist
                                // otherwise, hidden when it would just
                                // repeat the title
                                if (track.subtitle.isNotEmpty)
                                  Text(
                                    track.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              liked ? Icons.favorite : Icons.favorite_border,
                              color: liked
                                  ? tokens.nowPlaying
                                  : scheme.onSurfaceVariant,
                            ),
                            onPressed: () => likedProvider.toggleLike(track),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress slider, styled by the app-wide sliderTheme.
                      Slider(
                        value: backgroundPlayer.progress,
                        // seek applies on release, not while dragging
                        onChanged: (_) {},
                        onChangeEnd: (double position) async {
                          await backgroundPlayer.setSeek(position);
                        },
                        min: 0.0,
                        max: 1.0,
                      ),
                      // Time row.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_format(backgroundPlayer.elapsed),
                              style: theme.textTheme.bodySmall),
                          Text(_format(track.duration),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Transport controls.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.shuffle,
                                color: backgroundPlayer.shuffle
                                    ? tokens.nowPlaying
                                    : scheme.onSurface),
                            onPressed: backgroundPlayer.toggleShuffle,
                          ),
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.skip_previous),
                            onPressed: backgroundPlayer.skipToPrevious,
                          ),
                          // the brand-gradient play circle
                          Material(
                            color: Colors.transparent,
                            child: Ink(
                              width: 64,
                              height: 64,
                              decoration: ShapeDecoration(
                                gradient: tokens.brandGradient,
                                shape: const CircleBorder(),
                              ),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: backgroundPlayer.togglePlay,
                                child: Icon(
                                    backgroundPlayer.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: scheme.onPrimary,
                                    size: 34),
                              ),
                            ),
                          ),
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.skip_next),
                            onPressed: backgroundPlayer.skipToNext,
                          ),
                          IconButton(
                            icon: Icon(
                              backgroundPlayer.repeatMode == LoopMode.one
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                              color:
                                  backgroundPlayer.repeatMode != LoopMode.off
                                      ? tokens.nowPlaying
                                      : scheme.onSurface,
                            ),
                            onPressed: backgroundPlayer.cycleRepeat,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Volume row, same app-wide slider styling.
                      Row(
                        children: [
                          Icon(Icons.volume_down,
                              color: scheme.onSurfaceVariant),
                          Expanded(
                            child: Slider(
                              value: backgroundPlayer.volume,
                              onChanged: backgroundPlayer.setVolume,
                            ),
                          ),
                          Icon(Icons.volume_up,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                      // Bottom row: sleep timer + queue.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SleepTimerButton(player: backgroundPlayer),
                          // queue view not built yet, dimmed until it is
                          TextButton.icon(
                            onPressed: () {},
                            icon: Icon(Icons.queue_music_outlined,
                                size: 20, color: dimmed),
                            label: Text('Queue',
                                style: TextStyle(color: dimmed)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The sleep control's label: a live countdown ("Sleep · 14:32", hours as
/// "1:00:00") while a duration timer runs, the end-of-track wording, or
/// plain "Sleep" when nothing is armed.
String sleepCountdownLabel({Duration? remaining, required bool endOfTrack}) {
  if (endOfTrack) return 'Sleep · end of track';
  if (remaining == null) return 'Sleep';
  final h = remaining.inHours;
  final m = remaining.inMinutes.remainder(60);
  final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return 'Sleep · $h:${m.toString().padLeft(2, '0')}:$s';
  return 'Sleep · $m:$s';
}

/// Sleep timer control with its own one-second ticker, so the countdown
/// keeps moving even while playback is paused. The ticker only runs while
/// this sheet is open and a duration timer is armed, and only this button
/// rebuilds on a tick.
class _SleepTimerButton extends StatefulWidget {
  const _SleepTimerButton({required this.player});

  final BackgroundAudioProvider player;

  @override
  State<_SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends State<_SleepTimerButton> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(_SleepTimerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // the parent rebuilds on every arm/disarm/expiry notification
    _syncTicker();
  }

  void _syncTicker() {
    final counting = widget.player.sleepRemaining != null;
    if (counting && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!counting && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = widget.player;
    final color = player.sleepArmed
        ? theme.extension<LbTokens>()!.nowPlaying
        : theme.colorScheme.onSurfaceVariant;

    return TextButton.icon(
      onPressed: () => showSleepTimerSheet(context, player),
      icon: Icon(Icons.bedtime_outlined, size: 20, color: color),
      label: Text(
        sleepCountdownLabel(
          remaining: player.sleepRemaining,
          endOfTrack: player.sleepEndOfTrack,
        ),
        style: TextStyle(color: color),
      ),
    );
  }
}
