import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/widgets/search_result_tile.dart';

void main() {
  String plain(List<dynamic> spans) =>
      spans.map((s) => s.text as String).join();

  test('no query or no match keeps the text in one span', () {
    expect(matchSpans('Night Drive', '').single.text, 'Night Drive');
    expect(matchSpans('Night Drive', 'zzz').single.text, 'Night Drive');
  });

  test('tints the first case-insensitive match', () {
    final spans = matchSpans('Midnight City', 'night');
    expect(spans, hasLength(3));
    expect(spans[0].text, 'Mid');
    expect(spans[1].text, 'night');
    expect(spans[1].style?.color, isNotNull);
    expect(spans[2].text, ' City');
    expect(plain(spans), 'Midnight City');
  });

  test('match at the start and end has no empty spans', () {
    expect(matchSpans('Night Drive', 'night').first.text, 'Night');
    expect(matchSpans('Good Night', 'night').last.text, 'Night');
    for (final spans in [
      matchSpans('Night Drive', 'night'),
      matchSpans('Good Night', 'night'),
    ]) {
      expect(spans.every((s) => s.text!.isNotEmpty), isTrue);
    }
  });
}
