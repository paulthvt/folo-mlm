/// Supabase project coordinates for the client.
///
/// These are deliberately committed. The publishable key is designed to be
/// public and ships inside every binary anyway; Row Level Security is the
/// actual boundary. The service-role key never appears here, in the client, or
/// in any config file.
abstract final class SupabaseConfig {
  static const String url = 'https://cskjeqspecsyqioietrj.supabase.co';

  /// Modern publishable key, not the legacy anon JWT — those stop working at
  /// the end of 2026. Passed to `Supabase.initialize` as `publishableKey`;
  /// `anonKey` is deprecated as of `supabase_flutter` 2.17.
  static const String publishableKey =
      'sb_publishable_bsLrMyEAUZDcUjDeLj_xNA_D_TzK2NY';

  /// Where email confirmation, password recovery and OAuth come back to.
  /// Registered in the project's allowed redirect URLs, in the Android intent
  /// filter and in `Info.plist`.
  static const String redirectUrl = 'io.supabase.folo://login-callback/';
}
