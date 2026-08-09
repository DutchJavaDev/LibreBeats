import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liberated_beats/config/helpers.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/catalog_cache_store.dart';
import 'package:liberated_beats/data/server_registry.dart';

import '../data/beatmix_repository.dart';
import '../models/beat_models.dart';

/// Loads the beatmix catalog from all servers, merged in random order.
/// Every server has its own 20 minute timer, expired ones are refreshed
/// silently in the background. In persistent mode (the default) the results
/// and timers are stored on disk and read back on the next startup.
class LibreProvider extends ChangeNotifier {
  LibreProvider(
    this._registry,
    this._beatMixRepository,
    this._beatRepository, {
    Duration cacheTtl = const Duration(minutes: 20),
    Duration dripInterval = const Duration(milliseconds: 200),
    Duration watchInterval = const Duration(seconds: 30),
    CatalogCacheStore? store,
  })  : _cacheTtl = cacheTtl,
        _dripInterval = dripInterval,
        _watchInterval = watchInterval,
        _store = store ?? CatalogCacheStore();

  final ServerRegistry _registry;
  final BeatMixRepository _beatMixRepository;
  final BeatRepository _beatRepository;
  final CatalogCacheStore _store;

  // injectable for tests
  final Duration _cacheTtl;
  final Duration _dripInterval;
  final Duration _watchInterval;

  final _random = Random();

  // results + fetch time per server url
  final Map<String, CachedServerCatalog> _cache = {};
  bool _persistent = true;
  bool _hydrated = false;

  List<BeatMix> _beatMixes = [];
  bool _isFetching = false;
  Timer? _dripTimer;
  Timer? _watchTimer;
  bool _updateNotice = false;

  List<BeatMix> get beatMixes => _beatMixes;

  bool get isFetching => _isFetching;

  bool get isLoading => _isFetching && _beatMixes.isEmpty;

  /// Disk cache on/off, switched from the search screen
  bool get persistentCache => _persistent;

  /// True after an automatic refresh replaced results while the user was
  /// looking at the search page, shown as a banner there
  bool get updateNotice => _updateNotice;

  void clearUpdateNotice() {
    if (!_updateNotice) return;
    _updateNotice = false;
    notifyListeners();
  }

  /// Called by the scaffold: true while the search tab is on screen and the
  /// app is foregrounded. Runs a periodic check so an expired cache refreshes
  /// itself while the user is watching, everywhere else stays lazy.
  void setSearchVisible(bool visible) {
    if (visible) {
      _watchTimer ??= Timer.periodic(_watchInterval, (_) => _autoRefresh());
    } else {
      _watchTimer?.cancel();
      _watchTimer = null;
    }
  }

  Future<void> _autoRefresh() async {
    if (_isFetching) return;
    // empty grid means the first load never got content, retry the normal way
    if (_beatMixes.isEmpty) return ensureCatalog();

    final stale =
        _registry.healthy.where((s) => _expired(_cache[s.url])).toList();
    if (stale.isEmpty) return;

    _isFetching = true;
    try {
      final refreshed = await _fetchServers(stale);
      if (refreshed > 0) {
        final merged = _merged();
        if (merged.isNotEmpty) {
          merged.shuffle(_random);
          _beatMixes = merged;
        }
        _updateNotice = true;
        if (_persistent) await _store.save(_cache);
      }
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  bool get isConnected => _beatMixRepository.isConnected;

  bool _expired(CachedServerCatalog? entry) =>
      entry == null || DateTime.now().difference(entry.fetchedAt) > _cacheTtl;

  Future<void> setPersistentCache(bool value) async {
    if (_persistent == value) return;
    _persistent = value;
    await _store.savePersistentMode(value);
    if (value) {
      await _store.save(_cache);
    } else {
      await _store.clear();
    }
    notifyListeners();
  }

  // Called when the search tab is opened. Serves cached results per server
  // and only fetches the ones whose timer ran out.
  Future<void> ensureCatalog() async {
    if (_isFetching) return;
    _isFetching = true;
    _updateNotice = false; // navigating here counts as seeing the update
    notifyListeners();

    try {
      await _hydrate();
      await _registry.connectAll();
      // retry failed servers here too, otherwise an all-servers-down start
      // can never recover
      await _registry.reconnectFailed();

      // forget servers that were removed in settings
      _cache
          .removeWhere((url, _) => !_registry.servers.any((s) => s.url == url));

      // cold start with nothing at all -> drip mode later
      final dripMode = _beatMixes.isEmpty && _cache.isEmpty;

      // disk cache had content, show it right away (even if expired,
      // stale beats an empty grid while the refresh runs)
      if (_beatMixes.isEmpty && _cache.isNotEmpty) {
        _beatMixes = _merged()..shuffle(_random);
        notifyListeners();
      }

      final stale =
          _registry.healthy.where((s) => _expired(_cache[s.url])).toList();
      if (stale.isEmpty) return;

      if (dripMode) {
        await _dripLoad(stale);
      } else {
        await _fetchServers(stale);
        final merged = _merged();
        if (merged.isNotEmpty) {
          merged.shuffle(_random);
          _beatMixes = merged;
        }
      }

      if (_persistent) await _store.save(_cache);
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    _persistent = await _store.loadPersistentMode();
    if (_persistent) {
      _cache.addAll(await _store.load());
    }
  }

  // First ever load, trickle the mixes into the list one at a time
  Future<void> _dripLoad(List<ServerConnection> servers) async {
    final pending = <BeatMix>[];
    final fetches = _fetchServers(servers, onBatch: pending.addAll);

    _dripTimer?.cancel();
    _dripTimer = Timer.periodic(_dripInterval, (_) {
      if (pending.isEmpty) return;
      final mix = pending.removeAt(_random.nextInt(pending.length));
      _beatMixes.insert(_random.nextInt(_beatMixes.length + 1), mix);
      notifyListeners();
    });

    await fetches;

    // let the timer drain whatever is still pending
    while (pending.isNotEmpty && _dripTimer != null) {
      await Future.delayed(_dripInterval);
    }

    _dripTimer?.cancel();
    _dripTimer = null;
  }

  // Call the menu function on the given servers in parallel, returns how many
  // succeeded. A server that fails keeps its old entry, stale beats nothing.
  Future<int> _fetchServers(List<ServerConnection> servers,
      {void Function(List<BeatMix>)? onBatch}) async {
    var succeeded = 0;
    await Future.wait(servers.map((server) async {
      try {
        final batch = await _beatMixRepository.fetchMenuFromServer(server);
        _cache[server.url] =
            CachedServerCatalog(fetchedAt: DateTime.now(), mixes: batch);
        succeeded++;
        onBatch?.call(List.of(batch)..shuffle(_random));
      } catch (e) {
        PrintLog('menu fetch failed for ${server.host}: $e');
        _registry.markFailed(server);
      }
    }));
    return succeeded;
  }

  List<BeatMix> _merged() => [for (final e in _cache.values) ...e.mixes];

  // ---------------------------------------------------------------------------

  /// Searches the cached catalog first: beatmix titles and the titles of the
  /// beats embedded in them. Only when that finds nothing at all the healthy
  /// servers get queried live, beat and beatmix titles on the librebeats
  /// schema. Live results are shown but never stored in the cache. Cached
  /// beats remember which playlists they came from.
  Stream<SearchOutcome> findAllByTitle(String query) async* {
    final q = query.toLowerCase().trim();

    final localMixes =
        _beatMixes.where((m) => m.title.toLowerCase().contains(q)).toList();

    // same beat can sit in several cached mixes, key dedupes it but every
    // containing playlist is kept for the "in <playlist> +N" line
    final byKey = <String, (Beat, List<BeatMix>)>{};
    for (final mix in _beatMixes) {
      for (final beat in mix.beats ?? const <Beat>[]) {
        if (!beat.title.toLowerCase().contains(q)) continue;
        final entry = byKey[beat.key];
        if (entry == null) {
          byKey[beat.key] = (beat, [mix]);
        } else {
          entry.$2.add(mix);
        }
      }
    }

    if (byKey.isNotEmpty || localMixes.isNotEmpty) {
      DateTime? oldest;
      for (final entry in _cache.values) {
        if (oldest == null || entry.fetchedAt.isBefore(oldest)) {
          oldest = entry.fetchedAt;
        }
      }
      yield SearchOutcome(
        results: [
          for (final (beat, mixes) in byKey.values)
            SearchResult(
                beat: beat, inMix: mixes.first, inMixCount: mixes.length),
          for (final mix in localMixes) SearchResult(beatMix: mix),
        ],
        cachedAt: oldest,
      );
      return;
    }

    // cache came up empty, ask the servers directly
    yield const SearchOutcome(results: [], live: true, searching: true);
    final beatsFuture = _beatRepository.findByTitle(query);
    final mixesFuture = _beatMixRepository.findByTitle(query);
    final beats = await beatsFuture;
    final mixes = await mixesFuture;

    yield SearchOutcome(
      results: [
        for (final beat in beats) SearchResult(beat: beat),
        for (final mix in mixes) SearchResult(beatMix: mix),
      ],
      live: true,
    );
  }

  @override
  void dispose() {
    _dripTimer?.cancel();
    _dripTimer = null;
    _watchTimer?.cancel();
    _watchTimer = null;
    super.dispose();
  }
}
