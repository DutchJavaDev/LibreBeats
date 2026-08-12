import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ServerStatus { connecting, healthy, failed }

enum AddServerResult { added, duplicate, signInFailed }

class ServerConnection {
  ServerConnection({required this.url, required this.key, this.email, this.password});

  final String url;
  final String key;

  // per server login override, null means use the registry default
  String? email;
  String? password;

  SupabaseClient? client;
  ServerStatus status = ServerStatus.connecting;

  // why the last sign in failed, shown in the server detail sheet
  String? lastError;

  // when it went unreachable, shown as "2m ago" in the server list
  DateTime? failedAt;

  String get host => Uri.tryParse(url)?.host ?? url;
}

// injectable for tests
typedef ServerConnector = Future<void> Function(ServerConnection server);

// injectable for tests, the cheap liveness check behind checkHealth
typedef ServerProbe = Future<void> Function(ServerConnection server);

/// Keeps track of all supabase servers, persisted with shared_preferences
class ServerRegistry extends ChangeNotifier {
  ServerRegistry(
      {ServerConnector? connector,
      ServerProbe? probe,
      Duration checkTimeout = const Duration(seconds: 10)})
      : _checkTimeout = checkTimeout {
    _connector = connector ?? _defaultConnect;
    _probe = probe ?? _defaultProbe;
  }

  late final ServerConnector _connector;
  late final ServerProbe _probe;

  /// Hard cap on one server's health check. The sign-in has no timeout of
  /// its own, and a single hung request must not wedge checkHealth forever.
  final Duration _checkTimeout;

  // No login ships in the app. Release builds start empty and the default
  // login is set up in settings on first run (or arrives via a QR that
  // includes logins). Dev builds can bake one in with a git-ignored env.json:
  //   flutter run --dart-define-from-file=env.json
  static const String fallbackEmail =
      String.fromEnvironment('LIBREBEATS_DEV_EMAIL');
  static const String fallbackPassword =
      String.fromEnvironment('LIBREBEATS_DEV_PASSWORD');

  static const _prefsKey = 'librebeats_servers';
  static const _emailKey = 'librebeats_default_email';
  static const _passwordKey = 'librebeats_default_password';

  String _defaultEmail = fallbackEmail;
  String _defaultPassword = fallbackPassword;

  String get defaultEmail => _defaultEmail;
  String get defaultPassword => _defaultPassword;

  bool get hasDefaultLogin =>
      _defaultEmail.isNotEmpty && _defaultPassword.isNotEmpty;

  // the login a server actually signs in with
  (String, String) credentialsFor(ServerConnection server) =>
      (server.email ?? _defaultEmail, server.password ?? _defaultPassword);

  final List<ServerConnection> _servers = [];
  Future<void>? _connectAllFuture;

  List<ServerConnection> get servers => List.unmodifiable(_servers);

  List<ServerConnection> get healthy =>
      _servers.where((s) => s.status == ServerStatus.healthy).toList();

  // Load persisted servers ([seed] on first run), connectAll() does the sign in
  Future<void> load({List<(String, String)> seed = const []}) async {
    final prefs = await SharedPreferences.getInstance();

    _defaultEmail = prefs.getString(_emailKey) ?? fallbackEmail;
    _defaultPassword = prefs.getString(_passwordKey) ?? fallbackPassword;

    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final e in list) {
        _servers.add(ServerConnection(
          url: e['url'] as String,
          key: e['key'] as String,
          email: e['email'] as String?,
          password: e['password'] as String?,
        ));
      }
    } else {
      for (final (url, key) in seed) {
        _servers.add(ServerConnection(url: url, key: key));
      }
      // only write back when the seed was actually used, normal startups
      // should not touch disk here
      if (_servers.isNotEmpty) await _persist();
    }
    notifyListeners();
  }

  Future<void> setDefaultCredentials(String email, String password) async {
    _defaultEmail = email;
    _defaultPassword = password;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
    await prefs.setString(_passwordKey, password);

    notifyListeners();
    // servers that failed on the old login get another chance right away
    await reconnectFailed();
  }

  // Empty email/password clears the override so the server uses the default
  Future<void> setServerCredentials(ServerConnection server,
      {String? email, String? password}) async {
    server.email = (email == null || email.isEmpty) ? null : email;
    server.password = (password == null || password.isEmpty) ? null : password;
    await _persist();
    await reconnect(server);
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
    // the startup sign-in doubles as the first health check
    return _connectAllFuture ??= Future.wait(_servers.map(_connector)).then((_) {
      _lastCheckedAt = DateTime.now();
      notifyListeners();
    });
  }

  /// When the fleet's health was last verified, shown on the home screen
  /// digest. Null until the first check finishes.
  DateTime? get lastCheckedAt => _lastCheckedAt;
  DateTime? _lastCheckedAt;

  bool _checkingHealth = false;
  static const _minCheckInterval = Duration(seconds: 60);

  /// Re-verifies every server with a cheap probe: failed servers get a
  /// chance to recover, healthy ones that went away get flagged. Throttled
  /// to once a minute so revisiting the home tab does not hammer the fleet.
  /// Never touches connectAll's memoised future.
  Future<void> checkHealth({bool force = false}) async {
    if (_servers.isEmpty || _checkingHealth) return;
    if (!force &&
        _lastCheckedAt != null &&
        DateTime.now().difference(_lastCheckedAt!) < _minCheckInterval) {
      return;
    }

    // connecting means the startup sign-in is still busy, leave it alone
    final targets =
        _servers.where((s) => s.status != ServerStatus.connecting).toList();
    if (targets.isEmpty) return;

    _checkingHealth = true;
    try {
      // healthy servers get the cheap probe. Failed ones (and servers that
      // never signed in, which have no client to probe with) get a fresh
      // sign-in: that also repairs a session the server has revoked, which
      // a probe with the dead client never could. The timeout keeps one
      // hung request from wedging every future check.
      await Future.wait(targets.map((s) =>
          (s.client == null || s.status == ServerStatus.failed
                  ? _connector(s)
                  : _probe(s))
              .timeout(_checkTimeout, onTimeout: () {})));
      _lastCheckedAt = DateTime.now();
    } finally {
      _checkingHealth = false;
      notifyListeners();
    }
  }

  // One tiny authenticated select, exercising the whole path the app
  // depends on (gateway, PostgREST, the database) without the weight of a
  // full sign-in or a menu fetch.
  Future<void> _defaultProbe(ServerConnection server) async {
    // a probe can take seconds; if something else (reconnect, markFailed)
    // moved the server meanwhile, that result is fresher than this one
    final statusBefore = server.status;
    try {
      await server.client!
          .schema('librebeats')
          .from('beatmix')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      if (server.status != statusBefore) return;
      server.status = ServerStatus.healthy;
      server.lastError = null;
      server.failedAt = null;
    } catch (e) {
      if (server.status != statusBefore) return;
      server.status = ServerStatus.failed;
      server.failedAt ??= DateTime.now();
      server.lastError = '$e';
      PrintLog('Health probe failed for ${server.host}: $e');
    }
  }

  // Only kept + persisted when the sign in works. A QR code can carry its
  // own login for the server, otherwise the default is used.
  Future<AddServerResult> addServer(String url, String key,
      {String? email, String? password}) async {
    if (_servers.any((s) => s.url == url)) return AddServerResult.duplicate;

    final server = ServerConnection(
      url: url,
      key: key,
      email: (email == null || email.isEmpty) ? null : email,
      password: (password == null || password.isEmpty) ? null : password,
    );
    _servers.add(server);
    notifyListeners();

    await _connector(server);

    if (server.status == ServerStatus.healthy) {
      await _persist();
      notifyListeners();
      return AddServerResult.added;
    }

    _servers.remove(server);
    notifyListeners();
    return AddServerResult.signInFailed;
  }

  Future<void> removeServer(ServerConnection server) async {
    _servers.remove(server);
    await _persist();
    notifyListeners();
  }

  void markFailed(ServerConnection server) {
    server.status = ServerStatus.failed;
    server.failedAt ??= DateTime.now();
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

    final (email, password) = credentialsFor(server);
    if (email.isEmpty || password.isEmpty) {
      server.status = ServerStatus.failed;
      server.failedAt = DateTime.now();
      server.lastError = 'no login set, set the default login in settings';
      PrintLog('No login for ${server.host}, default login not set');
      return;
    }

    try {
      final client = server.client ?? SupabaseClient(server.url, server.key);
      final response = await client.auth
          .signInWithPassword(email: email, password: password);

      if (response.user != null) {
        server.client = client;
        server.status = ServerStatus.healthy;
        server.lastError = null;
        server.failedAt = null;
        PrintLog('Signed in to ${server.host} as ${response.user!.email}');
      } else {
        server.status = ServerStatus.failed;
        server.failedAt = DateTime.now();
        server.lastError = 'sign in returned no user';
        PrintLog('Sign-in to ${server.host} returned no user');
      }
    } catch (e) {
      server.status = ServerStatus.failed;
      server.failedAt = DateTime.now();
      server.lastError = '$e';
      PrintLog('Failed to connect to ${server.host}: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([
        for (final s in _servers)
          {
            'url': s.url,
            'key': s.key,
            if (s.email != null) 'email': s.email,
            if (s.password != null) 'password': s.password,
          },
      ]),
    );
  }
}
