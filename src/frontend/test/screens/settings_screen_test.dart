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
      Set<String> failing = const {}}) async {
    final registry = ServerRegistry(connector: (server) async {
      server.status = failing.contains(server.url)
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

  testWidgets('lists servers with host and status', (tester) async {
    await pumpSettings(tester, seed: const [
      ('https://a.example.com', 'k1'),
      ('https://b.example.com', 'k2'),
    ], failing: {
      'https://b.example.com'
    });

    expect(find.text('a.example.com'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('b.example.com'), findsOneWidget);
    expect(find.text('Unreachable'), findsOneWidget);
  });

  testWidgets('has the add server entry', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Add server'), findsOneWidget);
    expect(find.text('Scan a server QR code'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });

  testWidgets('delete removes the server', (tester) async {
    final registry = await pumpSettings(tester,
        seed: const [('https://a.example.com', 'k1')]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(registry.servers, isEmpty);
    expect(find.text('a.example.com'), findsNothing);
  });

  testWidgets('status updates when a server fails', (tester) async {
    final registry = await pumpSettings(tester,
        seed: const [('https://a.example.com', 'k1')]);
    expect(find.text('Connected'), findsOneWidget);

    registry.markFailed(registry.servers.first);
    await tester.pump();

    expect(find.text('Connected'), findsNothing);
    expect(find.text('Unreachable'), findsOneWidget);
  });
}
