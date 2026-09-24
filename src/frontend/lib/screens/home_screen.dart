import 'package:flutter/material.dart';
import 'package:liberated_beats/data/play_stats_store.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/providers/catalog_provider.dart';
import 'package:liberated_beats/providers/play_stats_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/browse_mix_card.dart';
import 'package:liberated_beats/widgets/home_beat_card.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

/// '31 plays', '1 play', '2 songs'
String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday', //
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  String get _dateLine {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';
  }

  // History rows and On repeat rows play the same way: a dead entry (un-liked
  // download, gone server) says so in a snackbar instead of failing silently.
  Future<void> _playBeat(BuildContext context, Beat beat) async {
    final played = await context.read<BackgroundAudioProvider>().playBeat(beat);
    if (!played && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${beat.title} is unavailable'),
      ));
    }
  }

  // Play stats only keep a snapshot of the mix, the tappable thing is the
  // live catalog entry. Not being there is normal (catalog not fetched yet,
  // server removed), so degrade to a snackbar.
  void _openMix(BuildContext context, MixPlayStat stat) {
    final mixes = context.read<LibreProvider>().beatMixes;
    for (final mix in mixes) {
      if (mix.key == stat.key) {
        showBeatMixDialog(context, mix);
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${stat.title} is not in your catalog right now'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    final stats = context.watch<PlayStatsProvider>();
    final registry = context.watch<ServerRegistry>();
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final tracks = backgroundPlayer.recentBeats;

    // pull to refresh re-probes the fleet, force skips the once-a-minute
    // throttle so the gesture always does something
    return RefreshIndicator(
      onRefresh: () => context.read<ServerRegistry>().checkHealth(force: true),
      child: CustomScrollView(
        // short pages must still pull
        physics: const AlwaysScrollableScrollPhysics(),
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
          // newest first (a replay moves back to the front).
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
                      onTap: () => _playBeat(context, t),
                    );
                  },
                ),
              ),
            ),
          ],
          // 3. On repeat: the most played songs, counted on device (a play is
          // 30s or half the track). Empty shows an invitation, not a gap.
          const SliverToBoxAdapter(child: SectionHeader('On repeat')),
          if (stats.topBeats.isEmpty)
            const SliverToBoxAdapter(
              child: _EmptySectionHint('Listen to songs to see this update'),
            )
          else
            SliverToBoxAdapter(
              child: Column(
                children: [
                  for (var i = 0; i < stats.topBeats.length; i++)
                    _RankedBeatRow(
                      rank: i + 1,
                      beat: stats.topBeats[i].beat,
                      plays: stats.topBeats[i].plays,
                      isActive: backgroundPlayer.currentBeat?.key ==
                          stats.topBeats[i].beat.key,
                      onTap: () => _playBeat(context, stats.topBeats[i].beat),
                    ),
                ],
              ),
            ),
          // 4. Heavy rotation: the most played mixes, with how many of their
          // songs actually got played. Empty shows an invitation, not a gap.
          const SliverToBoxAdapter(child: SectionHeader('Heavy rotation')),
          if (stats.topMixes.isEmpty)
            const SliverToBoxAdapter(
              child:
                  _EmptySectionHint('Listen to playlists to see this update'),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: stats.topMixes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final stat = stats.topMixes[i];
                    return SizedBox(
                      width: 140,
                      child: BrowseMixCard(
                        mix: stat.toBeatMix(),
                        subtitleOverride:
                            '${_count(stat.plays, 'play')} · ${_count(stat.distinctSongs, 'song')}',
                        onTap: () => _openMix(context, stat),
                      ),
                    );
                  },
                ),
              ),
            ),
          // 5. From your servers: the real health digest, refreshed on
          // visiting the tab (and by pulling down).
          const SliverToBoxAdapter(
            child: SectionHeader('From your servers'),
          ),
          if (registry.servers.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _ServerHealthCard(registry: registry),
              ),
            ),
          // 6. Trailing spacer.
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

/// What an empty play-stats section says instead of disappearing: the
/// section stays visible and invites listening.
class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        message,
        style: theme.textTheme.bodySmall!
            .copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// One most-played row: rank, artwork, title/playlist, play count. Tapping
/// plays the beat, the active one gets the now-playing tint.
class _RankedBeatRow extends StatelessWidget {
  const _RankedBeatRow({
    required this.rank,
    required this.beat,
    required this.plays,
    required this.isActive,
    required this.onTap,
  });

  final int rank;
  final Beat beat;
  final int plays;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;

    return InkWell(
      onTap: onTap,
      child: Padding(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(LbRadius.art),
                child: createCachedNetworkImage(
                  imageUrl: beat.localArtPath ?? beat.thumbnailUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: 40,
                ),
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
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontSize: 13,
                      color: isActive ? tokens.nowPlaying : null,
                    ),
                  ),
                  if (beat.subtitle.isNotEmpty)
                    Text(
                      beat.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Text(_count(plays, 'play'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The fleet health digest, straight from the server registry: problems
/// first ("1 of 3 servers unreachable"), all-clear otherwise, with when the
/// last check ran. The check itself fires on visiting the home tab.
class _ServerHealthCard extends StatelessWidget {
  const _ServerHealthCard({required this.registry});

  final ServerRegistry registry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;

    final servers = registry.servers;
    final total = servers.length;
    final failed = servers.where((s) => s.status == ServerStatus.failed).length;
    final connecting =
        servers.where((s) => s.status == ServerStatus.connecting).length;

    final String message;
    final Color tint;
    if (failed > 0) {
      message = '$failed of ${_count(total, 'server')} unreachable';
      tint = theme.colorScheme.error;
    } else if (connecting > 0) {
      message = '$connecting of ${_count(total, 'server')} connecting';
      tint = tokens.warning;
    } else {
      message =
          total == 1 ? 'Your server is healthy' : 'All $total servers healthy';
      tint = tokens.success;
    }

    final checked = registry.lastCheckedAt;

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
          child: Icon(Icons.dns_outlined, size: 17, color: tint),
        ),
        title: Text(message),
        subtitle: Text(
            checked == null ? 'Checking…' : 'Last checked ${_ago(checked)}'),
      ),
    );
  }
}
