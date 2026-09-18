import 'dart:math';
import 'package:flutter/material.dart';

class FloatingEmoji {
  final String emoji;
  double x; // Percentage (0.0 to 1.0)
  double y; // Offset from bottom in pixels
  final double speed;
  final double scale;
  final double waveAmplitude;
  final double waveFrequency;
  double opacity = 1.0;
  final double rotation;

  FloatingEmoji({
    required this.emoji,
    required this.x,
    required this.y,
    required this.speed,
    required this.scale,
    required this.waveAmplitude,
    required this.waveFrequency,
    required this.rotation,
  });
}

class FloatingReactionsCanvas extends StatefulWidget {
  final Stream<String>? reactionStream;

  const FloatingReactionsCanvas({super.key, this.reactionStream});

  @override
  State<FloatingReactionsCanvas> createState() => _FloatingReactionsCanvasState();
}

class _FloatingReactionsCanvasState extends State<FloatingReactionsCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<FloatingEmoji> _emojis = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateParticles);
    _controller.repeat();

    widget.reactionStream?.listen((emoji) {
      if (mounted) {
        _spawnEmoji(emoji);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnEmoji(String emoji) {
    setState(() {
      _emojis.add(FloatingEmoji(
        emoji: emoji,
        x: 0.2 + _random.nextDouble() * 0.6, // Spawn in center 60% of screen
        y: 0.0,
        speed: 2.0 + _random.nextDouble() * 3.5,
        scale: 0.7 + _random.nextDouble() * 0.8,
        waveAmplitude: 15.0 + _random.nextDouble() * 25.0,
        waveFrequency: 2.0 + _random.nextDouble() * 4.0,
        rotation: (_random.nextDouble() - 0.5) * 0.4,
      ));
    });
  }

  void _updateParticles() {
    if (_emojis.isEmpty) return;
    setState(() {
      for (int i = _emojis.length - 1; i >= 0; i--) {
        final item = _emojis[i];
        item.y += item.speed;
        
        // Horizontal wave motion
        // y acts as the progression time
        final wave = sin(item.y * 0.01 * item.waveFrequency) * item.waveAmplitude;
        
        // Fade out as it goes higher
        if (item.y > 350) {
          item.opacity = ((500.0 - item.y) / 150.0).clamp(0.0, 1.0);
        }

        if (item.y >= 500 || item.opacity <= 0.0) {
          _emojis.removeAt(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _EmojiPainter(emojis: _emojis),
        ),
      ),
    );
  }
}

class _EmojiPainter extends CustomPainter {
  final List<FloatingEmoji> emojis;

  _EmojiPainter({required this.emojis});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final item in emojis) {
      final double wave = sin(item.y * 0.015 * item.waveFrequency) * item.waveAmplitude;
      final double computedX = (item.x * size.width) + wave;
      final double computedY = size.height - item.y - 80.0; // Offset above bottom toolbar

      canvas.save();
      canvas.translate(computedX, computedY);
      canvas.rotate(item.rotation);
      canvas.scale(item.scale);

      textPainter.text = TextSpan(
        text: item.emoji,
        style: TextStyle(
          fontSize: 24,
          color: Colors.white.withOpacity(item.opacity),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
