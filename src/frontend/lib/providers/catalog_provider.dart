import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:liberated_beats/data/beat_repository.dart';
import 'package:liberated_beats/data/server_registry.dart';
import 'package:liberated_beats/main.dart';

import '../data/beatmix_repository.dart';
import '../models/beat_models.dart';

/// Loads the BeatMix catalog from every registered server, merges the results
/// in random order, and caches them for [_cacheTtl].
///
/// The first load per app run drips tiles into the grid one at a time (the
/// deliberate slow-load effect); once the TTL passes, the next visit keeps
/// showing the stale grid, refetches in the background from the servers that
/// still respond, and swaps the list in silently.
class LibreProvider extends ChangeNotifier {
  LibreProvider(this._registry, this._beatMixRepository, this._beatRepository);

  final ServerRegistry _registry;
  final BeatMixRepository _beatMixRepository;
  final BeatRepository _beatRepository;

  static const _cacheTtl = Duration(minutes: 20);
  static const _dripInterval = Duration(milliseconds: 200);

  final _random = Random();

  List<BeatMix> _beatMixes = [];
  DateTime? _fetchedAt;
  bool _isFetching = false;
  Timer? _dripTimer;

  List<BeatMix> get beatMixes => _beatMixes;

  /// True while a fetch is running (drip load or background refresh).
  bool get isFetching => _isFetching;

  /// True during the initial load, before anything is visible.
  bool get isLoading => _isFetching && _beatMixes.isEmpty;

  /// Kept for the Home screen's albums row (no album source yet).
  List<Album> get albums => const [];

  /// Whether at least one server is signed in and reachable.
  bool get isConnected => _beatMixRepository.isConnected;

  bool get _isStale =>
      _fetchedAt == null || DateTime.now().difference(_fetchedAt!) > _cacheTtl;

  /// Call whenever the Search tab is opened. Fetches on the first visit,
  /// serves the cache while fresh, and silently refreshes once the TTL passed.
  Future<void> ensureCatalog() async {
    if (_isFetching || !_isStale) return;
    _isFetching = true;
    notifyListeners();

    try {
      // Wait for the startup sign-ins before the first fetch (memoized).
      await _registry.connectAll();

      if (_beatMixes.isEmpty) {
        await _dripLoad();
      } else {
        await _silentRefresh();
      }

      if (_beatMixes.isNotEmpty) {
        // An all-servers-down first load stays stale so the next visit retries
        // instead of showing an empty grid for 20 minutes.
        _fetchedAt = DateTime.now();
      }
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  /// First load: fetch every server in parallel, then trickle the collected
  /// mixes into the visible list one tile at a time at [_dripInterval].
  Future<void> _dripLoad() async {
    final pending = <BeatMix>[];
    final fetches = _fetchAllServers(onBatch: pending.addAll);

    _dripTimer?.cancel();
    _dripTimer = Timer.periodic(_dripInterval, (_) {
      if (pending.isEmpty) return;
      final mix = pending.removeAt(_random.nextInt(pending.length));
      _beatMixes.insert(_random.nextInt(_beatMixes.length + 1), mix);
      notifyListeners();
    });

    await fetches;

    // Let the timer drain whatever is still pending (bail out if disposed).
    while (pending.isNotEmpty && _dripTimer != null) {
      await Future.delayed(_dripInterval);
    }

    _dripTimer?.cancel();
    _dripTimer = null;
  }

  /// TTL refresh: keep showing the stale list, rebuild off-screen from the
  /// servers that still work, and swap once — no loading state replay.
  Future<void> _silentRefresh() async {
    // Give previously failed servers a chance to rejoin the pool.
    await _registry.reconnectFailed();

    final fresh = <BeatMix>[];
    await _fetchAllServers(onBatch: fresh.addAll);

    if (fresh.isEmpty) return; // every server failed — keep the stale results

    fresh.shuffle(_random);
    _beatMixes = fresh;
  }

  /// Invokes the `menu` Edge Function on every healthy server in parallel.
  /// A failing server is marked failed in the registry and contributes
  /// nothing; the others still deliver.
  Future<void> _fetchAllServers(
      {required void Function(List<BeatMix>) onBatch}) {
    return Future.wait(_registry.healthy.map((server) async {
      try {
        final batch = await _beatMixRepository.fetchMenuFromServer(server);
        onBatch(batch..shuffle(_random));
      } catch (e) {
        PrintLog('menu fetch failed for ${server.host}: $e');
        _registry.markFailed(server);
      }
    }));
  }

  // ---------------------------------------------------------------------------

  /// Title search across the cached beatmixes and (server-side) beats.
  Stream<List<SearchResult>> findAllByTitle(String query) async* {
    final q = query.toLowerCase();

    final beats = await _beatRepository.findByTitle(query);
    final mixes =
        _beatMixes.where((m) => m.title.toLowerCase().contains(q)).toList();

    yield [
      for (final beat in beats) SearchResult(beat: beat),
      for (final mix in mixes) SearchResult(beatMix: mix),
    ];
  }

  @override
  void dispose() {
    _dripTimer?.cancel();
    _dripTimer = null;
    super.dispose();
  }
}
