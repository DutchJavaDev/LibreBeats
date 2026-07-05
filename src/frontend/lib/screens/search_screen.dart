import 'package:flutter/material.dart';
import 'package:liberated_beats/main.dart';
import 'package:liberated_beats/providers/catalog_provider.dart';
import 'package:liberated_beats/widgets/search_result_tile.dart';
import 'package:provider/provider.dart';
import '../models/beat_models.dart';

// (categories list remains unchanged)
final List<(String, Color)> _categories = [
  ('Hip Hop', const Color(0xFF1ED760)),
  ('Pop', const Color(0xFFE91E63)),
  ('Rock', const Color(0xFF2196F3)),
  ('Jazz', const Color(0xFFFFC107)),
  ('Classical', const Color(0xFF9C27B0)),
  ('Electronic', const Color(0xFF00BCD4)),
  ('R&B', const Color(0xFFFF5722)),
  ('Country', const Color(0xFF4CAF50)),
];

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

  Stream<List<BeatMix>> _buildBeatMixGrid(CatalogProvider catalog) async* {
    final beatMixes = await catalog.getAllBeatMixes();
    yield beatMixes;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogProvider>();
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
                    const Text(
                      'Search',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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
        // Results or categories (unchanged)
        if (_query.isNotEmpty)
          SliverToBoxAdapter(
            child: StreamBuilder<List<SearchResult>>(
              stream: catalog.findAllByTitle(_query),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  PrintLog("StreamError: ${snapshot.error.toString()}");
                }
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData) {
                    final searchResults = snapshot.data!;
                    if (searchResults.isEmpty) {
                      return const Center(
                        child: Text("No results found",
                            style: TextStyle(color: Colors.white)),
                      );
                    }
                    return Column(
                      children: searchResults
                          .map((search) => SearchTile(
                                search: search,
                              ))
                          .toList(),
                    );
                  } else {
                    return const Center(
                      child: Text("No results found",
                          style: TextStyle(color: Colors.white)),
                    );
                  }
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          )
        else ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Browse Playlists',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<List<BeatMix>>(
                stream: _buildBeatMixGrid(catalog),
                builder: (context, snapshot) {

                  if (snapshot.hasError) {
                    PrintLog("StreamError: ${snapshot.error.toString()}");
                  }

                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasData) {
                      final beatMixes = snapshot.data!;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.0,
                        ),
                        itemCount: beatMixes.length,
                        itemBuilder: (context, index) {
                          final beatMix = beatMixes[index];
                          return SearchTile(
                              search: SearchResult(beatMix: beatMix));
                        },
                      );
                    }

                    return const Center(
                        child: Text("No results found",
                            style: TextStyle(color: Colors.white)));
                  }

                  return const Center(child: CircularProgressIndicator());
                }),
          )
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
