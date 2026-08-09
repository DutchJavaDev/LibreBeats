import 'package:flutter/material.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/providers/catalog_provider.dart';
import 'package:liberated_beats/providers/liked_provider.dart';
import 'package:liberated_beats/widgets/browse_mix_card.dart';
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

  Widget _resultHeader(String title, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          '${title.toUpperCase()} · $count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFF1ED760),
          ),
        ),
      );

  String _ago(DateTime? t) {
    if (t == null) return 'just now';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

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
          _resultHeader('Songs', songs.length),
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
          _resultHeader('Playlists', mixes.length),
          for (final r in mixes) SearchTile(search: r, query: _query),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Center(
            child: Text(
              outcome.live
                  ? 'Nothing cached matched · live from your servers'
                  : 'From your catalog · updated ${_ago(outcome.cachedAt)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF777777)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<LibreProvider>();
    final topInset = MediaQuery.of(context).padding.top;

    // Fixed height for the sticky header:
    // topInset + top padding (16) + "Search" text height (~30) + gap (16) + text field height (50) + bottom padding (16)
    // Increase the height by 10 pixels to avoid bottom overflow
    final headerHeight = topInset + 16 + 30 + 16 + 50 + 16 + 10;

    return CustomScrollView(
      slivers: [
        // Sticky header
        SliverPersistentHeader(
          pinned: true,
          delegate: _SearchHeaderDelegate(
            height: headerHeight,
            child: Container(
              color: const Color(
                  0xFF121212), // Solid background to cover scrolled content
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        // switch between disk and in-memory server results
                        SizedBox(
                          height: 30,
                          child: TextButton.icon(
                            onPressed: () => catalog
                                .setPersistentCache(!catalog.persistentCache),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              catalog.persistentCache
                                  ? Icons.save_outlined
                                  : Icons.memory,
                              size: 16,
                              color: const Color(0xFFA7A7A7),
                            ),
                            label: Text(
                              catalog.persistentCache
                                  ? 'Cache: disk'
                                  : 'Cache: memory',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFA7A7A7)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 50, // Fixed height for the text field
                      child: TextField(
                        controller: _controller,
                        onChanged: (v) =>
                            v.isEmpty ? setState(() => _query = v) : null,
                        onEditingComplete: () =>
                            setState(() => _query = _controller.text),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Artists, songs, or podcasts',
                          hintStyle: const TextStyle(color: Colors.black54),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.black54),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1ED760).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x661ED760)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.autorenew,
                      size: 16, color: Color(0xFF1ED760)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Playlists were updated',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1ED760)),
                    ),
                  ),
                  InkWell(
                    onTap: catalog.clearUpdateNotice,
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFF1ED760)),
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
                          const Text('Searching your servers…',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFFA7A7A7))),
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
                          style:
                              const TextStyle(color: Color(0xFFA7A7A7))),
                    ),
                  );
                }
                return _results(outcome, context.watch<LikedProvider>());
              },
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                catalog.beatMixes.isEmpty
                    ? 'Browse playlists'
                    : 'Browse playlists · ${catalog.beatMixes.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: catalog.beatMixes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: catalog.isFetching
                          ? const CircularProgressIndicator(
                              color: Color(0xFF1ED760))
                          : const Text(
                              'No playlists yet — check your servers in Settings',
                              style: TextStyle(color: Color(0xFFA7A7A7))),
                    ),
                  )
                : _browseGrid(catalog, context.watch<LikedProvider>()),
          )
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
