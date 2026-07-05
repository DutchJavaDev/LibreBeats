import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:liberated_beats/main.dart';
import 'package:liberated_beats/services/audio_service.dart';

import '../models/beat_models.dart';

enum RepeatMode { off, all, one }

/// Holds all (simulated) playback state. There is no real audio engine wired
/// up — every value here lives in memory and is mutated by the UI.
class PlayerProvider extends ChangeNotifier {
  PlayerProvider(this._audioPlayback) {
    _audioPlayback.tickUpdater(tick);
    _audioPlayback.togglePlayUpdater(_togglePlay);
    _audioPlayback.onEnd(endOfBeat);
    _audioPlayback.onNext(nextTrack);
    _audioPlayback.onPrev(prevTrack);
  }

  final AudioPlaybackHandler _audioPlayback;

  Beat? _currentTrack;
  List<Beat> recentTracks = [];
  List<Beat> beats = [];
  List<Beat> beatsOriginal = [];
  bool _isPlaying = false;
  bool _enReached = false;
  double _progress = 0.0;
  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  double _volume = 1.0;

  Beat? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  double get progress => _progress;
  bool get shuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;
  double get volume => _volume;

  /// Elapsed time, derived by scaling the current track's duration by [progress].
  Duration get elapsed {
    final track = _currentTrack;
    if (track == null) return Duration.zero;
    return track.duration * _progress;
  }

  void playTrack(Beat track) {
    // Tapping the already-current track toggles play/pause instead of restarting.
    if (_currentTrack?.id == track.id) {
      togglePlay();
      return;
    }
    _currentTrack = track;

    _audioPlayback.setAudioSource(_currentTrack!);
    _audioPlayback.play();

    _progress = 0;
    _isPlaying = true;

    if (!recentTracks.any((t) => t.id == track.id)) {
      recentTracks.add(track);
    }

    notifyListeners();
  }

  void togglePlay() {
    _isPlaying = !_isPlaying;
    _isPlaying ? _audioPlayback.play() : _audioPlayback.pause();
    notifyListeners();
  }

  void _togglePlay(bool state){
    _isPlaying = state;
    notifyListeners();
  }

  void seek(double value) {
    _progress = value.clamp(0.0, 1.0);
    _audioPlayback.seek(elapsed);
    notifyListeners();
  }

  void setBeats(List<Beat> beats)
  {
    this.beats = beats;
    beatsOriginal = beats;
  }

  void nextTrack() {
    if (_currentTrack == null || beats.isEmpty) return;
    final idx = beats.indexWhere((t) => t.id == _currentTrack!.id);
    final next = (idx + 1) % beats.length;
    _currentTrack = beats[next];
    _audioPlayback.setAudioSource(_currentTrack!);
    _audioPlayback.play();
    _progress = 0;
    _isPlaying = true;
    notifyListeners();
  }

  void prevTrack() {
    if (_currentTrack == null || beats.isEmpty) return;
    // If we're more than 5% into the track, "previous" restarts it instead.
    if (_progress > 0.05) {
      _progress = 0;
      notifyListeners();
      return;
    }
    final idx = beats.indexWhere((t) => t.id == _currentTrack!.id);
    final prev = (idx - 1 + beats.length) % beats.length;
    _currentTrack = beats[prev];
    _audioPlayback.setAudioSource(_currentTrack!);
    _audioPlayback.play();
    _progress = 0;
    _isPlaying = true;
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if(_shuffle)
    {
      PrintLog(beats.map((e) => e.id));
      var random = Random();
      beats.shuffle(random);
    }
    else{
      beats.clear();
      beats.addAll(beatsOriginal);
    }

    notifyListeners();
  }

  void cycleRepeat() {
    _repeatMode = switch (_repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    PrintLog("Repeat mode $_repeatMode");
    notifyListeners();
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _audioPlayback.setVolume(_volume);
    notifyListeners();
  }

  void endOfBeat()
  {
    _enReached = true; 
  }

  /// Advances [progress] by [delta]. Intended to be driven by a ticker/audio
  /// callback; nothing in the current codebase calls this yet, so progress only
  /// changes when the user drags a slider.
  void tick(Duration delta) {
    if (!_isPlaying || _currentTrack == null) return;

    final totalMs = _currentTrack!.duration.inMilliseconds;
    if (totalMs == 0) {
      return;
    }

    // ✅ Set progress directly from the actual position
    _progress = (delta.inMilliseconds / totalMs).clamp(0.0, 1.0);
    
    if(_enReached)
    {
      _progress = 0;
      _isPlaying = false;
      _enReached = false;
      _audioPlayback.seek(Duration.zero);
      _audioPlayback.pause();

      if(_repeatMode == RepeatMode.one)
      {
        _audioPlayback.play();
      }
      else if(_repeatMode == RepeatMode.all || _repeatMode == RepeatMode.off)
      {
        nextTrack();
      }
    }

    notifyListeners();
  }
}


// Delta update: 214.45ms tick, progress: 0.9224676616915424 EndTime: 201000ms