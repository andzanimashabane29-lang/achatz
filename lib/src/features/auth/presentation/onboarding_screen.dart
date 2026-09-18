import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Three staggered stages: hero text, subtitle, buttons
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _subFade;
  late final Animation<Offset> _subSlide;
  late final Animation<double> _buttonsFade;
  late final Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.55, curve: Curves.easeOut)),
    );

    _subFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.75, curve: Curves.easeOut)),
    );
    _subSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.75, curve: Curves.easeOut)),
    );

    _buttonsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 1.0, curve: Curves.easeOut)),
    );
    _buttonsSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 1.0, curve: Curves.easeOut)),
    );

    // Start animation after first frame so the background is painted first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Hero glass card — fade + slide in first
              FadeTransition(
                opacity: _heroFade,
                child: SlideTransition(
                  position: _heroSlide,
                  child: GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'A-Chatz',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.6,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle fades in slightly after the title
                        FadeTransition(
                          opacity: _subFade,
                          child: SlideTransition(
                            position: _subSlide,
                            child: Text(
                              'Private conversations. Premium presence. '
                              'Real-time luxury messaging for modern communities.',
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.45,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Text(
                          'by Drixel Labs Incorporation',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Buttons fade in last
              FadeTransition(
                opacity: _buttonsFade,
                child: SlideTransition(
                  position: _buttonsSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 58),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Enter A-Chatz',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          // Fixed: use go_router context.push instead of
                          // Navigator.push + MaterialPageRoute, for consistent
                          // navigation history and deep-link support.
                          onPressed: () => context.push('/legal'),
                          child: Text(
                            'Terms, Privacy & Liability',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'By entering A-Chatz you agree to our Terms, Privacy Policy, '
                          'and Limitation of Liability.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
