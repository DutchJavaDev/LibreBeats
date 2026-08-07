import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/widgets/add_server_scan.dart';

void main() {
  test('parses a valid payload', () {
    expect(
        parseServerQrPayload(
            '{"url": "https://a.example.com", "key": "sb_publishable_x"}'),
        ('https://a.example.com', 'sb_publishable_x'));
    // whitespace gets trimmed, extra fields are fine
    expect(parseServerQrPayload('{"url": " https://a ", "key": " k "}'),
        ('https://a', 'k'));
    expect(
        parseServerQrPayload(
            '{"url": "https://a", "key": "k", "name": "My server", "v": 2}'),
        ('https://a', 'k'));
  });

  test('rejects missing or empty url/key', () {
    expect(parseServerQrPayload('{"url": "https://a"}'), isNull);
    expect(parseServerQrPayload('{"key": "k"}'), isNull);
    expect(parseServerQrPayload('{"url": "", "key": "k"}'), isNull);
    expect(parseServerQrPayload('{"url": "https://a", "key": ""}'), isNull);
  });

  test('rejects garbage without throwing', () {
    expect(parseServerQrPayload('hello world'), isNull);
    expect(parseServerQrPayload(''), isNull);
    expect(parseServerQrPayload('["https://a", "k"]'), isNull);
    expect(parseServerQrPayload('42'), isNull);
    expect(parseServerQrPayload('https://a.example.com'), isNull);
    expect(parseServerQrPayload('{"url": 1, "key": "k"}'), isNull);
    expect(parseServerQrPayload('{"url": "https://a", "key": null}'), isNull);
  });
}
