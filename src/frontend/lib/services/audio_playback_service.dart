import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/models/beat_models.dart';

class AudioPlaybackService extends BaseAudioHandler with SeekHandler {
  final audioPlayer = AudioPlayer();

  late VoidCallbackUpdateProgress _updateProgress;

  AudioPlaybackService() {
    // So that our clients (the Flutter UI and the system notification) know
    // what state to display, here we set up our audio handler to broadcast all
    // playback state changes as they happen via playbackState...
    audioPlayer.playbackEventStream.map(_transformEvent).pipe(playbackState);

    audioPlayer.positionStream.listen((position) {
      updateProgress(position);
    });

    // Playback has ended, set _enReached to true, then updateProgress will handle the rest (stop, next song or repeat)
    audioPlayer.playbackEventStream.listen((e) {
      _setCurrentBeat();
      _setMediaItemForBeat();
      if (e.duration == null) return;
      if (e.duration!.inSeconds == e.updatePosition.inSeconds) {
        _enReached = true;
      }
    });
  }

  bool get isPlaying => _isPlaying;
  bool _isPlaying = false;

  bool _enReached = false;

  double _progress = 0.0;

  // beat.key ('sourceId:id'), plain ids collide across servers
  String get beatKey => _beatKey;
  String _beatKey = '';

  Beat? get currentBeat => _currentBeat;
  Beat? _currentBeat;

  BeatMix? get currentBeatMix => _currentBeatMix;
  BeatMix? _currentBeatMix;

  List<Beat> get recentBeats => _recentBeats;
  final List<Beat> _recentBeats = [];

  final List<MediaItem> beatMediaItems = [];
  final List<UriAudioSource> beatAudioSources = [];

  void setBeatSource(Beat beat) async {
    final audioSource = _createSourceUri(beat);

    final audioSourceMediaItem = _createMediaItem(beat);

    audioPlayer.setAudioSource(audioSource);

    mediaItem.add(audioSourceMediaItem);

    _beatKey = beat.key;
    _currentBeat = beat;
  }

  void setBeatMix(BeatMix? mix, Beat? initalBeat) async {
    _currentBeatMix = mix;
    _currentBeat = initalBeat;

    beatMediaItems.clear();
    beatAudioSources.clear();

    var initialIndex = 0;

    for (var i = 0; i < mix!.beats!.length; i++) {
      final beat = mix.beats![i];
      beatMediaItems.add(_createMediaItem(beat));
      beatAudioSources.add(_createSourceUri(beat));

      if (initalBeat != null && initalBeat.id == beat.id) {
        initialIndex = i;
      }
    }

    audioPlayer.setAudioSources(beatAudioSources,
        preload: true,
        initialIndex: initialIndex,
        shuffleOrder: DefaultShuffleOrder());

    mediaItem.add(beatMediaItems[initialIndex]);

    _beatKey = initalBeat!.key;
    _currentBeat = initalBeat;
  }

  Future<bool> togglePlay() async {
    _isPlaying = !_isPlaying;

    if (isPlaying) {
      await audioPlayer.play();
    } else {
      await audioPlayer.pause();
    }
    return _isPlaying;
  }

  void setShuffleModeEnabled(bool shuffle) async {
    await audioPlayer.setShuffleModeEnabled(shuffle);
  }

  void setLoopMode(LoopMode mode) async {
    await audioPlayer.setLoopMode(mode);
  }

  void setVolume(double volume) async {
    await audioPlayer.setVolume(volume);
  }

  void setUpdateProgressCallback(VoidCallbackUpdateProgress updateProgress) {
    _updateProgress = updateProgress;
  }

  void updateProgress(Duration position) async {
    if (!_isPlaying) return;

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

      await audioPlayer.seek(Duration.zero);
      await audioPlayer.pause();

      // track recent played beats
      if (_currentBeat != null && !_recentBeats.contains(_currentBeat)) {
        _recentBeats.add(_currentBeat!);
      }

      if (audioPlayer.loopMode == LoopMode.one) {
        togglePlay();
      } else if (audioPlayer.loopMode == LoopMode.all) {
        await skipToNext();
      }
    }

    // Callback so the UI gets updated with the correct data
    _updateProgress(_progress, _currentBeat!);
  }

  @override
  Future<void> play() async {
    await togglePlay();
  }

  @override
  Future<void> pause() async {
    await togglePlay();
  }

  @override
  Future<void> stop() async {
    if (_isPlaying) {
      await togglePlay();
    }

    await audioPlayer.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await setSeek(position);
  }

  Future<void> setSeek(Duration position) async {
    await audioPlayer.seek(position < Duration.zero ? Duration.zero : position);
  }

  @override
  Future<void> skipToNext() async {
    if (audioPlayer.hasNext) {
      await audioPlayer.seekToNext();
      _setCurrentBeat();
      _setMediaItemForBeat();
      _updateProgress(0, _currentBeat!);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (audioPlayer.hasPrevious) {
      await audioPlayer.seekToPrevious();
      _setCurrentBeat();
      _setMediaItemForBeat();
      _updateProgress(0, _currentBeat!);
    }
  }

  void _setCurrentBeat() {
    var id = _getCurrentAudioSourceTagId();
    if (id == "") return;
    var currentBeat =
        _currentBeatMix!.beats!.where((i) => i.key == id).first;

    if (currentBeat.id != _currentBeat!.id) {
      _currentBeat = currentBeat;
    }
  }

  void _setMediaItemForBeat() {
    var id = _getCurrentAudioSourceTagId();
    if (id == "") return;
    var beatMediaItem = beatMediaItems.where((i) => i.id == id).first;

    mediaItem.add(beatMediaItem);
  }

  String _getCurrentAudioSourceTagId() {
    var index = audioPlayer.currentIndex;
    if (index == null) return "";
    var currentSource = audioPlayer.audioSources[index] as UriAudioSource;
    return currentSource.tag.toString();
  }

  // Helpers functions
  UriAudioSource _createSourceUri(Beat beat) =>
      AudioSource.uri(Uri.parse(beat.audioUrl!), tag: beat.key);

  MediaItem _createMediaItem(Beat beat) => MediaItem(
      id: beat.key,
      album: "x0x", // TODO fetch beatmix name with request (if any)
      title: beat.title,
      //artist: beat.artist,
      duration: beat.duration,
      artUri: Uri.parse(beat.thumbnailUrl));

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
      }[audioPlayer.processingState]!,
      playing: audioPlayer.playing,
      updatePosition: audioPlayer.position,
      bufferedPosition: audioPlayer.bufferedPosition,
      speed: audioPlayer.speed,
      queueIndex: event.currentIndex,
    );
  }
}
