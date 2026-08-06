import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:liberated_beats/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ServerStatus { connecting, healthy, failed }

/// One registered Supabase source: its connection settings, the signed-in
/// client (once available), and its current health.
class ServerConnection {
  ServerConnection({required this.url, required this.key});

  final String url;
  final String key;

  SupabaseClient? client;
  ServerStatus status = ServerStatus.connecting;

  String get host => Uri.tryParse(url)?.host ?? url;
}

/// Registry of Supabase servers ("sources"). Servers added in Settings are
/// persisted via shared_preferences and reconnected on the next startup.
///
/// Notifies listeners whenever a server is added/removed or a status changes,
/// so the Settings page can render live status dots.
class ServerRegistry extends ChangeNotifier {
  // DEVELOPMENT ONLY — every server is assumed to accept this one account.
  // Supplied via --dart-define so no credential ever lands in git:
  //   flutter run --dart-define=LIBREBEATS_DEV_EMAIL=you@example.com \
  //               --dart-define=LIBREBEATS_DEV_PASSWORD=yourpassword
  static const String devEmail =
      String.fromEnvironment('LIBREBEATS_DEV_EMAIL');
  static const String devPassword =
      String.fromEnvironment('LIBREBEATS_DEV_PASSWORD');

  static const _prefsKey = 'librebeats_servers';

  final List<ServerConnection> _servers = [];
  Future<void>? _connectAllFuture;

  List<ServerConnection> get servers => List.unmodifiable(_servers);

  List<ServerConnection> get healthy =>
      _servers.where((s) => s.status == ServerStatus.healthy).toList();

  /// Loads the persisted server list, or [seed] on a fresh install. Fast —
  /// does not touch the network; call [connectAll] afterwards to sign in.
  Future<void> load({List<(String, String)> seed = const []}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    var entries = seed;
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      entries = [
        for (final e in list) (e['url'] as String, e['key'] as String),
      ];
    }

    for (final (url, key) in entries) {
      _servers.add(ServerConnection(url: url, key: key));
    }

    await _persist();
    notifyListeners();
  }

  /// Signs in to every registered server in parallel. Memoized: repeat calls
  /// (e.g. the catalog waiting on startup sign-ins) share the same future.
  Future<void> connectAll() {
    return _connectAllFuture ??=
        Future.wait(_servers.map(_connect)).then((_) => notifyListeners());
  }

  /// Validates [url]/[key] by actually signing in; the server is only kept
  /// (and persisted) when the sign-in succeeds.
  Future<bool> addServer(String url, String key) async {
    if (_servers.any((s) => s.url == url)) return false;

    final server = ServerConnection(url: url, key: key);
    _servers.add(server);
    notifyListeners(); // show the "connecting" row immediately

    await _connect(server);

    if (server.status == ServerStatus.healthy) {
      await _persist();
      notifyListeners();
      return true;
    }

    _servers.remove(server);
    notifyListeners();
    return false;
  }

  Future<void> removeServer(ServerConnection server) async {
    _servers.remove(server);
    await _persist();
    notifyListeners();
  }

  /// Called when a fetch against [server] fails — flips its status dot.
  void markFailed(ServerConnection server) {
    server.status = ServerStatus.failed;
    notifyListeners();
  }

  /// Re-attempts sign-in for servers that previously failed. Used by the
  /// catalog's TTL refresh so a recovered server rejoins the pool.
  Future<void> reconnectFailed() async {
    final failed =
        _servers.where((s) => s.status == ServerStatus.failed).toList();
    if (failed.isEmpty) return;
    await Future.wait(failed.map(_connect));
    notifyListeners();
  }

  Future<void> _connect(ServerConnection server) async {
    server.status = ServerStatus.connecting;
    try {
      final client = server.client ?? SupabaseClient(server.url, server.key);
      final response = await client.auth
          .signInWithPassword(email: devEmail, password: devPassword);

      if (response.user != null) {
        server.client = client;
        server.status = ServerStatus.healthy;
        PrintLog('Signed in to ${server.host} as ${response.user!.email}');
      } else {
        server.status = ServerStatus.failed;
        PrintLog('Sign-in to ${server.host} returned no user');
      }
    } catch (e) {
      server.status = ServerStatus.failed;
      PrintLog('Failed to connect to ${server.host}: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([
        for (final s in _servers) {'url': s.url, 'key': s.key},
      ]),
    );
  }
}
