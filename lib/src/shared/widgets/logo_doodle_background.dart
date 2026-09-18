import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated ambient gradient orb background.
/// Two luminous orbs drift slowly using sine-wave offsets, giving every
/// screen a living, premium "liquid-glass" feel — no external packages needed.
class LogoDoodleBackground extends StatefulWidget {
  const LogoDoodleBackground({super.key});

  @override
  State<LogoDoodleBackground> createState() => _LogoDoodleBackgroundState();
}

class _LogoDoodleBackgroundState extends State<LogoDoodleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Orb colours adapt to the active theme
    final orbA = isDark
        ? cs.primary.withOpacity(0.22)
        : cs.primary.withOpacity(0.12);
    final orbB = isDark
        ? cs.secondary.withOpacity(0.14)
        : cs.secondary.withOpacity(0.08);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * 2 * math.pi;

        // Orb A drifts top-left → bottom-right
        final dxA = 0.10 + 0.08 * math.sin(t);
        final dyA = 0.10 + 0.08 * math.cos(t * 0.7);

        // Orb B drifts bottom-right → top-left (offset phase)
        final dxB = 0.75 + 0.07 * math.cos(t * 0.8 + 1.2);
        final dyB = 0.70 + 0.07 * math.sin(t * 0.6 + 2.1);

        return Container(
          decoration: BoxDecoration(color: isDark ? const Color(0xFF101012) : const Color(0xFFF5F5F5)),
          child: CustomPaint(
            painter: _OrbPainter(
              dxA: dxA, dyA: dyA, colorA: orbA,
              dxB: dxB, dyB: dyB, colorB: orbB,
            ),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({
    required this.dxA,
    required this.dyA,
    required this.colorA,
    required this.dxB,
    required this.dyB,
    required this.colorB,
  });

  final double dxA, dyA, dxB, dyB;
  final Color colorA, colorB;

  @override
  void paint(Canvas canvas, Size size) {
    void drawOrb(double dx, double dy, Color color, double radiusFactor) {
      final center = Offset(size.width * dx, size.height * dy);
      final radius = size.shortestSide * radiusFactor;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    drawOrb(dxA, dyA, colorA, 0.65);
    drawOrb(dxB, dyB, colorB, 0.55);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.dxA != dxA || old.dyA != dyA || old.dxB != dxB || old.dyB != dyB;
}
