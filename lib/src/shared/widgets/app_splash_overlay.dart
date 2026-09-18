import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium launch overlay: solid background + pulsing logo + graceful fade-out.
class AppSplashOverlay extends StatefulWidget {
  const AppSplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<AppSplashOverlay> createState() => _AppSplashOverlayState();
}

class _AppSplashOverlayState extends State<AppSplashOverlay>
    with SingleTickerProviderStateMixin {
  static const _minSplashDuration = Duration(milliseconds: 1200);
  static const _fadeDuration = Duration(milliseconds: 600);
  static const _logoSize = 190.0;

  /// Only show the splash once per app process.
  static bool _hasShownSplash = false;

  /// Whether the overlay widget is still in the tree.
  bool _visible = true;

  /// Drives AnimatedOpacity: 1.0 = visible, 0.0 = fading out.
  double _opacity = 1.0;

  /// Nullable — only created when we actually show the splash.
  AnimationController? _pulseCtrl;
  Animation<double>? _pulseAnim;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();

    if (_hasShownSplash) {
      // Skip the splash — remove it instantly on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = false);
      });
      return;
    }
    _hasShownSplash = true;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );

    _dismiss();
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await Future.delayed(_minSplashDuration);
    if (!mounted) return;
    // Kick off the opacity fade.
    setState(() => _opacity = 0.0);
    // Wait for the fade to finish before removing the widget from the tree.
    await Future.delayed(_fadeDuration);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          AnimatedOpacity(
            opacity: _opacity,
            duration: _fadeDuration,
            curve: Curves.easeOut,
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: Stack(
                children: [
                  // Pulsing logo in the centre
                  Center(
                    child: AnimatedBuilder(
                      // Use AlwaysStoppedAnimation as a safe fallback when
                      // _pulseAnim is null (i.e. the splash is being skipped).
                      animation:
                          _pulseAnim ?? const AlwaysStoppedAnimation(1.0),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnim?.value ?? 1.0,
                          child: child,
                        );
                      },
                      child: Container(
                        width: _logoSize,
                        height: _logoSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF3B82F6).withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo.png',
                            width: _logoSize,
                            height: _logoSize,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Branding text at the bottom
                  Positioned(
                    bottom: 42.0,
                    left: 0,
                    right: 0,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [
                                Color(0xFFFFFFFF),
                                Color(0xFFD1D5DB),
                                Color(0xFF9CA3AF),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'by Drixel Labs Incorporation',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'P R E M I U M   M E S S A G I N G',
                            style: GoogleFonts.outfit(
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
