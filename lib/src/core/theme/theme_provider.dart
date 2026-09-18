import 'package:a_chatz/src/core/theme/app_theme_preset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeSettings {
  const AppThemeSettings({
    required this.preset,
    required this.mode,
  });

  final AppThemePreset preset;
  final ThemeMode mode;

  AppThemeSettings copyWith({
    AppThemePreset? preset,
    ThemeMode? mode,
  }) {
    return AppThemeSettings(
      preset: preset ?? this.preset,
      mode: mode ?? this.mode,
    );
  }
}

// ---------------------------------------------------------------------------
// Riverpod 2.x — Notifier + NotifierProvider
// StateNotifier is still supported but Notifier is the recommended pattern
// for new code in Riverpod 2.x.
// ---------------------------------------------------------------------------

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeSettings>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<AppThemeSettings> {
  @override
  AppThemeSettings build() {
    // Start with the default while loading persisted settings.
    _loadTheme();
    return const AppThemeSettings(
      preset: AppThemePreset.ios,
      mode: ThemeMode.dark,
    );
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final presetIndex = prefs.getInt('app_color_theme');
    final modeIndex = prefs.getInt('app_theme');

    AppThemePreset preset = AppThemePreset.ios;
    if (presetIndex != null &&
        presetIndex >= 0 &&
        presetIndex < AppThemePreset.values.length) {
      preset = AppThemePreset.values[presetIndex];
      // Midnight was removed from active presets — fall back to iOS.
      if (preset == AppThemePreset.midnight) {
        preset = AppThemePreset.ios;
        await prefs.setInt('app_color_theme', preset.index);
      }
    } else {
      await prefs.setInt('app_color_theme', preset.index);
    }

    ThemeMode mode = ThemeMode.dark;
    if (modeIndex != null &&
        modeIndex >= 0 &&
        modeIndex < ThemeMode.values.length) {
      mode = ThemeMode.values[modeIndex];
    }

    state = AppThemeSettings(preset: preset, mode: mode);
  }

  Future<void> setPreset(AppThemePreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_color_theme', preset.index);
    state = state.copyWith(preset: preset);
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme', mode.index);
    state = state.copyWith(mode: mode);
  }

  /// Legacy toggle — cycles light ↔ dark.
  Future<void> toggleTheme() async {
    if (state.mode == ThemeMode.dark) {
      await setMode(ThemeMode.light);
    } else {
      await setMode(ThemeMode.dark);
    }
  }
}

class AccessibilitySettings {
  const AccessibilitySettings({
    required this.highContrast,
    required this.reduceAnimations,
  });

  final bool highContrast;
  final bool reduceAnimations;

  AccessibilitySettings copyWith({
    bool? highContrast,
    bool? reduceAnimations,
  }) {
    return AccessibilitySettings(
      highContrast: highContrast ?? this.highContrast,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
    );
  }
}

final accessibilityProvider = NotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
  AccessibilityNotifier.new,
);

class AccessibilityNotifier extends Notifier<AccessibilitySettings> {
  @override
  AccessibilitySettings build() {
    _loadSettings();
    return const AccessibilitySettings(
      highContrast: false,
      reduceAnimations: false,
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hc = prefs.getBool('accessibility_high_contrast') ?? false;
    final ra = prefs.getBool('accessibility_reduce_animations') ?? false;
    state = AccessibilitySettings(highContrast: hc, reduceAnimations: ra);
  }

  Future<void> setHighContrast(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accessibility_high_contrast', val);
    state = state.copyWith(highContrast: val);
  }

  Future<void> setReduceAnimations(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accessibility_reduce_animations', val);
    state = state.copyWith(reduceAnimations: val);
  }
}

extension AccessibilityExtension on BuildContext {
  bool get reduceAnimations {
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      return container.read(accessibilityProvider).reduceAnimations;
    } catch (_) {
      return false;
    }
  }

  bool get highContrast {
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      return container.read(accessibilityProvider).highContrast;
    } catch (_) {
      return false;
    }
  }

  Duration animationDuration(Duration original) {
    return reduceAnimations ? Duration.zero : original;
  }
}
