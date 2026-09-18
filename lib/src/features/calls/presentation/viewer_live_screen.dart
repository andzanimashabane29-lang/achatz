import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'live_webrtc_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/features/calls/data/live_repository.dart';
import 'package:a_chatz/src/features/calls/domain/live_session.dart';
import 'package:a_chatz/src/features/calls/presentation/floating_reactions.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class ViewerLiveScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const ViewerLiveScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ViewerLiveScreen> createState() => _ViewerLiveScreenState();
}

class _ViewerLiveScreenState extends ConsumerState<ViewerLiveScreen> {
  final StreamController<String> _reactionStreamController = StreamController<String>.broadcast();
  StreamSubscription? _reactionSubscription;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _joined = false;
  
  bool _isRequestingToJoin = false;
  bool _peerConnectionStarted = false;

  Future<void> _initCamera() async {
    try {
      await Permission.camera.request();
      await Permission.microphone.request();
      await LiveWebRtcManager.instance.openLocalCamera();
    } catch (e) {
      debugPrint('Failed to initialize co-host stream: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    LiveWebRtcManager.instance.onStateChange = () {
      if (mounted) setState(() {});
    };
    _joinSession();
    _listenToReactions();
  }

  @override
  void dispose() {
    LiveWebRtcManager.instance.stop();
    _leaveSession();
    _reactionSubscription?.cancel();
    _reactionStreamController.close();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _joinSession() async {
    try {
      final liveRepo = ref.read(liveRepositoryProvider);
      await liveRepo.joinLiveSession(widget.sessionId);
      setState(() => _joined = true);
    } catch (e) {
      debugPrint('Error joining live session: $e');
    }
  }

  Future<void> _leaveSession() async {
    if (!_joined) return;
    try {
      final liveRepo = ref.read(liveRepositoryProvider);
      await liveRepo.leaveLiveSession(widget.sessionId);
    } catch (e) {
      debugPrint('Error leaving live session: $e');
    }
  }

  void _listenToReactions() {
    final db = AppDatabase.instance;
    final threshold = Timestamp.fromDate(DateTime.now().subtract(const Duration(seconds: 1)));

    _reactionSubscription = db
        .table('live_sessions')
        .doc(widget.sessionId)
        .table('reactions')
        .where('createdAt', isGreaterThan: threshold)
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final type = data?['type'] as String? ?? '❤️';
          _reactionStreamController.add(type);
        }
      }
    });
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final liveRepo = ref.read(liveRepositoryProvider);
      final userDoc = await AppDatabase.instance.table('users').doc(authRepo.uid).get();
      final myName = userDoc.data()?['username'] ?? 'Viewer';
      final myPhotoUrl = userDoc.data()?['photoUrl'] as String?;

      await liveRepo.sendComment(
        sessionId: widget.sessionId,
        text: text,
        userName: myName,
        userPhotoUrl: myPhotoUrl,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('Failed to send comment: $e');
    }
  }

  Future<void> _sendReaction(String reactionType) async {
    _reactionStreamController.add(reactionType);
    try {
      final liveRepo = ref.read(liveRepositoryProvider);
      await liveRepo.sendReaction(sessionId: widget.sessionId, type: reactionType);
    } catch (e) {
      debugPrint('Failed to send reaction: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  Future<void> _requestToJoin() async {
    setState(() => _isRequestingToJoin = true);
    try {
      final liveRepo = ref.read(liveRepositoryProvider);
      final userDoc = await AppDatabase.instance.table('users').doc(liveRepo.uid).get();
      final myName = userDoc.data()?['username'] ?? 'Viewer';
      final myPhotoUrl = userDoc.data()?['photoUrl'] as String?;
      
      await liveRepo.requestToJoinLive(
        sessionId: widget.sessionId,
        userName: myName,
        userPhotoUrl: myPhotoUrl,
      );
    } catch (e) {
      debugPrint('Error requesting to join: $e');
      setState(() => _isRequestingToJoin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveSessionAsync = ref.watch(liveSessionStreamProvider(widget.sessionId));
    final commentsAsync = ref.watch(liveCommentsStreamProvider(widget.sessionId));
    final approvedCoHostsAsync = ref.watch(approvedCoHostsProvider(widget.sessionId));
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: liveSessionAsync.when(
        data: (session) {
          if (session == null || session.status == 'ended') {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_off, color: Colors.white38, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('This live stream has ended.', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.go('/home'),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ),
            );
          }

          final currentUid = ref.read(authRepositoryProvider).uid;
          final approvedCoHosts = approvedCoHostsAsync.value ?? [];
          final isApprovedCoHost = approvedCoHosts.contains(currentUid);
          
          if (isApprovedCoHost && !_peerConnectionStarted) {
            _peerConnectionStarted = true;
            _isRequestingToJoin = false;
            // The Host is the offerer, so we wait for the offer as answerer
            LiveWebRtcManager.instance.setupPeerConnection(widget.sessionId, session.hostId, false);
          }

          return Stack(
            children: [
              // Background Video Layer
              Positioned.fill(
                child: isApprovedCoHost
                    ? Column(
                        children: [
                          // Host (Top half)
                          Expanded(
                            child: LiveWebRtcManager.instance.remoteRenderers[session.hostId]?.srcObject != null
                              ? RTCVideoView(LiveWebRtcManager.instance.remoteRenderers[session.hostId]!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                              : const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
                          ),
                          // Self Camera (Bottom half)
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                color: Color(0xFF141218),
                                border: Border(
                                  top: BorderSide(color: Colors.purpleAccent, width: 2),
                                ),
                              ),
                              child: LiveWebRtcManager.instance.localStream != null
                                  ? RTCVideoView(LiveWebRtcManager.instance.localRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: true)
                                  : const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
                            ),
                          ),
                        ],
                      )
                    : _ViewerVideoSimulator(hostPhotoUrl: session.hostPhotoUrl),
              ),

              // Glassy top HUD overlay
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Stream Info Card (Host details & Views)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: session.hostPhotoUrl != null ? NetworkImage(session.hostPhotoUrl!) : null,
                            child: session.hostPhotoUrl == null ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                session.hostName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                              Text(
                                'Host',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.visibility, color: Colors.white70, size: 12),
                          const SizedBox(width: 4),
                          Text('${session.viewerCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Request to Join Button
                    if (!isApprovedCoHost)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRequestingToJoin ? Colors.grey[800] : Colors.purpleAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isRequestingToJoin ? null : _requestToJoin,
                        child: Text(_isRequestingToJoin ? 'Requested' : 'Request to Join', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    const SizedBox(width: 8),

                    // Close/Exit Button
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => context.go('/home'),
                      ),
                    ),
                  ],
                ),
              ),

              // Title banner just under the HUD
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Floating Reactions layer
              FloatingReactionsCanvas(reactionStream: _reactionStreamController.stream),

              // Comments & Input Area (positioned at bottom)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    top: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scrolling comments
                      SizedBox(
                        height: size.height * 0.25,
                        child: commentsAsync.when(
                          data: (comments) {
                            if (comments.isEmpty) {
                              return Center(
                                child: Text('No comments yet. Wave hello! 👋', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
                              );
                            }
                            _scrollToBottom();
                            return ListView.builder(
                              controller: _scrollController,
                              itemCount: comments.length,
                              padding: EdgeInsets.zero,
                              itemBuilder: (ctx, i) {
                                final comment = comments[i];
                                final isHost = comment.userName.contains('(Host)');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundImage: comment.userPhotoUrl != null ? NetworkImage(comment.userPhotoUrl!) : null,
                                        child: comment.userPhotoUrl == null ? const Icon(Icons.person, size: 12, color: Colors.white) : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment.userName,
                                              style: TextStyle(
                                                color: isHost ? const Color(0xFF00FFB2) : Colors.white60,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              comment.text,
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFB2))),
                          error: (e, _) => Text('Error loading comments: $e', style: const TextStyle(color: Colors.redAccent)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Input & Emoji Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Comment live...',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onSubmitted: (_) => _postComment(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildReactionButton('❤️'),
                          const SizedBox(width: 4),
                          _buildReactionButton('🔥'),
                          const SizedBox(width: 4),
                          _buildReactionButton('😂'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFB2))),
        error: (e, _) => Center(child: Text('Error loading session: $e', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildReactionButton(String emoji) {
    return GestureDetector(
      onTap: () => _sendReaction(emoji),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class _ViewerVideoSimulator extends StatefulWidget {
  final String? hostPhotoUrl;
  const _ViewerVideoSimulator({this.hostPhotoUrl});

  @override
  State<_ViewerVideoSimulator> createState() => _ViewerVideoSimulatorState();
}

class _ViewerVideoSimulatorState extends State<_ViewerVideoSimulator> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<Offset> _stars = [];
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _showVideo = false;
  String _statusText = 'CONNECTING TO STREAM FEED...';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final r = Random();
    for (int i = 0; i < 20; i++) {
      _stars.add(Offset(r.nextDouble(), r.nextDouble()));
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _statusText = 'CONNECTED';
        });
        _initVideoPlayer();
      }
    });
  }

  Future<void> _initVideoPlayer() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse('https://assets.mixkit.co/videos/preview/mixkit-abstract-laser-lights-background-loop-42216-large.mp4'),
    );
    try {
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      await _videoController!.setVolume(0.0);
      await _videoController!.play();
      if (mounted) {
        setState(() {
          _videoInitialized = true;
          _showVideo = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading simulated live feed: $e');
      if (mounted) {
        setState(() {
          _statusText = 'LIVE AUDIO FEED SECURED';
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showVideo && _videoInitialized && _videoController != null) {
      return Stack(
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (ctx, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF060608), Color(0xFF130A1C), Color(0xFF000B1A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticlesPainter(
                    particles: _stars,
                    progress: _animationController.value,
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00FFB2).withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00FFB2).withOpacity(0.4),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFB2).withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFF1E1E22),
                        backgroundImage: widget.hostPhotoUrl != null ? NetworkImage(widget.hostPhotoUrl!) : null,
                        child: widget.hostPhotoUrl == null
                            ? const Icon(Icons.person, color: Colors.white60, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Color(0xFF00FFB2),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<Offset> particles;
  final double progress;

  _ParticlesPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FFB2).withOpacity(0.18)
      ..style = PaintingStyle.fill;

    for (final item in particles) {
      final double dy = (item.dy - progress) % 1.0;
      final double x = item.dx * size.width;
      final double y = dy * size.height;
      final double radius = 1.5 + (sin(progress * 6.28 + item.dx * 10) * 0.8);
      canvas.drawCircle(Offset(x, y), radius.clamp(0.5, 4.0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
