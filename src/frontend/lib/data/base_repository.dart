import 'package:liberated_beats/data/server_registry.dart';

class BaseRepository {
  BaseRepository(this.registry);

  final ServerRegistry registry;

  bool get isConnected => registry.healthy.isNotEmpty;
}
