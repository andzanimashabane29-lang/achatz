import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui';

// ──────────────────────────────────────────────────────────────────────────────
// Data Models
// ──────────────────────────────────────────────────────────────────────────────

class CallFilterPreset {
  const CallFilterPreset({
    required this.name,
    required this.icon,
    required this.matrix,
    this.blurSigma = 0.0,
    this.gradient,
    this.overlayOpacity = 0.0,
    this.overlayColor = Colors.transparent,
  });

  final String name;
  final String icon;
  final List<double> matrix;
  final double blurSigma;
  final Gradient? gradient;
  final double overlayOpacity;
  final Color overlayColor;
}

class CallBackgroundPreset {
  const CallBackgroundPreset({
    required this.name,
    required this.icon,
    required this.gradient,
    this.emoji = '',
    this.blurSigma = 0.0,
  });

  final String name;
  final String icon;
  final Gradient gradient;
  final String emoji;
  final double blurSigma;
}

class CallFrameEffect {
  const CallFrameEffect({
    required this.name,
    required this.icon,
    required this.colors,
    this.emoji = '',
  });

  final String name;
  final String icon;
  final List<Color> colors;
  final String emoji;
}

// ──────────────────────────────────────────────────────────────────────────────
// State
// ──────────────────────────────────────────────────────────────────────────────

class CallEffectsState {
  CallEffectsState({
    this.filterIndex = -1,
    this.backgroundIndex = -1,
    this.frameIndex = -1,
    this.beautyMode = false,
  });

  int filterIndex;
  int backgroundIndex;
  int frameIndex;
  bool beautyMode;

  bool get hasAnyEffect =>
      filterIndex >= 0 || backgroundIndex >= 0 || frameIndex >= 0 || beautyMode;

  CallEffectsState copyWith({
    int? filterIndex,
    int? backgroundIndex,
    int? frameIndex,
    bool? beautyMode,
  }) {
    return CallEffectsState(
      filterIndex: filterIndex ?? this.filterIndex,
      backgroundIndex: backgroundIndex ?? this.backgroundIndex,
      frameIndex: frameIndex ?? this.frameIndex,
      beautyMode: beautyMode ?? this.beautyMode,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Static Presets
// ──────────────────────────────────────────────────────────────────────────────

final kCallFilters = <CallFilterPreset>[
  const CallFilterPreset(
    name: 'Beauty',
    icon: '✨',
    blurSigma: 0.8,
    matrix: [
      1.05, 0,    0,    0, 5,
      0,    1.05, 0,    0, 5,
      0,    0,    1.05, 0, 5,
      0,    0,    0,    1, 0,
    ],
  ),
  const CallFilterPreset(
    name: 'Cinema',
    icon: '🎬',
    matrix: [
      0.60, 0.30, 0.10, 0, -8,
      0.10, 0.70, 0.20, 0, -5,
      0.05, 0.15, 0.80, 0,  0,
      0,    0,    0,    1,  0,
    ],
  ),
  const CallFilterPreset(
    name: 'Warm',
    icon: '🌅',
    matrix: [
      1.20, 0,    0,    0, 20,
      0,    1.05, 0,    0,  5,
      0,    0,    0.85, 0, -10,
      0,    0,    0,    1,  0,
    ],
  ),
  const CallFilterPreset(
    name: 'Cool',
    icon: '❄️',
    matrix: [
      0.85, 0,    0,    0, -10,
      0,    1.0,  0,    0,  5,
      0,    0,    1.20, 0,  20,
      0,    0,    0,    1,  0,
    ],
  ),
  const CallFilterPreset(
    name: 'Vintage',
    icon: '📷',
    matrix: [
      0.90, 0.10, 0,    0, 10,
      0.08, 0.85, 0.07, 0,  5,
      0,    0.10, 0.80, 0,  0,
      0,    0,    0,    1,  0,
    ],
    overlayColor: Color(0xFFD4974A),
    overlayOpacity: 0.18,
  ),
  const CallFilterPreset(
    name: 'B&W',
    icon: '🖤',
    matrix: [
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0.33, 0.33, 0.33, 0, 0,
      0,    0,    0,    1, 0,
    ],
  ),
  const CallFilterPreset(
    name: 'Neon',
    icon: '💜',
    matrix: [
      1.40, 0,    0,    0,  0,
      0,    0.60, 0,    0, -20,
      0,    0,    1.60, 0,  20,
      0,    0,    0,    1,  0,
    ],
    overlayColor: Color(0xFF7B2FBE),
    overlayOpacity: 0.12,
  ),
  const CallFilterPreset(
    name: 'Cyber',
    icon: '🤖',
    matrix: [
      0.50, 0.50, 0,    0, -10,
      0,    1.20, 0,    0,  20,
      0,    0,    1.10, 0,   5,
      0,    0,    0,    1,   0,
    ],
    overlayColor: Color(0xFF00FF88),
    overlayOpacity: 0.10,
  ),
  const CallFilterPreset(
    name: 'Sunset',
    icon: '🌇',
    matrix: [
      1.30, 0.10, 0,    0, 15,
      0.05, 0.90, 0,    0,  5,
      0,    0,    0.60, 0, -20,
      0,    0,    0,    1,  0,
    ],
    overlayColor: Color(0xFFFF6B35),
    overlayOpacity: 0.15,
  ),
  const CallFilterPreset(
    name: 'Foggy',
    icon: '🌫️',
    blurSigma: 1.5,
    matrix: [
      1.0, 0, 0, 0, 30,
      0, 1.0, 0, 0, 30,
      0, 0, 1.0, 0, 30,
      0, 0, 0,   1,  0,
    ],
    overlayColor: Color(0xFFFFFFFF),
    overlayOpacity: 0.12,
  ),
  const CallFilterPreset(
    name: 'HDR',
    icon: '⚡',
    matrix: [
      1.30, -0.10, -0.10, 0, -5,
      -0.05, 1.30, -0.05, 0, -5,
      -0.05, -0.05, 1.30, 0, -5,
      0,     0,     0,    1,  0,
    ],
  ),
  const CallFilterPreset(
    name: 'Drama',
    icon: '🎭',
    matrix: [
      1.20, -0.05, -0.05, 0, -15,
      -0.10, 1.20, -0.10, 0, -15,
      -0.10, -0.10, 1.20, 0, -15,
      0,     0,     0,    1,   0,
    ],
    overlayColor: Color(0xFF000033),
    overlayOpacity: 0.20,
  ),
];

final kCallBackgrounds = <CallBackgroundPreset>[
  const CallBackgroundPreset(
    name: 'Blur',
    icon: '💨',
    blurSigma: 20,
    gradient: LinearGradient(
      colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  const CallBackgroundPreset(
    name: 'Space',
    icon: '🚀',
    emoji: '🌌',
    gradient: LinearGradient(
      colors: [Color(0xFF0D001A), Color(0xFF1A0033), Color(0xFF000D1A)],
      stops: [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  const CallBackgroundPreset(
    name: 'Office',
    icon: '🏢',
    emoji: '💼',
    gradient: LinearGradient(
      colors: [Color(0xFF1C2B3A), Color(0xFF2C3E50)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  const CallBackgroundPreset(
    name: 'Beach',
    icon: '🏖️',
    emoji: '🌊',
    gradient: LinearGradient(
      colors: [Color(0xFF006994), Color(0xFF00B4D8), Color(0xFFF4D03F)],
      stops: [0.0, 0.6, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  const CallBackgroundPreset(
    name: 'Mountain',
    icon: '⛰️',
    emoji: '🏔️',
    gradient: LinearGradient(
      colors: [Color(0xFF1A1A2E), Color(0xFF2C3E50), Color(0xFF4A4E69)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  const CallBackgroundPreset(
    name: 'City',
    icon: '🌆',
    emoji: '🏙️',
    gradient: LinearGradient(
      colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  const CallBackgroundPreset(
    name: 'Abstract',
    icon: '🎨',
    emoji: '🌈',
    gradient: SweepGradient(
      colors: [
        Color(0xFF7B2FBE),
        Color(0xFF0096FF),
        Color(0xFF00DFA2),
        Color(0xFFFF6B6B),
        Color(0xFF7B2FBE),
      ],
      center: Alignment.center,
    ),
  ),
  const CallBackgroundPreset(
    name: 'Studio',
    icon: '🎙️',
    emoji: '🎬',
    gradient: LinearGradient(
      colors: [Color(0xFF0A0A0A), Color(0xFF1A0A2E), Color(0xFF0A0A0A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  const CallBackgroundPreset(
    name: 'Aurora',
    icon: '🌌',
    emoji: '💚',
    gradient: LinearGradient(
      colors: [Color(0xFF001F3F), Color(0xFF00875A), Color(0xFF7B2FBE), Color(0xFF001F3F)],
      stops: [0.0, 0.35, 0.7, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  const CallBackgroundPreset(
    name: 'Café',
    icon: '☕',
    emoji: '🍵',
    gradient: LinearGradient(
      colors: [Color(0xFF3E2723), Color(0xFF6D4C41), Color(0xFF4E342E)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
];

final kCallFrames = <CallFrameEffect>[
  const CallFrameEffect(
    name: 'Hearts',
    icon: '❤️',
    colors: [Color(0xFFFF4B7D), Color(0xFFFF8FAB)],
    emoji: '❤️',
  ),
  const CallFrameEffect(
    name: 'Stars',
    icon: '⭐',
    colors: [Color(0xFFFFC107), Color(0xFFFFEB3B)],
    emoji: '⭐',
  ),
  const CallFrameEffect(
    name: 'Fire',
    icon: '🔥',
    colors: [Color(0xFFFF6B00), Color(0xFFFF3D00)],
    emoji: '🔥',
  ),
  const CallFrameEffect(
    name: 'Galaxy',
    icon: '🌌',
    colors: [Color(0xFF7B2FBE), Color(0xFF0096FF)],
    emoji: '✨',
  ),
  const CallFrameEffect(
    name: 'Neon',
    icon: '💚',
    colors: [Color(0xFF00FF88), Color(0xFF00DFA2)],
    emoji: '💡',
  ),
  const CallFrameEffect(
    name: 'Crystal',
    icon: '💎',
    colors: [Color(0xFF00B4D8), Color(0xFF90E0EF)],
    emoji: '💎',
  ),
];

// ──────────────────────────────────────────────────────────────────────────────
// Video View Wrapper — applies effects to any child widget
// ──────────────────────────────────────────────────────────────────────────────

class CallEffectsWrapper extends StatelessWidget {
  const CallEffectsWrapper({
    super.key,
    required this.child,
    required this.state,
    this.showBackground = false,
  });

  final Widget child;
  final CallEffectsState state;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    Widget view = child;

    // Apply beauty mode (soft focus & premium skin smoothing glow)
    if (state.beautyMode) {
      view = Stack(
        fit: StackFit.expand,
        children: [
          view,
          Opacity(
            opacity: 0.38,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  1.06, 0,    0,    0, 10,
                  0,    1.03, 0,    0,  6,
                  0,    0,    1.03, 0,  6,
                  0,    0,    0,    1,  0,
                ]),
                child: child,
              ),
            ),
          ),
        ],
      );
    }

    // Apply color filter
    if (state.filterIndex >= 0 && state.filterIndex < kCallFilters.length) {
      final f = kCallFilters[state.filterIndex];

      // Apply blur if filter has it
      if (f.blurSigma > 0) {
        view = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: f.blurSigma, sigmaY: f.blurSigma),
          child: view,
        );
      }

      // Apply color matrix
      view = ColorFiltered(
        colorFilter: ColorFilter.matrix(f.matrix),
        child: view,
      );

      // Apply color overlay
      if (f.overlayOpacity > 0) {
        view = Stack(
          fit: StackFit.expand,
          children: [
            view,
            Container(color: f.overlayColor.withOpacity(f.overlayOpacity)),
          ],
        );
      }
    }

    // Wrap with background
    if (showBackground && state.backgroundIndex >= 0 && state.backgroundIndex < kCallBackgrounds.length) {
      final bg = kCallBackgrounds[state.backgroundIndex];
      view = Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(gradient: bg.gradient),
          ),
          // Background emoji decoration
          if (bg.emoji.isNotEmpty)
            _BackgroundEmojiPattern(emoji: bg.emoji),
          // Apply blur to background if needed (bg blur effect)
          if (bg.blurSigma > 0)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: bg.blurSigma, sigmaY: bg.blurSigma),
              child: Container(color: Colors.transparent),
            ),
          // The actual video
          view,
        ],
      );
    }

    // Apply animated frame effect
    if (state.frameIndex >= 0 && state.frameIndex < kCallFrames.length) {
      final frame = kCallFrames[state.frameIndex];
      view = Stack(
        fit: StackFit.expand,
        children: [
          view,
          _AnimatedFrameBorder(frame: frame),
        ],
      );
    }

    return view;
  }
}

class _BackgroundEmojiPattern extends StatelessWidget {
  const _BackgroundEmojiPattern({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.07,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = (constraints.maxWidth / 60).ceil();
          final rows = (constraints.maxHeight / 60).ceil();
          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols),
            itemCount: cols * rows,
            itemBuilder: (_, __) => Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedFrameBorder extends StatefulWidget {
  const _AnimatedFrameBorder({required this.frame});
  final CallFrameEffect frame;

  @override
  State<_AnimatedFrameBorder> createState() => _AnimatedFrameBorderState();
}

class _AnimatedFrameBorderState extends State<_AnimatedFrameBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return CustomPaint(
          painter: _FrameBorderPainter(
            progress: _ctrl.value,
            colors: widget.frame.colors,
            emoji: widget.frame.emoji,
          ),
        );
      },
    );
  }
}

class _FrameBorderPainter extends CustomPainter {
  _FrameBorderPainter({
    required this.progress,
    required this.colors,
    required this.emoji,
  });

  final double progress;
  final List<Color> colors;
  final String emoji;

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Draw outer neon glow ──
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..color = colors[0].withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(20),
    );
    canvas.drawRRect(rrect, glowPaint);

    // ── 2. Draw crisp linear-gradient border ──
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..shader = LinearGradient(
        colors: [
          colors[0],
          colors[1],
          colors[0],
        ],
        stops: [
          (progress - 0.35).clamp(0.0, 1.0),
          progress,
          (progress + 0.35).clamp(0.0, 1.0),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRRect(rrect, borderPaint);

    // ── 3. Draw animated sparkle dots on the border ──
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final positions = [
      Offset(size.width * ((progress + 0.0) % 1.0), 4),
      Offset(size.width * ((progress + 0.25) % 1.0), 4),
      Offset(size.width * ((progress + 0.5) % 1.0), size.height - 4),
      Offset(size.width * ((progress + 0.75) % 1.0), size.height - 4),
    ];
    for (final p in positions) {
      dotPaint.color = colors[1];
      canvas.drawCircle(p, 4.5, dotPaint);
    }

    // ── 4. Draw 15 floating/drifting particle emojis (Instagram/TikTok style) ──
    if (emoji.isNotEmpty) {
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      for (int i = 0; i < 15; i++) {
        // Deterministic pseudo-random seed values based on index i
        final double startX = (math.sin(i * 12.34) * 0.5 + 0.5) * size.width;
        
        // Vertical progress flow: rises from bottom of screen to top
        final double progressOffset = (i * 0.07) % 1.0;
        final double currentProgress = (progress + progressOffset) % 1.0;
        final double y = size.height - (currentProgress * (size.height + 80));
        
        // Gently sway back and forth
        final double drift = math.sin(currentProgress * 2 * math.pi + (i * 5.0)) * 25.0;
        final double x = (startX + drift).clamp(10.0, size.width - 30.0);
        
        // Fade in near the bottom and fade out near the top
        final double opacity = math.sin(currentProgress * math.pi) * 0.75;
        final double scale = 0.5 + (math.cos(i * 8.9) * 0.5 + 0.5) * 1.0;

        if (opacity <= 0) continue;

        textPainter.text = TextSpan(
          text: emoji,
          style: TextStyle(
            fontSize: 18.0 * scale,
            color: Colors.white.withOpacity(opacity),
          ),
        );
        textPainter.layout();
        
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.sin(currentProgress * 4 + i) * 0.35); // gentle spin
        textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_FrameBorderPainter oldDelegate) => true;
}

// ──────────────────────────────────────────────────────────────────────────────
// Main Effects Panel
// ──────────────────────────────────────────────────────────────────────────────

class CallEffectsPanel extends StatefulWidget {
  const CallEffectsPanel({
    super.key,
    required this.state,
    required this.onStateChanged,
  });

  final CallEffectsState state;
  final ValueChanged<CallEffectsState> onStateChanged;

  @override
  State<CallEffectsPanel> createState() => _CallEffectsPanelState();
}

class _CallEffectsPanelState extends State<CallEffectsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CallEffectsState _state;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _state = CallEffectsState(
      filterIndex: widget.state.filterIndex,
      backgroundIndex: widget.state.backgroundIndex,
      frameIndex: widget.state.frameIndex,
      beautyMode: widget.state.beautyMode,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _update(CallEffectsState newState) {
    setState(() => _state = newState);
    widget.onStateChanged(newState);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0xFF2A2A3A), width: 1)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFF0096FF)],
                  ).createShader(bounds),
                  child: const Text(
                    '✨ Effects & Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                if (_state.hasAnyEffect)
                  GestureDetector(
                    onTap: () {
                      _update(CallEffectsState());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Beauty Mode Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _BeautyModeToggle(
              enabled: _state.beautyMode,
              onChanged: (v) => _update(_state.copyWith(beautyMode: v)),
            ),
          ),
          const SizedBox(height: 16),

          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFF0096FF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '🎨 Filters'),
                  Tab(text: '🖼️ Backgrounds'),
                  Tab(text: '🌟 Frames'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Filters Tab ──
                _FiltersTab(
                  selectedIndex: _state.filterIndex,
                  onSelect: (i) => _update(_state.copyWith(
                    filterIndex: _state.filterIndex == i ? -1 : i,
                  )),
                ),

                // ── Backgrounds Tab ──
                _BackgroundsTab(
                  selectedIndex: _state.backgroundIndex,
                  onSelect: (i) => _update(_state.copyWith(
                    backgroundIndex: _state.backgroundIndex == i ? -1 : i,
                  )),
                ),

                // ── Frames Tab ──
                _FramesTab(
                  selectedIndex: _state.frameIndex,
                  onSelect: (i) => _update(_state.copyWith(
                    frameIndex: _state.frameIndex == i ? -1 : i,
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Beauty Mode Toggle
// ──────────────────────────────────────────────────────────────────────────────

class _BeautyModeToggle extends StatelessWidget {
  const _BeautyModeToggle({required this.enabled, required this.onChanged});
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF7B2FBE), Color(0xFFFF4B7D)],
                )
              : null,
          color: enabled ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? Colors.transparent : Colors.white12,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF7B2FBE).withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            const Text('🌸', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Beauty Mode',
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Smooth skin & soft focus',
                  style: TextStyle(
                    color: enabled ? Colors.white70 : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 26,
              decoration: BoxDecoration(
                color: enabled ? Colors.white.withOpacity(0.25) : Colors.white12,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: enabled ? 22 : 2,
                    top: 3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: enabled ? Colors.white : Colors.white54,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Filters Tab
// ──────────────────────────────────────────────────────────────────────────────

class _FiltersTab extends StatelessWidget {
  const _FiltersTab({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: kCallFilters.length,
      itemBuilder: (context, index) {
        final f = kCallFilters[index];
        final selected = index == selectedIndex;
        return GestureDetector(
          onTap: () => onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF7B2FBE), Color(0xFF0096FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected ? null : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF7B2FBE)
                    : Colors.white.withOpacity(0.08),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF7B2FBE).withOpacity(0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Filter preview swatch
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: _filterSwatchColors(index),
                    ),
                    border: Border.all(
                      color: selected ? Colors.white54 : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(f.icon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  f.name,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Color> _filterSwatchColors(int index) {
    final swatches = [
      [const Color(0xFFFFCDD2), const Color(0xFFF8BBD9)], // Beauty
      [const Color(0xFF263238), const Color(0xFF37474F)], // Cinema
      [const Color(0xFFFF8F00), const Color(0xFFFFD54F)], // Warm
      [const Color(0xFF0288D1), const Color(0xFF80DEEA)], // Cool
      [const Color(0xFF8D6E63), const Color(0xFFD7CCC8)], // Vintage
      [const Color(0xFF424242), const Color(0xFFBDBDBD)], // B&W
      [const Color(0xFF6A1B9A), const Color(0xFFCE93D8)], // Neon
      [const Color(0xFF00897B), const Color(0xFF80CBC4)], // Cyber
      [const Color(0xFFE64A19), const Color(0xFFFFCC80)], // Sunset
      [const Color(0xFFB0BEC5), const Color(0xFFECEFF1)], // Foggy
      [const Color(0xFF1565C0), const Color(0xFF82B1FF)], // HDR
      [const Color(0xFF1A237E), const Color(0xFF283593)], // Drama
    ];
    if (index < swatches.length) {
      return swatches[index].cast<Color>();
    }
    return [Colors.grey.shade700, Colors.grey.shade500];
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Backgrounds Tab
// ──────────────────────────────────────────────────────────────────────────────

class _BackgroundsTab extends StatelessWidget {
  const _BackgroundsTab({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: kCallBackgrounds.length,
      itemBuilder: (context, index) {
        final bg = kCallBackgrounds[index];
        final selected = index == selectedIndex;
        return GestureDetector(
          onTap: () => onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? Colors.white : Colors.white12,
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background gradient preview
                  Container(
                    decoration: BoxDecoration(gradient: bg.gradient),
                  ),
                  // Emoji decoration
                  if (bg.emoji.isNotEmpty)
                    Center(
                      child: Text(
                        bg.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  // Blur overlay for blur bg
                  if (bg.blurSigma > 0)
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(color: Colors.black26),
                    ),
                  // Name label
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: Colors.black45,
                      child: Text(
                        '${bg.icon} ${bg.name}',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Selected checkmark
                  if (selected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Frames Tab
// ──────────────────────────────────────────────────────────────────────────────

class _FramesTab extends StatelessWidget {
  const _FramesTab({required this.selectedIndex, required this.onSelect});
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: kCallFrames.length,
      itemBuilder: (context, index) {
        final frame = kCallFrames[index];
        final selected = index == selectedIndex;
        return GestureDetector(
          onTap: () => onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: frame.colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: selected ? null : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? frame.colors.first.withOpacity(0.8)
                    : Colors.white12,
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: frame.colors.first.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated frame preview
                if (selected)
                  _MiniAnimatedFrame(colors: frame.colors)
                else
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: Text(
                        frame.icon,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  frame.name,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniAnimatedFrame extends StatefulWidget {
  const _MiniAnimatedFrame({required this.colors});
  final List<Color> colors;

  @override
  State<_MiniAnimatedFrame> createState() => _MiniAnimatedFrameState();
}

class _MiniAnimatedFrameState extends State<_MiniAnimatedFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: SweepGradient(
              colors: [
                widget.colors[0],
                widget.colors[1],
                widget.colors[0],
              ],
              startAngle: _ctrl.value * 2 * math.pi,
              endAngle: (_ctrl.value + 1) * 2 * math.pi,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  widget.colors.length > 1 ? '✨' : '⭐',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Live Effects Badge (shown on effects button when active)
// ──────────────────────────────────────────────────────────────────────────────

class EffectsActiveBadge extends StatefulWidget {
  const EffectsActiveBadge({super.key});

  @override
  State<EffectsActiveBadge> createState() => _EffectsActiveBadgeState();
}

class _EffectsActiveBadgeState extends State<EffectsActiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B2FBE), Color(0xFF0096FF)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
