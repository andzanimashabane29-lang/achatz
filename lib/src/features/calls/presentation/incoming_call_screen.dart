import 'package:a_chatz/src/features/calls/providers/call_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:a_chatz/src/shared/widgets/ambient_background.dart';
import 'dart:async';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.isVideo,
    required this.callerName,
  });

  final String callId;
  final bool isVideo;
  final String callerName;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  AudioPlayer? _webRingtonePlayer;
  StreamSubscription? _statusSubscription;

  void _playWebRingtone() async {
    try {
      _webRingtonePlayer = AudioPlayer();
      await _webRingtonePlayer!.setReleaseMode(ReleaseMode.loop);
      await _webRingtonePlayer!.play(AssetSource('ringtone.mp3'));
    } catch (e) {
      debugPrint('Error playing web ringtone: $e');
    }
  }

  void _stopWebRingtone() async {
    try {
      await _webRingtonePlayer?.stop();
      await _webRingtonePlayer?.dispose();
      _webRingtonePlayer = null;
    } catch (e) {
      debugPrint('Error stopping web ringtone: $e');
    }
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
      _playWebRingtone();
    }
  }

  void _stopRingtone() async {
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
    if (isMobile) {
      try {
        FlutterRingtonePlayer().stop();
      } catch (_) {}
    } else {
      _stopWebRingtone();
    }
  }

  @override
  void initState() {
    super.initState();
    _playRingtone();

    _statusSubscription = ref.read(callRepositoryProvider)
        .callStream(widget.callId)
        .listen((snap) {
      if (!snap.exists) {
        _stopRingtone();
        if (mounted) context.pop();
        return;
      }
      final data = snap.data();
      final status = data?['status'] as String? ?? 'ringing';
      if (status == 'ended' || status == 'declined' || status == 'cancelled') {
        _stopRingtone();
        if (mounted) context.pop();
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _stopRingtone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      theme: ChatThemePreset.neonEclipse,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              const CircleAvatar(
                radius: 64,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  color: Colors.black,
                  size: 56,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                widget.callerName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.isVideo ? 'Incoming video call' : 'Incoming voice call',
                style: const TextStyle(color: Colors.white70),
              ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.redAccent,
                    child: IconButton(
                      icon: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        _stopRingtone();
                        await ref
                            .read(callRepositoryProvider)
                            .declineCall(widget.callId);

                        if (context.mounted) {
                          context.pop();
                        }
                      },
                    ),
                  ),

                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.green,
                    child: IconButton(
                      icon: Icon(
                        widget.isVideo ? Icons.videocam : Icons.call,
                        color: Colors.white,
                      ),
                       onPressed: () async {
                        _stopRingtone();
                        final nameParam = Uri.encodeComponent(widget.callerName);
                        await ref.read(callRepositoryProvider).answerCall(widget.callId);
                        if (context.mounted) {
                          context.push(
                            '/call-room/${widget.callId}?caller=false&video=${widget.isVideo}&name=$nameParam',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}