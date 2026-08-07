import 'package:flutter/material.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {

  const HomeScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final topInset = MediaQuery.of(context).padding.top;
    final tracks = backgroundPlayer.recentBeats;

    return CustomScrollView(
      slivers: [
        // 1. Header with greeting. The quick-picks grid that used to live
        // here duplicated the history carousel below.
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A3A2A), Color(0xFF121212)],
              ),
            ),
            child: Text(
              _greeting,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
        ),
        // 2. History: the last 10 played beats as a horizontal carousel,
        // newest first (a replay moves back to the front).
        if (tracks.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('History',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 164,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  final isActive = backgroundPlayer.currentBeat?.key == t.key;
                  return _HistoryCard(
                    beat: t,
                    isActive: isActive,
                    onTap: () => backgroundPlayer.playBeat(t),
                  );
                },
              ),
            ),
          ),
        ],
        // 3. Trailing spacer.
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

/// One entry in the horizontal history carousel: square artwork (gradient
/// fallback) with title + artist below, highlighted while playing.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.beat,
    required this.isActive,
    required this.onTap,
  });

  final Beat beat;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 108,
              height: 108,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: beat.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: createCachedNetworkImage(
                  imageUrl: beat.thumbnailUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              beat.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF1ED760) : Colors.white),
            ),
            Text(
              beat.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFFA7A7A7)),
            ),
          ],
        ),
      ),
    );
  }
}
