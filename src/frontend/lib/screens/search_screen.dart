import 'dart:async';
import 'package:flutter/material.dart';
import 'package:librebeats/data/models.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/shared_widgets.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;
  Timer? _debounce;
  String _lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() { _results = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final library = context.read<LibraryProvider>();
      final res = await library.search(q);
      if (mounted) setState(() { _results = res; _loading = false; _lastQuery = q; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: true,
          backgroundColor: LibreBeatsTheme.background,
          title: const Text('Search'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                autofocus: false,
                style: const TextStyle(color: LibreBeatsTheme.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Songs, artists, albums...',
                  prefixIcon: const Icon(Icons.search, color: LibreBeatsTheme.textSecondary, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18, color: LibreBeatsTheme.textSecondary),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),

        if (_controller.text.isEmpty)
          const SliverToBoxAdapter(child: _BrowseCategories()),

        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: LibreBeatsTheme.accent, strokeWidth: 2)),
            ),
          ),

        if (!_loading && _controller.text.isNotEmpty && _results.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.search_off, color: LibreBeatsTheme.textDim, size: 48),
                  const SizedBox(height: 12),
                  Text('No results for "$_lastQuery"',
                      style: const TextStyle(color: LibreBeatsTheme.textSecondary, fontSize: 15)),
                ],
              ),
            ),
          ),

        if (!_loading && _results.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('${_results.length} results for "$_lastQuery"',
                  style: const TextStyle(color: LibreBeatsTheme.textSecondary, fontSize: 13)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ResultTile(result: _results[i]),
              childCount: _results.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SearchResult result;
  const _ResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final icon = result.type == SearchResultType.song
        ? Icons.music_note_rounded
        : result.type == SearchResultType.playlist
            ? Icons.queue_music_rounded
            : result.type == SearchResultType.artist
                ? Icons.person_rounded
                : Icons.album_rounded;

    return InkWell(
      onTap: () {
        if (result.type == SearchResultType.song && result.data is Song) {
          player.playSong(result.data as Song);
        }
        // TODO: navigate to playlist/album/artist
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: LibreBeatsTheme.surface,
                borderRadius: BorderRadius.circular(
                    result.type == SearchResultType.artist ? 24 : 8),
              ),
              child: Icon(icon, color: LibreBeatsTheme.textSecondary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.title,
                      style: const TextStyle(
                          color: LibreBeatsTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      ChipTag(
                        label: result.type.name.toUpperCase(),
                        color: result.type == SearchResultType.song
                            ? LibreBeatsTheme.accent
                            : result.type == SearchResultType.playlist
                                ? const Color(0xFF1DB954)
                                : LibreBeatsTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(result.subtitle,
                            style: const TextStyle(
                                color: LibreBeatsTheme.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (result.type == SearchResultType.song)
              IconButton(
                icon: const Icon(Icons.more_vert, size: 18),
                color: LibreBeatsTheme.textSecondary,
                onPressed: () {},
                splashRadius: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _BrowseCategories extends StatelessWidget {
  const _BrowseCategories();

  static const _cats = [
    ('Trending', '🔥', Color(0xFF8B1A1A)),
    ('Electronic', '⚡', Color(0xFF1A3A5A)),
    ('Indie', '🎸', Color(0xFF3A2A1A)),
    ('Focus', '🎯', Color(0xFF1A3A2A)),
    ('Hip-Hop', '🎤', Color(0xFF2A1A3A)),
    ('Ambient', '🌊', Color(0xFF1A2A3A)),
    ('Rock', '🤘', Color(0xFF3A1A1A)),
    ('Jazz', '🎷', Color(0xFF2A3A1A)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Browse by genre'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.0,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: _cats.length,
            itemBuilder: (_, i) {
              final (name, emoji, color) = _cats[i];
              return GestureDetector(
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}