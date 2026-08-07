import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ServerRegistry> pumpSettings(WidgetTester tester,
      {List<(String, String)> seed = const [],
      Set<String>? failing}) async {
    final fails = failing ?? {};
    final registry = ServerRegistry(connector: (server) async {
      server.status = fails.contains(server.url)
          ? ServerStatus.failed
          : ServerStatus.healthy;
    });
    await registry.load(seed: seed);
    await registry.connectAll();

    await tester.pumpWidget(
      ChangeNotifierProvider<ServerRegistry>.value(
        value: registry,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    return registry;
  }

  testWidgets('collapsed summary shows the fleet state, no rows', (tester) async {
    final registry = await pumpSettings(tester, seed: const [
      ('https://a.example.com', 'k1'),
      ('https://b.example.com', 'k2'),
    ], failing: {
      'https://b.example.com'
    });

    // without a default login the summary nudges towards setting one
    expect(find.text('No default login set'), findsOneWidget);

    await registry.setDefaultCredentials('me@example.com', 'pw');
    await tester.pump();
    expect(find.text('1 of 2 connected'), findsOneWidget);
    // servers stay hidden until expanded
    expect(find.text('a.example.com'), findsNothing);
    expect(find.text('b.example.com'), findsNothing);
  });

  testWidgets('expanding groups servers with problems on top', (tester) async {
    await pumpSettings(tester, seed: const [
      ('https://a.example.com', 'k1'),
      ('https://b.example.com', 'k2'),
    ], failing: {
      'https://b.example.com'
    });

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();

    expect(find.text('UNREACHABLE (1)'), findsOneWidget);
    expect(find.text('CONNECTED (1)'), findsOneWidget);
    // failed server is listed above the healthy one
    expect(tester.getTopLeft(find.text('b.example.com')).dy,
        lessThan(tester.getTopLeft(find.text('a.example.com')).dy));
  });

  testWidgets('retry all reconnects failed servers', (tester) async {
    final failing = {'https://b.example.com'};
    final registry = await pumpSettings(tester, seed: const [
      ('https://a.example.com', 'k1'),
      ('https://b.example.com', 'k2'),
    ], failing: failing);

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();

    failing.clear(); // server came back
    await tester.tap(find.text('Retry all'));
    await tester.pumpAndSettle();

    expect(registry.healthy, hasLength(2));
    expect(find.text('UNREACHABLE (1)'), findsNothing);
  });

  testWidgets('remove goes through the detail sheet with confirm',
      (tester) async {
    final registry = await pumpSettings(tester,
        seed: const [('https://a.example.com', 'k1')]);

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('a.example.com'));
    await tester.pumpAndSettle();

    // detail sheet shows the full url
    expect(find.text('https://a.example.com'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // cancel first, nothing happens
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(registry.servers, hasLength(1));

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last); // confirm
    await tester.pumpAndSettle();

    expect(registry.servers, isEmpty);
  });

  testWidgets('default login can be edited from the servers section',
      (tester) async {
    final registry = await pumpSettings(tester,
        seed: const [('https://a.example.com', 'k1')]);

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();
    // nothing baked in, the section nudges towards setting it up
    expect(find.text('Not set, servers need this to sign in'), findsOneWidget);

    await tester.tap(find.text('Default login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'hunter2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(registry.defaultEmail, 'me@example.com');
    expect(registry.defaultPassword, 'hunter2');
    expect(find.text('me@example.com'), findsOneWidget);
  });

  testWidgets('filter shows up for long lists and narrows them',
      (tester) async {
    await pumpSettings(tester, seed: [
      for (var i = 1; i <= 9; i++) ('https://server$i.example.com', 'k$i'),
    ]);

    await tester.tap(find.text('Servers').last);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('server3.example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'server3');
    await tester.pumpAndSettle();

    expect(find.text('server3.example.com'), findsOneWidget);
    expect(find.text('server5.example.com'), findsNothing);
  });
}
