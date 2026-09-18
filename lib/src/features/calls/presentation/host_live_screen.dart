import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/features/calls/data/live_repository.dart';
import 'package:a_chatz/src/features/calls/domain/live_session.dart';
import 'package:a_chatz/src/features/calls/presentation/floating_reactions.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'live_webrtc_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class HostLiveScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const HostLiveScreen({super.key, required this.sessionId});

  @override
  ConsumerState<HostLiveScreen> createState() => _HostLiveScreenState();
}

class _HostLiveScreenState extends ConsumerState<HostLiveScreen> {
  bool _cameraInitialized = false;
  DateTime _startTime = DateTime.now();
  int _peakViewers = 0;
  bool _isScreenSharing = false;

  final StreamController<String> _reactionStreamController = StreamController<String>.broadcast();
  StreamSubscription? _reactionSubscription;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Set<String> _connectedCoHosts = {};

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _initCamera();
    LiveWebRtcManager.instance.onStateChange = () {
      if (mounted) setState(() {});
    };
    _listenToReactions();
  }

  @override
  void dispose() {
    LiveWebRtcManager.instance.stop();
    _reactionSubscription?.cancel();
    _reactionStreamController.close();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      await Permission.camera.request();
      await Permission.microphone.request();
      await LiveWebRtcManager.instance.openLocalCamera();
      if (mounted) {
        setState(() => _cameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Failed to initialize local stream: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (LiveWebRtcManager.instance.localStream == null) return;
    final videoTrack = LiveWebRtcManager.instance.localStream!.getVideoTracks().firstWhere((track) => track.kind == 'video');
    Helper.switchCamera(videoTrack);
    setState(() {});
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

  Future<void> _endLiveConfirm() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101012),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Live Stream?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end your live stream broadcast?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Stream', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _finishLiveStream();
    }
  }

  Future<void> _finishLiveStream() async {
    final liveRepo = ref.read(liveRepositoryProvider);
    await liveRepo.endLiveSession(widget.sessionId);

    final duration = DateTime.now().difference(_startTime);
    final durationStr = '${duration.inMinutes}m ${duration.inSeconds % 60}s';

    if (mounted) {
      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: const Color(0xFF0F0F12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => WillPopScope(
          onWillPop: () async => false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_off, color: Colors.redAccent, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Live Stream Ended',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your broadcast was successful. Here are your stats:',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('Duration', durationStr, Icons.timer_outlined),
                    _buildStatCard('Peak Viewers', '$_peakViewers', Icons.people_outline),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/home');
                    },
                    child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00FFB2), size: 20),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final liveRepo = ref.read(liveRepositoryProvider);
      final userDoc = await AppDatabase.instance.table('users').doc(authRepo.uid).get();
      final myName = userDoc.data()?['username'] ?? 'Host';
      final myPhotoUrl = userDoc.data()?['photoUrl'] as String?;

      await liveRepo.sendComment(
        sessionId: widget.sessionId,
        text: text,
        userName: '$myName (Host)',
        userPhotoUrl: myPhotoUrl,
      );
      
      _scrollToBottom();
    } catch (e) {
      debugPrint('Failed to send comment: $e');
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

  void _showJoinRequestsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Consumer(
          builder: (context, ref, child) {
            final requestsAsync = ref.watch(joinRequestsProvider(widget.sessionId));
            
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Co-Host Requests',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: requestsAsync.when(
                        data: (requests) {
                          if (requests.isEmpty) {
                            return const Center(
                              child: Text('No pending requests.', style: TextStyle(color: Colors.white54)),
                            );
                          }
                          return ListView.builder(
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final req = requests[index];
                              final username = req['userName'] ?? 'User';
                              final photoUrl = req['userPhotoUrl'] as String?;
                              final uid = req['userId'] as String;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                  child: photoUrl == null ? const Icon(Icons.person) : null,
                                ),
                                title: Text(username, style: const TextStyle(color: Colors.white)),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00FFB2),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    final liveRepo = ref.read(liveRepositoryProvider);
                                    await liveRepo.approveJoinRequest(widget.sessionId, uid);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Approved $username to join!'),
                                          backgroundColor: const Color(0xFF00FFB2),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FFB2))),
                        error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGrid(List<Widget> views) {
    if (views.isEmpty) return Container();
    if (views.length == 1) return views.first;
    if (views.length == 2) {
      return Column(
        children: views.map((v) => Expanded(child: Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
          child: v,
        ))).toList(),
      );
    }
    
    // Grid 2 columns
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 0.75,
      children: views.map((v) => Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
        child: v,
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveSessionAsync = ref.watch(liveSessionStreamProvider(widget.sessionId));
    final commentsAsync = ref.watch(liveCommentsStreamProvider(widget.sessionId));
    final requestsAsync = ref.watch(joinRequestsProvider(widget.sessionId));
    final approvedCoHostsAsync = ref.watch(approvedCoHostsProvider(widget.sessionId));
    final size = MediaQuery.of(context).size;

    final pendingRequestsCount = requestsAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: liveSessionAsync.when(
        data: (session) {
          if (session == null || session.status == 'ended') {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Text('This live stream has ended.', style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            );
          }

          if (session.viewerCount > _peakViewers) {
            _peakViewers = session.viewerCount;
          }
          
          final approvedCoHosts = approvedCoHostsAsync.value ?? [];
          for (final coHostId in approvedCoHosts) {
            if (!_connectedCoHosts.contains(coHostId)) {
              _connectedCoHosts.add(coHostId);
              LiveWebRtcManager.instance.setupPeerConnection(widget.sessionId, coHostId, true);
            }
          }
          
          final List<Widget> videoViews = [];
          
          if (_cameraInitialized && LiveWebRtcManager.instance.localStream != null) {
            videoViews.add(RTCVideoView(LiveWebRtcManager.instance.localRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: true));
          } else {
            videoViews.add(const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)));
          }
          
          for (final coHostId in approvedCoHosts) {
            final renderer = LiveWebRtcManager.instance.remoteRenderers[coHostId];
            if (renderer != null && renderer.srcObject != null) {
              videoViews.add(Stack(
                children: [
                  Positioned.fill(child: RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)),
                  Positioned(
                    top: 10, right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                      onPressed: () async {
                        final liveRepo = ref.read(liveRepositoryProvider);
                        await liveRepo.removeCoHost(widget.sessionId, coHostId);
                        LiveWebRtcManager.instance.removePeerConnection(coHostId);
                        _connectedCoHosts.remove(coHostId);
                      },
                    ),
                  ),
                ],
              ));
            } else {
              videoViews.add(Container(
                color: Colors.black,
                child: const Center(child: Text('Loading Co-Host...', style: TextStyle(color: Colors.white54))),
              ));
            }
          }

          return Stack(
            children: [
              // Camera Grid View
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: _buildGrid(videoViews),
                ),
              ),

              // Glassy top HUD overlay
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Stream Info Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                          const SizedBox(width: 8),
                          const Icon(Icons.visibility, color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text('${session.viewerCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.people_alt, color: Colors.white, size: 24),
                                  onPressed: _showJoinRequestsSheet,
                                  tooltip: 'Co-Host Requests',
                                ),
                                if (pendingRequestsCount > 0)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$pendingRequestsCount',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(width: 4),

                            // Mic toggle
                            IconButton(
                              icon: Icon(LiveWebRtcManager.instance.isMuted ? Icons.mic_off : Icons.mic, color: LiveWebRtcManager.instance.isMuted ? Colors.redAccent : Colors.white, size: 24),
                              onPressed: () => LiveWebRtcManager.instance.toggleMute(),
                            ),

                            // Camera On/Off
                            IconButton(
                              icon: Icon(LiveWebRtcManager.instance.isCameraOff ? Icons.videocam_off : Icons.videocam, color: LiveWebRtcManager.instance.isCameraOff ? Colors.redAccent : Colors.white, size: 24),
                              onPressed: () => LiveWebRtcManager.instance.toggleCamera(),
                            ),

                            // Camera flip (if camera available)
                            if (LiveWebRtcManager.instance.localStream != null)
                              IconButton(
                                icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
                                onPressed: _toggleCamera,
                              ),

                            const SizedBox(width: 4),

                            // End stream button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: _endLiveConfirm,
                              child: const Text('END LIVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Title overlay just under the HUD
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Floating Reactions layer
              FloatingReactionsCanvas(reactionStream: _reactionStreamController.stream),

              // Comments & Input Area
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
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

                      // Input Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Comment as host...',
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
                          CircleAvatar(
                            backgroundColor: const Color(0xFF00FFB2),
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.black, size: 18),
                              onPressed: _postComment,
                            ),
                          ),
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
}
