import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  /// Supabase Project URL.
  /// Can be overridden via `--dart-define=SUPABASE_URL=...`
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://poonntsdomkzfqidboug.supabase.co',
  );

  /// Supabase Anonymous Public API Key.
  /// Can be overridden via `--dart-define=SUPABASE_ANON_KEY=...`
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_rxZ-S3VvYS1IO5PtHkNWPQ_4-wModGO',
  );

  /// Convenient accessor for the global SupabaseClient instance
  static SupabaseClient get client => Supabase.instance.client;

  /// Convenient accessor for Supabase auth
  static GoTrueClient get auth => Supabase.instance.client.auth;

  /// Current authenticated user
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  /// Current user ID
  static String? get currentUid => Supabase.instance.client.auth.currentUser?.id;

  /// Whether a user is currently authenticated
  static bool get isAuthenticated => currentUser != null;
}
