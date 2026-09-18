import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';

class IncomingCallOverlayManager {
  static final IncomingCallOverlayManager instance = IncomingCallOverlayManager._();
  IncomingCallOverlayManager._();

  OverlayEntry? _entry;
  AudioPlayer? _ringtonePlayer;

  void show({
    required BuildContext context,
    required String callId,
    required String callerName,
    required String? callerPhotoUrl,
    required bool isVideo,
    required VoidCallback onDecline,
    required VoidCallback onAnswer,
  }) {
    if (_entry != null) return;

    _playRingtone();

    _entry = OverlayEntry(
      builder: (ctx) => _IncomingCallBanner(
        callId: callId,
        callerName: callerName,
        callerPhotoUrl: callerPhotoUrl,
        isVideo: isVideo,
        onDecline: () {
          _stopRingtone();
          remove();
          onDecline();
        },
        onAnswer: () {
          _stopRingtone();
          onAnswer();
          Future.delayed(const Duration(milliseconds: 600), () => remove());
        },
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  void remove() {
    _stopRingtone();
    _entry?.remove();
    _entry = null;
  }

  void _playRingtone() async {
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
    if (isMobile) {
      try {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.electronic,
          looping: true,
          volume: 1.0,
          asAlarm: true,
        );
      } catch (_) {}
    } else {
      try {
        _ringtonePlayer = AudioPlayer();
        await _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);
        await _ringtonePlayer!.play(AssetSource('ringtone.mp3'));
      } catch (_) {}
    }
  }

  void _stopRingtone() async {
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
    if (isMobile) {
      try {
        FlutterRingtonePlayer().stop();
      } catch (_) {}
    } else {
      try {
        await _ringtonePlayer?.stop();
        await _ringtonePlayer?.dispose();
        _ringtonePlayer = null;
      } catch (_) {}
    }
  }
}

class _IncomingCallBanner extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerPhotoUrl;
  final bool isVideo;
  final VoidCallback onDecline;
  final VoidCallback onAnswer;

  const _IncomingCallBanner({
    required this.callId,
    required this.callerName,
    required this.callerPhotoUrl,
    required this.isVideo,
    required this.onDecline,
    required this.onAnswer,
  });

  @override
  State<_IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<_IncomingCallBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = (size.width > 500) ? 420.0 : size.width - 24.0;

    return Positioned(
      top: 50.0,
      left: (size.width - width) / 2,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          elevation: 24,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: width,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xEB1A1A1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                // Caller avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white10,
                  backgroundImage: widget.callerPhotoUrl != null
                      ? NetworkImage(widget.callerPhotoUrl!)
                      : null,
                  child: widget.callerPhotoUrl == null
                      ? Text(
                          widget.callerName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // Name & Type text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.callerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.isVideo ? '📹 Incoming Video Call...' : '📞 Incoming Voice Call...',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Decline Action Button
                GestureDetector(
                  onTap: widget.onDecline,
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.redAccent,
                    child: Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Answer Action Button
                GestureDetector(
                  onTap: widget.onAnswer,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.greenAccent.shade700,
                    child: Icon(
                      widget.isVideo ? Icons.videocam : Icons.call,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
