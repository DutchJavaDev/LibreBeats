import 'package:flutter/material.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/sample/home_sample_data.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/browse_mix_card.dart';
import 'package:liberated_beats/widgets/home_beat_card.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday', //
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  String get _dateLine {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final tracks = backgroundPlayer.recentBeats;

    return CustomScrollView(
      slivers: [
        // 1. Flat greeting header with the brand rule, no gradient wash.
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                const BrandRule(),
                const SizedBox(height: 6),
                Text(_dateLine, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        // 2. History: the last 10 played beats as a horizontal carousel,
        // newest first (a replay moves back to the front). The only real
        // data on this screen besides the greeting.
        if (tracks.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader('History')),
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
                  return HomeBeatCard(
                    beat: t,
                    isActive: isActive,
                    isPlaying: isActive && backgroundPlayer.isPlaying,
                    onTap: () async {
                      // a dead entry (un-liked download, gone server) says so
                      // and disappears from the row
                      final played = await backgroundPlayer.playBeat(t);
                      if (!played && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${t.title} is unavailable'),
                        ));
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
        // 3. Most listened songs — mocked sample data (Preview), ranked rows.
        const SliverToBoxAdapter(
          child: SectionHeader('On repeat', trailing: PreviewChip()),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              for (var i = 0; i < sampleMostListened.length; i++)
                _RankedBeatRow(rank: i + 1, entry: sampleMostListened[i]),
            ],
          ),
        ),
        // 4. Most listened playlists — mocked sample data (Preview).
        const SliverToBoxAdapter(
          child: SectionHeader('Heavy rotation', trailing: PreviewChip()),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sampleTopMixes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final entry = sampleTopMixes[i];
                return SizedBox(
                  width: 140,
                  child: BrowseMixCard(
                    mix: entry.mix,
                    fallbackArt: sampleMixArt[entry.mix.id],
                    subtitleOverride:
                        '${entry.plays} plays · ${entry.mix.trackCount} songs',
                    onTap: () {}, // sample data, nothing to open
                  ),
                );
              },
            ),
          ),
        ),
        // 5. Server updates — mocked sample data (Preview).
        const SliverToBoxAdapter(
          child: SectionHeader('From your servers', trailing: PreviewChip()),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              for (final update in sampleServerUpdates)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _ServerUpdateCard(update: update),
                ),
            ],
          ),
        ),
        // 6. Trailing spacer.
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

/// One mocked most-listened row: rank, artwork, title/playlist, play count.
class _RankedBeatRow extends StatelessWidget {
  const _RankedBeatRow({required this.rank, required this.entry});

  final int rank;
  final SampleRankedBeat entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final beat = entry.beat;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$rank',
              style: theme.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: rank == 1
                    ? tokens.nowPlaying
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: beat.color,
              borderRadius: BorderRadius.circular(LbRadius.art),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall!.copyWith(fontSize: 13),
                ),
                Text(
                  beat.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text('${entry.plays} plays', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// One mocked server update: new playlists or the health digest.
class _ServerUpdateCard extends StatelessWidget {
  const _ServerUpdateCard({required this.update});

  final SampleServerUpdate update;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final healthy = update.kind == SampleUpdateKind.healthDigest;
    final tint = healthy ? tokens.success : theme.colorScheme.primary;

    return Card(
      child: ListTile(
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(healthy ? Icons.dns_outlined : Icons.playlist_add,
              size: 17, color: tint),
        ),
        title: Text(update.message),
        subtitle: Text(update.host.isEmpty
            ? update.timeAgo
            : '${update.host} · ${update.timeAgo}'),
      ),
    );
  }
}
