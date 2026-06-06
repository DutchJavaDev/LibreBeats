import 'package:flutter/material.dart';
import 'package:librebeats/data/models.dart';
import '../theme/app_theme.dart';

// ── Album Art Placeholder ──────────────────────────────────────────────────
class AlbumArt extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final String? fallbackEmoji;

  const AlbumArt({
    super.key,
    this.url,
    this.size = 52,
    this.radius = 8,
    this.fallbackEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: LibreBeatsTheme.surface,
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          fallbackEmoji ?? '🎵',
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );
  }
}

// ── Song Tile ──────────────────────────────────────────────────────────────
class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool showDuration;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onMore,
    this.showDuration = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            AlbumArt(size: 48, fallbackEmoji: '🎵'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title,
                      style: const TextStyle(
                          color: LibreBeatsTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${song.artist} • ${song.album}',
                      style: const TextStyle(
                          color: LibreBeatsTheme.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (showDuration)
              Text(song.durationString,
                  style: const TextStyle(
                      color: LibreBeatsTheme.textDim, fontSize: 12)),
            const SizedBox(width: 4),
            if (onMore != null)
              IconButton(
                icon: const Icon(Icons.more_vert, size: 18),
                color: LibreBeatsTheme.textSecondary,
                onPressed: onMore,
                splashRadius: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Playlist Card (vertical) ───────────────────────────────────────────────
class PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback? onTap;
  final double width;

  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onTap,
    this.width = 140,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: width,
                  height: width,
                  decoration: BoxDecoration(
                    color: LibreBeatsTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: playlist.isServer
                          ? [const Color(0xFF1A2A3A), const Color(0xFF0D1520)]
                          : [const Color(0xFF2A1A1A), const Color(0xFF150D0D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: playlist.isServer ? Text('📡' ,
                      style: const TextStyle(fontSize: 20)) : Image.network(playlist.coverArtUrl ?? ""),
                    // child: Text(
                    //   playlist.isServer ? '📡' : '🎵',
                    //   style: TextStyle(fontSize: width * 0.35),
                    // ),
                  ),
                ),
                if (playlist.isServer)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB95422),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1DB954), width: 1),
                      ),
                      child: const Text('SERVER',
                          style: TextStyle(
                              color: Color(0xFF1DB954),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(playlist.name,
                style: const TextStyle(
                    color: LibreBeatsTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('${playlist.songCount} songs',
                style: const TextStyle(
                    color: LibreBeatsTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: LibreBeatsTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      color: LibreBeatsTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ── Accent Button ──────────────────────────────────────────────────────────
class AccentButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool outlined;

  const AccentButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : LibreBeatsTheme.accent,
          borderRadius: BorderRadius.circular(24),
          border: outlined
              ? Border.all(color: LibreBeatsTheme.accent, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  color: outlined ? LibreBeatsTheme.accent : Colors.white,
                  size: 16),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(
                    color: outlined ? LibreBeatsTheme.accent : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Chip Tag ───────────────────────────────────────────────────────────────
class ChipTag extends StatelessWidget {
  final String label;
  final Color? color;

  const ChipTag({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? LibreBeatsTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.5), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: c, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );
  }
}

// ── Shimmer Loader ─────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
              LibreBeatsTheme.surface, LibreBeatsTheme.surfaceVariant, _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}