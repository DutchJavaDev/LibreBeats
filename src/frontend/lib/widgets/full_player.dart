import 'package:flutter/material.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';


/// Full-screen "now playing" sheet, opened from the [MiniPlayer]. Drag down to
/// dismiss. The like state is local to the sheet and resets on reopen.
class FullPlayer extends StatefulWidget {
  const FullPlayer({super.key});

  @override
  State<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<FullPlayer> {
  bool _liked = false;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final track = backgroundPlayer.currentBeat;

    if (track == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
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
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header row.
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.more_horiz,
                                color: Colors.white),
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
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 32,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: createCachedNetworkImage(
                            imageUrl: track.thumbnailUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
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
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white),
                                ),
                                Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14, color: Color(0xFFA7A7A7)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _liked ? Icons.favorite : Icons.favorite_border,
                              color: _liked
                                  ? const Color(0xFF1ED760)
                                  : const Color(0xFFA7A7A7),
                            ),
                            onPressed: () => setState(() => _liked = !_liked),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress slider.
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.2),
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 14),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: backgroundPlayer.progress,
                          // seek applies on release, not while dragging
                          onChanged: (_) {},
                          onChangeEnd: (double position) async {
                            await backgroundPlayer.setSeek(position);
                          },
                          min: 0.0,
                          max: 1.0,
                        ),
                      ),
                      // Time row.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_format(backgroundPlayer.elapsed),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFA7A7A7))),
                          Text(_format(track.duration),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFA7A7A7))),
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
                                    ? const Color(0xFF1ED760)
                                    : Colors.white),
                            onPressed: backgroundPlayer.toggleShuffle,
                          ),
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.skip_previous,
                                color: Colors.white),
                            onPressed: backgroundPlayer.skipToPrevious,
                          ),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: IconButton(
                              icon: Icon(
                                  backgroundPlayer.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.black,
                                  size: 34),
                              onPressed: backgroundPlayer.togglePlay,
                            ),
                          ),
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.skip_next,
                                color: Colors.white),
                            onPressed: backgroundPlayer.skipToNext,
                          ),
                          IconButton(
                            icon: Icon(
                              backgroundPlayer.repeatMode == LoopMode.one
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                              color:
                                  backgroundPlayer.repeatMode != LoopMode.off
                                      ? const Color(0xFF1ED760)
                                      : Colors.white,
                            ),
                            onPressed: backgroundPlayer.cycleRepeat,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Volume row.
                      Row(
                        children: [
                          const Icon(Icons.volume_down,
                              color: Color(0xFFA7A7A7)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.white,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.2),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5),
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: backgroundPlayer.volume,
                                onChanged: backgroundPlayer.setVolume,
                              ),
                            ),
                          ),
                          const Icon(Icons.volume_up, color: Color(0xFFA7A7A7)),
                        ],
                      ),
                      // Bottom row.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.share_outlined,
                                color: Color(0xFFA7A7A7)),
                            label: const Text('Share',
                                style: TextStyle(color: Color(0xFFA7A7A7))),
                          ),
                          TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.queue_music_outlined,
                                color: Color(0xFFA7A7A7)),
                            label: const Text('Queue',
                                style: TextStyle(color: Color(0xFFA7A7A7))),
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
