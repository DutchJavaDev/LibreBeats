import 'package:liberated_beats/models/beat_models.dart';

class PlayState {
  Beat? currentPlayingBeat;
  Duration? currentDuration;
  BeatMix? currentBeatMix;
  List<Beat?> currentQueue = [];
  double? currentVolume;

  PlayState(
      {required this.currentPlayingBeat,
      required this.currentDuration,
      required this.currentBeatMix,
      required this.currentQueue,
      required this.currentVolume});
}
