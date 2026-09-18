import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Common Colors
  static const primaryPurple = Color(0xFFA259FF); // Beautiful Purple Accent
  static const iosBlue = Color(0xFF0A84FF); // Fallback standard

  // WhatsApp Dark Colors
  static const waDarkBackground = Color(0xFF111B21);
  static const waDarkSurface = Color(0xFF202C33);
  static const waDarkText = Color(0xFFE9EDEF);
  static const waDarkMuted = Color(0xFF8696A0);

  // iOS Light Colors
  static const iosLightBackground = Color(0xFFF2F2F7);
  static const iosLightSurface = Color(0xFFFFFFFF);
  static const iosLightText = Color(0xFF1C1C1E);
  static const iosLightMuted = Color(0xFF8E8E93);

  static ThemeData get darkLuxury {
    // We use a slightly smaller default typography scaling
    final textTheme = GoogleFonts.outfitTextTheme().apply(
      bodyColor: waDarkText,
      displayColor: waDarkText,
      fontSizeFactor: 0.95, // Make everything slightly more compact globally
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: waDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: waDarkMuted,
        surface: waDarkSurface,
        onPrimary: Colors.white,
        onSurface: waDarkText,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: waDarkBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: waDarkText,
          fontSize: 18, // Standard iOS size
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: primaryPurple),
      ),
      iconTheme: const IconThemeData(color: waDarkMuted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: waDarkSurface,
        hintStyle: const TextStyle(color: waDarkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // More compact
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryPurple, width: 1.0),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get lightLuxury {
    final textTheme = GoogleFonts.outfitTextTheme().apply(
      bodyColor: iosLightText,
      displayColor: iosLightText,
      fontSizeFactor: 0.95, // Make everything slightly more compact globally
    );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: iosLightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryPurple,
        secondary: iosLightMuted,
        surface: iosLightSurface,
        onPrimary: Colors.white,
        onSurface: iosLightText,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: iosLightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryPurple),
        titleTextStyle: GoogleFonts.outfit(
          color: iosLightText,
          fontSize: 18, // Standard iOS size
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      iconTheme: const IconThemeData(color: iosLightMuted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: iosLightSurface,
        hintStyle: const TextStyle(color: iosLightMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // More compact
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryPurple, width: 1.0),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
