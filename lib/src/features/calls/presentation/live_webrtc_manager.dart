import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class LiveWebRtcManager {
  static final LiveWebRtcManager instance = LiveWebRtcManager._internal();
  LiveWebRtcManager._internal();

  MediaStream? localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  
  // For up to 6 co-hosts
  final Map<String, RTCPeerConnection> peerConnections = {};
  final Map<String, RTCVideoRenderer> remoteRenderers = {};
  
  bool isInitialized = false;
  String? currentSessionId;
  
  bool isMuted = false;
  bool isCameraOff = false;

  Function()? onStateChange;

  final Map<String, dynamic> config = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      }
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> initLocalRenderer() async {
    if (!isInitialized) {
      await localRenderer.initialize();
      isInitialized = true;
    }
  }

  Future<void> openLocalCamera() async {
    await initLocalRenderer();
    if (localStream != null) return;

    final videoConstraints = {
      'facingMode': 'user', // Front camera — fixes wrong angle
      'width': {'ideal': 1920, 'min': 1280},
      'height': {'ideal': 1080, 'min': 720},
      'frameRate': {'ideal': 30, 'min': 15},
      'aspectRatio': {'ideal': 1.7778}, // 16:9
    };

    // First attempt: HD quality
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': videoConstraints,
      });
      localStream = stream;
      localRenderer.srcObject = stream;
      onStateChange?.call();
    } catch (e) {
      debugPrint('Live stream HD camera failed, trying 720p: $e');
      // Second attempt: 720p fallback
      try {
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
            'frameRate': {'ideal': 30},
          },
        });
        localStream = stream;
        localRenderer.srcObject = stream;
        onStateChange?.call();
      } catch (e2) {
        debugPrint('Live stream 720p failed, trying basic front camera: $e2');
        // Third attempt: basic front camera (fixes angle)
        try {
          final stream = await navigator.mediaDevices.getUserMedia({
            'audio': true,
            'video': {'facingMode': 'user'},
          });
          localStream = stream;
          localRenderer.srcObject = stream;
          onStateChange?.call();
        } catch (e3) {
          debugPrint('Live stream front camera failed, last resort: $e3');
          try {
            final stream = await navigator.mediaDevices.getUserMedia({
              'audio': true,
              'video': true,
            });
            localStream = stream;
            localRenderer.srcObject = stream;
            onStateChange?.call();
          } catch (err) {
            debugPrint('All Live stream getUserMedia attempts failed: $err');
          }
        }
      }
    }
  }

  Future<void> setupPeerConnection(String sessionId, String otherUid, bool isOfferer) async {
    if (peerConnections.containsKey(otherUid)) return;
    await openLocalCamera();
    currentSessionId = sessionId;

    final pc = await createPeerConnection(config);
    peerConnections[otherUid] = pc;

    final remoteRenderer = RTCVideoRenderer();
    await remoteRenderer.initialize();
    remoteRenderers[otherUid] = remoteRenderer;

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await pc.addTrack(track, localStream!);
      }
    }

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        onStateChange?.call();
      }
    };

    final myUid = AppAuth.instance.currentUser?.uid ?? '';
    final smallUid = isOfferer ? myUid : otherUid;
    final largeUid = isOfferer ? otherUid : myUid;
    final connDocId = '${smallUid}_${largeUid}';

    final connRef = AppDatabase.instance
        .table('live_sessions')
        .doc(sessionId)
        .table('connections')
        .doc(connDocId);

    pc.onIceCandidate = (candidate) async {
      if (candidate == null) return;
      try {
        await connRef
            .table(isOfferer ? 'candidates_offerer' : 'candidates_answerer')
            .add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('Error sending ICE: $e');
      }
    };

    if (isOfferer) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      await connRef.set({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'answer': null,
      });

      connRef.snapshots().listen((snap) async {
        final data = snap.data();
        if (data != null && data['answer'] != null) {
          final answer = data['answer'];
          final desc = RTCSessionDescription(answer['sdp'], answer['type']);
          final currentState = await pc.getRemoteDescription();
          if (currentState == null) {
            await pc.setRemoteDescription(desc);
          }
        }
      });

      connRef.table('candidates_answerer').snapshots().listen((snap) async {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final candidate = RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              );
              await pc.addCandidate(candidate);
            }
          }
        }
      });
    } else {
      // Answerer logic
      connRef.snapshots().listen((snap) async {
        final data = snap.data();
        if (data != null && data['offer'] != null) {
          final offer = data['offer'];
          final currentState = await pc.getRemoteDescription();
          if (currentState == null) {
            final desc = RTCSessionDescription(offer['sdp'], offer['type']);
            await pc.setRemoteDescription(desc);

            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);

            await connRef.update({
              'answer': {
                'type': answer.type,
                'sdp': answer.sdp,
              }
            });
          }
        }
      });

      connRef.table('candidates_offerer').snapshots().listen((snap) async {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final candidate = RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              );
              await pc.addCandidate(candidate);
            }
          }
        }
      });
    }
    
    onStateChange?.call();
  }
  
  Future<void> removePeerConnection(String otherUid) async {
    final pc = peerConnections.remove(otherUid);
    await pc?.close();
    
    final renderer = remoteRenderers.remove(otherUid);
    renderer?.srcObject = null;
    await renderer?.dispose();
    
    onStateChange?.call();
  }

  void toggleMute() {
    isMuted = !isMuted;
    if (localStream != null) {
      for (final track in localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
    onStateChange?.call();
  }

  void toggleCamera() {
    isCameraOff = !isCameraOff;
    if (localStream != null) {
      for (final track in localStream!.getVideoTracks()) {
        track.enabled = !isCameraOff;
      }
    }
    onStateChange?.call();
  }

  Future<void> stop() async {
    localRenderer.srcObject = null;
    
    for (var renderer in remoteRenderers.values) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
    remoteRenderers.clear();
    
    localStream?.getTracks().forEach((track) {
      track.stop();
    });
    await localStream?.dispose();
    localStream = null;

    for (var pc in peerConnections.values) {
      await pc.close();
    }
    peerConnections.clear();

    currentSessionId = null;
    isMuted = false;
    isCameraOff = false;
    onStateChange?.call();
  }
}
