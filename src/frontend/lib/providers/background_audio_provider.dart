import 'package:flutter/material.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';

final class BackgroundAudioProvider extends ChangeNotifier {
  BackgroundAudioProvider(this._playbackService) {
    _playbackService.setUpdateProgressCallback(updateProgress);
    // repaint the history UI when a play is recorded or the persisted
    // history finishes loading on startup
    _playbackService.setRecentsChangedCallback(notifyListeners);
    // repaint when the sleep timer arms, disarms or fires
    _playbackService.setSleepChangedCallback(notifyListeners);
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

  /// Time left on the sleep timer, null when no duration timer is armed.
  /// The label rides the position tick, no extra timer needed for the UI.
  Duration? get sleepRemaining {
    final until = _playbackService.sleepUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get sleepEndOfTrack => _playbackService.sleepEndOfTrack;

  /// The originally picked length, for marking the armed sheet option.
  Duration? get sleepDuration => _playbackService.sleepDuration;

  bool get sleepArmed => sleepRemaining != null || sleepEndOfTrack;

  void setSleepTimer(Duration? duration) {
    _playbackService.setSleepTimer(duration);
    notifyListeners();
  }

  void setSleepEndOfTrack() {
    _playbackService.setSleepEndOfTrack();
    notifyListeners();
  }

  // Set a beatmix, then from there play the selected beat
  Future<void> playBeatMix(BeatMix beatmix, Beat selectedBeat) async {
    // Tapping the already-current track toggles play/pause instead of
    // restarting, same as playBeat. Without this a tap on the playing row
    // pauses, reloads the queue and plays again.
    if (_playbackService.beatKey == selectedBeat.key) {
      await togglePlay();
      return;
    }

    if (isPlaying) await togglePlay();

    // a failed load (dead server, bad url) should not flip to "playing"
    final loaded = await _playbackService.setBeatMix(beatmix, selectedBeat);
    if (!loaded) return;

    await togglePlay();
  }

  // This should only play a single beat, repeat it or stop after play.
  // False when there is nothing to play, the beat also gets dropped from
  // the history so dead entries do not linger on home.
  Future<bool> playBeat(Beat beat) async {
    // sample data has no stream to play
    if (!beat.isPlayable) return false;

    // Tapping the already-current track toggles play/pause instead of restarting.
    if (_playbackService.beatKey == beat.key) {
      await togglePlay();
      return true;
    }

    if (isPlaying) await togglePlay();

    // a failed load (dead server, bad url) should not flip to "playing"
    final loaded = await _playbackService.setBeatSource(beat);
    if (!loaded) {
      _playbackService.removeRecent(beat.key);
      return false;
    }

    await togglePlay();
    return true;
  }

  Future<void> togglePlay() async {
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
  Future<void> setSeek(double value) async {
    _progress = value.clamp(0.0, 1.0);
    await _playbackService.setSeek(elapsed);
    notifyListeners();
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
