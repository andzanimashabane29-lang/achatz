import 'dart:async';
import 'package:flutter/material.dart';

class FloatingNotification extends StatefulWidget {
  const FloatingNotification({
    super.key,
    required this.title,
    required this.body,
    this.photoUrl,
    required this.onTap,
  });

  final String title;
  final String body;
  final String? photoUrl;
  final VoidCallback onTap;

  static OverlayEntry? _activeOverlay;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    String? photoUrl,
    required VoidCallback onTap,
  }) {
    _activeOverlay?.remove();
    _activeOverlay = null;
    _dismissTimer?.cancel();

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => FloatingNotification(
        title: title,
        body: body,
        photoUrl: photoUrl,
        onTap: onTap,
      ),
    );

    overlay.insert(entry);
    _activeOverlay = entry;

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      dismiss();
    });
  }

  static void dismiss() {
    _activeOverlay?.remove();
    _activeOverlay = null;
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  @override
  State<FloatingNotification> createState() => _FloatingNotificationState();
}

class _FloatingNotificationState extends State<FloatingNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              FloatingNotification.dismiss();
              widget.onTap();
            },
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -5) {
                FloatingNotification.dismiss();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xE61C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2C2C2E), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  )
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF2C2C2E),
                    backgroundImage: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                        ? NetworkImage(widget.photoUrl!)
                        : null,
                    child: widget.photoUrl == null || widget.photoUrl!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.body,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
