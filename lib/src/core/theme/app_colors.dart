import 'package:flutter/material.dart';

/// A-Chatz Unified Color System
/// ─────────────────────────────────────────────────────────
/// All accent/semantic colors in the app MUST come from here.
/// Never hardcode raw Color literals in UI widgets.
///
/// Brand Primary: Purple  #A259FF
/// ─────────────────────────────────────────────────────────
abstract final class AppColors {
  // ── Brand ────────────────────────────────────────────────
  /// Main brand accent – purple. Used for CTAs, selected states, badges.
  static const primary = Color(0xFFA259FF);

  /// Lighter tint of brand for backgrounds / highlights.
  static const primaryLight = Color(0xFFD0A8FF);

  /// Muted / ghost version of brand accent.
  static const primaryMuted = Color(0x33A259FF); // 20% opacity

  // ── Semantic ─────────────────────────────────────────────
  /// Online presence dot, sent/delivered tick, success toasts.
  static const online = Color(0xFF4CD964);   // iOS-style green

  /// Unread message badge, active badge count.
  static const badge = Color(0xFFA259FF);    // aligned to brand

  /// Missed call, error, critical alert.
  static const error = Color(0xFFFF3B30);    // iOS-style red

  /// Warning / caution state.
  static const warning = Color(0xFFFF9F0A);  // iOS-style amber

  /// Info accent – used for status unseen dot, blue-tick info icon.
  static const info = Color(0xFF0A84FF);     // iOS-style blue

  // ── Verification tiers ───────────────────────────────────
  /// Tier 1 (blue-tick): standard verified
  static const verifiedBlue   = Color(0xFF0A84FF);
  /// Tier 2 (purple-tick): creator verified
  static const verifiedPurple = Color(0xFFA259FF);
  /// Tier 3 (gold-tick): premium / celebrity
  static const verifiedGold   = Color(0xFFFFD60A);

  // ── Dark surface palette ─────────────────────────────────
  static const darkBg       = Color(0xFF111113);
  static const darkSurface  = Color(0xFF1C1C1F);
  static const darkSurface2 = Color(0xFF2C2C2F);
  static const darkBorder   = Color(0xFF2C2C2F);

  // ── Text on dark ─────────────────────────────────────────
  static const textPrimary   = Color(0xFFF2F2F7);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary  = Color(0xFF48484A);

  // ── Light surface palette ────────────────────────────────
  static const lightBg      = Color(0xFFF2F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder  = Color(0xFFD1D1D6);

  // ── Chat bubbles ─────────────────────────────────────────
  static const bubbleSent     = Color(0xFF2C2C2F);
  static const bubbleReceived = Color(0xFF1C1C1F);

  // ── Helpers ──────────────────────────────────────────────
  /// Returns the correct verified badge color for a given tier string.
  static Color verifiedColor(String? tier) => switch (tier) {
    'tier2' => verifiedPurple,
    'tier3' => verifiedGold,
    _       => verifiedBlue,
  };
}
