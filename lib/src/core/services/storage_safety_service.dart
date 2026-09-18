import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:a_chatz/src/core/router/app_router.dart';

class StorageSafetyService {
  static final StorageSafetyService instance = StorageSafetyService._();
  StorageSafetyService._();

  static const _channel = MethodChannel('com.achatz.app/storage');
  static const double _minRequiredSpaceMb = 50.0; // Show "Storage Full" if free space is below 50MB
  static const double _bytesInMb = 1024 * 1024;

  bool _isOverlayOpen = false;
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _checkStoragePeriodically();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkStoragePeriodically();
    });
  }

  void stop() {
    _timer?.cancel();
  }

  Future<void> _checkStoragePeriodically() async {
    try {
      final freeSpaceBytes = await _getFreeSpaceBytes();
      if (freeSpaceBytes != null) {
        final freeSpaceMb = freeSpaceBytes / _bytesInMb;
        debugPrint('Available Free Storage Space: ${freeSpaceMb.toStringAsFixed(2)} MB');
        if (freeSpaceMb < _minRequiredSpaceMb) {
          _showStorageFullOverlay();
        } else {
          _hideStorageFullOverlay();
        }
      }
    } catch (e) {
      debugPrint('Error checking storage space: $e');
    }
  }

  Future<int?> _getFreeSpaceBytes() async {
    if (kIsWeb) return null; // Web platform storage is handled by browser quota

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final int? freeBytes = await _channel.invokeMethod<int>('getFreeDiskSpace');
        return freeBytes;
      } else if (Platform.isWindows) {
        // Run wmic to get free disk space for C: drive on Windows
        final result = await Process.run('wmic', [
          'logicaldisk',
          'where',
          'DeviceID="C:"',
          'get',
          'FreeSpace'
        ]);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          for (final line in lines) {
            final clean = line.trim();
            if (clean.isNotEmpty && clean != 'FreeSpace') {
              return int.tryParse(clean);
            }
          }
        }
      } else if (Platform.isMacOS || Platform.isLinux) {
        // Run df to check space on Unix systems
        final result = await Process.run('df', ['-b', '/']);
        if (result.exitCode != 0) {
          // Fallback if -b is unsupported
          final resultK = await Process.run('df', ['-k', '/']);
          if (resultK.exitCode == 0) {
            final output = resultK.stdout.toString();
            final matches = RegExp(r'\/\s*$').hasMatch(output) 
                ? output 
                : resultK.stdout.toString();
            final parts = matches.split('\n')[1].split(RegExp(r'\s+'));
            if (parts.length > 3) {
              final freeKb = int.tryParse(parts[3]);
              if (freeKb != null) return freeKb * 1024;
            }
          }
        } else {
          final lines = result.stdout.toString().split('\n');
          if (lines.length > 1) {
            final parts = lines[1].split(RegExp(r'\s+'));
            if (parts.length > 3) {
              return int.tryParse(parts[3]);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Platform storage check failed: $e');
    }

    // Secondary fallback: Try writing a test file to detect if disk is full
    try {
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/chatz_space_test.tmp');
      await testFile.writeAsBytes(List<int>.generate(1024 * 1024, (_) => 0)); // Write 1MB test file
      await testFile.delete();
      return 100 * 1024 * 1024; // If writing succeeded, assume space is OK (say 100MB)
    } catch (e) {
      if (e is FileSystemException) {
        return 0; // If write failed due to disk space, return 0 (Storage Full)
      }
    }

    return null;
  }

  void _showStorageFullOverlay() {
    final context = rootNavigatorKey.currentContext;
    if (context == null || _isOverlayOpen) return;

    _isOverlayOpen = true;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.95),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.25),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.disc_full_rounded,
                        size: 64,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Storage is Full',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your device has run out of storage space. You cannot use A-Chatz to send or receive messages, media, or make calls until you free up space.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideStorageFullOverlay() {
    if (!_isOverlayOpen) return;
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      Navigator.pop(context);
    }
    _isOverlayOpen = false;
  }
}
