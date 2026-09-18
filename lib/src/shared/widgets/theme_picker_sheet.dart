import 'package:a_chatz/src/core/theme/app_theme_preset.dart';
import 'package:a_chatz/src/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showThemePickerSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF101012),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Consumer(
        builder: (_, ref, __) {
          final settings = ref.watch(themeProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'App theme',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose a color style. Use brightness below for light, dark, or system.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: AppThemePreset.values.length,
                    itemBuilder: (_, i) {
                      final preset = AppThemePreset.values[i];
                      final selected = settings.preset == preset;
                      return GestureDetector(
                        onTap: () =>
                            ref.read(themeProvider.notifier).setPreset(preset),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: preset.previewColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF00FFB2)
                                      : Colors.white24,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              child: Icon(
                                preset.icon,
                                color: preset.isDarkByDefault
                                    ? Colors.white70
                                    : Colors.black54,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              preset.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? const Color(0xFF00FFB2)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Brightness',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.phone_android_outlined, size: 16),
                      ),
                    ],
                    selected: {settings.mode},
                    onSelectionChanged: (set) {
                      ref.read(themeProvider.notifier).setMode(set.first);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
