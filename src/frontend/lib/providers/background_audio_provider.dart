import 'package:flutter/material.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/main.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';

final class BackgroundAudioProvider extends ChangeNotifier {
  BackgroundAudioProvider(this._playbackService) {
    _playbackService.setUpdateProgressCallback(updateProgress);
  }

  final AudioPlaybackService _playbackService;

  // TODO does not reflect actuall recents
  List<Beat> get recentBeats => _playbackService.recentBeats;

  bool _shuffle = false;
  LoopMode _repeatMode = LoopMode.off;
  double _volume = 1.0;

  Beat? get currentBeat => _currentBeat;
  Beat? _currentBeat;

  bool get isPlaying => _playbackService.isPlaying;

  double get progress => _progress;
  double _progress = 0.0;

  bool get shuffle => _shuffle;
  LoopMode get repeatMode => _repeatMode;
  double get volume => _volume;

  Duration get elapsed {
    final track = _playbackService.currentBeat;
    if (track == null) return Duration.zero;
    return track.duration * progress;
  }

  // Set a beatmix, then from there play the selected beat
  void playBeatMix(BeatMix beatmix, Beat selectedBeat) {
    if (isPlaying) togglePlay();
    _playbackService.setBeatMix(beatmix, selectedBeat);
    togglePlay();
  }

  // This should only play a single beat, repeat it or stop after play
  void playBeat(Beat beat) async {
    // Tapping the already-current track toggles play/pause instead of restarting.
    if (_playbackService.beatId == beat.id) {
      togglePlay();
      return;
    }

    if (isPlaying) togglePlay();

    _playbackService.setBeatSource(beat);

    togglePlay();
  }

  void togglePlay() async {
    await _playbackService.togglePlay();
    notifyListeners();
  }

  void updateProgress(double nProgress, Beat currentBeat) {
    _progress = nProgress;

    // Display the current playing song
    if (_currentBeat != currentBeat) {
      _currentBeat = currentBeat;
    }

    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _playbackService.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  void cycleRepeat() {
    _repeatMode = switch (_repeatMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    _playbackService.setLoopMode(_repeatMode);
    notifyListeners();
  }

  void setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    _playbackService.setVolume(_volume);
    notifyListeners();
  }

  // BaseAudioHandler overides
  Future<ValueChanged<double>?> setSeek(double value) async {
    _progress = value.clamp(0.0, 1.0);
    await _playbackService.setSeek(elapsed);
    notifyListeners();
    return null;
  }

  Future<void> skipToNext() async {
    await _playbackService.skipToNext();
    notifyListeners();
  }

  Future<void> skipToPrevious() async {
    await _playbackService.skipToPrevious();
    notifyListeners();
  }
}
