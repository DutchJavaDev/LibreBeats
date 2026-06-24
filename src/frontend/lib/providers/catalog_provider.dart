import 'package:flutter/foundation.dart';

import '../data/music_repository.dart';
import '../models/track.dart';

/// Loads the catalog from [MusicRepository] (fake data for now) and exposes it
/// to the UI together with simple loading/error state. Fetches once on creation.
class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._repository) {
    load();
  }

  final MusicRepository _repository;

  bool _isLoading = false;
  String? _error;
  List<Track> _tracks = const [];
  List<Album> _albums = const [];
  List<Playlist> _playlists = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Track> get tracks => _tracks;
  List<Album> get albums => _albums;
  List<Playlist> get playlists => _playlists;

  /// Whether the underlying repository has a live Supabase connection (false
  /// while running on placeholder config / fake data).
  bool get isConnected => _repository.isConnected;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tracks = await _repository.fetchTracks();
      _albums = await _repository.fetchAlbums();
      _playlists = await _repository.fetchPlaylists();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
