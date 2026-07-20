import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liberated_beats/data/beat_repository.dart';

import '../data/beatmix_repository.dart';
import '../models/beat_models.dart';

/// Loads the catalog from [BeatMixRepository] (fake data for now) and exposes it
/// to the UI together with simple loading/error state. Fetches once on creation.
class LibreProvider extends ChangeNotifier {
  LibreProvider(this._beatMixRepository, this._beatRepository);

  final BeatMixRepository _beatMixRepository;
  final BeatRepository _beatRepository;

  bool _isLoading = false;
  String? _error;
  List<Beat> _beats = const [];
  List<Album> _albums = const [];
  List<BeatMix> _beatMixes = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Beat> get beat => _beats;
  List<Album> get albums => _albums;
  List<BeatMix> get beatMixes => _beatMixes;

  /// Whether the underlying repository has a live Supabase connection (false
  /// while running on placeholder config / fake data).
  bool get isConnected => _beatMixRepository.isConnected;

  /// Searches for beatmixes and beats whose title matches the given [query].
  /// Returns a stream of search results, which will emit a new list every time
  Stream<List<SearchResult>> findAllByTitle(final String query) async* {

    _beats = await _beatRepository.findByTitle(query);
    
    _beatMixes = await _beatMixRepository.findByTitle(query);
    
    var results = <SearchResult>[];

    for (var beat in _beats) {
      results.add(SearchResult(beat: beat));
    }

    for (var beatmix in _beatMixes) {
      results.add(SearchResult(beatMix: beatmix));
    }

    yield results;
  }

  // ---------------------------------------------------------------------------

  Future<List<BeatMix>> getAllBeatMixes() async {
    _beatMixes = await _beatMixRepository.getAll();
    return _beatMixes;
  }
}
