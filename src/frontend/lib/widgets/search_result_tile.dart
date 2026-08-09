import 'package:flutter/material.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

/// The first case-insensitive occurrence of [query] tinted green, so a
/// result shows why it matched.
List<TextSpan> matchSpans(String text, String query) {
  final q = query.trim();
  if (q.isEmpty) return [TextSpan(text: text)];
  final index = text.toLowerCase().indexOf(q.toLowerCase());
  if (index < 0) return [TextSpan(text: text)];
  return [
    if (index > 0) TextSpan(text: text.substring(0, index)),
    TextSpan(
        text: text.substring(index, index + q.length),
        style: const TextStyle(color: Color(0xFF1ED760))),
    if (index + q.length < text.length)
      TextSpan(text: text.substring(index + q.length)),
  ];
}

/// A search result, one row grammar for songs and playlists.
class SearchTile extends StatelessWidget {
  final SearchResult search;
  final String query;
  final bool liked;
  final bool downloaded;

  /// Set when another result shares this title, names the server.
  final String? hostLabel;

  const SearchTile({
    super.key,
    required this.search,
    this.query = '',
    this.liked = false,
    this.downloaded = false,
    this.hostLabel,
  });

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundPlayer = context.watch<BackgroundAudioProvider>();
    if (search.beatMix != null) {
      return _mixRow(context, search.beatMix!);
    } else if (search.beat != null) {
      return _beatRow(context, search.beat!, backgroundPlayer);
    }
    return const Center(
        child: Text('No results found', style: TextStyle(color: Colors.white)));
  }

  Widget _beatRow(BuildContext context, Beat beat,
      BackgroundAudioProvider backgroundPlayer) {
    final isActive = backgroundPlayer.currentBeat?.key == beat.key;

    // provenance beats the artist line, the artist line only shows when it
    // actually says something new (ingest stores the title there too)
    String? subtitle;
    if (search.inMix != null) {
      final extra = search.inMixCount > 1 ? ' +${search.inMixCount - 1}' : '';
      subtitle = 'in ${search.inMix!.title}$extra';
    } else if (beat.artist.isNotEmpty && beat.artist != beat.title) {
      subtitle = beat.artist;
    }
    if (hostLabel != null) {
      subtitle = subtitle == null ? hostLabel : '$subtitle · $hostLabel';
    }

    return ListTile(
      onTap: () async {
        // a song from a cached playlist plays inside it, skip walks the list
        if (search.inMix != null) {
          await backgroundPlayer.playBeatMix(search.inMix!, beat);
          return;
        }
        final played = await backgroundPlayer.playBeat(beat);
        if (!played && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFF282828),
            content: Text('${beat.title} is unavailable',
                style: const TextStyle(color: Colors.white)),
          ));
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 48,
          height: 48,
          child: ColoredBox(
            color: const Color(0xFF282828),
            child: createCachedNetworkImage(
              imageUrl: beat.localArtPath ?? beat.thumbnailUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      title: Text.rich(
        TextSpan(children: matchSpans(beat.title, query)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF1ED760) : Colors.white,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (liked) ...[
            const Icon(Icons.favorite, size: 14, color: Color(0xFF1ED760)),
            const SizedBox(width: 6),
          ],
          if (downloaded) ...[
            const Icon(Icons.download_done, size: 14, color: Color(0xFFA7A7A7)),
            const SizedBox(width: 6),
          ],
          Text(
            _format(beat.duration),
            style: const TextStyle(fontSize: 13, color: Color(0xFFA7A7A7)),
          ),
        ],
      ),
    );
  }

  Widget _mixRow(BuildContext context, BeatMix beatMix) {
    return ListTile(
      onTap: () => showBeatMixDialog(context, beatMix),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: ColoredBox(
            color: const Color(0xFF282828),
            child: createCachedNetworkImage(
              imageUrl: beatMix.thumbnailUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      title: Text.rich(
        TextSpan(children: matchSpans(beatMix.title, query)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      subtitle: Text(
        '${beatMix.trackCount} songs',
        style: const TextStyle(fontSize: 12, color: Color(0xFFA7A7A7)),
      ),
      trailing:
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFFA7A7A7)),
    );
  }

}
