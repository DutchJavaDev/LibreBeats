import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/widgets/add_server_scan.dart';

void main() {
  test('parses a single server payload', () {
    expect(
        parseServerQrPayload(
            '{"url": "https://a.example.com", "key": "sb_publishable_x"}'),
        [('https://a.example.com', 'sb_publishable_x', null, null)]);
    // whitespace gets trimmed, extra fields are fine
    expect(parseServerQrPayload('{"url": " https://a ", "key": " k "}'),
        [('https://a', 'k', null, null)]);
    expect(
        parseServerQrPayload(
            '{"url": "https://a", "key": "k", "name": "My server", "v": 2}'),
        [('https://a', 'k', null, null)]);
  });

  test('parses a list of servers from one code', () {
    expect(
        parseServerQrPayload(
            '[{"url": "https://a", "key": "k1"}, {"url": "https://b", "key": "k2"}]'),
        [('https://a', 'k1', null, null), ('https://b', 'k2', null, null)]);
    // one bad entry rejects the whole code
    expect(
        parseServerQrPayload('[{"url": "https://a", "key": "k1"}, {"url": ""}]'),
        isNull);
    expect(parseServerQrPayload('[]'), isNull);
  });

  test('entries can carry their own login', () {
    expect(
        parseServerQrPayload(
            '{"url": "https://a", "key": "k", "email": "me@example.com", "password": "pw"}'),
        [('https://a', 'k', 'me@example.com', 'pw')]);
    // empty login fields count as not set
    expect(
        parseServerQrPayload(
            '{"url": "https://a", "key": "k", "email": "", "password": ""}'),
        [('https://a', 'k', null, null)]);
    // mixed list, one with login one without
    expect(
        parseServerQrPayload(
            '[{"url": "https://a", "key": "k1", "email": "x@y.z", "password": "p"}, {"url": "https://b", "key": "k2"}]'),
        [('https://a', 'k1', 'x@y.z', 'p'), ('https://b', 'k2', null, null)]);
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
    expect(parseServerQrPayload('{"url": "https://a", "key": "k", "email": 5}'),
        isNull);
  });
}
