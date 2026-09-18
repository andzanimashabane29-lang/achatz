import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:a_chatz/src/shared/widgets/wallpaper_background.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperPickerScreen extends StatefulWidget {
  const WallpaperPickerScreen({super.key});

  @override
  State<WallpaperPickerScreen> createState() => _WallpaperPickerScreenState();
}

class _WallpaperPickerScreenState extends State<WallpaperPickerScreen> {
  final List<String> wallpapers = [
    'assets/wallpapers/default.jpg',
    'assets/wallpapers/luxury_dark.jpg',
    'assets/wallpapers/royal_blue.jpg',
    'assets/wallpapers/emerald_green.jpg',
    'assets/wallpapers/deep_crimson.jpg',
    'assets/wallpapers/obsidian_gold.jpg',
  ];

  String? selectedWallpaper;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedWallpaper = prefs.getString('chat_wallpaper_path');
    });
  }

  Future<void> _save(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_wallpaper_path', path);
    setState(() {
      selectedWallpaper = path;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallpaper updated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium Wallpapers',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Choose a luxury background for your conversations',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.6,
              ),
              itemCount: wallpapers.length,
              itemBuilder: (context, index) {
                final wp = wallpapers[index];
                final isSelected = selectedWallpaper == wp;
                
                return GestureDetector(
                  onTap: () => _save(wp),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.greenAccent : Colors.white10,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          WallpaperBackground(
                            wallpaperPath: wp,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  wp.split('/').last.replaceAll('.jpg', '').replaceAll('_', ' ').toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Positioned(
                              top: 10,
                              right: 10,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.greenAccent,
                                child: Icon(Icons.check, size: 16, color: Colors.black),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('chat_wallpaper_path');
                setState(() => selectedWallpaper = null);
              },
              child: const Text('Reset to Default', style: TextStyle(color: Colors.redAccent)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForWallpaper(String path) {
    if (path.contains('default')) return const Color(0xFF0F0F11);
    if (path.contains('luxury_dark')) return const Color(0xFF1A1A1D);
    if (path.contains('royal_blue')) return const Color(0xFF0D1B2A);
    if (path.contains('emerald_green')) return const Color(0xFF0B201F);
    if (path.contains('deep_crimson')) return const Color(0xFF2D0A0A);
    if (path.contains('obsidian_gold')) return const Color(0xFF1C1C1C);
    return Colors.black;
  }
}
