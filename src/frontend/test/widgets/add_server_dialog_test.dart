import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/widgets/add_server_scan.dart';

void main() {
  (String, String)? result;
  var completed = false;

  Future<void> openDialog(WidgetTester tester) async {
    result = null;
    completed = false;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<(String, String)>(
              context: context,
              builder: (_) => const AddServerDialog(),
            );
            completed = true;
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('submits trimmed url and key', (tester) async {
    await openDialog(tester);

    await tester.enterText(
        find.byType(TextField).at(0), '  https://x.example.com  ');
    await tester.enterText(find.byType(TextField).at(1), 'sb_publishable_abc');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result, ('https://x.example.com', 'sb_publishable_abc'));
  });

  testWidgets('add with empty fields does nothing', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Server URL'), findsOneWidget); // still open
    expect(completed, isFalse);
  });

  testWidgets('cancel returns null', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('no crash while the close animation runs', (tester) async {
    // regression: controllers used to get disposed before the route was gone
    await openDialog(tester);

    await tester.enterText(find.byType(TextField).at(0), 'https://a');
    await tester.enterText(find.byType(TextField).at(1), 'k');
    await tester.tap(find.text('Add'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, ('https://a', 'k'));
  });
}
