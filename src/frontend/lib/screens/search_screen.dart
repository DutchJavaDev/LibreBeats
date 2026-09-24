import 'package:flutter/material.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/providers/catalog_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/widgets/browse_mix_card.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/search_result_tile.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';
import '../models/beat_models.dart';

// Custom delegate for the sticky header
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _SearchHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _ago(DateTime? t) {
    if (t == null) return 'just now';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  Widget _countTrailing(int count) =>
      Text('$count', style: Theme.of(context).textTheme.bodySmall);

  Widget _browseGrid(LibreProvider catalog, LikedProvider liked) {
    // playlists sharing a title get a server label to tell them apart
    final titleCounts = <String, int>{};
    for (final m in catalog.beatMixes) {
      final t = m.title.toLowerCase();
      titleCounts[t] = (titleCounts[t] ?? 0) + 1;
    }
    String? hostFor(BeatMix mix) {
      if ((titleCounts[mix.title.toLowerCase()] ?? 0) < 2) return null;
      final host = Uri.tryParse(mix.sourceId)?.host;
      return (host == null || host.isEmpty) ? mix.sourceId : host;
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: catalog.beatMixes.length,
      itemBuilder: (context, index) {
        final beatMix = catalog.beatMixes[index];
        return BrowseMixCard(
          mix: beatMix,
          liked: liked.isMixLiked(beatMix.key),
          hostLabel: hostFor(beatMix),
          onTap: () => showBeatMixDialog(context, beatMix),
        );
      },
    );
  }

  Widget _results(SearchOutcome outcome, LikedProvider liked) {
    final songs = [
      for (final r in outcome.results)
        if (r.beat != null) r
    ];
    final mixes = [
      for (final r in outcome.results)
        if (r.beatMix != null) r
    ];

    // duplicate titles get a server label so they can be told apart
    final titleCounts = <String, int>{};
    for (final r in songs) {
      final t = r.beat!.title.toLowerCase();
      titleCounts[t] = (titleCounts[t] ?? 0) + 1;
    }
    String? hostFor(Beat beat) {
      if ((titleCounts[beat.title.toLowerCase()] ?? 0) < 2) return null;
      final host = Uri.tryParse(beat.sourceId)?.host;
      return (host == null || host.isEmpty) ? beat.sourceId : host;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (songs.isNotEmpty) ...[
          SectionHeader('Songs',
              trailing: _countTrailing(songs.length),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0)),
          for (final r in songs)
            SearchTile(
              search: r,
              query: _query,
              liked: liked.isLiked(r.beat!.key),
              downloaded: liked.isDownloaded(r.beat!.key),
              hostLabel: hostFor(r.beat!),
            ),
        ],
        if (mixes.isNotEmpty) ...[
          SectionHeader('Playlists',
              trailing: _countTrailing(mixes.length),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0)),
          for (final r in mixes) SearchTile(search: r, query: _query),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Center(
            child: Text(
              outcome.live
                  ? 'Nothing cached matched · live from your servers'
                  : 'From your catalog · updated ${_ago(outcome.cachedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<LibreProvider>();
    final theme = Theme.of(context);
    final topInset = MediaQuery.of(context).padding.top;

    // Fixed height for the sticky header:
    // topInset + top padding (20) + title row (48, the cache toggle's tap
    // target sets it now) + gap (12) + text field height (50) + bottom
    // padding (16) + slack (10)
    final headerHeight = topInset + 20 + 48 + 12 + 50 + 16 + 10;

    return RefreshIndicator(
      // keep the spinner clear of the pinned opaque header
      edgeOffset: headerHeight,
      onRefresh: () => catalog.ensureCatalog(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Sticky header
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchHeaderDelegate(
              height: headerHeight,
              child: Container(
                // solid background to cover scrolled content
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, topInset + 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Search',
                                  style: theme.textTheme.headlineMedium),
                              const SizedBox(height: 6),
                              const BrandRule(),
                            ],
                          ),
                          // switch between disk and in-memory server results
                          SizedBox(
                            height: 48,
                            child: TextButton.icon(
                              onPressed: () => catalog
                                  .setPersistentCache(!catalog.persistentCache),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    theme.colorScheme.onSurfaceVariant,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: Icon(
                                catalog.persistentCache
                                    ? Icons.save_outlined
                                    : Icons.memory,
                                size: 16,
                              ),
                              label: Text(
                                catalog.persistentCache
                                    ? 'Cache: disk'
                                    : 'Cache: memory',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 50, // fixed height for the text field
                        child: TextField(
                          controller: _controller,
                          onChanged: (v) =>
                              v.isEmpty ? setState(() => _query = v) : null,
                          onEditingComplete: () =>
                              setState(() => _query = _controller.text),
                          style: theme.textTheme.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Artists, songs, or beatmixes',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // banner after an automatic refresh happened while on this page
          if (catalog.updateNotice)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.autorenew,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Playlists were updated',
                        style: theme.textTheme.bodySmall!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: catalog.clearUpdateNotice,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: Icon(Icons.close,
                          size: 16, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          // Results, sectioned into songs and playlists with a freshness line
          if (_query.isNotEmpty)
            SliverToBoxAdapter(
              child: StreamBuilder<SearchOutcome>(
                stream: catalog.findAllByTitle(_query),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    PrintLog("StreamError: ${snapshot.error.toString()}");
                  }
                  final outcome = snapshot.data;
                  if (outcome == null || outcome.searching) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Center(child: CircularProgressIndicator()),
                          if (outcome?.searching ?? false) ...[
                            const SizedBox(height: 12),
                            Text('Searching your servers…',
                                style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    );
                  }
                  if (outcome.results.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                            "Nothing matched '$_query', checked your servers too",
                            style: theme.textTheme.bodyMedium),
                      ),
                    );
                  }
                  return _results(outcome, context.watch<LikedProvider>());
                },
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                'Browse playlists',
                trailing: catalog.beatMixes.isEmpty
                    ? null
                    : _countTrailing(catalog.beatMixes.length),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              ),
            ),
            SliverToBoxAdapter(
              child: catalog.beatMixes.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: catalog.isFetching
                            ? const CircularProgressIndicator()
                            : Text(
                                'No playlists yet — check your servers in Settings',
                                style: theme.textTheme.bodyMedium),
                      ),
                    )
                  : _browseGrid(catalog, context.watch<LikedProvider>()),
            )
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}
