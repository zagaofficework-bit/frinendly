import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Supabase project URL.
  /// You can replace this with your project URL from Supabase Dashboard -> Project Settings -> API,
  /// or pass it at run time: flutter run --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pjqtzecslzjilvloehva.supabase.co',
  );

  /// Supabase anon public API key.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_mapsM_YGxpsj5myYeZzZBQ_vHR4J6xL',
  );


  /// Returns true only if valid credentials have been set.
  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE') &&
      supabaseAnonKey.trim().isNotEmpty &&
      !supabaseAnonKey.contains('YOUR_ANON');

  /// Safe accessor for SupabaseClient instance
  static SupabaseClient? get client {
    if (isConfigured) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
