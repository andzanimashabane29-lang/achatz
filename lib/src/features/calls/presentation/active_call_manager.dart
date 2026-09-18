import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:audioplayers/audioplayers.dart';

class ActiveCallManager {
  static final ActiveCallManager instance = ActiveCallManager._();
  ActiveCallManager._();

  String? activeCallId;
  bool isCaller = false;
  bool isVideo = false;
  bool connected = false;
  bool muted = false;
  bool cameraOff = true; // Default privacy first
  bool speakerOn = true;
  bool sharingScreen = false;
  int durationSeconds = 0;
  String? remoteUserName;
  String? remotePhotoUrl;
  bool swapViews = false;
  bool remoteCameraOn = true;

  RTCPeerConnection? peer;
  MediaStream? localStream;
  MediaStream? screenStream;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  final Map<String, RTCPeerConnection> peerConnections = {};
  final Map<String, MediaStream> remoteStreams = {};
  final Map<String, RTCVideoRenderer> remoteRenderers = {};
  final Map<String, bool> remoteCameraStatuses = {};
  final Map<String, bool> remoteMuteStatuses = {};
  final Map<String, bool> remoteScreenSharingStatuses = {};

  bool isMinimized = false;
  Timer? _callTimer;
  VoidCallback? onStateChanged;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _statusSubscription;

  void listenToCallStatus(String callId) {
    _statusSubscription?.cancel();
    _statusSubscription = AppDatabase.instance
        .table('calls')
        .doc(callId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data == null) return;

      final status = data['status'];
      if (status == 'ended' || status == 'declined') {
        clear();
      }
    });
  }

  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  void startCallTimer(Function(int) onTick) {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      durationSeconds++;
      onTick(durationSeconds);
      if (onStateChanged != null) onStateChanged!();
    });
  }

  void stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  void clear() {
    _statusSubscription?.cancel();
    _statusSubscription = null;
    stopCallTimer();
    peer?.close();
    peer = null;
    localStream?.getTracks().forEach((t) => t.stop());
    localStream = null;
    screenStream?.getTracks().forEach((t) => t.stop());
    screenStream = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    peerConnections.forEach((uid, pc) {
      try { pc.close(); } catch (_) {}
    });
    peerConnections.clear();
    remoteStreams.forEach((uid, stream) {
      try { stream.getTracks().forEach((t) => t.stop()); } catch (_) {}
    });
    remoteStreams.clear();
    remoteRenderers.forEach((uid, r) {
      try {
        r.srcObject = null;
        r.dispose();
      } catch (_) {}
    });
    remoteRenderers.clear();
    remoteCameraStatuses.clear();
    remoteMuteStatuses.clear();
    remoteScreenSharingStatuses.clear();

    activeCallId = null;
    isMinimized = false;
    durationSeconds = 0;
    connected = false;
    muted = false;
    cameraOff = true;
    sharingScreen = false;
    swapViews = false;
    remoteCameraOn = true;
    if (onStateChanged != null) onStateChanged!();
  }
}
