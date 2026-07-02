import 'package:flutter/foundation.dart';
import 'package:liberated_beats/data/beat_repository.dart';

import '../data/beatmix_repository.dart';
import '../models/beat_models.dart';

/// Loads the catalog from [BeatMixRepository] (fake data for now) and exposes it
/// to the UI together with simple loading/error state. Fetches once on creation.
class CatalogProvider extends ChangeNotifier {
  
  CatalogProvider(this._beatMixRepository, this._beatRepository);

  final BeatMixRepository _beatMixRepository;
  final BeatRepository _beatRepository;

  bool _isLoading = false;
  String? _error;
  List<Beat> _tracks = const [];
  List<Album> _albums = const [];
  List<BeatMix> _playlists = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Beat> get tracks => _tracks;
  List<Album> get albums => _albums;
  List<BeatMix> get playlists => _playlists;

  /// Whether the underlying repository has a live Supabase connection (false
  /// while running on placeholder config / fake data).
  bool get isConnected => _beatMixRepository.isConnected;

  /// Searches for beatmixes and beats whose title matches the given [query].
  /// Returns a stream of search results, which will emit a new list every time
  Stream<List<SearchResult>> findAllByTitle(String query) async* {
    var beatmixes = await _beatMixRepository.findByTitle(query);
    var beats = await _beatRepository.findByTitle(query);

    var results = <SearchResult>[];

    for(var beatmix in beatmixes){
      results.add(SearchResult(beatMix: beatmix));
    }
    for(var beat in beats){
      results.add(SearchResult(beat: beat));
    }
    yield results;
  }
}
