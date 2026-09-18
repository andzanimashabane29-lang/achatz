import 'dart:io';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/logo_doodle_background.dart';

class WallpaperBackground extends StatelessWidget {
  final String wallpaperPath;
  final Widget? child;

  const WallpaperBackground({
    super.key,
    required this.wallpaperPath,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!wallpaperPath.startsWith('assets/wallpapers/')) {
      // It's a custom file background
      final file = File(wallpaperPath);
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file.existsSync())
              Opacity(
                opacity: 0.3,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const LogoDoodleBackground();
                  },
                ),
              )
            else
              const LogoDoodleBackground(),
            if (child != null) child!,
          ],
        ),
      );
    }

    // It is a premium preset background
    final Gradient gradient;
    double doodleOpacity = 0.03;

    if (wallpaperPath.contains('luxury_dark')) {
      gradient = const RadialGradient(
        center: Alignment.topRight,
        radius: 1.5,
        colors: [
          Color(0xFF2E2E38), // Obsidian/bronze glow
          Color(0xFF16161D), // Deep charcoal
          Color(0xFF0F0F12), // Black
        ],
      );
      doodleOpacity = 0.025;
    } else if (wallpaperPath.contains('royal_blue')) {
      gradient = const RadialGradient(
        center: Alignment.topRight,
        radius: 1.5,
        colors: [
          Color(0xFF1B263B), // Sapphire highlight
          Color(0xFF0D1B2A), // Navy
          Color(0xFF070B14), // Midnight black
        ],
      );
      doodleOpacity = 0.03;
    } else if (wallpaperPath.contains('emerald_green')) {
      gradient = const RadialGradient(
        center: Alignment.topRight,
        radius: 1.5,
        colors: [
          Color(0xFF14352F), // Forest green highlight
          Color(0xFF0B201F), // Jade/emerald
          Color(0xFF050E0D), // Deep dark green/black
        ],
      );
      doodleOpacity = 0.035;
    } else if (wallpaperPath.contains('deep_crimson')) {
      gradient = const RadialGradient(
        center: Alignment.topRight,
        radius: 1.5,
        colors: [
          Color(0xFF4A1212), // Crimson highlight
          Color(0xFF2D0A0A), // Burgundy
          Color(0xFF150404), // Obsidian red/black
        ],
      );
      doodleOpacity = 0.025;
    } else if (wallpaperPath.contains('obsidian_gold')) {
      gradient = const RadialGradient(
        center: Alignment.topRight,
        radius: 1.5,
        colors: [
          Color(0xFF382F1D), // Warm bronze/gold glow
          Color(0xFF1C1C1C), // Obsidian
          Color(0xFF0C0C0C), // Pure black
        ],
      );
      doodleOpacity = 0.02;
    } else {
      // Default wallpaper
      gradient = const RadialGradient(
        center: Alignment.topRight,
        radius: 1.2,
        colors: [
          Color(0xFF221515), // Subtle red-dark brand tone
          Color(0xFF0F0B0B),
          Color(0xFF070505),
        ],
      );
      doodleOpacity = 0.03;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _DoodleOverlay(opacity: doodleOpacity),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _DoodleOverlay extends StatelessWidget {
  final double opacity;

  const _DoodleOverlay({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double size = 32.0;
        const double spacing = 50.0;

        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;

        final int cols = (width / (size + spacing)).ceil() + 1;
        final int rows = (height / (size + spacing)).ceil() + 1;

        return Stack(
          children: List.generate(rows * cols, (index) {
            final int r = index ~/ cols;
            final int c = index % cols;

            final double offsetX = (r % 2 == 0) ? (spacing / 2) : 0;
            final double left = c * (size + spacing) + offsetX - (size / 2);
            final double top = r * (size + spacing) - (size / 2);

            final double angle = ((r * 7 + c * 13) % 4) * 0.15;

            return Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: angle,
                  child: Image.asset(
                    'assets/logo.png',
                    width: size,
                    height: size,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
