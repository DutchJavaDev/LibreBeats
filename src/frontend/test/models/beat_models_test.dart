import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/models/beat_models.dart';

void main() {
  Beat makeBeat(int id, String sourceId) => Beat(
        id: id,
        sourceId: sourceId,
        title: 'T',
        artist: 'A',
        duration: Duration.zero,
        color: sampleTracks.first.color,
      );

  test('beat key is sourceId:id', () {
    expect(makeBeat(7, 'https://a.example.com').key, 'https://a.example.com:7');
  });

  test('same id on two servers gives different keys', () {
    expect(makeBeat(1, 'server-a').key, isNot(makeBeat(1, 'server-b').key));
  });

  test('sample data uses the sample source', () {
    expect(sampleTracks.first.key, 'sample:1');
  });

  test('beatmix key works the same way', () {
    const mix = BeatMix(
        id: 3,
        sourceId: 'server-a',
        title: 'Mix',
        thumbnailUrl: '',
        trackCount: 0,
        beats: []);
    expect(mix.key, 'server-a:3');
  });

  test('sample track keys are unique', () {
    expect(sampleTracks.map((t) => t.key).toSet().length, sampleTracks.length);
  });

  test('only beats with a stream url are playable', () {
    // sample data has no audioUrl, playBeat skips those instead of crashing
    for (final t in sampleTracks) {
      expect(t.isPlayable, isFalse);
    }

    final streamed = Beat(
      id: 1,
      title: 'T',
      artist: 'A',
      duration: Duration.zero,
      color: sampleTracks.first.color,
      audioUrl: 'https://a/stream.mp3',
    );
    expect(streamed.isPlayable, isTrue);

    final empty = Beat(
      id: 2,
      title: 'T',
      artist: 'A',
      duration: Duration.zero,
      color: sampleTracks.first.color,
      audioUrl: '',
    );
    expect(empty.isPlayable, isFalse);
  });

  test('sample playlists all have a beats list', () {
    for (final mix in samplePlaylists) {
      expect(mix.beats, isNotNull);
    }
  });
}
