import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class PremiumAvatar extends StatelessWidget {
  final String? userId;
  final String? photoUrl;
  final double radius;
  final VoidCallback? onTap;

  const PremiumAvatar({
    super.key,
    this.userId,
    this.photoUrl,
    this.radius = 22,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the maximum outer size so both premium and standard avatars take up the exact same width
    final double padding = 3.0;
    final double outerSize = (radius * 2) + (padding * 2) + 4.0;

    if (userId == null) {
      return SizedBox(
        width: outerSize,
        height: outerSize,
        child: Center(child: _buildAvatar(photoUrl)),
      );
    }

    // Outer stream: check if user is currently hosting a live session
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppDatabase.instance
          .table('live_sessions')
          .where('hostId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, liveSnap) {
        final isLive = (liveSnap.data?.docs.isNotEmpty) ?? false;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance.table('users').doc(userId).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final borderType = data?['profileBorder'] as String? ?? 'none';
            final userPhotoUrl = data?['photoUrl'] as String? ?? photoUrl;
            final photoVisibility = data?['profilePhotoVisibility'] as String? ?? 'Everyone';

            final currentUid = AppAuth.instance.currentUser?.uid;
            final isSelf = userId == currentUid;

            String? resolvedUrl;
            if (isSelf) {
              resolvedUrl = userPhotoUrl;
            } else if (photoVisibility == 'Nobody') {
              resolvedUrl = null;
            } else {
              resolvedUrl = userPhotoUrl;
            }

            final avatarWidget = _buildAvatar(resolvedUrl);

            // Live border takes priority over premium border
            if (isLive) {
              return _buildLiveBorder(outerSize, avatarWidget);
            }

            // Handle 'My contacts' visibility with FutureBuilder for non-live users
            if (!isSelf && photoVisibility == 'My contacts') {
              return FutureBuilder<DocumentSnapshot>(
                future: AppDatabase.instance
                    .table('users')
                    .doc(userId)
                    .table('contacts')
                    .doc(currentUid)
                    .get(),
                builder: (context, contactSnap) {
                  final isContact = contactSnap.data?.exists ?? false;
                  final finalUrl = isContact ? userPhotoUrl : null;
                  return _buildWithBorder(context, outerSize, borderType, radius, _buildAvatar(finalUrl));
                },
              );
            }

            return _buildWithBorder(context, outerSize, borderType, radius, avatarWidget);
          },
        );
      },
    );
  }

  Widget _buildLiveBorder(double outerSize, Widget avatar) {
    return SizedBox(
      width: outerSize + 4,
      height: outerSize + 10,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedLiveBorder(
            radius: radius,
            child: avatar,
          ),
          // "LIVE" pill badge at the bottom centre of the avatar
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8002D),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8002D).withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithBorder(BuildContext context, double outerSize, String borderType, double radius, Widget avatar) {
    if (borderType == 'none') {
      return SizedBox(
        width: outerSize,
        height: outerSize,
        child: Center(child: avatar),
      );
    }

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Center(
        child: AnimatedBorderWrapper(
          borderType: borderType,
          radius: radius,
          child: avatar,
        ),
      ),
    );
  }

  Widget _buildAvatar(String? url) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[800],
        backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
        child: url == null || url.isEmpty
            ? Icon(Icons.person, color: Colors.white38, size: radius)
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnimatedLiveBorder – pulsing red ring shown when user is live
// ─────────────────────────────────────────────────────────────────────────────

class AnimatedLiveBorder extends StatefulWidget {
  final double radius;
  final Widget child;

  const AnimatedLiveBorder({
    super.key,
    required this.radius,
    required this.child,
  });

  @override
  State<AnimatedLiveBorder> createState() => _AnimatedLiveBorderState();
}

class _AnimatedLiveBorderState extends State<AnimatedLiveBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double padding = 3.0;
    final double outerSize = (widget.radius * 2) + (padding * 2) + 4.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE8002D).withOpacity(0.4 + 0.6 * (1.0 - t)),
                  width: 2.0 + t * 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8002D).withOpacity(0.2 + 0.4 * (1.0 - t)),
                    blurRadius: 6 + t * 8,
                    spreadRadius: 0.5 + t * 1.5,
                  ),
                ],
              ),
            ),
            // Dark gap circle
            Container(
              width: outerSize - 2,
              height: outerSize - 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
              padding: EdgeInsets.all(padding),
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnimatedBorderWrapper – rotating premium profile borders
// ─────────────────────────────────────────────────────────────────────────────

class AnimatedBorderWrapper extends StatefulWidget {
  final String borderType;
  final double radius;
  final Widget child;

  const AnimatedBorderWrapper({
    super.key,
    required this.borderType,
    required this.radius,
    required this.child,
  });

  @override
  State<AnimatedBorderWrapper> createState() => AnimatedBorderWrapperState();
}

class AnimatedBorderWrapperState extends State<AnimatedBorderWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double padding = 3.0;
    final double outerSize = (widget.radius * 2) + (padding * 2) + 4.0;

    if (widget.borderType == 'pulsing_gold') {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 + (math.sin(_controller.value * 2 * math.pi) * 0.05);
          final opacity = 0.5 + (math.sin(_controller.value * 2 * math.pi) * 0.3);

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: outerSize - 2,
                  height: outerSize - 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(opacity),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: outerSize,
                height: outerSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                padding: EdgeInsets.all(padding),
                child: widget.child,
              ),
            ],
          );
        },
      );
    }

    Gradient gradient;
    if (widget.borderType == 'neon_rainbow') {
      gradient = const SweepGradient(
        colors: [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
          Colors.red,
        ],
      );
    } else if (widget.borderType == 'cyberpunk') {
      gradient = const SweepGradient(
        colors: [
          Colors.cyan,
          Colors.pink,
          Colors.cyan,
        ],
      );
    } else {
      // electric_blue
      gradient = const SweepGradient(
        colors: [
          Colors.blueAccent,
          Colors.lightBlueAccent,
          Color(0xFF00E5FF),
          Colors.blueAccent,
        ],
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: outerSize,
              height: outerSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
            ),
            RotationTransition(
              turns: _controller,
              child: Container(
                width: outerSize - 2,
                height: outerSize - 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                ),
              ),
            ),
            Container(
              width: outerSize - 6,
              height: outerSize - 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}
