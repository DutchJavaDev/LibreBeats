import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/data/history_store.dart';
import 'package:liberated_beats/models/beat_models.dart';

/// http(s) stays a network url, anything else is a file on disk. Uri.parse
/// on a plain path would mangle it (a windows drive letter becomes a scheme).
Uri mediaUri(String url) =>
    url.startsWith('http') ? Uri.parse(url) : Uri.file(url);

class AudioPlaybackService extends BaseAudioHandler with SeekHandler {
  final audioPlayer = AudioPlayer();

  final HistoryStore _historyStore;

  /// When set, may return a file on disk to play instead of the beat's url
  /// (a finished liked download). Resolved per play, so a beat that got
  /// un-liked in the meantime just streams again instead of crashing on a
  /// deleted file.
  String? Function(Beat beat)? localSourceResolver;

  VoidCallbackUpdateProgress? _updateProgress;
  void Function()? _recentsChanged;

  AudioPlaybackService({HistoryStore? historyStore})
      : _historyStore = historyStore ?? HistoryStore() {
    _setupAudioSession();
    _restoreRecents();

    // So that our clients (the Flutter UI and the system notification) know
    // what state to display, here we set up our audio handler to broadcast all
    // playback state changes as they happen via playbackState...
    audioPlayer.playbackEventStream.map(_transformEvent).pipe(playbackState);

    audioPlayer.positionStream.listen((position) {
      updateProgress(position);
    });

    audioPlayer.playbackEventStream.listen((e) {
      _setCurrentBeat();
      _setMediaItemForBeat();
    }, onError: (Object e, StackTrace st) {
      PrintLog('Playback error: $e');
    });

    // The player is the source of truth for playing/paused. External changes
    // (media notification, headset, audio focus loss) land here too, so the
    // flag can not drift from what is actually audible.
    audioPlayer.playingStream.listen((playing) {
      if (_isPlaying == playing) return;
      _isPlaying = playing;
      final beat = _currentBeat;
      if (beat != null) _updateProgress?.call(_progress, beat);
    });

    // Playback has ended. Advancing through the queue and repeat one/all are
    // just_audio's job, completed only fires when the whole queue ran out:
    // rewind and stay paused.
    audioPlayer.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        if (_sleepEndOfTrack) _clearSleep();
        await audioPlayer.pause();
        await audioPlayer.seek(Duration.zero);
      }
    });

    // End-of-track sleep: the queue advancing on its own is the track
    // ending, so pause there instead of playing the next one.
    audioPlayer.positionDiscontinuityStream.listen((discontinuity) async {
      if (_sleepEndOfTrack &&
          discontinuity.reason == PositionDiscontinuityReason.autoAdvance) {
        _clearSleep();
        await pause();
      }
    });
  }

  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Headphones unplugged / bluetooth dropped: pause instead of switching
      // to the loudspeaker.
      session.becomingNoisyEventStream.listen((_) {
        audioPlayer.pause();
      });

      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              audioPlayer.setVolume(audioPlayer.volume / 2);
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (audioPlayer.playing) {
                _pausedByInterruption = true;
                audioPlayer.pause();
              }
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              audioPlayer.setVolume((audioPlayer.volume * 2).clamp(0.0, 1.0));
            case AudioInterruptionType.pause:
              if (_pausedByInterruption) audioPlayer.play();
              _pausedByInterruption = false;
            case AudioInterruptionType.unknown:
              _pausedByInterruption = false;
          }
        }
      });
    } catch (e) {
      // no audio_session backend on this platform, playback still works
      PrintLog('Audio session setup failed: $e');
    }
  }

  bool get isPlaying => _isPlaying;
  bool _isPlaying = false;

  bool _pausedByInterruption = false;

  // Sleep timer, session-only: either a wall-clock deadline or pause when
  // the current track ends. Never both at once.
  Timer? _sleepTimer;

  /// When the duration timer pauses playback, null when not armed.
  DateTime? get sleepUntil => _sleepUntil;
  DateTime? _sleepUntil;

  /// The originally picked length, so the sheet can mark the armed option.
  Duration? get sleepDuration => _sleepDuration;
  Duration? _sleepDuration;

  /// Pause when the current track finishes instead of at a fixed time.
  bool get sleepEndOfTrack => _sleepEndOfTrack;
  bool _sleepEndOfTrack = false;

  void Function()? _sleepChanged;

  void setSleepChangedCallback(void Function() sleepChanged) {
    _sleepChanged = sleepChanged;
  }

  /// Arms the timer for [duration]; null disarms. Replaces any earlier
  /// timer, including an end-of-track one.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEndOfTrack = false;
    _sleepDuration = duration;
    _sleepUntil = duration == null ? null : DateTime.now().add(duration);
    if (duration != null) {
      _sleepTimer = Timer(duration, () async {
        _clearSleep();
        await pause();
      });
    }
    _sleepChanged?.call();
  }

  /// Pause when the current track ends. Replaces a duration timer.
  void setSleepEndOfTrack() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepUntil = null;
    _sleepDuration = null;
    _sleepEndOfTrack = true;
    _sleepChanged?.call();
  }

  void _clearSleep() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepUntil = null;
    _sleepDuration = null;
    _sleepEndOfTrack = false;
    _sleepChanged?.call();
  }

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

  Future<bool> setBeatSource(Beat beat) async {
    _currentBeatMix = null;

    final audioSource = _createSourceUri(beat);
    final audioSourceMediaItem = _createMediaItem(beat);

    beatMediaItems
      ..clear()
      ..add(audioSourceMediaItem);
    beatAudioSources
      ..clear()
      ..add(audioSource);

    try {
      await audioPlayer.setAudioSource(audioSource);
    } catch (e) {
      PrintLog('Failed to load "${beat.title}": $e');
      return false;
    }

    mediaItem.add(audioSourceMediaItem);

    _beatKey = beat.key;
    _currentBeat = beat;
    _progress = 0;
    _recordRecent(beat);
    return true;
  }

  Future<bool> setBeatMix(BeatMix? mix, Beat? initalBeat) async {
    if (mix == null) return false;

    // sample data has no stream url, skip it instead of handing the player an
    // unplayable source. Queue items carry the owning mix for subtitles.
    final beats = (mix.beats ?? const <Beat>[])
        .where((beat) => beat.isPlayable)
        .map((beat) =>
            beat.mixTitle == null ? beat.copyWith(mixTitle: mix.title) : beat)
        .toList();
    if (beats.isEmpty) {
      PrintLog('Nothing playable in "${mix.title}"');
      return false;
    }

    _currentBeatMix = mix;

    beatMediaItems.clear();
    beatAudioSources.clear();

    var initialIndex = 0;

    for (var i = 0; i < beats.length; i++) {
      final beat = beats[i];
      beatMediaItems.add(_createMediaItem(beat));
      beatAudioSources.add(_createSourceUri(beat));

      // match by key, plain ids collide across servers
      if (initalBeat != null && initalBeat.key == beat.key) {
        initialIndex = i;
      }
    }

    try {
      await audioPlayer.setAudioSources(beatAudioSources,
          preload: true,
          initialIndex: initialIndex,
          shuffleOrder: DefaultShuffleOrder());
    } catch (e) {
      PrintLog('Failed to load mix "${mix.title}": $e');
      _currentBeatMix = null;
      return false;
    }

    mediaItem.add(beatMediaItems[initialIndex]);

    final startBeat = beats[initialIndex];
    _beatKey = startBeat.key;
    _currentBeat = startBeat;
    _progress = 0;
    _recordRecent(startBeat);
    return true;
  }

  Future<bool> togglePlay() async {
    _isPlaying = !_isPlaying;

    if (_isPlaying) {
      // play()'s future only completes when playback pauses or ends later,
      // awaiting it here would block the caller for the whole track
      unawaited(audioPlayer.play());
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

  void setRecentsChangedCallback(void Function() recentsChanged) {
    _recentsChanged = recentsChanged;
  }

  void updateProgress(Duration position) {
    final beat = _currentBeat;
    if (beat == null) return;

    // the player's decoded duration when known, catalog metadata while loading
    final totalMs =
        audioPlayer.duration?.inMilliseconds ?? beat.duration.inMilliseconds;
    if (totalMs == 0) {
      return;
    }

    // Set progress directly from the actual position
    _progress = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    // Callback so the UI gets updated with the correct data
    _updateProgress?.call(_progress, beat);
  }

  // The system (notification, headset, Android Auto) sends explicit play and
  // pause commands, these have to be idempotent instead of blind toggles.
  @override
  Future<void> play() async {
    if (!_isPlaying) await togglePlay();
  }

  @override
  Future<void> pause() async {
    if (_isPlaying) await togglePlay();
  }

  @override
  Future<void> stop() async {
    await audioPlayer.stop();
    // let audio_service tear down the notification / foreground service
    await super.stop();
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
    // a manual skip means someone is awake, drop an end-of-track sleep
    if (_sleepEndOfTrack) _clearSleep();
    if (audioPlayer.hasNext) {
      await audioPlayer.seekToNext();
      _setCurrentBeat();
      _setMediaItemForBeat();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_sleepEndOfTrack) _clearSleep();
    if (audioPlayer.hasPrevious) {
      await audioPlayer.seekToPrevious();
      _setCurrentBeat();
      _setMediaItemForBeat();
    }
  }

  void _setCurrentBeat() {
    var id = _getCurrentAudioSourceTagId();
    if (id == "") return;

    // single beat playback has no mix to look tracks up in
    final beats = _currentBeatMix?.beats;
    if (beats == null) return;

    final index = beats.indexWhere((i) => i.key == id);
    if (index == -1) return;
    final currentBeat = beats[index];

    if (currentBeat.key != _currentBeat?.key) {
      _currentBeat = currentBeat;
      _beatKey = currentBeat.key;
      _progress = 0;
      _recordRecent(currentBeat);
      _updateProgress?.call(_progress, currentBeat);
    }
  }

  void _setMediaItemForBeat() {
    var id = _getCurrentAudioSourceTagId();
    if (id == "") return;

    final index = beatMediaItems.indexWhere((i) => i.id == id);
    if (index == -1) return;

    // only rebroadcast on an actual change, this runs on every player event
    if (mediaItem.valueOrNull?.id != id) {
      mediaItem.add(beatMediaItems[index]);
    }
  }

  String _getCurrentAudioSourceTagId() {
    var index = audioPlayer.currentIndex;
    if (index == null || index >= audioPlayer.audioSources.length) return "";
    var currentSource = audioPlayer.audioSources[index] as UriAudioSource;
    return currentSource.tag.toString();
  }

  // Play history, newest first. A replayed beat moves back to the top instead
  // of appearing twice, the oldest entry drops off past the cap. Persisted so
  // it survives an app restart.
  static const _maxRecents = 10;
  void _recordRecent(Beat beat) {
    _recentBeats.removeWhere((b) => b.key == beat.key);
    _recentBeats.insert(0, beat);
    if (_recentBeats.length > _maxRecents) _recentBeats.removeLast();
    unawaited(_historyStore.save(_recentBeats));
    _recentsChanged?.call();
  }

  /// Drops a beat that turned out unplayable from the history so it does
  /// not linger on the home screen. No-op when it is not in there.
  void removeRecent(String key) {
    final before = _recentBeats.length;
    _recentBeats.removeWhere((b) => b.key == key);
    if (_recentBeats.length == before) return;
    unawaited(_historyStore.save(_recentBeats));
    _recentsChanged?.call();
  }

  // Reload the persisted history on startup. Anything already played before
  // the load finished stays on top of the restored entries.
  Future<void> _restoreRecents() async {
    final stored = await _historyStore.load();
    if (stored.isEmpty) return;

    for (final beat in stored) {
      if (_recentBeats.any((b) => b.key == beat.key)) continue;
      if (_recentBeats.length >= _maxRecents) break;
      _recentBeats.add(beat);
    }
    _recentsChanged?.call();
  }

  // Helpers functions
  UriAudioSource _createSourceUri(Beat beat) {
    final local = localSourceResolver?.call(beat);
    return AudioSource.uri(
        local != null ? Uri.file(local) : mediaUri(beat.audioUrl!),
        tag: beat.key);
  }

  MediaItem _createMediaItem(Beat beat) => MediaItem(
      id: beat.key,
      album: beat.mixTitle ?? _currentBeatMix?.title,
      title: beat.title,
      // the notification's second line follows the app: owning mix, artist
      // fallback, nothing when it would repeat the title
      artist: beat.subtitle.isEmpty ? null : beat.subtitle,
      duration: beat.duration,
      artUri: beat.thumbnailUrl.isEmpty ? null : mediaUri(beat.thumbnailUrl));

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (audioPlayer.playing) MediaControl.pause else MediaControl.play,
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
