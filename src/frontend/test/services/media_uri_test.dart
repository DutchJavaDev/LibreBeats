import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/services/audio_playback_service.dart';

void main() {
  test('http urls stay network uris', () {
    final uri = mediaUri('https://a.example.com/audio/1.opus');
    expect(uri.scheme, 'https');
    expect(uri.host, 'a.example.com');
  });

  test('plain paths become file uris', () {
    final uri = mediaUri('/data/user/0/app/offline/tracks/aa_1.opus');
    expect(uri.scheme, 'file');
    expect(uri.path, endsWith('aa_1.opus'));
  });
}
