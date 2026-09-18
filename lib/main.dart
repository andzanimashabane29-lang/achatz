import 'package:a_chatz/src/app.dart';
import 'package:a_chatz/src/services/notification_service.dart';
import 'package:a_chatz/src/core/services/linked_accounts_manager.dart';
import 'package:a_chatz/src/core/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Clear all extra mock/linked accounts to prevent UI confusion
  try {
    await LinkedAccountsManager.clearAllAccountsExceptOfficial();
  } catch (_) {}

  // Initialize Supabase Backend
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await EasyLocalization.ensureInitialized();
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService initialization failed: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('zu'),
        Locale('xh'),
        Locale('af'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(
        child: AChatzApp(),
      ),
    ),
  );
}