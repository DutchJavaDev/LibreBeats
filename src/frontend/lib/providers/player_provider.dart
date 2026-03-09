// TODO Implement this library.import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:librebeats/data/models.dart';

class PlayerProvider extends ChangeNotifier {
  Song? _currentSong;
  Playlist? _currentPlaylist;
  List<Song> _queue = [];
  int _queueIndex = 0;

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  RepeatMode _repeat = RepeatMode.none;
  ShuffleMode _shuffle = ShuffleMode.off;

  bool _miniPlayerVisible = false;
  bool _fullPlayerVisible = false;

  // Getters
  Song? get currentSong => _currentSong;
  Playlist? get currentPlaylist => _currentPlaylist;
  List<Song> get queue => _queue;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  RepeatMode get repeat => _repeat;
  ShuffleMode get shuffle => _shuffle;
  bool get miniPlayerVisible => _miniPlayerVisible;
  bool get fullPlayerVisible => _fullPlayerVisible;
  double get progress => _duration.inSeconds > 0
      ? _position.inSeconds / _duration.inSeconds
      : 0.0;

  // Play a song
  Future<void> playSong(Song song, {Playlist? playlist, List<Song>? queue}) async {
    _currentSong = song;
    _currentPlaylist = playlist;
    if (queue != null) {
      _queue = queue;
      _queueIndex = queue.indexWhere((s) => s.id == song.id);
    } else {
      _queue = [song];
      _queueIndex = 0;
    }
    _isPlaying = true;
    _isLoading = true;
    _miniPlayerVisible = true;
    _position = Duration.zero;
    _duration = song.duration;
    notifyListeners();

    // Simulate loading
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoading = false;
    notifyListeners();

    // Simulate playback progress
    _simulatePlayback();
  }

  void _simulatePlayback() async {
    while (_isPlaying && _currentSong != null) {
      await Future.delayed(const Duration(seconds: 1));
      if (_isPlaying) {
        _position += const Duration(seconds: 1);
        if (_position >= _duration) {
          await skipNext();
          return;
        }
        notifyListeners();
      }
    }
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    if (_isPlaying) _simulatePlayback();
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (_queue.isEmpty) return;
    if (_repeat == RepeatMode.one) {
      await playSong(_currentSong!, playlist: _currentPlaylist, queue: _queue);
      return;
    }
    int next = _queueIndex + 1;
    if (next >= _queue.length) {
      if (_repeat == RepeatMode.all) {
        next = 0;
      } else {
        _isPlaying = false;
        notifyListeners();
        return;
      }
    }
    _queueIndex = next;
    await playSong(_queue[next], playlist: _currentPlaylist, queue: _queue);
  }

  Future<void> skipPrev() async {
    if (_position.inSeconds > 3) {
      _position = Duration.zero;
      notifyListeners();
      return;
    }
    if (_queue.isEmpty) return;
    int prev = _queueIndex - 1;
    if (prev < 0) prev = _queue.length - 1;
    _queueIndex = prev;
    await playSong(_queue[prev], playlist: _currentPlaylist, queue: _queue);
  }

  void seek(double ratio) {
    _position = Duration(seconds: (_duration.inSeconds * ratio).round());
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  void toggleRepeat() {
    _repeat = RepeatMode.values[(_repeat.index + 1) % RepeatMode.values.length];
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = _shuffle == ShuffleMode.off ? ShuffleMode.on : ShuffleMode.off;
    notifyListeners();
  }

  void showFullPlayer() {
    _fullPlayerVisible = true;
    notifyListeners();
  }

  void hideFullPlayer() {
    _fullPlayerVisible = false;
    notifyListeners();
  }

  void stopAndHide() {
    _isPlaying = false;
    _miniPlayerVisible = false;
    _fullPlayerVisible = false;
    _currentSong = null;
    notifyListeners();
  }
}