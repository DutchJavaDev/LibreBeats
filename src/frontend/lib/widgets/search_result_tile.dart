import 'package:flutter/material.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/providers/background_audio_provider.dart';
import 'package:liberated_beats/theme/lb_tokens.dart';
import 'package:liberated_beats/widgets/lb_brand.dart';
import 'package:liberated_beats/widgets/widget_builder.dart';
import 'package:provider/provider.dart';

/// The first case-insensitive occurrence of [query] tinted with [highlight],
/// so a result shows why it matched.
List<TextSpan> matchSpans(String text, String query, {Color? highlight}) {
  final q = query.trim();
  if (q.isEmpty) return [TextSpan(text: text)];
  final index = text.toLowerCase().indexOf(q.toLowerCase());
  if (index < 0) return [TextSpan(text: text)];
  return [
    if (index > 0) TextSpan(text: text.substring(0, index)),
    TextSpan(
        text: text.substring(index, index + q.length),
        // tests call this without a theme, the dark token covers that
        style: TextStyle(color: highlight ?? LbTokens.dark.nowPlaying)),
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
    return const Center(child: Text('No results found'));
  }

  Widget _beatRow(BuildContext context, Beat beat,
      BackgroundAudioProvider backgroundPlayer) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    final isActive = backgroundPlayer.currentBeat?.key == beat.key;

    // provenance beats the subtitle line; the model already blanks lines
    // that would only repeat the title
    String? subtitle;
    if (search.inMix != null) {
      final extra = search.inMixCount > 1 ? ' +${search.inMixCount - 1}' : '';
      subtitle = 'in ${search.inMix!.title}$extra';
    } else if (beat.subtitle.isNotEmpty) {
      subtitle = beat.subtitle;
    }
    if (hostLabel != null) {
      subtitle = subtitle == null ? hostLabel : '$subtitle · $hostLabel';
    }

    return ListTile(
      onTap: () async {
        // a song from a cached playlist plays inside it, skip walks the list
        if (search.inMix != null) {
          final played =
              await backgroundPlayer.playBeatMix(search.inMix!, beat);
          if (!played && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${beat.title} is unavailable'),
            ));
          }
          return;
        }
        final played = await backgroundPlayer.playBeat(beat);
        if (!played && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${beat.title} is unavailable'),
          ));
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(LbRadius.art),
        child: SizedBox(
          width: 48,
          height: 48,
          child: ColoredBox(
            color: tokens.artworkPlaceholder,
            child: createCachedNetworkImage(
              imageUrl: beat.localArtPath ?? beat.thumbnailUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              memCacheWidth: 48,
            ),
          ),
        ),
      ),
      title: Text.rich(
        TextSpan(
            children:
                matchSpans(beat.title, query, highlight: tokens.nowPlaying)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isActive
            ? theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700)
            : theme.textTheme.titleSmall,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            PlayingBarsIndicator(playing: backgroundPlayer.isPlaying),
            const SizedBox(width: 10),
          ],
          if (liked) ...[
            Icon(Icons.favorite, size: 14, color: tokens.nowPlaying),
            const SizedBox(width: 6),
          ],
          if (downloaded) ...[
            Icon(Icons.download_done,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            _format(beat.duration),
            // same role as BeatTile's duration so row types match
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _mixRow(BuildContext context, BeatMix beatMix) {
    final theme = Theme.of(context);
    final tokens = theme.extension<LbTokens>()!;
    return ListTile(
      onTap: () => showBeatMixDialog(context, beatMix),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(LbRadius.art),
        child: SizedBox(
          width: 48,
          height: 48,
          child: ColoredBox(
            color: tokens.artworkPlaceholder,
            child: createCachedNetworkImage(
              imageUrl: beatMix.thumbnailUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              memCacheWidth: 48,
            ),
          ),
        ),
      ),
      title: Text.rich(
        TextSpan(
            children:
                matchSpans(beatMix.title, query, highlight: tokens.nowPlaying)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        '${beatMix.trackCount} songs',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Icon(Icons.chevron_right,
          size: 18, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
