import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/main.dart';
import 'package:liberated_beats/models/beat_models.dart';

final class BackgroundAudioProvider extends BaseAudioHandler
    with ChangeNotifier, SeekHandler {
  BackgroundAudioProvider() {
    // So that our clients (the Flutter UI and the system notification) know
    // what state to display, here we set up our audio handler to broadcast all
    // playback state changes as they happen via playbackState...
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.positionStream.listen((position) {
      updateProgress(position);
    });

    // Playback has ended, set _enReached to true, then tick will handle the rest (stop, next song or repeat)
    _player.playbackEventStream.listen((e) {
      if (e.duration == null) return;
      if (e.duration!.inSeconds == e.updatePosition.inSeconds) {
        _enReached = true;
      }
    });
  }

  final _player = AudioPlayer();

  Beat? _currentBeat;
  List<Beat> recentBeats = [];
  List<Beat> beats = [];
  List<MediaItem> beatMedaiItems = [];
  MediaItem? _currentMediaItem;

  bool _isPlaying = false;
  bool _enReached = false;
  double _progress = 0.0;
  bool _shuffle = false;
  LoopMode _repeatMode = LoopMode.off;
  double _volume = 1.0;

  Beat? get currentTrack => _currentBeat;
  bool get isPlaying => _isPlaying;
  double get progress => _progress;
  bool get shuffle => _shuffle;
  LoopMode get repeatMode => _repeatMode;
  double get volume => _volume;

  Duration get elapsed {
    final track = _currentBeat;
    if (track == null) return Duration.zero;
    return track.duration * _progress;
  }

  // Set a beatmix, then from there play the selected beat
  void playBeatMix(BeatMix beatmix, Beat selectedBeat) {
    // TODO slowly reduce the sound over time instead
    if (isPlaying) {
      togglePlay();
    }

    final List<AudioSource> audioSources = [];
    var initialIndex = 0;

    for (var i = 0; i < beatmix.beats!.length; i++) {
      final beat = beatmix.beats![i];
      audioSources.add(_createUri(beat));
      beatMedaiItems[i] = _createMediaItem(beat);

      if (beat.id == selectedBeat.id) {
        initialIndex = i;
      }
    }

    _player.setAudioSources(audioSources,
        initialIndex: initialIndex,
        initialPosition: Duration.zero,
        preload: true,
        shuffleOrder: DefaultShuffleOrder());

    seek(Duration.zero);

    togglePlay();
  }

  // This should only play a single beat, repeat it or stop after play
  void playBeat(Beat beat) async {
    // Tapping the already-current track toggles play/pause instead of restarting.
    if (_currentBeat?.id == beat.id) {
      togglePlay();
      return;
    }

    _currentBeat = beat;

    _player.setAudioSource(_createUri(beat),
        preload: true, initialPosition: Duration.zero);
    
    _progress = 0;

    //var _beatDuration = await _player.load();

    mediaItem.add(_createMediaItem(beat));

    togglePlay();

    notifyListeners();
  }

  void togglePlay() async {
    _isPlaying = !_isPlaying;

    if (isPlaying) {
      setMediaItem();
      await _player.play();
    } else {
      await _player.pause();
    }

    notifyListeners();
  }

  void setMediaItem() async {
    // ignore: no_leading_underscores_for_local_identifiers
    final _mediatype = _getMediaItem();
    if (_mediatype != null && !await mediaItem.contains(_mediatype)) {
      mediaItem.add(_getMediaItem());
    }
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    _player.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  void cycleRepeat() {
    _repeatMode = switch (_repeatMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    _player.setLoopMode(_repeatMode);
    PrintLog("Repeat mode $_repeatMode");
    notifyListeners();
  }

  void setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  void updateProgress(Duration position) async {
    if (!_isPlaying || _currentBeat == null) return;

    final totalMs = _currentBeat!.duration.inMilliseconds;
    if (totalMs == 0) {
      return;
    }

    // Set progress directly from the actual position
    _progress = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    if (_enReached) {
      _progress = 0;
      _isPlaying = false;
      _enReached = false;
      await _player.seek(Duration.zero);
      await _player.pause();

      if (_repeatMode == LoopMode.one) {
        togglePlay();
      } else if (_repeatMode == LoopMode.all || _repeatMode == LoopMode.off) {
        await skipToNext();
      }
    }

    notifyListeners();
  }

  // BaseAudioHandler overides
  @override
  Future<void> play() async {
    togglePlay();
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    togglePlay();
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    setSeek(position);
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    // TODO handle actions
  }

  Future<ValueChanged<double>?> setSeek(Duration position) async {
    if (position < Duration.zero) 0;
    final positionDouble = position.inSeconds.toDouble();
    _progress = positionDouble.clamp(0.0, 1.0);
    await _player.seek(position);
    notifyListeners();
    return null;
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      notifyListeners();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      notifyListeners();
    }
  }

  MediaItem? _getMediaItem() {
    var source = _player.audioSource;

    if (source == null) return null;

    if (_currentMediaItem != null) return _currentMediaItem;

    // Can fail, maby
    _currentMediaItem =
        // ignore: unrelated_type_equality_checks
        beatMedaiItems.where((i) => i.id == _currentBeat?.id).first;

    return _currentMediaItem;
  }

  // Helpers functions
  UriAudioSource _createUri(Beat beat) =>
      AudioSource.uri(Uri.parse(beat.audioUrl!));

  MediaItem _createMediaItem(Beat beat) => MediaItem(
      id: beat.id.toString(),
      album: "x0x", // TODO fetch beatmix name with request (if any)
      title: beat.title,
      //artist: beat.artist,
      duration: beat.duration,
      artUri: Uri.parse(beat.album));

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  void clearResources() {
    dispose();
    _player.dispose();
  }
}
