import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'active_call_manager.dart';
class FloatingCallOverlay extends StatefulWidget {
  const FloatingCallOverlay({super.key});

  static OverlayEntry? _entry;
  static BuildContext? _overlayContext;

  static void show(BuildContext context) {
    if (_entry != null) return;
    _overlayContext = context;
    _entry = OverlayEntry(
      builder: (ctx) => const FloatingCallOverlay(),
    );
    Overlay.of(context).insert(_entry!);
  }

  static void remove() {
    _entry?.remove();
    _entry = null;
    _overlayContext = null;
  }

  @override
  State<FloatingCallOverlay> createState() => _FloatingCallOverlayState();
}

class _FloatingCallOverlayState extends State<FloatingCallOverlay> {
  double xOffset = 20.0;
  double yOffset = 80.0;

  @override
  void initState() {
    super.initState();
    ActiveCallManager.instance.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    ActiveCallManager.instance.onStateChanged = null;
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final manager = ActiveCallManager.instance;
    if (manager.activeCallId == null) {
      // Safely auto-remove if call is ended
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FloatingCallOverlay.remove();
      });
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final width = 150.0;
    final height = 220.0;

    // Constrain position to screen bounds
    xOffset = xOffset.clamp(0.0, size.width - width);
    yOffset = yOffset.clamp(50.0, size.height - height - 50.0);

    final showVideo = manager.isVideo && !manager.remoteCameraOn && manager.connected;

    return Positioned(
      left: xOffset,
      top: yOffset,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            xOffset += details.delta.dx;
            yOffset += details.delta.dy;
          });
        },
        onTap: () {
          // Restore the Call Screen!
          FloatingCallOverlay.remove();
          manager.isMinimized = false;
          final ctx = FloatingCallOverlay._overlayContext ?? context;
          final nameParam = manager.remoteUserName != null ? Uri.encodeComponent(manager.remoteUserName!) : '';
          final photoParam = manager.remotePhotoUrl != null ? Uri.encodeComponent(manager.remotePhotoUrl!) : '';
          ctx.push('/call-room/${manager.activeCallId}?caller=${manager.isCaller}&video=${manager.isVideo}&name=$nameParam&photoUrl=$photoParam');
        },
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF16161A),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // Video View / Avatar View
                  Builder(
                    builder: (context) {
                      final activeRemoteUidWithCamera = manager.remoteCameraStatuses.entries
                          .firstWhere((e) => e.value == true, orElse: () => const MapEntry('', false))
                          .key;
                      final hasRemoteVideo = manager.isVideo &&
                          activeRemoteUidWithCamera.isNotEmpty &&
                          manager.remoteRenderers.containsKey(activeRemoteUidWithCamera) &&
                          manager.remoteRenderers[activeRemoteUidWithCamera]?.srcObject != null;

                      final showRenderer = hasRemoteVideo || (manager.isVideo && manager.remoteRenderer.srcObject != null && manager.remoteCameraOn);
                      final rendererToUse = hasRemoteVideo ? manager.remoteRenderers[activeRemoteUidWithCamera]! : manager.remoteRenderer;

                      if (showRenderer) {
                        return Positioned.fill(
                          child: RTCVideoView(
                            rendererToUse,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        );
                      }

                      return Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF121214), Color(0xFF1E1E22)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white10,
                                backgroundImage: manager.remotePhotoUrl != null
                                    ? NetworkImage(manager.remotePhotoUrl!)
                                    : null,
                                child: manager.remotePhotoUrl == null
                                    ? const Icon(Icons.person, color: Colors.white54, size: 28)
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                manager.remoteUserName ?? 'Active Call',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Call Status / Time
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 8),
                          const SizedBox(width: 4),
                          Text(
                            manager.connected ? _formatDuration(manager.durationSeconds) : 'Connecting',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Mini Quick controls at bottom
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mic Button
                        GestureDetector(
                          onTap: () {
                            manager.muted = !manager.muted;
                            manager.localStream?.getAudioTracks().forEach((track) {
                              track.enabled = !manager.muted;
                            });
                            if (manager.onStateChanged != null) manager.onStateChanged!();
                            setState(() {});
                          },
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: manager.muted ? Colors.redAccent : Colors.white24,
                            child: Icon(
                              manager.muted ? Icons.mic_off : Icons.mic,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),

                        // Hangup Button
                        GestureDetector(
                          onTap: () async {
                            final activeId = manager.activeCallId;
                            if (activeId != null) {
                              try {
                                await AppDatabase.instance
                                    .table('calls')
                                    .doc(activeId)
                                    .update({'status': 'ended'});
                              } catch (e) {
                                debugPrint('Error ending minimized call: $e');
                              }
                            }
                            manager.clear();
                            FloatingCallOverlay.remove();
                          },
                          child: const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.redAccent,
                            child: Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
