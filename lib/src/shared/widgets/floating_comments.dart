import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class FloatingCommentItem {
  final String id;
  final String senderName;
  final String text;
  final String? avatarUrl;
  double x; // Horizontal percentage (0.0 to 1.0)
  double y; // Offset from bottom in pixels
  final double speed;
  final double scale;
  final double waveAmplitude;
  final double waveFrequency;
  final double rotation;
  double opacity = 1.0;

  FloatingCommentItem({
    required this.id,
    required this.senderName,
    required this.text,
    this.avatarUrl,
    required this.x,
    required this.y,
    required this.speed,
    required this.scale,
    required this.waveAmplitude,
    required this.waveFrequency,
    required this.rotation,
  });
}

class FloatingCommentsOverlay extends StatefulWidget {
  final Stream<Map<String, dynamic>>? commentStream;

  const FloatingCommentsOverlay({super.key, this.commentStream});

  @override
  State<FloatingCommentsOverlay> createState() => _FloatingCommentsOverlayState();
}

class _FloatingCommentsOverlayState extends State<FloatingCommentsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<FloatingCommentItem> _items = [];
  final Random _random = Random();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updatePositions);
    _controller.repeat();

    _subscription = widget.commentStream?.listen((data) {
      if (mounted) {
        final text = data['text'] as String? ?? '';
        final senderName = data['senderName'] as String? ?? 'Someone';
        final avatarUrl = data['avatarUrl'] as String?;
        if (text.isNotEmpty) {
          spawnComment(senderName, text, avatarUrl);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void spawnComment(String senderName, String text, [String? avatarUrl]) {
    if (!mounted) return;
    setState(() {
      _items.add(FloatingCommentItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        senderName: senderName,
        text: text,
        avatarUrl: avatarUrl,
        x: 0.15 + _random.nextDouble() * 0.5, // Spawn in center region
        y: 0.0,
        speed: 1.5 + _random.nextDouble() * 2.0,
        scale: 0.85 + _random.nextDouble() * 0.2,
        waveAmplitude: 10.0 + _random.nextDouble() * 20.0,
        waveFrequency: 1.5 + _random.nextDouble() * 3.0,
        rotation: (_random.nextDouble() - 0.5) * 0.25,
      ));
    });
  }

  void _updatePositions() {
    if (_items.isEmpty) return;
    setState(() {
      for (int i = _items.length - 1; i >= 0; i--) {
        final item = _items[i];
        item.y += item.speed;

        // Fade out as it goes higher
        if (item.y > 280) {
          item.opacity = ((400.0 - item.y) / 120.0).clamp(0.0, 1.0);
        }

        if (item.y >= 400 || item.opacity <= 0.0) {
          _items.removeAt(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: _items.map((item) {
                final double wave = sin(item.y * 0.015 * item.waveFrequency) * item.waveAmplitude;
                final double computedX = (item.x * constraints.maxWidth) + wave - 110; // offset center of width
                final double computedY = constraints.maxHeight - item.y - 120.0;

                return Positioned(
                  left: computedX.clamp(16.0, constraints.maxWidth - 240.0),
                  top: computedY,
                  child: Opacity(
                    opacity: item.opacity,
                    child: Transform.scale(
                      scale: item.scale,
                      child: Transform.rotate(
                        angle: item.rotation,
                        child: _buildCommentBubble(item),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommentBubble(FloatingCommentItem item) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white24,
            backgroundImage: item.avatarUrl != null ? NetworkImage(item.avatarUrl!) : null,
            child: item.avatarUrl == null
                ? const Icon(Icons.person, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.senderName,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
