import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ServerStatus { connecting, healthy, failed }

class ServerConnection {
  ServerConnection({required this.url, required this.key});

  final String url;
  final String key;

  SupabaseClient? client;
  ServerStatus status = ServerStatus.connecting;

  String get host => Uri.tryParse(url)?.host ?? url;
}

// injectable for tests
typedef ServerConnector = Future<void> Function(ServerConnection server);

/// Keeps track of all supabase servers, persisted with shared_preferences
class ServerRegistry extends ChangeNotifier {
  ServerRegistry({ServerConnector? connector}) {
    _connector = connector ?? _defaultConnect;
  }

  late final ServerConnector _connector;

  // DEVELOPMENT ONLY, same account on every server for now
  // pass with --dart-define=LIBREBEATS_DEV_EMAIL / LIBREBEATS_DEV_PASSWORD
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

  // Load persisted servers ([seed] on first run), connectAll() does the sign in
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

    // only write back when the seed was actually used, normal startups
    // should not touch disk here
    if (raw == null && _servers.isNotEmpty) {
      await _persist();
    }
    notifyListeners();
  }

  // "url1,url2" + "key1,key2" -> [(url1, key1), (url2, key2)]
  static List<(String, String)> parseSeedList(String urls, String keys) {
    if (urls.isEmpty || keys.isEmpty) return const [];

    final urlList = urls.split(',');
    final keyList = keys.split(',');
    final count =
        urlList.length < keyList.length ? urlList.length : keyList.length;

    return [
      for (var i = 0; i < count; i++) (urlList[i].trim(), keyList[i].trim()),
    ];
  }

  // Sign in to every server, repeat calls share the same future
  Future<void> connectAll() {
    return _connectAllFuture ??=
        Future.wait(_servers.map(_connector)).then((_) => notifyListeners());
  }

  // Only kept + persisted when the sign in works
  Future<bool> addServer(String url, String key) async {
    if (_servers.any((s) => s.url == url)) return false;

    final server = ServerConnection(url: url, key: key);
    _servers.add(server);
    notifyListeners();

    await _connector(server);

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

  void markFailed(ServerConnection server) {
    server.status = ServerStatus.failed;
    notifyListeners();
  }

  // Retry a single server, used by the servers screen
  Future<void> reconnect(ServerConnection server) async {
    server.status = ServerStatus.connecting;
    notifyListeners();
    await _connector(server);
    notifyListeners();
  }

  // Retry sign-in for failed servers so they can rejoin
  Future<void> reconnectFailed() async {
    final failed =
        _servers.where((s) => s.status == ServerStatus.failed).toList();
    if (failed.isEmpty) return;
    await Future.wait(failed.map(_connector));
    notifyListeners();
  }

  Future<void> _defaultConnect(ServerConnection server) async {
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
