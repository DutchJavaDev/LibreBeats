import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/widgets/queue_sheet.dart';

void main() {
  test('shuffle off is the plain order, whatever the indices say', () {
    expect(playbackOrder(3, [2, 0, 1], false), [0, 1, 2]);
    expect(playbackOrder(0, [], false), isEmpty);
  });

  test('shuffle on returns the traversal order', () {
    expect(playbackOrder(3, [2, 0, 1], true), [2, 0, 1]);
    expect(playbackOrder(1, [0], true), [0]);
  });

  test('indices that do not fit the queue fall back to plain order', () {
    expect(playbackOrder(3, [0, 1], true), [0, 1, 2]); // too short
    expect(playbackOrder(3, [0, 1, 3], true), [0, 1, 2]); // out of range
    expect(playbackOrder(2, [-1, 0], true), [0, 1]);
    expect(playbackOrder(0, [0], true), isEmpty);
  });
}
