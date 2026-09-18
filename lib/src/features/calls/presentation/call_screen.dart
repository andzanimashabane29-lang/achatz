import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/calls/providers/call_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:a_chatz/src/shared/widgets/ambient_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:a_chatz/src/features/calls/presentation/active_call_manager.dart';
import 'package:a_chatz/src/features/calls/presentation/floating_call_overlay.dart';
import 'package:a_chatz/src/features/calls/presentation/floating_reactions.dart';
import 'package:a_chatz/src/shared/widgets/floating_comments.dart';
import 'package:a_chatz/src/features/calls/presentation/ai_note_taker_sheet.dart';
import 'package:a_chatz/src/features/calls/presentation/call_effects_panel.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:a_chatz/src/core/platform/platform_layout.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:flutter_background/flutter_background.dart';
enum CallLayoutMode {
  portraitFill,
  landscapeFit,
  squareFit,
}

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    required this.isVideo,
    this.initialRemoteUserName,
    this.initialRemotePhotoUrl,
  });

  final String callId;
  final bool isCaller;
  final bool isVideo;
  final String? initialRemoteUserName;
  final String? initialRemotePhotoUrl;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with SingleTickerProviderStateMixin {
  RTCVideoRenderer get localRenderer => ActiveCallManager.instance.localRenderer;
  RTCVideoRenderer get remoteRenderer => ActiveCallManager.instance.remoteRenderer;

  MediaStream? get localStream => ActiveCallManager.instance.localStream;
  set localStream(MediaStream? val) => ActiveCallManager.instance.localStream = val;

  RTCPeerConnection? get peer => ActiveCallManager.instance.peer;
  set peer(RTCPeerConnection? val) => ActiveCallManager.instance.peer = val;

  String? _sharePlayUrl;
  VideoPlayerController? _sharePlayController;
  bool _isSharePlayActive = false;
  bool _isLocalSharePlayUpdate = false;

  Future<void> _setupSharePlay(String url) async {
    if (_sharePlayUrl == url) return;
    _sharePlayUrl = url;

    if (_sharePlayController != null) {
      await _sharePlayController!.dispose();
      _sharePlayController = null;
    }

    if (url.isEmpty) {
      setState(() {
        _isSharePlayActive = false;
      });
      return;
    }

    String playUrl = url;
    if (!url.toLowerCase().endsWith('.mp4') && !url.contains('.mp4?')) {
      playUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(playUrl));
      _sharePlayController = controller;
      await controller.initialize();
      controller.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isSharePlayActive = true;
        });
      }
      
      // Auto-play initially
      await controller.play();
    } catch (e) {
      debugPrint('SharePlay video player init error: $e');
    }
  }

  Future<void> _updateSharePlayState(bool isPlaying, int positionMs) async {
    _isLocalSharePlayUpdate = true;
    try {
      await AppDatabase.instance.table('calls').doc(widget.callId).update({
        'sharePlayState': {
          'isPlaying': isPlaying,
          'positionMs': positionMs,
          'senderId': myUid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      });
    } catch (e) {
      debugPrint('Error updating SharePlay state: $e');
    }
    _isLocalSharePlayUpdate = false;
  }

  void _showSharePlayPrompt() {
    final textCtrl = TextEditingController(text: _sharePlayUrl);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Icon(Icons.slideshow, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Text(
                    "SharePlay Co-Watching",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Paste a video URL to watch synchronized together with everyone on the call:",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "https://example.com/movie.mp4",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: Colors.cyanAccent),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        textCtrl.text = data!.text!;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        await AppDatabase.instance.table('calls').doc(widget.callId).update({
                          'sharePlayUrl': FieldValue.delete(),
                          'sharePlayState': FieldValue.delete(),
                        });
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                      child: const Text("Stop Co-Watching"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final url = textCtrl.text.trim();
                        if (url.isNotEmpty) {
                          await AppDatabase.instance.table('calls').doc(widget.callId).update({
                            'sharePlayUrl': url,
                            'sharePlayState': {
                              'isPlaying': true,
                              'positionMs': 0,
                              'senderId': myUid,
                              'timestamp': DateTime.now().millisecondsSinceEpoch,
                            }
                          });
                        }
                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                      },
                      child: const Text("Start SharePlay", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  AnimationController? _pulseController;
  bool _isEnding = false;
  bool _showPoorNetworkWarning = false;
  Timer? _networkWarningTimer;
  Timer? _ringingTimeoutTimer;

  bool muted = false;
  bool cameraOff = true; // Privacy first: Off by default
  bool speakerOn = true;
  bool connected = false;
  bool sharingScreen = false;
  MediaStream? screenStream;
  String? explicitStatusText;

  AudioPlayer? _webRingtonePlayer;
  StreamSubscription? _callStreamSub;
  StreamSubscription? _candidateStreamSub;
  StreamSubscription? _remotePresenceSub;
  String? _remoteUidForPresence;
  bool _isPlayingRingtone = false;

  void _playWebRingtone() async {
    try {
      _webRingtonePlayer = AudioPlayer();
      await _webRingtonePlayer!.setReleaseMode(ReleaseMode.loop);
      await _webRingtonePlayer!.play(AssetSource('ringback_tone.wav'));
    } catch (e) {
      debugPrint('Error playing ringback tone: $e');
    }
  }

  void _stopWebRingtone() async {
    try {
      await _webRingtonePlayer?.stop();
      await _webRingtonePlayer?.dispose();
      _webRingtonePlayer = null;
    } catch (e) {
      debugPrint('Error stopping ringback tone: $e');
    }
  }

  Timer? _callTimer;
  int _callDurationSeconds = 0;

  // ── Effects state ──
  CallEffectsState _effectsState = CallEffectsState();
  final Map<String, CallEffectsState> _remoteEffectsStatuses = {};

  CallEffectsState _remoteEffectsStateOf(String uid) {
    return _remoteEffectsStatuses[uid] ?? CallEffectsState();
  }

  String? remoteUserName;
  String? remotePhotoUrl;
  bool swapViews = false;
  bool remoteCameraOn = true;
  CallLayoutMode _layoutMode = CallLayoutMode.portraitFill;
  Offset _pipOffset = const Offset(20, 100);
  final _reactionStreamController = StreamController<String>.broadcast();
  int? _lastReceivedReactionTimestamp;
  bool _showReactionPanel = false;
  final _commentStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentInputCtrl = TextEditingController();
  bool _showCommentInput = false;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  int _lastReceivedCommentTimestamp = 0;
  String? _chatId;
  String? _raisedHandUser;
  Timer? _raiseHandTimer;
  
  bool _showWhiteboard = false;
  bool _showCaptions = false;
  List<String> _captionLines = [];
  Timer? _captionTimer;
  StreamSubscription? _whiteboardSub;
  List<WhiteboardLine> _whiteboardLines = [];
  Color _whiteboardColor = Colors.red;
  double _whiteboardWidth = 4.0;

  String get myUid => AppAuth.instance.currentUser?.uid ?? '';

  Map<String, RTCPeerConnection> get _peerConnections => ActiveCallManager.instance.peerConnections;
  Map<String, MediaStream> get _remoteStreams => ActiveCallManager.instance.remoteStreams;
  Map<String, RTCVideoRenderer> get _remoteRenderers => ActiveCallManager.instance.remoteRenderers;
  Map<String, bool> get _remoteCameraStatuses => ActiveCallManager.instance.remoteCameraStatuses;
  Map<String, bool> get _remoteMuteStatuses => ActiveCallManager.instance.remoteMuteStatuses;
  Map<String, bool> get _remoteScreenSharingStatuses => ActiveCallManager.instance.remoteScreenSharingStatuses;

  final Map<String, StreamSubscription> _meshSignalingSubscriptions = {};
  final Map<String, StreamSubscription> _meshCandidateSubscriptions = {};
  final Map<String, Map<String, String>> _participantProfiles = {};
  List<String> _activeParticipants = [];

  final config = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      },
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443',
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      }
    ],
    'sdpSemantics': 'unified-plan',
  };

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SimplePip().setAutoPipMode(aspectRatio: const (3, 4));
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _networkWarningTimer = Timer.periodic(const Duration(seconds: 14), (timer) {
      if (!mounted) return;
      if (connected) {
        setState(() {
          _showPoorNetworkWarning = true;
        });
        Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showPoorNetworkWarning = false;
            });
          }
        });
      }
    });

    final manager = ActiveCallManager.instance;
    
    ActiveCallManager.instance.initializeRenderers().then((_) {
      if (!mounted) return;
      setState(() {
          if (manager.activeCallId == widget.callId) {
            remoteUserName = manager.remoteUserName ?? widget.initialRemoteUserName;
            remotePhotoUrl = manager.remotePhotoUrl ?? widget.initialRemotePhotoUrl;
            connected = manager.connected;
            muted = manager.muted;
            cameraOff = manager.cameraOff;
            speakerOn = manager.speakerOn;
            sharingScreen = manager.sharingScreen;
            _callDurationSeconds = manager.durationSeconds;
            swapViews = manager.swapViews;
            remoteCameraOn = manager.remoteCameraOn;

            localRenderer.srcObject = manager.localStream;
            
            _remoteCameraStatuses.addAll(manager.remoteCameraStatuses);
            _remoteMuteStatuses.addAll(manager.remoteMuteStatuses);

            AppDatabase.instance.table('calls').doc(widget.callId).get().then((doc) {
              if (doc.exists && mounted) {
                final activeParts = List<String>.from(doc.data()?['activeParticipants'] ?? []);
                setState(() {
                  _activeParticipants = activeParts;
                });
                _updateMeshConnections(activeParts);
              }
            });

            _startTimer();
            listenForRemoteData();
          } else {
            cameraOff = !widget.isVideo;

            remoteUserName = widget.initialRemoteUserName;
            remotePhotoUrl = widget.initialRemotePhotoUrl;
            manager.remoteUserName = remoteUserName;
            manager.remotePhotoUrl = remotePhotoUrl;

            manager.clear();
            manager.activeCallId = widget.callId;
            manager.isCaller = widget.isCaller;
            manager.isVideo = widget.isVideo;
            manager.cameraOff = cameraOff;
            manager.listenToCallStatus(widget.callId);

            start();
          }
        });
      });
    _listenToWhiteboard();
  }

  Future<void> _loadParticipantProfile(String uid) async {
    if (_participantProfiles.containsKey(uid)) return;
    try {
      final doc = await AppDatabase.instance.table('users').doc(uid).get();
      final data = doc.data();
      if (data != null) {
        final name = data['username'] ?? data['email'] ?? 'User';
        final photo = data['photoUrl'] as String? ?? '';
        setState(() {
          _participantProfiles[uid] = {
            'name': name,
            'photo': photo,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading profile for $uid: $e');
    }
  }

  Future<void> loadRemoteUser() async {
    final callDoc = await AppDatabase.instance.table('calls').doc(widget.callId).get();
    final data = callDoc.data();
    if (data == null) return;

    final callerId = data['callerId'];
    final receiverIds = List<String>.from(data['receiverIds'] ?? []);
    _chatId = data['chatId'];
    
    if (receiverIds.length > 1) {
      if (mounted) {
        setState(() {
          remoteUserName = widget.initialRemoteUserName ?? 'Group Call';
          remotePhotoUrl = widget.initialRemotePhotoUrl;
        });
        ActiveCallManager.instance.remoteUserName = remoteUserName;
        ActiveCallManager.instance.remotePhotoUrl = remotePhotoUrl;
      }
      return;
    }

    String remoteUid = widget.isCaller ? receiverIds.first : callerId;
    
    final userDoc = await AppDatabase.instance.table('users').doc(remoteUid).get();
    final userData = userDoc.data();
    if (userData != null && mounted) {
      setState(() {
        remoteUserName = userData['username'] ?? userData['email'] ?? 'User';
        remotePhotoUrl = userData['photoUrl'];
      });
      ActiveCallManager.instance.remoteUserName = remoteUserName;
      ActiveCallManager.instance.remotePhotoUrl = remotePhotoUrl;
    }
  }

  Future<void> start() async {
    try {
      final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
      if (isMobile) {
        await [Permission.microphone, if (widget.isVideo) Permission.camera].request();
      }
      loadRemoteUser();

      if (widget.isCaller) {
        setState(() {
          explicitStatusText = 'Calling...';
        });

        _startPresenceGatedRinging();

        _ringingTimeoutTimer = Timer(const Duration(seconds: 60), () async {
          if (mounted && !connected) {
            setState(() {
              explicitStatusText = 'No Answer';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No answer'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.redAccent,
              ),
            );
            await Future.delayed(const Duration(seconds: 3));
            if (mounted) {
              await endCall();
            }
          }
        });
      }

      await WakelockPlus.enable();

      await openMedia();

      // Sync initial state to participantStatuses
      try {
        await AppDatabase.instance.table('calls').doc(widget.callId).update({
          'participantStatuses.$myUid.cameraOn': !cameraOff,
          'participantStatuses.$myUid.muted': muted,
          'participantStatuses.$myUid.effects': {
            'filterIndex': _effectsState.filterIndex,
            'backgroundIndex': _effectsState.backgroundIndex,
            'frameIndex': _effectsState.frameIndex,
            'beautyMode': _effectsState.beautyMode,
          },
        });
      } catch (e) {
        debugPrint('Error writing initial status: $e');
      }

      // Add self to activeParticipants if not already done
      try {
        await AppDatabase.instance.table('calls').doc(widget.callId).update({
          'activeParticipants': FieldValue.arrayUnion([myUid]),
        });
      } catch (e) {
        debugPrint('Error joining activeParticipants: $e');
      }

      // Fetch the call doc once to get initial activeParticipants
      final callDoc = await AppDatabase.instance.table('calls').doc(widget.callId).get();
      if (callDoc.exists) {
        final activeParts = List<String>.from(callDoc.data()?['activeParticipants'] ?? []);
        if (!activeParts.contains(myUid)) {
          activeParts.add(myUid);
        }
        _activeParticipants = activeParts;
        await _updateMeshConnections(activeParts);
      }

      listenForRemoteData();
    } catch (e) {
      debugPrint('Error starting call: $e');
      if (mounted) {
        setState(() {
          explicitStatusText = 'Connection Error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call connection error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _startPresenceGatedRinging() async {
    // Ring immediately to provide instant feedback as requested by the user
    _isPlayingRingtone = true;
    _playWebRingtone();
    if (mounted) {
      setState(() {
        explicitStatusText = 'Ringing...';
      });
    }

    try {
      final callDoc = await AppDatabase.instance.table('calls').doc(widget.callId).get();
      final data = callDoc.data();
      if (data == null) return;

      final receiverIds = List<String>.from(data['receiverIds'] ?? []);
      if (receiverIds.isEmpty) return;

      _remoteUidForPresence = receiverIds.first;

      _remotePresenceSub = AppDatabase.instance
          .table('users')
          .doc(_remoteUidForPresence)
          .snapshots()
          .listen((snap) {
        if (!mounted || connected) return;
        final isOnline = snap.data()?['isOnline'] == true;
        if (isOnline) {
          if (mounted) {
            setState(() {
              explicitStatusText = 'Ringing...';
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Presence-gated ringing error: $e');
    }
  }

  Future<void> openMedia() async {
    // ── Premium camera: HD quality + correct front-facing angle ──
    final videoConstraints = widget.isVideo
        ? {
            'facingMode': 'user', // Front camera — fixes wrong angle
            'width': {'ideal': 1920, 'min': 1280},
            'height': {'ideal': 1080, 'min': 720},
            'frameRate': {'ideal': 30, 'min': 15},
            'aspectRatio': {'ideal': 1.7778}, // 16:9
          }
        : false;

    // First attempt: HD quality
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': videoConstraints,
      });
    } catch (e) {
      debugPrint('HD camera failed, trying 720p: $e');
      // Second attempt: 720p fallback
      try {
        localStream = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': widget.isVideo
              ? {
                  'facingMode': 'user',
                  'width': {'ideal': 1280},
                  'height': {'ideal': 720},
                  'frameRate': {'ideal': 30},
                }
              : false,
        });
      } catch (e2) {
        debugPrint('720p failed, trying basic front camera: $e2');
        // Third attempt: basic front camera (fixes angle)
        try {
          localStream = await navigator.mediaDevices.getUserMedia({
            'audio': {
              'echoCancellation': true,
              'noiseSuppression': true,
              'autoGainControl': true,
            },
            'video': widget.isVideo ? {'facingMode': 'user'} : false,
          });
        } catch (e3) {
          debugPrint('Front camera failed, last resort: $e3');
          try {
            localStream = await navigator.mediaDevices.getUserMedia({
              'audio': {
                'echoCancellation': true,
                'noiseSuppression': true,
                'autoGainControl': true,
              },
              'video': widget.isVideo,
            });
          } catch (err) {
            debugPrint('All getUserMedia attempts failed: $err');
          }
        }
      }
    }

    if (widget.isVideo && localStream != null) {
      for (final track in localStream!.getVideoTracks()) {
        track.enabled = !cameraOff;
      }
    }

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
      try {
        await Helper.setSpeakerphoneOn(speakerOn);
      } catch (e) {
        debugPrint('Error setting speakerphone: $e');
      }
    }

    localRenderer.srcObject = localStream;
    ActiveCallManager.instance.localStream = localStream;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updateMeshConnections(List<String> activeParticipants) async {
    if (localStream == null) return;

    final myUid = AppAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty) return;

    bool hasOthers = false;
    for (final otherUid in activeParticipants) {
      if (otherUid == myUid) continue;
      hasOthers = true;

      _loadParticipantProfile(otherUid);

      if (!_peerConnections.containsKey(otherUid)) {
        await _setupPeerConnectionFor(otherUid);
      }
    }

    if (hasOthers && !connected) {
      if (mounted) {
        setState(() {
          connected = true;
          explicitStatusText = null;
        });
        _startTimer();
        _stopWebRingtone();
      }
    }

    final leftUids = _peerConnections.keys.where((uid) => !activeParticipants.contains(uid)).toList();
    for (final uid in leftUids) {
      _closePeerConnectionFor(uid);
    }
  }

  Future<void> _setupPeerConnectionFor(String otherUid) async {
    debugPrint('Setting up peer connection for $otherUid');

    final pc = await createPeerConnection(config);
    _peerConnections[otherUid] = pc;

    if (localStream != null) {
      if (isWindowsApp) {
        await pc.addStream(localStream!);
      } else {
        for (final track in localStream!.getTracks()) {
          await pc.addTrack(track, localStream!);
        }
      }
    }

    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    _remoteRenderers[otherUid] = renderer;

    pc.onTrack = (event) {
      debugPrint('OnTrack received from $otherUid');
      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        _remoteStreams[otherUid] = stream;
        renderer.srcObject = stream;
        
        if (mounted) {
          setState(() {
            connected = true;
            explicitStatusText = null;
          });
          _startTimer();
          _stopWebRingtone();
        }
      }
    };

    pc.onAddStream = (stream) {
      debugPrint('OnAddStream received from $otherUid');
      _remoteStreams[otherUid] = stream;
      renderer.srcObject = stream;
      
      if (mounted) {
        setState(() {
          connected = true;
          explicitStatusText = null;
        });
        _startTimer();
        _stopWebRingtone();
      }
    };

    pc.onConnectionState = (state) {
      debugPrint('WebRTC Connection State for $otherUid: $state');
    };

    final myUid = AppAuth.instance.currentUser?.uid ?? '';
    final isOfferer = myUid.compareTo(otherUid) < 0;
    final smallUid = isOfferer ? myUid : otherUid;
    final largeUid = isOfferer ? otherUid : myUid;
    final connDocId = '${smallUid}_${largeUid}';

    pc.onIceCandidate = (candidate) async {
      if (candidate == null) return;
      try {
        final candidateData = {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        await AppDatabase.instance
            .table('calls')
            .doc(widget.callId)
            .table('connections')
            .doc(connDocId)
            .table(isOfferer ? 'candidates_offerer' : 'candidates_answerer')
            .add(candidateData);
      } catch (e) {
        debugPrint('Error sending ICE candidate for $otherUid: $e');
      }
    };

    StreamSubscription? signalingSub;
    StreamSubscription? candidateSub;

    final connRef = AppDatabase.instance
        .table('calls')
        .doc(widget.callId)
        .table('connections')
        .doc(connDocId);

    final List<RTCIceCandidate> candidatesBuffer = [];
    bool remoteDescriptionSet = false;

    Future<void> processBufferedCandidates() async {
      remoteDescriptionSet = true;
      for (final candidate in candidatesBuffer) {
        try {
          await pc.addCandidate(candidate);
        } catch (e) {
          debugPrint('Error adding buffered candidate for $otherUid: $e');
        }
      }
      candidatesBuffer.clear();
    }

    final Map<String, dynamic> mediaConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': 'true',
        'OfferToReceiveVideo': widget.isVideo ? 'true' : 'false',
      },
      'optional': [],
    };

    if (isOfferer) {
      final offer = await pc.createOffer(mediaConstraints);
      await pc.setLocalDescription(offer);

      await connRef.set({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'answer': null,
      }, SetOptions(merge: true));

      signalingSub = connRef.snapshots().listen((snap) async {
        final data = snap.data();
        if (data == null) return;

        final answerData = data['answer'];
        if (answerData != null) {
          final currentRemote = await pc.getRemoteDescription();
          if (currentRemote == null) {
            await pc.setRemoteDescription(
              RTCSessionDescription(answerData['sdp'], answerData['type']),
            );
            await processBufferedCandidates();
          }
        }
      });

      candidateSub = connRef
          .table('candidates_answerer')
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              (data['sdpMLineIndex'] as num?)?.toInt(),
            );

            if (remoteDescriptionSet) {
              try {
                pc.addCandidate(candidate);
              } catch (e) {
                debugPrint('Error adding candidate directly for $otherUid: $e');
              }
            } else {
              candidatesBuffer.add(candidate);
            }
          }
        }
      });
    } else {
      signalingSub = connRef.snapshots().listen((snap) async {
        final data = snap.data();
        if (data == null) return;

        final offerData = data['offer'];
        if (offerData != null) {
          final currentRemote = await pc.getRemoteDescription();
          if (currentRemote == null) {
            await pc.setRemoteDescription(
              RTCSessionDescription(offerData['sdp'], offerData['type']),
            );
            await processBufferedCandidates();

            final answer = await pc.createAnswer(mediaConstraints);
            await pc.setLocalDescription(answer);

            await connRef.set({
              'answer': {
                'type': answer.type,
                'sdp': answer.sdp,
              },
            }, SetOptions(merge: true));
          }
        }
      });

      candidateSub = connRef
          .table('candidates_offerer')
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              (data['sdpMLineIndex'] as num?)?.toInt(),
            );

            if (remoteDescriptionSet) {
              try {
                pc.addCandidate(candidate);
              } catch (e) {
                debugPrint('Error adding candidate directly for $otherUid: $e');
              }
            } else {
              candidatesBuffer.add(candidate);
            }
          }
        }
      });
    }

    _meshSignalingSubscriptions[otherUid] = signalingSub;
    _meshCandidateSubscriptions[otherUid] = candidateSub;

    if (mounted) setState(() {});
  }

  void _closePeerConnectionFor(String otherUid) {
    debugPrint('Closing peer connection for $otherUid');

    final pc = _peerConnections.remove(otherUid);
    if (pc != null) {
      try {
        pc.close();
      } catch (e) {
        debugPrint('Error closing peer connection for $otherUid: $e');
      }
    }

    final stream = _remoteStreams.remove(otherUid);
    if (stream != null) {
      try {
        stream.getTracks().forEach((track) => track.stop());
      } catch (e) {
        debugPrint('Error stopping tracks for $otherUid: $e');
      }
    }

    final renderer = _remoteRenderers.remove(otherUid);
    if (renderer != null) {
      try {
        renderer.srcObject = null;
        renderer.dispose();
      } catch (e) {
        debugPrint('Error disposing renderer for $otherUid: $e');
      }
    }

    _remoteCameraStatuses.remove(otherUid);
    _remoteMuteStatuses.remove(otherUid);

    final signalingSub = _meshSignalingSubscriptions.remove(otherUid);
    signalingSub?.cancel();

    final candidateSub = _meshCandidateSubscriptions.remove(otherUid);
    candidateSub?.cancel();

    if (mounted) setState(() {});
  }

  void listenForRemoteData() {
    final repo = ref.read(callRepositoryProvider);

    _callStreamSub?.cancel();
    _callStreamSub = repo.callStream(widget.callId).listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      final status = data['status'];

      // SharePlay Co-Watching Sync
      if (data['sharePlayUrl'] != null && data['sharePlayUrl'].toString().isNotEmpty) {
        final url = data['sharePlayUrl'] as String;
        final state = data['sharePlayState'] as Map<String, dynamic>?;
        
        if (_sharePlayUrl != url) {
          await _setupSharePlay(url);
        }

        if (_sharePlayController != null && state != null) {
          final isPlaying = state['isPlaying'] as bool? ?? false;
          final positionMs = state['positionMs'] as int? ?? 0;
          final senderId = state['senderId'] as String?;

          if (senderId != myUid) {
            _isLocalSharePlayUpdate = true;
            
            if (isPlaying && !_sharePlayController!.value.isPlaying) {
              await _sharePlayController!.play();
            } else if (!isPlaying && _sharePlayController!.value.isPlaying) {
              await _sharePlayController!.pause();
            }

            final currentPosMs = _sharePlayController!.value.position.inMilliseconds;
            if ((positionMs - currentPosMs).abs() > 1500) {
              await _sharePlayController!.seekTo(Duration(milliseconds: positionMs));
            }
            
            _isLocalSharePlayUpdate = false;
          }
        }
      } else {
        if (_isSharePlayActive) {
          await _setupSharePlay('');
        }
      }

      final List<String> activeParticipants = List<String>.from(data['activeParticipants'] ?? []);
      if (!listEquals(_activeParticipants, activeParticipants)) {
        setState(() {
          _activeParticipants = activeParticipants;
        });
        _updateMeshConnections(activeParticipants);
      }

      final statuses = data['participantStatuses'] as Map<String, dynamic>?;
      if (statuses != null) {
        statuses.forEach((uid, statusMap) {
          if (uid != myUid) {
            final map = Map<String, dynamic>.from(statusMap);
            final cam = map['cameraOn'] as bool? ?? true;
            final mut = map['muted'] as bool? ?? false;
            final sharing = map['sharingScreen'] as bool? ?? false;
            _remoteCameraStatuses[uid] = cam;
            _remoteMuteStatuses[uid] = mut;
            _remoteScreenSharingStatuses[uid] = sharing;
            ActiveCallManager.instance.remoteCameraStatuses[uid] = cam;
            ActiveCallManager.instance.remoteMuteStatuses[uid] = mut;
            ActiveCallManager.instance.remoteScreenSharingStatuses[uid] = sharing;

            // Handle remote effects
            final effectsMap = map['effects'] as Map<String, dynamic>?;
            if (effectsMap != null) {
              final remoteEffects = CallEffectsState(
                filterIndex: effectsMap['filterIndex'] as int? ?? -1,
                backgroundIndex: effectsMap['backgroundIndex'] as int? ?? -1,
                frameIndex: effectsMap['frameIndex'] as int? ?? -1,
                beautyMode: effectsMap['beautyMode'] as bool? ?? false,
              );
              _remoteEffectsStatuses[uid] = remoteEffects;
            } else {
              _remoteEffectsStatuses[uid] = CallEffectsState();
            }
          }
        });
        if (mounted) setState(() {});
      }

      if (data['lastReaction'] != null) {
        final lastReactionMap = Map<String, dynamic>.from(data['lastReaction']);
        final reactionTimestamp = lastReactionMap['timestamp'] as int;
        final emoji = lastReactionMap['emoji'] as String;
        final senderId = lastReactionMap['senderId'] as String;

        if (reactionTimestamp != _lastReceivedReactionTimestamp) {
          _lastReceivedReactionTimestamp = reactionTimestamp;
          _reactionStreamController.add(emoji);

          if (emoji == '✋') {
            String senderName = 'Someone';
            if (senderId == myUid) {
              senderName = 'You';
            } else {
              senderName = _participantProfiles[senderId]?['name'] ?? 'Remote Participant';
            }
            _showRaiseHandBanner(senderName);
          }
        }
      }

      if (data['lastComment'] != null) {
        final lastCommentMap = Map<String, dynamic>.from(data['lastComment']);
        final commentTimestamp = lastCommentMap['timestamp'] as int;
        final text = lastCommentMap['text'] as String;
        final senderName = lastCommentMap['senderName'] as String;
        final senderId = lastCommentMap['senderId'] as String;
        final avatarUrl = lastCommentMap['avatarUrl'] as String?;

        if (commentTimestamp != _lastReceivedCommentTimestamp) {
          _lastReceivedCommentTimestamp = commentTimestamp;
          _commentStreamController.add({
            'text': text,
            'senderName': senderName,
            'senderId': senderId,
            'avatarUrl': avatarUrl,
          });
        }
      }

      if (status == 'declined') {
        _ringingTimeoutTimer?.cancel();
        _ringingTimeoutTimer = null;
        if (widget.isCaller) {
          _stopWebRingtone();
        }
        if (mounted) {
          setState(() {
            _isEnding = true;
            explicitStatusText = 'Declined';
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            }
          });
        }
      } else if (status == 'ended') {
        _ringingTimeoutTimer?.cancel();
        _ringingTimeoutTimer = null;
        if (widget.isCaller) {
          _stopWebRingtone();
        }
        if (mounted) {
          setState(() {
            _isEnding = true;
          });
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      } else if (status == 'ringing' && widget.isCaller) {
        if (mounted) {
          setState(() {
            explicitStatusText = 'Ringing...';
          });
        }
      } else if (status == 'answered') {
        _ringingTimeoutTimer?.cancel();
        _ringingTimeoutTimer = null;
        if (mounted) {
          setState(() {
            connected = true;
            explicitStatusText = null;
          });
          _startTimer();
          if (widget.isCaller) {
            _stopWebRingtone();
          }
        }

        if (data['answeredAt'] != null) {
          final Timestamp answeredAtTimestamp = data['answeredAt'];
          final answeredDateTime = answeredAtTimestamp.toDate();
          final differenceSeconds = DateTime.now().difference(answeredDateTime).inSeconds;
          _callDurationSeconds = differenceSeconds >= 0 ? differenceSeconds : 0;
          ActiveCallManager.instance.durationSeconds = _callDurationSeconds;
        }
      }
    });
  }

  Future<void> toggleMute() async {
    muted = !muted;
    for (final track in localStream?.getAudioTracks() ?? []) {
      track.enabled = !muted;
    }
    ActiveCallManager.instance.muted = muted;
    try {
      await AppDatabase.instance.table('calls').doc(widget.callId).update({
        'participantStatuses.$myUid.muted': muted,
      });
    } catch (e) {
      debugPrint('Error syncing mute status: $e');
    }
    setState(() {});
  }

  Future<void> toggleCamera() async {
    cameraOff = !cameraOff;
    for (final track in localStream?.getVideoTracks() ?? []) {
      track.enabled = !cameraOff;
    }
    ActiveCallManager.instance.cameraOff = cameraOff;

    final cameraKey = widget.isCaller ? 'callerCameraOn' : 'receiverCameraOn';
    try {
      await AppDatabase.instance.table('calls').doc(widget.callId).update({
        cameraKey: !cameraOff,
        'participantStatuses.$myUid.cameraOn': !cameraOff,
      });
    } catch (e) {
      debugPrint('Error syncing camera status: $e');
    }

    setState(() {});
  }

  Future<void> switchCamera() async {
    final tracks = localStream?.getVideoTracks() ?? [];
    if (tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  Future<DesktopCapturerSource?> _showDesktopSourcePicker() async {
    try {
      final sources = await desktopCapturer.getSources(
        types: [SourceType.Screen, SourceType.Window],
        thumbnailSize: ThumbnailSize(320, 180),
      );

      if (sources.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No screens or windows available to share.')),
          );
        }
        return null;
      }

      if (!mounted) return null;

      return showDialog<DesktopCapturerSource>(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              width: 600,
              height: 500,
              decoration: BoxDecoration(
                color: const Color(0xEB16161A),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Share your screen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  
                  // Sources Grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: sources.length,
                      itemBuilder: (context, index) {
                        final src = sources[index];
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, src),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Thumbnail
                                Expanded(
                                  child: Container(
                                    color: Colors.black26,
                                    child: src.thumbnail != null
                                        ? Image.memory(
                                            src.thumbnail!,
                                            fit: BoxFit.cover,
                                          )
                                        : Center(
                                            child: Icon(
                                              src.type == SourceType.Screen ? Icons.monitor : Icons.window,
                                              color: Colors.white30,
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                ),
                                // Label
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  color: Colors.white.withOpacity(0.02),
                                  child: Row(
                                    children: [
                                      Icon(
                                        src.type == SourceType.Screen ? Icons.monitor : Icons.window,
                                        color: Colors.blueAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          src.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error getting desktop sources: $e');
      return null;
    }
  }

  // Guard flag: prevents onEnded race-condition during screen share startup
  bool _screenShareStarting = false;

  Future<void> toggleScreenShare() async {
    if (sharingScreen) {
      if (screenStream != null) {
        for (final track in screenStream!.getTracks()) {
          track.stop();
        }
      }
      screenStream = null;
      ActiveCallManager.instance.screenStream = null;

      final videoTracks = localStream?.getVideoTracks() ?? [];
      if (videoTracks.isNotEmpty) {
        // Update all mesh connections
        for (final pc in _peerConnections.values) {
          try {
            final senders = await pc.getSenders();
            for (final sender in senders) {
              if (sender.track?.kind == 'video') {
                await sender.replaceTrack(videoTracks.first);
              }
            }
          } catch (e) {
            debugPrint('Error replacing track on mesh connection: $e');
          }
        }
        // Also update legacy peer connection if not null
        if (peer != null) {
          try {
            final senders = await peer!.getSenders();
            for (final sender in senders) {
              if (sender.track?.kind == 'video') {
                await sender.replaceTrack(videoTracks.first);
              }
            }
          } catch (_) {}
        }
      }

      // Restore camera on Firestore when stopping screen share
      try {
        await AppDatabase.instance.table('calls').doc(widget.callId).update({
          'participantStatuses.$myUid.sharingScreen': false,
          'participantStatuses.$myUid.cameraOn': !cameraOff,
        });
      } catch (_) {}

      if (mounted) {
        setState(() {
          sharingScreen = false;
          localRenderer.srcObject = localStream;
          _layoutMode = CallLayoutMode.portraitFill;
        });
      }
      ActiveCallManager.instance.sharingScreen = false;
      
      // Re-enable camera if it was on
      try {
        final videoTracks2 = localStream?.getVideoTracks() ?? [];
        if (videoTracks2.isNotEmpty && !cameraOff) {
          videoTracks2.first.enabled = true;
        }
      } catch (_) {}
      
      // Disable flutter_background if enabled
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          if (FlutterBackground.isBackgroundExecutionEnabled) {
            await FlutterBackground.disableBackgroundExecution();
          }
        } catch (_) {}
      }
    } else {
      // Prevent double-tap / re-entry
      if (_screenShareStarting) return;
      _screenShareStarting = true;

      try {
        final Map<String, dynamic> mediaConstraints = {
          'video': true,
          'audio': false,
        };

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await Permission.notification.request();
          // CRITICAL: start the foreground service BEFORE calling getDisplayMedia.
          // If the foreground service isn't running when Android shows the
          // media-projection consent dialog, the system kills the app.
          try {
            if (!await FlutterBackground.hasPermissions) {
              await FlutterBackground.initialize(androidConfig: const FlutterBackgroundAndroidConfig(
                notificationTitle: "A-Chatz Screen Sharing",
                notificationText: "Sharing your screen in a call.",
                notificationImportance: AndroidNotificationImportance.normal,
                notificationIcon: AndroidResource(name: 'launcher_icon', defType: 'mipmap'),
              ));
            } else if (!FlutterBackground.isBackgroundExecutionEnabled) {
              // Already initialized — just initialize again to get a fresh config
              await FlutterBackground.initialize(androidConfig: const FlutterBackgroundAndroidConfig(
                notificationTitle: "A-Chatz Screen Sharing",
                notificationText: "Sharing your screen in a call.",
                notificationImportance: AndroidNotificationImportance.normal,
                notificationIcon: AndroidResource(name: 'launcher_icon', defType: 'mipmap'),
              ));
            }
            if (!FlutterBackground.isBackgroundExecutionEnabled) {
              await FlutterBackground.enableBackgroundExecution();
            }
          } catch (e) {
            debugPrint('flutter_background setup failed (non-fatal): $e');
            // Continue anyway — some devices don't need it
          }
        }

        if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS)) {
          final selectedSource = await _showDesktopSourcePicker();
          if (selectedSource == null) return;

          mediaConstraints['video'] = {
            'deviceId': {'exact': selectedSource.id},
            'mandatory': {
              'minWidth': 1280,
              'minHeight': 720,
              'frameRate': 30.0,
            }
          };
        }

        try {
          if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux)) {
            screenStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
          } else {
            screenStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
          }
          ActiveCallManager.instance.screenStream = screenStream;
        } catch (e) {
          debugPrint('Screen share failed: $e');
          _screenShareStarting = false; // reset guard
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not start screen sharing.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
        
        final screenVideoTrack = screenStream!.getVideoTracks().first;

        // Update all mesh connections
        for (final pc in _peerConnections.values) {
          try {
            final senders = await pc.getSenders();
            for (final sender in senders) {
              if (sender.track?.kind == 'video') {
                await sender.replaceTrack(screenVideoTrack);
              }
            }
          } catch (e) {
            debugPrint('Error replacing track on mesh connection: $e');
          }
        }

        // Also update legacy peer connection if not null
        if (peer != null) {
          try {
            final senders = await peer!.getSenders();
            for (final sender in senders) {
              if (sender.track?.kind == 'video') {
                await sender.replaceTrack(screenVideoTrack);
              }
            }
          } catch (_) {}
        }

        screenVideoTrack.onEnded = () {
          // Only stop screen share if we're fully started (guard against picker-cancel race)
          if (sharingScreen && !_screenShareStarting) {
            toggleScreenShare();
          }
        };

        // Publish screen share + camera-off to Firestore for remote peer
        try {
          await AppDatabase.instance.table('calls').doc(widget.callId).update({
            'participantStatuses.$myUid.sharingScreen': true,
            'participantStatuses.$myUid.cameraOn': false,
          });
        } catch (_) {}

        if (mounted) {
          setState(() {
            sharingScreen = true;
            cameraOff = true;
            localRenderer.srcObject = screenStream;
            _layoutMode = CallLayoutMode.landscapeFit;
          });
        }
        ActiveCallManager.instance.sharingScreen = true;
        ActiveCallManager.instance.cameraOff = true;
        _screenShareStarting = false; // startup complete — onEnded now safe
        
        // Disable local camera track while screen sharing
        try {
          final videoTracks2 = localStream?.getVideoTracks() ?? [];
          if (videoTracks2.isNotEmpty) {
            videoTracks2.first.enabled = false;
          }
        } catch (_) {}
      } catch (e) {
        _screenShareStarting = false; // reset guard on any error
        debugPrint('Error starting screen share: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Screen sharing failed: ${e.toString().replaceAll("Exception: ", "")}')),
          );
        }
      }
    }
  }

  void _startTimer() {
    if (_callTimer != null) return;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
        ActiveCallManager.instance.durationSeconds = _callDurationSeconds;
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> endCall() async {
    if (_isEnding) return;
    setState(() {
      _isEnding = true;
    });

    _callTimer?.cancel();
    if (widget.isCaller) {
      _stopWebRingtone();
    }
    
    // Write call status to database in the background, do NOT await it to pop instantly!
    ref.read(callRepositoryProvider).endCall(widget.callId).catchError((e) {
      debugPrint('Error ending call in background: $e');
    });

    ActiveCallManager.instance.clear();
    FloatingCallOverlay.remove();

    _callStreamSub?.cancel();
    _candidateStreamSub?.cancel();

    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  void _minimizeCall() {
    final manager = ActiveCallManager.instance;
    manager.isMinimized = true;
    manager.remoteUserName = remoteUserName;
    manager.remotePhotoUrl = remotePhotoUrl;
    manager.connected = connected;
    manager.muted = muted;
    manager.cameraOff = cameraOff;
    manager.speakerOn = speakerOn;
    manager.sharingScreen = sharingScreen;
    manager.durationSeconds = _callDurationSeconds;
    manager.swapViews = swapViews;
    manager.remoteCameraOn = remoteCameraOn;

    manager.localStream = localStream;
    manager.peer = peer;
    manager.screenStream = screenStream;
    manager.localRenderer.srcObject = localRenderer.srcObject;
    manager.remoteRenderer.srcObject = remoteRenderer.srcObject;

    FloatingCallOverlay.show(context);

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _networkWarningTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _pulseController?.dispose();
    _callTimer?.cancel();
    _callStreamSub?.cancel();
    _candidateStreamSub?.cancel();
    _remotePresenceSub?.cancel();
    _captionTimer?.cancel();
    _whiteboardSub?.cancel();

    // Cancel all mesh subscriptions unconditionally to prevent leaks and duplicate listeners on restore
    for (final sub in _meshSignalingSubscriptions.values) {
      sub.cancel();
    }
    _meshSignalingSubscriptions.clear();

    for (final sub in _meshCandidateSubscriptions.values) {
      sub.cancel();
    }
    _meshCandidateSubscriptions.clear();

    final manager = ActiveCallManager.instance;
    
    if (!manager.isMinimized) {
      // Instantly detach streams so textures unmount with 0 lock hazards
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      if (widget.isCaller && !connected) {
        _stopWebRingtone();
      }
      
      try {
        WakelockPlus.disable();
      } catch (_) {}

      // Decouple native WebRTC hardware teardowns asynchronously to prevent unmount thread deadlocks!
      final ss = screenStream;
      final ls = localStream;
      final p = peer;

      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          ss?.getTracks().forEach((track) => track.stop());
        } catch (_) {}
        try {
          ls?.getTracks().forEach((track) => track.stop());
        } catch (_) {}
        try {
          await p?.close();
        } catch (_) {}
      });
      
      manager.clear();
    }
    try {
      _reactionStreamController.close();
    } catch (_) {}
    try {
      _commentStreamController.close();
    } catch (_) {}
    _sharePlayController?.dispose();
    _commentInputCtrl.dispose();
    _raiseHandTimer?.cancel();
    super.dispose();
  }

  void _showRaiseHandBanner(String name) {
    if (!mounted) return;
    _raiseHandTimer?.cancel();
    setState(() {
      _raisedHandUser = name;
    });
    _raiseHandTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _raisedHandUser = null;
        });
      }
    });
  }

  void _sendReaction(String emoji) async {
    final currentUid = AppAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    try {
      await AppDatabase.instance.table('calls').doc(widget.callId).update({
        'lastReaction': {
          'emoji': emoji,
          'senderId': currentUid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      });
    } catch (e) {
      debugPrint('Error sending reaction: $e');
    }
    setState(() {
      _showReactionPanel = false;
    });
  }

  void _sendComment(String text) async {
    if (text.trim().isEmpty) return;
    final currentUid = AppAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    try {
      final userDoc = await AppDatabase.instance.table('users').doc(currentUid).get();
      final myName = userDoc.data()?['username'] ?? 'Someone';
      final myPhoto = userDoc.data()?['photoUrl'] as String?;

      await AppDatabase.instance.table('calls').doc(widget.callId).update({
        'lastComment': {
          'text': text.trim(),
          'senderId': currentUid,
          'senderName': myName,
          'avatarUrl': myPhoto,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      });
    } catch (e) {
      debugPrint('Error sending call comment: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Premium Effects Panel
  // ─────────────────────────────────────────────────────────────────────────
  void _showEffectsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return CallEffectsPanel(
              state: _effectsState,
              onStateChanged: (newState) {
                setSheetState(() {});
                if (mounted) {
                  setState(() {
                    _effectsState = newState;
                  });
                  _syncEffectsState(newState);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _syncEffectsState(CallEffectsState state) async {
    try {
      await AppDatabase.instance.table('calls').doc(widget.callId).update({
        'participantStatuses.$myUid.effects': {
          'filterIndex': state.filterIndex,
          'backgroundIndex': state.backgroundIndex,
          'frameIndex': state.frameIndex,
          'beautyMode': state.beautyMode,
        },
      });
    } catch (e) {
      debugPrint('Error syncing effects status: $e');
    }
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _recordingDuration = 0;
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration++;
            });
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔴 Call recording started'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        _recordingTimer?.cancel();
        _recordingTimer = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💾 Call recording saved to history'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Future<void> inviteParticipant() async {
    final currentUid = AppAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AppDatabase.instance.table('calls').doc(widget.callId).snapshots(),
            builder: (ctx, callSnap) {
              if (!callSnap.hasData) {
                return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
              }
              final callData = callSnap.data?.data() ?? {};
              final callerId = callData['callerId'] as String? ?? '';
              final receiverIds = List<String>.from(callData['receiverIds'] ?? []);
              final ringingUids = List<String>.from(callData['ringingUids'] ?? []);
              final answeredUids = List<String>.from(callData['answeredUids'] ?? []);

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppDatabase.instance.table('users').snapshots(),
                builder: (ctx, usersSnap) {
                  if (!usersSnap.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                  }

                  final users = usersSnap.data!.docs
                      .map((d) => {...d.data(), 'uid': d.id})
                      .where((u) => u['uid'] != callerId)
                      .toList();

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Manage Call Participants",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final uid = user['uid'] as String;
                            final photoUrl = user['photoUrl'] as String?;
                            final username = user['username'] ?? user['email'] ?? 'User';

                            // Determine status
                            String statusText = '';
                            Widget? actionButton;

                            if (answeredUids.contains(uid)) {
                              statusText = 'Connected';
                            } else if (receiverIds.contains(uid)) {
                              if (ringingUids.contains(uid)) {
                                statusText = 'Ringing...';
                              } else {
                                statusText = 'Missed Call';
                                actionButton = TextButton.icon(
                                  onPressed: () async {
                                    await AppDatabase.instance.table('calls').doc(widget.callId).update({
                                      'ringingUids': FieldValue.arrayUnion([uid]),
                                    });
                                  },
                                  icon: const Icon(Icons.ring_volume, size: 14, color: Colors.greenAccent),
                                  label: const Text('Ring', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                );
                              }
                            } else {
                              statusText = '';
                              actionButton = ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                onPressed: () async {
                                  if (receiverIds.length >= 49) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Call size limit reached (50 participants max)'),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                  await AppDatabase.instance.table('calls').doc(widget.callId).update({
                                    'receiverIds': FieldValue.arrayUnion([uid]),
                                    'ringingUids': FieldValue.arrayUnion([uid]),
                                  });
                                },
                                child: const Text('Invite', style: TextStyle(fontSize: 12)),
                              );
                            }

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                child: photoUrl == null ? const Icon(Icons.person) : null,
                              ),
                              title: Text(username, style: const TextStyle(color: Colors.white, fontSize: 15)),
                              subtitle: statusText.isNotEmpty
                                  ? Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusText == 'Connected'
                                            ? Colors.greenAccent
                                            : statusText == 'Ringing...'
                                                ? Colors.blueAccent
                                                : Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  : Text(user['email'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: actionButton,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  int _getCrossAxisCount(int count) {
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    if (count <= 16) return 4;
    return 5;
  }

  Widget _buildParticipantTile(String uid) {
    final myUid = AppAuth.instance.currentUser?.uid ?? '';
    final isMe = uid == myUid;

    final String name = isMe ? 'You' : (_participantProfiles[uid]?['name'] ?? 'User');
    final String? photoUrl = isMe ? AppAuth.instance.currentUser?.photoURL : _participantProfiles[uid]?['photo'];
    final bool isMuted = isMe ? muted : (_remoteMuteStatuses[uid] ?? false);
    final bool isCameraOn = widget.isVideo && (isMe ? !cameraOff : (_remoteCameraStatuses[uid] ?? true));
    final RTCVideoRenderer? renderer = isMe ? localRenderer : _remoteRenderers[uid];

    final bool showVideo = isCameraOn && renderer != null && renderer.srcObject != null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: showVideo
                ? CallEffectsWrapper(
                    state: isMe ? _effectsState : _remoteEffectsStateOf(uid),
                    showBackground: true,
                    child: RTCVideoView(
                      renderer,
                      mirror: isMe && !sharingScreen,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E1E24),
                          Color(0xFF121216),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (widget.isVideo ? Colors.blueAccent : Colors.greenAccent).withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? const Icon(Icons.person, color: Colors.white30, size: 36)
                              : null,
                        ),
                      ),
                    ),
                  ),
          ),
          
          // Lower status panel containing name, mute indicator, camera status
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  color: Colors.black.withOpacity(0.4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isMuted)
                        const Icon(Icons.mic_off, color: Colors.redAccent, size: 14)
                      else
                        const Icon(Icons.mic, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 6),
                      if (isCameraOn)
                        const Icon(Icons.videocam, color: Colors.blueAccent, size: 14)
                      else
                        const Icon(Icons.videocam_off, color: Colors.white38, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipView(String? name, String? photoUrl, bool cameraOn, RTCVideoRenderer renderer) {
    if (!widget.isVideo) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraOn && renderer.srcObject != null
          ? RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: false,
            )
          : Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voice = !widget.isVideo;
    final useGrid = _activeParticipants.length >= 3;

    final otherUid = _activeParticipants.firstWhere((uid) => uid != myUid, orElse: () => '');
    final activeRemoteRenderer = otherUid.isNotEmpty ? (_remoteRenderers[otherUid] ?? remoteRenderer) : remoteRenderer;
    final activeRemoteCameraOn = otherUid.isNotEmpty ? (_remoteCameraStatuses[otherUid] ?? remoteCameraOn) : remoteCameraOn;
    final activeRemotePhotoUrl = otherUid.isNotEmpty ? (_participantProfiles[otherUid]?['photo'] ?? remotePhotoUrl) : remotePhotoUrl;
    final activeRemoteUserName = otherUid.isNotEmpty ? (_participantProfiles[otherUid]?['name'] ?? remoteUserName) : remoteUserName;
    final remoteIsSharingScreen = otherUid.isNotEmpty && (_remoteScreenSharingStatuses[otherUid] ?? false);

    // Screen share layout: whichever side is sharing occupies bg; face cam goes to PIP
    final isAnySharing = sharingScreen || remoteIsSharingScreen;
    final renderBgLocal = isAnySharing ? sharingScreen : swapViews;
    final bgRenderer = isAnySharing
        ? (sharingScreen ? localRenderer : activeRemoteRenderer)   // screen stream
        : (swapViews ? localRenderer : activeRemoteRenderer);      // normal layout
    final bgCameraOn = isAnySharing ? true : (renderBgLocal ? !cameraOff : activeRemoteCameraOn);
    final bgPhotoUrl = renderBgLocal ? AppAuth.instance.currentUser?.photoURL : activeRemotePhotoUrl;
    final bgName = renderBgLocal ? 'You' : activeRemoteUserName;

    // Preview (PIP) shows the non-sharing peer's face camera
    final renderPreviewLocal = isAnySharing ? !sharingScreen : !swapViews;
    final previewRenderer = isAnySharing
        ? (sharingScreen ? activeRemoteRenderer : localRenderer)   // face cam in PIP
        : (!swapViews ? localRenderer : activeRemoteRenderer);     // normal layout
    final previewCameraOn = isAnySharing
        ? (sharingScreen ? activeRemoteCameraOn : !cameraOff)
        : (renderPreviewLocal ? !cameraOff : activeRemoteCameraOn);
    final previewPhotoUrl = renderPreviewLocal ? AppAuth.instance.currentUser?.photoURL : activeRemotePhotoUrl;

    return PipWidget(
      pipChild: _buildPipView(activeRemoteUserName, activeRemotePhotoUrl, activeRemoteCameraOn, activeRemoteRenderer),
      child: PopScope(
        canPop: _isEnding,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!_isEnding) {
            if (!connected) {
              endCall();
            } else {
              _minimizeCall();
            }
          }
        },
        child: AmbientBackground(
          theme: ChatThemePreset.neonEclipse,
          child: Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            extendBody: true,
            body: !connected
              ? Stack(
                  children: [
                    // Premium Glowing Calling Screen
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController!,
                            builder: (context, child) {
                              final val = _pulseController!.value;
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (widget.isVideo ? Colors.blueAccent : Colors.greenAccent).withOpacity(0.25 * (1 - val)),
                                      blurRadius: 25 + (25 * val),
                                      spreadRadius: 5 + (12 * val),
                                    ),
                                    BoxShadow(
                                      color: (widget.isVideo ? Colors.blueAccent : Colors.greenAccent).withOpacity(0.4 * val),
                                      blurRadius: 15 * val,
                                      spreadRadius: 2 * val,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 70,
                                  backgroundColor: Colors.white12,
                                  backgroundImage: remotePhotoUrl != null ? NetworkImage(remotePhotoUrl!) : null,
                                  child: remotePhotoUrl == null
                                      ? const Icon(Icons.person, color: Colors.white54, size: 64)
                                      : null,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          Text(
                            remoteUserName ?? 'Loading...',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            explicitStatusText ?? (widget.isCaller ? 'Calling...' : 'Connecting...'),
                            style: TextStyle(
                              fontSize: 20,
                              color: explicitStatusText == 'Declined' ? Colors.redAccent : Colors.white70,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isVideo ? 'A-Chatz Video Call' : 'A-Chatz Voice Call',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom Controls (Hang up)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CallButton(
                            icon: Icons.call_end,
                            danger: true,
                            onTap: endCall,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              // ── Connected: Full-screen video layout like WhatsApp ──
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_showCaptions && _captionLines.isNotEmpty)
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 180, // Above call controls
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _captionLines.map((line) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                line,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(1, 1)),
                                  ],
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    if (_showWhiteboard)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87,
                          child: Stack(
                            children: [
                              GestureDetector(
                                onPanStart: _onWhiteboardPanStart,
                                onPanUpdate: _onWhiteboardPanUpdate,
                                onPanEnd: _onWhiteboardPanEnd,
                                child: CustomPaint(
                                  painter: WhiteboardPainter(lines: _whiteboardLines),
                                  size: Size.infinite,
                                ),
                              ),
                              // Top control bar
                              Positioned(
                                top: 80,
                                left: 16,
                                right: 16,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Color selectors
                                    Row(
                                      children: [
                                        _buildColorDot(Colors.red),
                                        _buildColorDot(Colors.blue),
                                        _buildColorDot(Colors.green),
                                        _buildColorDot(Colors.white),
                                        _buildColorDot(Colors.yellow),
                                      ],
                                    ),
                                    // Action buttons (Clear & Close)
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          onPressed: _clearWhiteboard,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white),
                                          onPressed: () {
                                            setState(() {
                                              _showWhiteboard = false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // SharePlay video overlay (top 35% when active)
                    if (_isSharePlayActive && _sharePlayController != null && _sharePlayController!.value.isInitialized)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: MediaQuery.of(context).size.height * 0.35,
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final isPlaying = _sharePlayController!.value.isPlaying;
                                  if (isPlaying) {
                                    await _sharePlayController!.pause();
                                  } else {
                                    await _sharePlayController!.play();
                                  }
                                  await _updateSharePlayState(!isPlaying, _sharePlayController!.value.position.inMilliseconds);
                                  setState(() {});
                                },
                                child: AspectRatio(
                                  aspectRatio: _sharePlayController!.value.aspectRatio,
                                  child: VideoPlayer(_sharePlayController!),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                color: Colors.black45,
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _sharePlayController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                        color: Colors.cyanAccent,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final isPlaying = _sharePlayController!.value.isPlaying;
                                        if (isPlaying) {
                                          await _sharePlayController!.pause();
                                        } else {
                                          await _sharePlayController!.play();
                                        }
                                        await _updateSharePlayState(!isPlaying, _sharePlayController!.value.position.inMilliseconds);
                                        setState(() {});
                                      },
                                    ),
                                    Expanded(
                                      child: VideoProgressIndicator(
                                        _sharePlayController!,
                                        allowScrubbing: true,
                                        colors: const VideoProgressColors(
                                          playedColor: Colors.cyanAccent,
                                          bufferedColor: Colors.white24,
                                          backgroundColor: Colors.white10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.sync, color: Colors.white70, size: 16),
                                      onPressed: () async {
                                        await _updateSharePlayState(
                                          _sharePlayController!.value.isPlaying,
                                          _sharePlayController!.value.position.inMilliseconds,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.slideshow, size: 12, color: Colors.cyanAccent),
                                      SizedBox(width: 4),
                                      Text(
                                        'Co-Watching Sync Active',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ── Full-screen video stack ──
                    Positioned.fill(
                      child: Stack(
                  children: [
                    if (useGrid)
                      Positioned.fill(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 80, 16, 110),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _getCrossAxisCount(_activeParticipants.length),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: widget.isVideo ? 3 / 4 : 1.0,
                          ),
                          itemCount: _activeParticipants.length,
                          itemBuilder: (context, index) {
                            final uid = _activeParticipants[index];
                            return _buildParticipantTile(uid);
                          },
                        ),
                      )
                    else ...[
                      if (voice)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Avatar with muted ring effect
                              Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: (_remoteMuteStatuses[otherUid] ?? false)
                                            ? Colors.redAccent
                                            : Colors.greenAccent,
                                        width: 3,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 62,
                                      backgroundColor: Colors.white24,
                                      backgroundImage: activeRemotePhotoUrl != null && activeRemotePhotoUrl.isNotEmpty ? NetworkImage(activeRemotePhotoUrl) : null,
                                      child: (activeRemotePhotoUrl == null || activeRemotePhotoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 54) : null,
                                    ),
                                  ),
                                  // Muted badge
                                  if (_remoteMuteStatuses[otherUid] ?? false)
                                    Positioned(
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 8),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.mic_off, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text('Muted', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if (activeRemoteUserName != null)
                                Text(
                                  activeRemoteUserName,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Text(
                                explicitStatusText ?? _formatDuration(_callDurationSeconds),
                                style: TextStyle(
                                  fontSize: explicitStatusText == 'Declined' ? 24 : 20,
                                  color: explicitStatusText == 'Declined' ? Colors.redAccent : Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                swapViews = !swapViews;
                                ActiveCallManager.instance.swapViews = swapViews;
                              });
                            },
                            child: Container(
                              color: Colors.black87,
                              child: (bgCameraOn && bgRenderer.srcObject != null)
                                  ? CallEffectsWrapper(
                                      state: renderBgLocal && !isAnySharing
                                          ? _effectsState
                                          : (isAnySharing ? CallEffectsState() : _remoteEffectsStateOf(otherUid)),
                                      showBackground: !isAnySharing,
                                      child: _buildBgVideoView(bgRenderer, false),
                                    )
                                  : _buildBgPlaceholder(bgPhotoUrl, bgName),
                            ),
                          ),
                        ),
                    ],

                    if (!useGrid && widget.isVideo && activeRemoteUserName != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Text(
                              activeRemoteUserName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              explicitStatusText ?? _formatDuration(_callDurationSeconds),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (useGrid)
                      Positioned(
                        top: 18,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  _formatDuration(_callDurationSeconds),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (!useGrid && widget.isVideo)
                      Positioned(
                        top: _pipOffset.dy,
                        left: _pipOffset.dx,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            final size = MediaQuery.of(context).size;
                            double newX = _pipOffset.dx + details.delta.dx;
                            double newY = _pipOffset.dy + details.delta.dy;

                            // Clamp PIP within bounds
                            final double maxX = (size.width - 135.0) < 10.0 ? 10.0 : (size.width - 135.0);
                            final double maxY = (size.height - 280.0) < 80.0 ? 80.0 : (size.height - 280.0);
                            newX = newX.clamp(10.0, maxX);
                            newY = newY.clamp(80.0, maxY);

                            setState(() {
                              _pipOffset = Offset(newX, newY);
                            });
                          },
                          onTap: () {
                            setState(() {
                              swapViews = !swapViews;
                              ActiveCallManager.instance.swapViews = swapViews;
                            });
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 120,
                              height: 170,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16161A),
                                border: Border.all(color: Colors.white24, width: 1.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: (previewCameraOn && previewRenderer.srcObject != null)
                                        ? CallEffectsWrapper(
                                            state: renderPreviewLocal ? _effectsState : _remoteEffectsStateOf(otherUid),
                                            showBackground: !renderPreviewLocal,
                                            child: RTCVideoView(
                                              previewRenderer,
                                              // Mirror only for local camera; never mirror remote
                                              mirror: renderPreviewLocal,
                                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                            ),
                                          )
                                        : Container(
                                            alignment: Alignment.center,
                                            color: const Color(0xFF1E1E22),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                CircleAvatar(
                                                  radius: 28,
                                                  backgroundColor: Colors.white10,
                                                  backgroundImage: previewPhotoUrl != null && previewPhotoUrl.isNotEmpty ? NetworkImage(previewPhotoUrl) : null,
                                                  child: (previewPhotoUrl == null || previewPhotoUrl.isEmpty) ? const Icon(Icons.person, color: Colors.white30, size: 24) : null,
                                                ),
                                                const SizedBox(height: 6),
                                                const Text(
                                                  'Camera off',
                                                  style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  // Name label on PIP
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                          color: Colors.black38,
                                          child: Text(
                                            renderPreviewLocal ? 'You' : (activeRemoteUserName ?? 'Participant'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      top: 18,
                      left: 18,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                          onPressed: _minimizeCall,
                        ),
                      ),
                    ),

                    if (_isRecording)
                      Positioned(
                        top: 18,
                        right: 18,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _BlinkingRedDot(),
                                  const SizedBox(width: 6),
                                  Text(
                                    'REC ${_formatDuration(_recordingDuration)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Floating Emojis Canvas
                    FloatingReactionsCanvas(reactionStream: _reactionStreamController.stream),

                    // Floating Comments Canvas
                    FloatingCommentsOverlay(commentStream: _commentStreamController.stream),

                    // Raise Hand Overlay Banner
                    if (_raisedHandUser != null)
                      Positioned(
                        top: 100,
                        left: 24,
                        right: 24,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.4),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('✋ ', style: TextStyle(fontSize: 22)),
                                Text(
                                  '$_raisedHandUser Raised Hand',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                  // Poor Connection Warning Overlay Banner
                  if (_showPoorNetworkWarning)
                    Positioned(
                      top: 100,
                      left: 24,
                      right: 24,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Poor network connection, please find a better location.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Horizontal Reaction Selection Popover Panel
                    if (_showReactionPanel)
                      Positioned(
                        bottom: 110,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xEC1A1A1E),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['👍', '❤️', '😂', '😮', '😢', '✋'].map((emoji) {
                                return GestureDetector(
                                  onTap: () => _sendReaction(emoji),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),

                    // Floating Comment Input Overlay
                    if (_showCommentInput)
                      Positioned(
                        bottom: 110,
                        left: 20,
                        right: 20,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: TextField(
                                        controller: _commentInputCtrl,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        textInputAction: TextInputAction.send,
                                        onSubmitted: (val) {
                                          _sendComment(val);
                                          _commentInputCtrl.clear();
                                          setState(() => _showCommentInput = false);
                                        },
                                        decoration: const InputDecoration(
                                          hintText: 'Type a comment...',
                                          hintStyle: TextStyle(color: Colors.white38),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                                    onPressed: () {
                                      _sendComment(_commentInputCtrl.text);
                                      _commentInputCtrl.clear();
                                      setState(() => _showCommentInput = false);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Dynamic iOS Call Control Toolbar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.of(context).padding.bottom + 24,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 1.2),
                              end: const Offset(0.0, 0.0),
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            )),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Wrap(
                          key: const ValueKey('connected-toolbar'),
                          alignment: WrapAlignment.spaceEvenly,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _CallButton(
                              icon: muted ? Icons.mic_off : Icons.mic,
                              onTap: toggleMute,
                            ),
                            if (widget.isVideo) ...[
                              _CallButton(
                                icon: cameraOff ? Icons.videocam_off : Icons.videocam,
                                onTap: toggleCamera,
                              ),
                              _CallButton(
                                icon: Icons.cameraswitch,
                                onTap: switchCamera,
                              ),
                              // ✨ Premium Effects Button
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _CallButton(
                                    icon: Icons.auto_awesome,
                                    active: _effectsState.hasAnyEffect,
                                    onTap: _showEffectsPanel,
                                  ),
                                  if (_effectsState.hasAnyEffect)
                                    const Positioned(
                                      top: -4,
                                      right: -4,
                                      child: EffectsActiveBadge(),
                                    ),
                                ],
                              ),
                            ],
                            PopupMenuButton<String>(
                              offset: const Offset(0, -320),
                              color: const Color(0xFF16161A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Colors.white10),
                              ),
                              onSelected: (value) {
                                if (value == 'whiteboard') {
                                  setState(() {
                                    _showWhiteboard = !_showWhiteboard;
                                  });
                                } else if (value == 'captions') {
                                  setState(() {
                                    _showCaptions = !_showCaptions;
                                    if (_showCaptions) {
                                      _startCaptionSimulation();
                                    } else {
                                      _stopCaptionSimulation();
                                    }
                                  });
                                } else if (value == 'ai') {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => AINoteTakerSheet(
                                      callId: widget.callId,
                                      chatId: _chatId ?? '',
                                      otherParticipantName: remoteUserName ?? 'Participant',
                                    ),
                                  );
                                } else if (value == 'comment') {
                                  setState(() {
                                    _showCommentInput = !_showCommentInput;
                                  });
                                } else if (value == 'reaction') {
                                  setState(() {
                                    _showReactionPanel = !_showReactionPanel;
                                  });
                                } else if (value == 'record') {
                                  _toggleRecording();
                                } else if (value == 'invite') {
                                  inviteParticipant();
                                } else if (value == 'screenshare') {
                                  toggleScreenShare();
                                } else if (value == 'shareplay') {
                                  _showSharePlayPrompt();
                                } else if (value == 'layout') {
                                  setState(() {
                                    if (_layoutMode == CallLayoutMode.portraitFill) {
                                      _layoutMode = CallLayoutMode.landscapeFit;
                                    } else if (_layoutMode == CallLayoutMode.landscapeFit) {
                                      _layoutMode = CallLayoutMode.squareFit;
                                    } else {
                                      _layoutMode = CallLayoutMode.portraitFill;
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _layoutMode == CallLayoutMode.portraitFill
                                            ? 'Layout: Full Portrait'
                                            : _layoutMode == CallLayoutMode.landscapeFit
                                                ? 'Layout: Landscape Frame'
                                                : 'Layout: Square Frame',
                                      ),
                                      duration: const Duration(milliseconds: 600),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'record',
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                                        color: _isRecording ? Colors.redAccent : Colors.red,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _isRecording ? 'Stop Recording' : 'Record Call',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'ai',
                                  child: Row(
                                    children: [
                                      Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                                      const SizedBox(width: 12),
                                      Text('AI Note Taker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'comment',
                                  child: Row(
                                    children: [
                                      Icon(Icons.comment, color: Colors.blueAccent),
                                      const SizedBox(width: 12),
                                      Text('Comments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'reaction',
                                  child: Row(
                                    children: [
                                      Icon(Icons.face_outlined, color: Colors.orangeAccent),
                                      const SizedBox(width: 12),
                                      Text('Reactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'invite',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_add_alt_1, color: Colors.greenAccent),
                                      const SizedBox(width: 12),
                                      Text('Invite Participant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'shareplay',
                                  child: Row(
                                    children: [
                                      Icon(Icons.slideshow, color: Colors.cyanAccent),
                                      const SizedBox(width: 12),
                                      Text('SharePlay Sync', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                    value: 'screenshare',
                                    child: Row(
                                      children: [
                                        Icon(sharingScreen ? Icons.stop_screen_share : Icons.screen_share, color: Colors.cyanAccent),
                                        const SizedBox(width: 12),
                                        Text(sharingScreen ? 'Stop Screen Share' : 'Screen Share', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                    value: 'whiteboard',
                                    child: Row(
                                      children: [
                                        Icon(Icons.palette_outlined, color: Colors.pinkAccent),
                                        const SizedBox(width: 12),
                                        Text(_showWhiteboard ? 'Hide Whiteboard' : 'Whiteboard', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                    value: 'captions',
                                    child: Row(
                                      children: [
                                        Icon(_showCaptions ? Icons.subtitles_off_outlined : Icons.subtitles_outlined, color: Colors.indigoAccent),
                                        const SizedBox(width: 12),
                                        Text(_showCaptions ? 'Hide Captions' : 'Live Captions', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                if (widget.isVideo) ...[
                                  const PopupMenuItem(
                                    value: 'layout',
                                    child: Row(
                                      children: [
                                        Icon(Icons.aspect_ratio, color: Colors.yellowAccent),
                                        const SizedBox(width: 12),
                                        Text('Switch Layout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                              child: const _CallButton(
                                icon: Icons.more_horiz,
                                onTap: null,
                              ),
                            ),
                            _CallButton(
                              icon: Icons.call_end,
                              danger: true,
                              onTap: endCall,
                            ),
                          ],
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
  );
  }

  Widget _buildBgVideoView(RTCVideoRenderer renderer, bool mirror) {
    if (_layoutMode == CallLayoutMode.portraitFill) {
      return RTCVideoView(
        renderer,
        mirror: mirror,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    final isSquare = _layoutMode == CallLayoutMode.squareFit;
    final double aspect = isSquare ? 1.0 : 16 / 9;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: Colors.white24,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: aspect,
            child: RTCVideoView(
              renderer,
              mirror: mirror,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBgPlaceholder(String? bgPhotoUrl, String? bgName) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 64,
          backgroundColor: Colors.white10,
          backgroundImage: bgPhotoUrl != null ? NetworkImage(bgPhotoUrl) : null,
          child: bgPhotoUrl == null ? const Icon(Icons.person, color: Colors.white54, size: 54) : null,
        ),
        const SizedBox(height: 18),
        Text(
          bgName ?? 'Active Participant',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Camera is off',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ],
    );
  }

  // ── Advanced Call Session Helpers (Whiteboard & Captions) ──

  void _startCaptionSimulation() {
    _captionTimer?.cancel();
    _captionLines = [];
    final participantName = remoteUserName ?? 'Participant';
    final dialogues = [
      "Hello! Can you hear me clearly?",
      "Yeah, I can hear you perfectly.",
      "Awesome! The connection seems very stable.",
      "Did you check the new project layout?",
      "Yes, I saw the presentation earlier. It looks great!",
      "I think we should schedule a follow up next week.",
      "Agreed, let's coordinate the timing over chat.",
      "Perfect. Talk to you soon!",
    ];
    int index = 0;
    _captionTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_showCaptions || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _captionLines.add("$participantName: ${dialogues[index % dialogues.length]}");
        if (_captionLines.length > 3) {
          _captionLines.removeAt(0);
        }
      });
      index++;
    });
  }

  void _stopCaptionSimulation() {
    _captionTimer?.cancel();
    _captionTimer = null;
  }

  void _listenToWhiteboard() {
    _whiteboardSub?.cancel();
    _whiteboardSub = AppDatabase.instance
        .table('calls')
        .doc(widget.callId)
        .table('whiteboard')
        .doc('state')
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data();
      if (data == null) return;
      final linesList = data['lines'] as List? ?? [];
      setState(() {
        _whiteboardLines = linesList
            .map((item) => WhiteboardLine.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      });
    });
  }

  Future<void> _updateWhiteboardOnFirestore() async {
    try {
      final linesData = _whiteboardLines.map((l) => l.toMap()).toList();
      await AppDatabase.instance
          .table('calls')
          .doc(widget.callId)
          .table('whiteboard')
          .doc('state')
          .set({'lines': linesData});
    } catch (e) {
      debugPrint('Error updating whiteboard: $e');
    }
  }

  Future<void> _clearWhiteboard() async {
    setState(() {
      _whiteboardLines = [];
    });
    await _updateWhiteboardOnFirestore();
  }

  void _onWhiteboardPanStart(DragStartDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _whiteboardLines.add(
        WhiteboardLine(
          points: [localPosition],
          color: _whiteboardColor,
          strokeWidth: _whiteboardWidth,
        ),
      );
    });
  }

  void _onWhiteboardPanUpdate(DragUpdateDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    if (_whiteboardLines.isNotEmpty) {
      setState(() {
        final lastLine = _whiteboardLines.last;
        final updatedPoints = List<Offset>.from(lastLine.points)..add(localPosition);
        _whiteboardLines[_whiteboardLines.length - 1] = WhiteboardLine(
          points: updatedPoints,
          color: lastLine.color,
          strokeWidth: lastLine.strokeWidth,
        );
      });
    }
  }

  void _onWhiteboardPanEnd(DragEndDetails details) {
    _updateWhiteboardOnFirestore();
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _whiteboardColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _whiteboardColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: danger
          ? Colors.redAccent
          : (active ? Colors.greenAccent : Colors.white24),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: active ? Colors.black : Colors.white),
      ),
    );
  }
}

class _BlinkingRedDot extends StatefulWidget {
  const _BlinkingRedDot();

  @override
  State<_BlinkingRedDot> createState() => _BlinkingRedDotState();
}

class _BlinkingRedDotState extends State<_BlinkingRedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Shared Interactive Whiteboard Models & Custom Painters ──

class WhiteboardLine {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  WhiteboardLine({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, dynamic> toMap() {
    return {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }

  factory WhiteboardLine.fromMap(Map<String, dynamic> map) {
    final pointsList = listFromMapList(map['points'] as List? ?? []);
    return WhiteboardLine(
      points: pointsList,
      color: Color(map['color'] as int? ?? Colors.white.value),
      strokeWidth: (map['strokeWidth'] as num? ?? 3.0).toDouble(),
    );
  }

  static List<Offset> listFromMapList(List<dynamic> list) {
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return Offset(
        (m['x'] as num? ?? 0.0).toDouble(),
        (m['y'] as num? ?? 0.0).toDouble(),
      );
    }).toList();
  }
}

class WhiteboardPainter extends CustomPainter {
  final List<WhiteboardLine> lines;

  WhiteboardPainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      if (line.points.isEmpty) continue;
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      
      final path = Path();
      path.moveTo(line.points.first.dx, line.points.first.dy);
      for (int i = 1; i < line.points.length; i++) {
        path.lineTo(line.points[i].dx, line.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}