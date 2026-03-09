// TODO Implement this library.import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:librebeats/data/models.dart';
import 'package:uuid/uuid.dart';
const _uuid = Uuid();

class LibraryProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────
  List<Playlist> _playlists = [];
  List<MusicServer> _servers = [];
  Song? _lastPlayedSong;
  Playlist? _lastPlayedPlaylist;
  int _localStorageUsedMb = 0;

  bool _isLoading = false;
  String? _error;

  // Mock data on init
  LibraryProvider() {
    _loadMockData();
  }

  void _loadMockData() {
    final songs = [
      Song(id: 's1', title: 'Midnight Static', artist: 'Neon Void', album: 'Frequencies', duration: const Duration(minutes: 3, seconds: 42)),
      Song(id: 's2', title: 'Hollow Frequencies', artist: 'Circuit Breaker', album: 'Phase II', duration: const Duration(minutes: 4, seconds: 15)),
      Song(id: 's3', title: 'Solar Drift', artist: 'Pale Mirror', album: 'Dusk', duration: const Duration(minutes: 5, seconds: 1)),
      Song(id: 's4', title: 'Subterranean', artist: 'The Hollow', album: 'Depths', duration: const Duration(minutes: 3, seconds: 28)),
      Song(id: 's5', title: 'Glass Architecture', artist: 'Neon Void', album: 'Prism', duration: const Duration(minutes: 4, seconds: 55)),
      Song(id: 's6', title: 'Rewired', artist: 'Circuit Breaker', album: 'Phase II', duration: const Duration(minutes: 3, seconds: 11)),
      Song(id: 's7', title: 'Cascade Protocol', artist: 'The Hollow', album: 'Depths', duration: const Duration(minutes: 4, seconds: 33)),
    ];

    _playlists = [
      Playlist(id: 'p1', name: 'Late Night Drives', songs: songs.sublist(0, 3), lastPlayed: DateTime.now().subtract(const Duration(hours: 1))),
      Playlist(id: 'p2', name: 'Focus Mode', songs: songs.sublist(2, 6), lastPlayed: DateTime.now().subtract(const Duration(hours: 3))),
      Playlist(id: 'p3', name: 'Indie Picks', songs: songs.sublist(1, 5), isServer: true, serverId: 'srv1', lastPlayed: DateTime.now().subtract(const Duration(hours: 5))),
      Playlist(id: 'p4', name: 'Workout Anthems', songs: songs.sublist(3, 7), lastPlayed: DateTime.now().subtract(const Duration(days: 1))),
      Playlist(id: 'p5', name: 'Chill Waves', songs: songs.sublist(0, 4), isServer: true, serverId: 'srv2', lastPlayed: DateTime.now().subtract(const Duration(days: 2))),
    ];

    _servers = [
      MusicServer(id: 'srv1', name: 'Navidrome Home', url: 'http://192.168.1.10:4533', username: 'admin', type: ServerType.navidrome, status: ServerStatus.online, songCount: 1204),
      MusicServer(id: 'srv2', name: 'Jellyfin Media', url: 'http://media.local:8096', username: 'user', type: ServerType.jellyfin, status: ServerStatus.online, songCount: 3891),
    ];

    _lastPlayedSong = songs.first;
    _lastPlayedPlaylist = _playlists.first;
    _localStorageUsedMb = 247;
  }

  // ── Getters ────────────────────────────────────────────────────────────
  List<Playlist> get playlists => _playlists;
  List<Playlist> get userPlaylists => _playlists.where((p) => !p.isServer).toList();
  List<Playlist> get serverPlaylists => _playlists.where((p) => p.isServer).toList();
  List<Playlist> get playlistsByLastPlayed {
    final sorted = [..._playlists];
    sorted.sort((a, b) {
      if (a.lastPlayed == null && b.lastPlayed == null) return 0;
      if (a.lastPlayed == null) return 1;
      if (b.lastPlayed == null) return -1;
      return b.lastPlayed!.compareTo(a.lastPlayed!);
    });
    return sorted;
  }

  List<MusicServer> get servers => _servers;
  Song? get lastPlayedSong => _lastPlayedSong;
  Playlist? get lastPlayedPlaylist => _lastPlayedPlaylist;
  int get localStorageUsedMb => _localStorageUsedMb;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Suggestions: pull from server playlists + random mix
  List<Song> get suggestions {
    final all = _playlists.expand((p) => p.songs).toList();
    all.shuffle();
    return all.take(8).toList();
  }

  // ── Playlist CRUD ──────────────────────────────────────────────────────
  void addPlaylist(String name, {String? description}) {
    _playlists.add(Playlist(
      id: _uuid.v4(),
      name: name,
      description: description,
    ));
    notifyListeners();
  }

  void removePlaylist(String id) {
    _playlists.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void updatePlaylist(String id, {String? name, String? description}) {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    if (name != null) _playlists[idx].name = name;
    if (description != null) _playlists[idx].description = description;
    notifyListeners();
  }

  void addSongToPlaylist(String playlistId, Song song) {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;
    if (!_playlists[idx].songs.any((s) => s.id == song.id)) {
      _playlists[idx].songs.add(song);
      notifyListeners();
    }
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;
    _playlists[idx].songs.removeWhere((s) => s.id == songId);
    notifyListeners();
  }

  void markPlaylistPlayed(String playlistId) {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      _playlists[idx].lastPlayed = DateTime.now();
      notifyListeners();
    }
  }

  // ── Server Management ──────────────────────────────────────────────────
  Future<void> addServer(MusicServer server) async {
    _servers.add(server);
    notifyListeners();
    await _checkServerStatus(server.id);
  }

  void removeServer(String id) {
    _servers.removeWhere((s) => s.id == id);
    _playlists.removeWhere((p) => p.serverId == id);
    notifyListeners();
  }

  Future<void> _checkServerStatus(String serverId) async {
    final idx = _servers.indexWhere((s) => s.id == serverId);
    if (idx == -1) return;
    // Simulate check
    await Future.delayed(const Duration(seconds: 1));
    _servers[idx].status = ServerStatus.online;
    notifyListeners();
  }

  Future<void> checkAllServers() async {
    for (final s in _servers) {
      await _checkServerStatus(s.id);
    }
  }

  // ── Local Storage ──────────────────────────────────────────────────────
  Future<void> clearLocalStorage() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    _localStorageUsedMb = 0;
    _isLoading = false;
    notifyListeners();
  }

  // ── Search ─────────────────────────────────────────────────────────────
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    await Future.delayed(const Duration(milliseconds: 400));

    final q = query.toLowerCase();
    final results = <SearchResult>[];

    final allSongs = _playlists.expand((p) => p.songs).toSet().toList();
    for (final song in allSongs) {
      if (song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q) ||
          song.album.toLowerCase().contains(q)) {
        results.add(SearchResult(
          type: SearchResultType.song,
          id: song.id,
          title: song.title,
          subtitle: '${song.artist} • ${song.album}',
          data: song,
        ));
      }
    }

    for (final pl in _playlists) {
      if (pl.name.toLowerCase().contains(q)) {
        results.add(SearchResult(
          type: SearchResultType.playlist,
          id: pl.id,
          title: pl.name,
          subtitle: '${pl.songCount} songs',
          data: pl,
        ));
      }
    }

    return results;
  }
}