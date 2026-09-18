import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemePreset {
  midnight,
  oled,
  light,
  ios,
  whatsapp,
  ocean,
  purple,
  sunset,
  rose,
}

extension AppThemePresetX on AppThemePreset {
  String get label => switch (this) {
        AppThemePreset.midnight => 'Midnight',
        AppThemePreset.oled => 'OLED Black',
        AppThemePreset.light => 'Classic Light',
        AppThemePreset.ios => 'Apple iOS',
        AppThemePreset.whatsapp => 'Forest Green',
        AppThemePreset.ocean => 'Ocean Blue',
        AppThemePreset.purple => 'Royal Purple',
        AppThemePreset.sunset => 'Sunset Amber',
        AppThemePreset.rose => 'Rose Blush',
      };

  IconData get icon => switch (this) {
        AppThemePreset.midnight => Icons.dark_mode_outlined,
        AppThemePreset.oled => Icons.contrast_outlined,
        AppThemePreset.light => Icons.light_mode_outlined,
        AppThemePreset.ios => Icons.phone_iphone_outlined,
        AppThemePreset.whatsapp => Icons.chat_outlined,
        AppThemePreset.ocean => Icons.water_outlined,
        AppThemePreset.purple => Icons.auto_awesome_outlined,
        AppThemePreset.sunset => Icons.wb_twilight_outlined,
        AppThemePreset.rose => Icons.favorite_outline,
      };

  Color get previewColor => switch (this) {
        AppThemePreset.midnight => const Color(0xFF1C1C1E),
        AppThemePreset.oled => const Color(0xFF000000),
        AppThemePreset.light => const Color(0xFFF2F2F7),
        AppThemePreset.ios => const Color(0xFF007AFF),
        AppThemePreset.whatsapp => const Color(0xFF075E54),
        AppThemePreset.ocean => const Color(0xFF1565C0),
        AppThemePreset.purple => const Color(0xFF6A1B9A),
        AppThemePreset.sunset => const Color(0xFFE65100),
        AppThemePreset.rose => const Color(0xFFC2185B),
      };

  bool get isDarkByDefault => switch (this) {
        AppThemePreset.light => false,
        AppThemePreset.ios => false,
        _ => true,
      };
}

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class AppThemeCatalog {
  static ThemeData theme(AppThemePreset preset, {required bool dark, bool highContrast = false, bool reduceAnimations = false}) {
    final colors = _palette(preset, dark: dark);
    final textTheme = GoogleFonts.outfitTextTheme().apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );

    return ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        secondary: colors.muted,
        onSecondary: colors.onSurface,
        surface: colors.surface,
        onSurface: colors.onSurface,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      iconTheme: IconThemeData(
        color: highContrast
            ? (dark ? Colors.white : Colors.black)
            : colors.muted,
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: reduceAnimations ? const NoAnimationPageTransitionsBuilder() : const CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: reduceAnimations ? const NoAnimationPageTransitionsBuilder() : const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: reduceAnimations ? const NoAnimationPageTransitionsBuilder() : const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: reduceAnimations ? const NoAnimationPageTransitionsBuilder() : const CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: highContrast ? (dark ? Colors.white : Colors.black) : colors.onSurface),
        titleTextStyle: GoogleFonts.outfit(
          color: colors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.primary, size: 24);
          }
          return IconThemeData(
            color: highContrast
                ? (dark ? Colors.white : Colors.black87)
                : colors.muted,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: highContrast
                ? (dark ? Colors.white : Colors.black87)
                : colors.muted,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: TextStyle(color: colors.onSurface.withOpacity(0.45)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
      ),
    );
  }

  static _ThemePalette _palette(AppThemePreset preset, {required bool dark}) {
    if (!dark) {
      switch (preset) {
        case AppThemePreset.ios:
          return const _ThemePalette(
            background: Color(0xFFF2F2F7), // iOS system light background
            surface: Color(0xFFFFFFFF),    // iOS system light surface
            primary: Color(0xFF007AFF),    // iOS system blue
            onPrimary: Colors.white,
            onSurface: Color(0xFF000000),
            muted: Color(0xFF8E8E93),      // iOS system gray
          );
        case AppThemePreset.whatsapp:
          return const _ThemePalette(
            background: Color(0xFFFFFFFF),
            surface: Color(0xFFF7F7F7),
            primary: Color(0xFF008069),
            onPrimary: Colors.white,
            onSurface: Color(0xFF111B21),
            muted: Color(0xFF667781),
          );
        case AppThemePreset.ocean:
          return const _ThemePalette(
            background: Color(0xFFF0F9FF),
            surface: Colors.white,
            primary: Color(0xFF0EA5E9),
            onPrimary: Colors.white,
            onSurface: Color(0xFF0F172A),
            muted: Color(0xFF64748B),
          );
        case AppThemePreset.purple:
          return const _ThemePalette(
            background: Color(0xFFFAF5FF),
            surface: Colors.white,
            primary: Color(0xFFA855F7),
            onPrimary: Colors.white,
            onSurface: Color(0xFF1E1B4B),
            muted: Color(0xFF64748B),
          );
        case AppThemePreset.sunset:
          return const _ThemePalette(
            background: Color(0xFFFFF7ED),
            surface: Colors.white,
            primary: Color(0xFFF97316),
            onPrimary: Colors.white,
            onSurface: Color(0xFF2C1010),
            muted: Color(0xFF8C5B30),
          );
        case AppThemePreset.rose:
          return const _ThemePalette(
            background: Color(0xFFFFF1F2),
            surface: Colors.white,
            primary: Color(0xFFF43F5E),
            onPrimary: Colors.white,
            onSurface: Color(0xFF2A0D16),
            muted: Color(0xFF9E4B5B),
          );
        case AppThemePreset.midnight:
        case AppThemePreset.oled:
        case AppThemePreset.light:
        default:
          return const _ThemePalette(
            background: Color(0xFFFAFAFA),
            surface: Colors.white,
            primary: Color(0xFF1D4ED8),
            onPrimary: Colors.white,
            onSurface: Color(0xFF0F172A),
            muted: Color(0xFF64748B),
          );
      }
    }

    switch (preset) {
      case AppThemePreset.ios:
        return const _ThemePalette(
          background: Color(0xFF000000), // iOS pure black
          surface: Color(0xFF1C1C1E),    // iOS grouped background
          primary: Color(0xFF0A84FF),    // iOS system blue (dark version)
          onPrimary: Colors.white,
          onSurface: Colors.white,
          muted: Color(0xFF8E8E93),
        );
      case AppThemePreset.whatsapp:
        return const _ThemePalette(
          background: Color(0xFF111B21), // WhatsApp dark background
          surface: Color(0xFF202C33),    // WhatsApp dark surface
          primary: Color(0xFF00A884),    // WhatsApp green
          onPrimary: Colors.white,
          onSurface: Color(0xFFE9EDEF),
          muted: Color(0xFF8696A0),
        );
      case AppThemePreset.midnight:
        return const _ThemePalette(
          background: Color(0xFF0B1014), // Very deep midnight blue/black
          surface: Color(0xFF151B21),
          primary: Color(0xFF3B82F6),
          onPrimary: Colors.white,
          onSurface: Color(0xFFF8FAFC),
          muted: Color(0xFF94A3B8),
        );
      case AppThemePreset.oled:
        return const _ThemePalette(
          background: Color(0xFF000000), // True black for OLED
          surface: Color(0xFF121212),
          primary: Color(0xFF8B5CF6),
          onPrimary: Colors.white,
          onSurface: Color(0xFFF3F4F6),
          muted: Color(0xFF9CA3AF),
        );
      case AppThemePreset.ocean:
        return const _ThemePalette(
          background: Color(0xFF0F172A),
          surface: Color(0xFF1E293B),
          primary: Color(0xFF0EA5E9),
          onPrimary: Colors.white,
          onSurface: Color(0xFFF8FAFC),
          muted: Color(0xFF94A3B8),
        );
      case AppThemePreset.purple:
        return const _ThemePalette(
          background: Color(0xFF1E1B4B),
          surface: Color(0xFF2E2A5D),
          primary: Color(0xFFA855F7),
          onPrimary: Colors.white,
          onSurface: Color(0xFFF8FAFC),
          muted: Color(0xFF94A3B8),
        );
      case AppThemePreset.sunset:
        return const _ThemePalette(
          background: Color(0xFF2C1010),
          surface: Color(0xFF3F1919),
          primary: Color(0xFFF97316),
          onPrimary: Colors.white,
          onSurface: Color(0xFFFFF7ED),
          muted: Color(0xFFFDBA74),
        );
      case AppThemePreset.rose:
        return const _ThemePalette(
          background: Color(0xFF2A0D16),
          surface: Color(0xFF3D1623),
          primary: Color(0xFFF43F5E),
          onPrimary: Colors.white,
          onSurface: Color(0xFFFFF1F2),
          muted: Color(0xFFFDA4AF),
        );
      default:
        return const _ThemePalette(
          background: Color(0xFF09090B),
          surface: Color(0xFF18181B),
          primary: Color(0xFF2563EB),
          onPrimary: Colors.white,
          onSurface: Color(0xFFF8FAFC),
          muted: Color(0xFF94A3B8),
        );
    }
  }
}

class _ThemePalette {
  const _ThemePalette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.onSurface,
    required this.muted,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color onSurface;
  final Color muted;
}
