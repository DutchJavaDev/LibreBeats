/// Supabase connection settings.
///
/// Replace the placeholders below with your project's credentials from the
/// Supabase dashboard (Project Settings → API). For the self-hosted stack in
/// `src/backend`, use your gateway URL and the anon key.
///
/// While the placeholders are unchanged, [isConfigured] returns `false`: the app
/// skips `Supabase.initialize` and the repository serves fake data, so it still
/// runs end-to-end without a backend.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// True only when real (non-placeholder) credentials have been provided.
  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      url != 'YOUR_SUPABASE_URL' &&
      anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
