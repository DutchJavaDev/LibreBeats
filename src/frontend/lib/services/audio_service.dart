import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:liberated_beats/models/beat_models.dart';

typedef DurationCallback = void Function(Duration position);

class AudioPlaybackHandler extends BaseAudioHandler with SeekHandler {
  AudioPlaybackHandler() {
    // So that our clients (the Flutter UI and the system notification) know
    // what state to display, here we set up our audio handler to broadcast all
    // playback state changes as they happen via playbackState...
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  final _player = AudioPlayer();

  void setAudioSource(Beat beat) async {
    await _player.setAudioSource(AudioSource.uri(Uri.parse(beat.audioUrl!)));
    
    mediaItem.add(MediaItem(
      id: beat.id.toString(),
      album: "None", // TODO fetch beatmix name with request (if any)
      title: beat.title,
      artist: beat.artist,
      duration: beat.duration,
      artUri: Uri.parse(beat.album),
    ));
  }

  void tickUpdater(DurationCallback onTick) {
    _player.positionStream.listen((position) {
      onTick(position);
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
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
}
