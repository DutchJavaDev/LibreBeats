import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/track.dart';

/// Single point of access to the music catalog.
///
/// For now every method returns **fake data** (the in-memory sample lists) after
/// a short simulated delay, so the UI has a realistic async "fetch" to render.
/// The real Supabase queries are sketched in comments — swap them in once the
/// backend tables (see `src/backend`: `Beat`, `BeatMix`) are reachable.
class MusicRepository {
  /// The Supabase client — available only after `Supabase.initialize` has run,
  /// i.e. when [SupabaseConfig.isConfigured] is true. The fake-data path below
  /// never touches it; it is used by the real queries (commented out).
  SupabaseClient? get _client =>
      SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Whether a live Supabase connection is available.
  bool get isConnected => _client != null;

  Future<List<Track>> fetchTracks() async {
    // Real implementation:
    //   final rows = await _client!.from('Beat').select();
    //   return rows.map(_trackFromRow).toList();
    await Future<void>.delayed(const Duration(milliseconds: 300)); // simulate network
    return sampleTracks;
  }

  Future<List<Album>> fetchAlbums() async {
    // Real implementation:
    //   final rows = await _client!.from('BeatMix').select().eq('type', 'album');
    //   return rows.map(_albumFromRow).toList();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return sampleAlbums;
  }

  Future<List<Playlist>> fetchPlaylists() async {
    // Real implementation:
    //   final rows = await _client!.from('BeatMix').select().eq('type', 'playlist');
    //   return rows.map(_playlistFromRow).toList();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return samplePlaylists;
  }

  // ---------------------------------------------------------------------------
  // Row → model mapping (for the real implementation).
  //
  // Supabase returns JSON maps. Gradients aren't stored in the catalog, so pick
  // one from the shared palette (e.g. by index) when mapping real rows.
  //
  // Track _trackFromRow(Map<String, dynamic> row) => Track(
  //       id: row['Id'] as String,
  //       title: row['Title'] as String,
  //       artist: row['Artist'] as String,
  //       album: row['Album'] as String? ?? '',
  //       duration: Duration(seconds: row['DurationSeconds'] as int? ?? 0),
  //       color: sampleTracks.first.color,
  //       audioUrl: row['StreamUrl'] as String?,
  //     );
  // ---------------------------------------------------------------------------
}
