import 'package:liberated_beats/data/server_registry.dart';

/// Shared base for repositories: access to the multi-server [ServerRegistry].
class BaseRepository {
  BaseRepository(this.registry);

  final ServerRegistry registry;

  /// Whether at least one server is signed in and reachable.
  bool get isConnected => registry.healthy.isNotEmpty;
}
