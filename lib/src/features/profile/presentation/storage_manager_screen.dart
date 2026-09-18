import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

class SettingsStorageManagerScreen extends StatefulWidget {
  const SettingsStorageManagerScreen({super.key});

  @override
  State<SettingsStorageManagerScreen> createState() => _SettingsStorageManagerScreenState();
}

class _SettingsStorageManagerScreenState extends State<SettingsStorageManagerScreen> {
  bool _loading = true;
  double _imagesSizeMB = 0.0;
  double _videosSizeMB = 0.0;
  double _audiosSizeMB = 0.0;
  double _tempSizeMB = 0.0;

  double _totalDeviceSpaceMB = 0.0;
  double _freeDeviceSpaceMB = 0.0;

  @override
  void initState() {
    super.initState();
    _calculateStorageSizes();
  }

  Future<void> _calculateStorageSizes() async {
    setState(() {
      _loading = true;
    });

    try {
      final cacheDir = await getTemporaryDirectory();
      final docsDir = await getApplicationDocumentsDirectory();

      double imgBytes = 0.0;
      double vidBytes = 0.0;
      double audBytes = 0.0;
      double tempBytes = 0.0;

      // Scan directories recursively
      await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final size = await entity.length();
            final path = entity.path.toLowerCase();
            if (path.contains('.jpg') || path.contains('.png') || path.contains('.webp') || path.contains('.jpeg') || path.contains('libcachedimagedata')) {
              imgBytes += size;
            } else if (path.contains('.mp4') || path.contains('.mov') || path.contains('.m4v')) {
              vidBytes += size;
            } else if (path.contains('.mp3') || path.contains('.m4a') || path.contains('.wav') || path.contains('.ogg')) {
              audBytes += size;
            } else {
              tempBytes += size;
            }
          } catch (_) {}
        }
      }

      await for (final entity in docsDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final size = await entity.length();
            final path = entity.path.toLowerCase();
            if (path.contains('.jpg') || path.contains('.png') || path.contains('.webp') || path.contains('.jpeg')) {
              imgBytes += size;
            } else if (path.contains('.mp4') || path.contains('.mov') || path.contains('.m4v')) {
              vidBytes += size;
            } else if (path.contains('.mp3') || path.contains('.m4a') || path.contains('.wav') || path.contains('.ogg')) {
              audBytes += size;
            } else {
              tempBytes += size;
            }
          } catch (_) {}
        }
      }

      double totalSpace = 0.0;
      double freeSpace = 0.0;
      try {
        const channel = MethodChannel('com.achatz.app/storage');
        final totalBytes = await channel.invokeMethod<int>('getTotalDiskSpace') ?? 0;
        final freeBytes = await channel.invokeMethod<int>('getFreeDiskSpace') ?? 0;
        totalSpace = totalBytes / (1024 * 1024);
        freeSpace = freeBytes / (1024 * 1024);
      } catch (_) {}

      setState(() {
        _imagesSizeMB = imgBytes / (1024 * 1024);
        _videosSizeMB = vidBytes / (1024 * 1024);
        _audiosSizeMB = audBytes / (1024 * 1024);
        _tempSizeMB = tempBytes / (1024 * 1024);
        _totalDeviceSpaceMB = totalSpace;
        _freeDeviceSpaceMB = freeSpace;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _imagesSizeMB = 0.0;
        _videosSizeMB = 0.0;
        _audiosSizeMB = 0.0;
        _tempSizeMB = 0.0;
        _loading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _loading = true;
    });

    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      
      // Reset sizes dynamically!
      setState(() {
        _imagesSizeMB = 0.0;
        _videosSizeMB = 0.0;
        _audiosSizeMB = 0.0;
        _tempSizeMB = 0.0;
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("A-Chatz local storage cache wiped successfully!"),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error cleaning cache: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  double get _totalSizeMB => _imagesSizeMB + _videosSizeMB + _audiosSizeMB + _tempSizeMB;

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Local Storage Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Disk Usage Circle HUD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.storage_rounded, color: Colors.greenAccent, size: 44),
                          const SizedBox(height: 12),
                          const Text("Total A-Chatz Cache", style: TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            "${_totalSizeMB.toStringAsFixed(1)} MB",
                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          if (_totalDeviceSpaceMB > 0) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    const Text("Device Total", style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text("${(_totalDeviceSpaceMB / 1024).toStringAsFixed(1)} GB", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Text("Device Free", style: TextStyle(color: Colors.white54, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text("${(_freeDeviceSpaceMB / 1024).toStringAsFixed(1)} GB", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Text(
                            "This cache contains locally saved files to keep conversations lightning fast and reduce data usage.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Category List Breakdown
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Storage Breakdown",
                        style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildStorageCategoryTile(
                      icon: Icons.image_outlined,
                      color: Colors.blueAccent,
                      title: "Images & Photos",
                      sizeMB: _imagesSizeMB,
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _buildStorageCategoryTile(
                      icon: Icons.videocam_outlined,
                      color: Colors.purpleAccent,
                      title: "Videos & Reels",
                      sizeMB: _videosSizeMB,
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _buildStorageCategoryTile(
                      icon: Icons.mic_none_outlined,
                      color: Colors.orangeAccent,
                      title: "Voice Notes & Audio",
                      sizeMB: _audiosSizeMB,
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _buildStorageCategoryTile(
                      icon: Icons.folder_open_outlined,
                      color: Colors.greenAccent,
                      title: "Temporary Metadata Files",
                      sizeMB: _tempSizeMB,
                    ),

                    const SizedBox(height: 40),

                    // Clear Storage Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _totalSizeMB < 0.1 ? null : _clearCache,
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: const Text("Wipe Local Storage Cache", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.9),
                          disabledBackgroundColor: Colors.white12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStorageCategoryTile({
    required IconData icon,
    required Color color,
    required String title,
    required double sizeMB,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Text(
            "${sizeMB.toStringAsFixed(2)} MB",
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
