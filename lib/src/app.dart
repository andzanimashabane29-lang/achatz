import 'package:a_chatz/src/core/router/app_router.dart';
import 'package:a_chatz/src/core/theme/app_theme_preset.dart';
import 'package:a_chatz/src/shared/widgets/passcode_lock_wrapper.dart';
import 'package:a_chatz/src/core/services/storage_safety_service.dart';
import 'package:a_chatz/src/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class AChatzApp extends ConsumerStatefulWidget {
  const AChatzApp({super.key});

  @override
  ConsumerState<AChatzApp> createState() => _AChatzAppState();
}

class _AChatzAppState extends ConsumerState<AChatzApp> {
  @override
  void initState() {
    super.initState();
    // Dismiss the native splash screen now that Flutter is ready to render
    FlutterNativeSplash.remove();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StorageSafetyService.instance.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final accessibility = ref.watch(accessibilityProvider);

    return PasscodeLockWrapper(
      child: MaterialApp.router(
        routerConfig: appRouter,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        debugShowCheckedModeBanner: false,
        themeMode: themeSettings.mode,
        theme: AppThemeCatalog.theme(
          themeSettings.preset,
          dark: false,
          highContrast: accessibility.highContrast,
          reduceAnimations: accessibility.reduceAnimations,
        ),
        darkTheme: AppThemeCatalog.theme(
          themeSettings.preset,
          dark: true,
          highContrast: accessibility.highContrast,
          reduceAnimations: accessibility.reduceAnimations,
        ),
      ),
    );
  }
}
