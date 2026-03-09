// TODO Implement this library.import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:librebeats/data/models.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

// ── Mini Player ────────────────────────────────────────────────────────────
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        if (!player.miniPlayerVisible || player.currentSong == null) {
          return const SizedBox.shrink();
        }
        final song = player.currentSong!;
        return GestureDetector(
          onTap: player.showFullPlayer,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            decoration: BoxDecoration(
              color: LibreBeatsTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: LibreBeatsTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar at top
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: LinearProgressIndicator(
                    value: player.progress,
                    backgroundColor: LibreBeatsTheme.border,
                    valueColor: const AlwaysStoppedAnimation(LibreBeatsTheme.accent),
                    minHeight: 2,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      AlbumArt(size: 40, radius: 8),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title,
                                style: const TextStyle(
                                    color: LibreBeatsTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(song.artist,
                                style: const TextStyle(
                                    color: LibreBeatsTheme.textSecondary,
                                    fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      _MiniBtn(
                        icon: Icons.skip_previous_rounded,
                        onTap: player.skipPrev,
                      ),
                      _MiniBtn(
                        icon: player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 32,
                        onTap: player.togglePlayPause,
                        color: LibreBeatsTheme.textPrimary,
                      ),
                      _MiniBtn(
                        icon: Icons.skip_next_rounded,
                        onTap: player.skipNext,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;

  const _MiniBtn({
    required this.icon,
    this.onTap,
    this.size = 22,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size, color: color ?? LibreBeatsTheme.textSecondary),
      onPressed: onTap,
      splashRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(),
    );
  }
}

// ── Full Player Screen ─────────────────────────────────────────────────────
class FullPlayerSheet extends StatefulWidget {
  const FullPlayerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FullPlayerSheet(),
    );
  }

  @override
  State<FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends State<FullPlayerSheet> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final song = player.currentSong;
        if (song == null) return const SizedBox.shrink();

        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: LibreBeatsTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                      color: LibreBeatsTheme.textSecondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            player.currentPlaylist?.name ?? 'Now Playing',
                            style: const TextStyle(
                                color: LibreBeatsTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 22),
                      color: LibreBeatsTheme.textSecondary,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // Album Art (large)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A1A1A), Color(0xFF0D0808)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: LibreBeatsTheme.accent.withOpacity(0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🎵', style: TextStyle(fontSize: 80)),
                      ),
                    ),
                  ),
                ),
              ),

              // Song info + like
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title,
                              style: const TextStyle(
                                  color: LibreBeatsTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 4),
                          Text(song.artist,
                              style: const TextStyle(
                                  color: LibreBeatsTheme.textSecondary,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _liked = !_liked),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(_liked),
                          color: _liked
                              ? LibreBeatsTheme.accent
                              : LibreBeatsTheme.textSecondary,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: LibreBeatsTheme.accent,
                        inactiveTrackColor: LibreBeatsTheme.border,
                        thumbColor: Colors.white,
                        overlayColor: LibreBeatsTheme.accentDim,
                      ),
                      child: Slider(
                        value: player.progress.clamp(0.0, 1.0),
                        onChanged: player.seek,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(player.position),
                            style: const TextStyle(
                                color: LibreBeatsTheme.textSecondary, fontSize: 12)),
                        Text(_formatDuration(player.duration),
                            style: const TextStyle(
                                color: LibreBeatsTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: player.shuffle == ShuffleMode.on
                            ? LibreBeatsTheme.accent
                            : LibreBeatsTheme.textSecondary,
                      ),
                      onPressed: player.toggleShuffle,
                    ),
                    // Prev
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded,
                          size: 36, color: LibreBeatsTheme.textPrimary),
                      onPressed: player.skipPrev,
                    ),
                    // Play/Pause
                    GestureDetector(
                      onTap: player.togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: LibreBeatsTheme.textPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: LibreBeatsTheme.background,
                          size: 32,
                        ),
                      ),
                    ),
                    // Next
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded,
                          size: 36, color: LibreBeatsTheme.textPrimary),
                      onPressed: player.skipNext,
                    ),
                    // Repeat
                    IconButton(
                      icon: Icon(
                        player.repeat == RepeatMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: player.repeat != RepeatMode.none
                            ? LibreBeatsTheme.accent
                            : LibreBeatsTheme.textSecondary,
                      ),
                      onPressed: player.toggleRepeat,
                    ),
                  ],
                ),
              ),

              // Volume
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    const Icon(Icons.volume_mute_rounded,
                        color: LibreBeatsTheme.textSecondary, size: 18),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: LibreBeatsTheme.textSecondary,
                          inactiveTrackColor: LibreBeatsTheme.border,
                          thumbColor: LibreBeatsTheme.textSecondary,
                          overlayColor: LibreBeatsTheme.accentDim,
                        ),
                        child: Slider(
                          value: player.volume,
                          onChanged: player.setVolume,
                        ),
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded,
                        color: LibreBeatsTheme.textSecondary, size: 18),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}