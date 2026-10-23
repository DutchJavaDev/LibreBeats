import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/data/play_state_store.dart';
import 'package:liberated_beats/models/beat_models.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';

final class BackgroundAudioProvider extends ChangeNotifier {
  BackgroundAudioProvider(this._playbackService, this._playStateStore) {
    _playbackService.setUpdateProgressCallback(updateProgress);
    // repaint the history UI when a play is recorded or the persisted
    // history finishes loading on startup
    _playbackService.setRecentsChangedCallback(notifyListeners);
    // repaint when the sleep timer arms, disarms or fires
    _playbackService.setSleepChangedCallback(notifyListeners);

    unawaited(resumeLastPlayState());
  }

  Future<void> resumeLastPlayState() async {
    if (_playStateStore.lastPlayedBeat != null &&
        _playStateStore.lastPlayedBeatMix != null &&
        _playStateStore.lastPlayedBeatMix!.title.isNotEmpty) {
      _currentBeat = _playStateStore.lastPlayedBeat;

      // PrintLog('Restoring beat + beatmix');

      // a failed load (dead server, bad url) should not flip to "playing"
      final loaded = await _playbackService.setBeatMix(
          _playStateStore.lastPlayedBeatMix, _currentBeat);
      if (!loaded) {
        PrintLog('Failed to load ${_currentBeat!.artist}');
        _playbackService.removeRecent(_currentBeat!.key);
        return;
      }
    } else if (_playStateStore.lastPlayedBeat != null) {
      _currentBeat = _playStateStore.lastPlayedBeat;

      // PrintLog('Restoring beat');

      // a failed load (dead server, bad url) should not flip to "playing"
      final loaded = await _playbackService.setBeatSource(_currentBeat!);
      if (!loaded) {
        PrintLog('Failed to load ${_currentBeat!.artist}');
        _playbackService.removeRecent(_currentBeat!.key);
        return;
      }

      if (_playStateStore.lastKnowQueue.isNotEmpty) {
        _playbackService.queueBeats.clear();
        _playbackService.queueBeats.add(_currentBeat!);
      }
    }

    if (_playStateStore.lastPlayedBeatElapsedDuration != null) {
      final elapsedDuration = _playStateStore.lastPlayedBeatElapsedDuration!;

      await _playbackService.seek(elapsedDuration);
    }
  }

  final AudioPlaybackService _playbackService;

  final PlayStateStore _playStateStore;

  // TODO does not reflect actuall recents
  List<Beat> get recentBeats => _playbackService.recentBeats;

  bool _shuffle = false;
  LoopMode _repeatMode = LoopMode.off;
  double _volume = 1.0;

  Beat? get currentBeat => _currentBeat;
  Beat? _currentBeat;

  bool get isPlaying => _playbackService.isPlaying;

  double get progress => _progressNotifier.value;

  /// Only the two progress consumers (the mini bar, the full player slider)
  /// listen here, the 5-60Hz position ticks stay off notifyListeners entirely.
  ValueListenable<double> get progressListenable => _progressNotifier;
  final _progressNotifier = ValueNotifier<double>(0.0);

  bool get shuffle => _shuffle;
  LoopMode get repeatMode => _repeatMode;
  double get volume => _volume;

  Duration get elapsed {
    final track = _playbackService.currentBeat;
    if (track == null) return Duration.zero;
    return track.duration * progress;
  }

  /// Time left on the sleep timer, null when no duration timer is armed.
  /// The full player's sleep button runs its own one-second ticker.
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
  Future<bool> playBeatMix(BeatMix beatmix, Beat selectedBeat) async {
    // Tapping the already-current track toggles play/pause instead of
    // restarting, same as playBeat. Without this a tap on the playing row
    // pauses, reloads the queue and plays again.
    if (_playbackService.beatKey == selectedBeat.key) {
      await togglePlay();
      return true;
    }

    if (isPlaying) await togglePlay();

    // a failed load (dead server, bad url) should not flip to "playing"
    final loaded = await _playbackService.setBeatMix(beatmix, selectedBeat);
    if (!loaded) return false;

    await _playStateStore.setLastPlayedBeatAndBeatMix(
        selectedBeat, Duration.zero, _playbackService.queueBeats, beatmix);

    await togglePlay();
    return true;
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

    await _playStateStore.setLastPlayedBeatAndBeatMix(
        beat, Duration.zero, [], null);

    await togglePlay();
    return true;
  }

  Future<void> togglePlay() async {
    await _playbackService.togglePlay();
    notifyListeners();
  }

  bool _lastNotifiedPlaying = false;

  void updateProgress(double nProgress, Beat currentBeat) async {
    _progressNotifier.value = nProgress;

    // a full notify only for what actually repaints widgets: a track change
    // or a play/pause flip (the service piggybacks its playingStream
    // listener on this callback)
    final playing = isPlaying;
    if (_currentBeat != currentBeat || _lastNotifiedPlaying != playing) {
      _currentBeat = currentBeat;
      _lastNotifiedPlaying = playing;
      _playStateStore.setLastPlayedBeatAndBeatMix(_currentBeat, Duration.zero,
          _playbackService.queueBeats, _playbackService.currentBeatMix);
      notifyListeners();
    }
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
    _progressNotifier.value = value.clamp(0.0, 1.0);
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

  List<Beat> get queueBeats => _playbackService.queueBeats;

  List<int> get shuffleIndices => _playbackService.shuffleIndices;

  // the player's own flag, [_shuffle] is just what the toggle button paints
  bool get shuffleEnabled => _playbackService.shuffleEnabled;

  Future<void> skipToQueueItem(int index) async {
    await _playbackService.skipToQueueItem(index);
    notifyListeners();
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    super.dispose();
  }
}
