import 'package:flutter/material.dart';
import 'package:liberated_beats/main.dart';
import 'package:liberated_beats/providers/catalog_provider.dart';
import 'package:liberated_beats/widgets/search_result_tile.dart';
import 'package:provider/provider.dart';

import '../models/beat_models.dart';
import '../providers/player_provider.dart';
import '../widgets/track_tile.dart';

/// Browse categories shown when the query is empty. Each entry is a
/// (label, color) record.
const List<(String, Color)> _categories = [
  ('Podcasts', Color(0xFF1DB954)),
  ('Live Events', Color(0xFFE91429)),
  ('Made For You', Color(0xFF509BF5)),
  ('New Releases', Color(0xFFFF6437)),
  ('Hip-Hop', Color(0xFFAF2896)),
  ('Electronic', Color(0xFFE8C32E)),
  ('Indie', Color(0xFF148A08)),
  ('Rock', Color(0xFFBC5900)),
  ('Pop', Color(0xFF1DB954)),
  ('Jazz', Color(0xFFE91429)),
  ('Classical', Color(0xFF509BF5)),
  ('R&B', Color(0xFFFF6437)),
];

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

  @override
  Widget build(BuildContext context) {
    //final player = context.watch<PlayerProvider>();
    final catalog = context.watch<CatalogProvider>();
    final topInset = MediaQuery.of(context).padding.top;

    return CustomScrollView(
      slivers: [
        // Header + search field.
        SliverToBoxAdapter(
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
                      color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  onChanged: (v) =>
                      v.isEmpty ? setState(() => _query = v) : null,
                  onEditingComplete: () =>
                      setState(() => _query = _controller.text),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Artists, songs, or podcasts',
                    hintStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Results / categories.
        // if (_query.isNotEmpty && filtered.isEmpty)
        //   SliverToBoxAdapter(
        //     child: Padding(
        //       padding: const EdgeInsets.all(32),
        //       child: Center(
        //         child: Text(
        //           'No results for "$_query"',
        //           style: const TextStyle(color: Color(0xFFA7A7A7)),
        //         ),
        //       ),
        //     ),
        //   )
        // else
         if (_query.isNotEmpty)
          SliverToBoxAdapter(
            child: StreamBuilder<List<SearchResult>>(
              stream: catalog.findAllByTitle(_query),
              builder: (context, snapshot) {

                if(snapshot.hasError){
                  PrintLog("StreamError: ${snapshot.error.toString()}");
                }

                if (snapshot.connectionState == ConnectionState.done) {

                  if (snapshot.hasData) {
                    final searchResults = snapshot.data!;

                    if(searchResults.isEmpty){
                      return const Center(child: Text("No results found", style: TextStyle(color: Colors.white),));
                    }

                    return Column(
                      children: searchResults.map((search) => SearchTile(search: search, onTap: () {}, isActive: false, isPlaying: false)).toList(),
                    );
                  } else {
                    return const Center(child: Text("No results found", style: TextStyle(color: Colors.white),));
                  }
                }
                return const  Center(child: CircularProgressIndicator());
              })
          )
        else ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Browse categories',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.0,
              children: [
                for (final c in _categories)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Material(
                      color: c.$2,
                      child: InkWell(
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              c.$1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
