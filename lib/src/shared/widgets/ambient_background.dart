import 'package:flutter/material.dart';

enum ChatThemePreset {
  none,
  neonEclipse,
  auroraBorealis,
  cyberpunkAmber,
  obsidianOled,
  cyberpunkNeon,
}

class AmbientBackground extends StatelessWidget {
  final ChatThemePreset theme;
  final Widget child;

  const AmbientBackground({
    Key? key,
    required this.theme,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Strictly forced to Theme Background to prevent any neon color bleeding
    return Container(
      color: Theme.of(context).colorScheme.background,
      child: child,
    );
  }
}
