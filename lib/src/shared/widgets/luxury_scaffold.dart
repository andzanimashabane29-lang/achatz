import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/logo_doodle_background.dart';

class LuxuryScaffold extends StatelessWidget {
  const LuxuryScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.appBar,
    this.floatingActionButton,
  });

  final Widget child;
  final EdgeInsets padding;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          const LogoDoodleBackground(),
          SafeArea(
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0x1EFFFFFF) : const Color(0x1E000000),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0x2AFFFFFF) : const Color(0x2A000000)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 18)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
