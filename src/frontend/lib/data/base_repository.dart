import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class BaseRepository {
  /// The Supabase client — available only after `Supabase.initialize` has run,
  /// i.e. when [SupabaseConfig.isConfigured] is true. The fake-data path below
  /// never touches it; it is used by the real queries (commented out).
  SupabaseClient? get client =>
      SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  /// Whether a live Supabase connection is available.
  bool get isConnected => client != null;
}