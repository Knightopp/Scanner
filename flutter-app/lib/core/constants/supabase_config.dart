/// Configuration for Supabase integration.
///
/// Values must be supplied at build or run time via `--dart-define`:
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<your-publishable-key>
/// ```
///
/// NEVER pass or store the service_role secret key here. Only the public/anon key.
class SupabaseConfig {
  SupabaseConfig._();

  /// The Supabase Project URL provided via --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sdkadflrxjdhxduwvrsz.supabase.co',
  );

  /// The Supabase Publishable (anon) Key provided via --dart-define=SUPABASE_PUBLISHABLE_KEY=...
  /// (also supports SUPABASE_ANON_KEY as fallback)
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_WQB6od9EydJmJ_RmqncFuw_KzBjwg1w'),
  );

  /// Returns true if both URL and Publishable Key were provided.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;
}
