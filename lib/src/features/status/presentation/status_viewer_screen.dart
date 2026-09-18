import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/status/domain/status_models.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:a_chatz/src/shared/widgets/link_preview_widget.dart';
import 'package:a_chatz/src/features/chat/presentation/contact_detail_screen.dart';
import 'package:a_chatz/src/features/calls/presentation/floating_reactions.dart';
import 'package:a_chatz/src/shared/widgets/floating_comments.dart';
import 'package:a_chatz/src/features/status/data/spotify_service.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/music_sticker_widget.dart';
import 'package:a_chatz/src/features/status/presentation/create_text_status_screen.dart';
import 'package:a_chatz/src/features/status/presentation/music_trimmer.dart';
import 'dart:async';

import 'dart:math' as math;
import 'dart:ui';
import 'package:a_chatz/src/core/platform/platform_layout.dart';

class StatusViewerScreen extends ConsumerStatefulWidget {
  const StatusViewerScreen({
    super.key,
    required this.stories,
    required this.isMine,
  });

  final List<StatusStory> stories;
  final bool isMine;

  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  int index = 0;
  late AnimationController progress;
  VideoPlayerController? videoController;
  final AudioPlayer _audioPlayer = AudioPlayer()..setAudioContext(AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: {
        AVAudioSessionOptions.mixWithOthers,
      },
    ),
    android: AudioContextAndroid(
      isSpeakerphoneOn: true,
      audioMode: AndroidAudioMode.normal,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  ));

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  bool reacting = false;
  String? instantReaction;
  bool _isMediaBuffering = true;

  Duration _musicPosition = Duration.zero;
  SpotifyTrack? _currentStatusTrack;
  static final Map<String, String> _previewUrlCache = {};
  
  // Audio playback state
  final _reactionStreamController = StreamController<String>.broadcast();
  final _commentStreamController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription? _statusRealtimeSub;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  String? _lastReactionSyncUser;
  String? _lastReactionSyncEmoji;
  int _lastCommentSyncCount = 0;

  late List<StatusStory> _stories;

  StatusStory get story => _stories[index];

  @override
  void initState() {
    super.initState();
    _stories = List.from(widget.stories);

    progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        nextStory();
      }
    });

    loadStory();
  }

  Future<void> loadStory() async {
    progress.stop();
    progress.reset();

    await videoController?.dispose();
    videoController = null;

    _positionSubscription?.cancel();
    _positionSubscription = null;
    _playerCompleteSubscription?.cancel();
    _playerCompleteSubscription = null;

    _listenToStatusDoc(story.id);

    if (!widget.isMine) {
      ref.read(statusRepositoryProvider).markSeen(story.id);
    }

    if (mounted) setState(() => _isMediaBuffering = true);

    // Safety fallback: if media hangs, force UI to continue immediately so user can see it
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        if (_isMediaBuffering) {
          debugPrint('Media load timeout, forcing play');
          setState(() => _isMediaBuffering = false);
        }
        if (!progress.isAnimating) {
          progress.forward();
        }
      }
    });

    bool mediaHandledAsync = false;
    List<Future<void>> loadingFutures = [];

    if (story.type == StatusType.audio) {
      mediaHandledAsync = true;
      loadingFutures.add(() async {
        try {
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(UrlSource(story.mediaUrl));
        } catch (e) {
          debugPrint('Voice status playback error: $e');
        }
      }());
    } else if (story.musicTitle != null) {
      mediaHandledAsync = true;
      loadingFutures.add(() async {
        try {
          String? secureUrl;
          final cacheKey = '${story.musicTitle}_${story.musicArtist}';
          
          if (_previewUrlCache.containsKey(cacheKey)) {
             secureUrl = _previewUrlCache[cacheKey];
             if (mounted) {
               setState(() {
                 _currentStatusTrack = SpotifyTrack(
                   id: 0,
                   title: story.musicTitle!,
                   artist: story.musicArtist ?? 'Unknown',
                   previewUrl: secureUrl,
                 );
               });
             }
          } else {
            // Dynamically fetch fresh preview URL to avoid Spotify CDN expiration
            final tracks = await MusicService.searchTracks('${story.musicTitle} ${story.musicArtist ?? ''}')
                .timeout(const Duration(seconds: 4), onTimeout: () => []);
            if (tracks.isNotEmpty && tracks.first.previewUrl != null) {
              secureUrl = tracks.first.previewUrl!.replaceAll('http://', 'https://');
              _previewUrlCache[cacheKey] = secureUrl;
              if (mounted) setState(() => _currentStatusTrack = tracks.first);
            } else if (story.musicPreviewUrl != null && story.musicPreviewUrl!.isNotEmpty) {
              // Fallback to the stored one
              secureUrl = story.musicPreviewUrl!.replaceAll('http://', 'https://');
              if (mounted) {
                setState(() {
                  _currentStatusTrack = SpotifyTrack(
                    id: 0,
                    title: story.musicTitle!,
                    artist: story.musicArtist ?? 'Unknown',
                    previewUrl: secureUrl,
                  );
                });
              }
            }
          }

          if (secureUrl != null) {
            final startMs = story.musicStartTimeMs ?? 0;
            final endMs = story.musicEndTimeMs;

            await _audioPlayer.setReleaseMode(ReleaseMode.loop);
            await _audioPlayer.play(UrlSource(secureUrl));
            await _audioPlayer.seek(Duration(milliseconds: startMs));

            bool isSeeking = false;
            _positionSubscription = _audioPlayer.onPositionChanged.listen((pos) async {
              if (mounted) setState(() => _musicPosition = pos);
              if (isSeeking) return;

              if (pos.inMilliseconds < startMs || (endMs != null && pos.inMilliseconds >= endMs)) {
                isSeeking = true;
                await _audioPlayer.seek(Duration(milliseconds: startMs));
                isSeeking = false;
              }
            });
          }
        } catch (e) {
          debugPrint('Audio playback error: $e');
        }
      }());
    }

    if (story.type == StatusType.video && story.mediaUrl.isNotEmpty) {
      mediaHandledAsync = true;
      loadingFutures.add(() async {
        try {
          videoController = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
          await videoController!.initialize();
          if (mounted) {
            videoController!.play();
            progress.duration = videoController!.value.duration;
          }
        } catch (e) {
          debugPrint('Video initialization error or timeout: $e');
          // Fast fallback for timeout or error
          if (mounted) {
            setState(() => _isMediaBuffering = false);
            if (!progress.isAnimating) progress.forward();
          }
        }
      }());
    }

    if (loadingFutures.isNotEmpty) {
      Future.wait(loadingFutures).whenComplete(() {
        if (mounted) {
          setState(() => _isMediaBuffering = false);
          if (!progress.isAnimating) {
            progress.forward();
          }
        }
      });
    }

    if (story.type == StatusType.audio) {
      progress.duration = const Duration(seconds: 15); // Standard fallback
      _audioPlayer.onDurationChanged.listen((dur) {
        if (mounted && dur.inSeconds > 0) {
          setState(() {
            progress.duration = dur;
          });
        }
      });
    } else if (story.musicPreviewUrl != null && story.musicPreviewUrl!.isNotEmpty) {
      progress.duration = const Duration(seconds: 30);
    } else if (story.type != StatusType.video) {
      progress.duration = const Duration(seconds: 4);
    }

    if (!mediaHandledAsync) {
      if (mounted) {
        setState(() => _isMediaBuffering = false);
        progress.forward();
      }
    }

    if (mounted) {
      // Pre-cache the next image status if it exists
      if (index + 1 < _stories.length) {
        final nextStory = _stories[index + 1];
        if (nextStory.type == StatusType.image && nextStory.mediaUrl.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(nextStory.mediaUrl), context);
        }
      }
    }
  }

  void _listenToStatusDoc(String statusId) {
    _statusRealtimeSub?.cancel();
    _lastCommentSyncCount = 0;
    _lastReactionSyncUser = null;
    _lastReactionSyncEmoji = null;

    _statusRealtimeSub = AppDatabase.instance
        .table('statuses')
        .doc(statusId)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      // Caption sync
      final caption = data['caption'] as String?;
      if (caption != null && caption != story.caption) {
        _stories[index] = story.copyWith(caption: caption);
        if (mounted) setState(() {});
      }

      // SeenBy sync
      final seenByRaw = Map<String, dynamic>.from(data['seenBy'] ?? {});
      if (seenByRaw.length != story.seenBy.length) {
        final Map<String, DateTime> newSeenBy = {};
        seenByRaw.forEach((k, v) {
          if (v is Timestamp) {
            newSeenBy[k] = v.toDate();
          } else if (v is DateTime) {
            newSeenBy[k] = v;
          }
        });
        _stories[index] = story.copyWith(seenBy: newSeenBy);
        if (mounted) setState(() {});
      }

      // Reactions sync
      final reactions = Map<String, String>.from(data['reactions'] ?? {});
      final currentUid = AppAuth.instance.currentUser?.uid;

      reactions.forEach((uid, emoji) {
        if (uid != currentUid) {
          if (_lastReactionSyncUser != uid || _lastReactionSyncEmoji != emoji) {
            _lastReactionSyncUser = uid;
            _lastReactionSyncEmoji = emoji;
            _reactionStreamController.add(emoji);
          }
        }
      });

      // Comments sync
      final comments = List<Map<String, dynamic>>.from(
        (data['comments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e))
      );

      if (comments.length > _lastCommentSyncCount) {
        for (int i = _lastCommentSyncCount; i < comments.length; i++) {
          final comment = comments[i];
          final cUserId = comment['userId'] as String?;
          if (cUserId != currentUid) {
            _commentStreamController.add({
              'text': comment['text'] as String? ?? '',
              'senderName': comment['userName'] as String? ?? 'Someone',
              'avatarUrl': null,
            });
          }
        }
        _lastCommentSyncCount = comments.length;
      }
    });
  }

  void nextStory() {
    _audioPlayer.stop();

    if (index < _stories.length - 1) {
      setState(() {
        index++;
        instantReaction = null;
      });
      loadStory();
    } else {
      Navigator.pop(context);
    }
  }

  void previousStory() {
    _audioPlayer.stop();

    if (index > 0) {
      setState(() {
        index--;
        instantReaction = null;
      });
      loadStory();
    }
  }

  Future<void> reactFast(String emoji) async {
    if (reacting) return;

    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    setState(() {
      reacting = true;
      instantReaction = emoji;
    });

    _reactionStreamController.add(emoji);

    try {
      await ref.read(statusRepositoryProvider).reactToStatus(
            story: story,
            emoji: emoji,
          );
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 350));

    if (mounted) {
      setState(() => reacting = false);
    }
  }

  Future<void> showReactionSheet() async {
    progress.stop();
    videoController?.pause();
    _audioPlayer.pause();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        final emojis = ['💖', '🔥', '😂', '🤩', '🎉', '🙌'];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: emojis.map((emoji) {
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await reactFast(emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(
                        fontSize: 42,
                        shadows: [
                          Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (mounted) {
      progress.forward();
      videoController?.play();
      if (story.musicTitle != null) _audioPlayer.resume();
    }
  }

  Future<void> showCommentSheet() async {
    final controller = TextEditingController();

    progress.stop();
    videoController?.pause();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(sheetContext).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Reply to status',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write a reply...',
                    filled: true,
                    fillColor: const Color(0xFF17171A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;

                    HapticFeedback.lightImpact();
                    Navigator.pop(sheetContext);

                    final uid = AppAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      AppDatabase.instance.table('users').doc(uid).get().then((userDoc) {
                        final myName = userDoc.data()?['username'] ?? 'You';
                        _commentStreamController.add({
                          'text': text,
                          'senderName': myName,
                          'avatarUrl': userDoc.data()?['photoUrl'],
                        });
                      });
                    }

                    await ref.read(statusRepositoryProvider).commentOnStatus(
                          story: story,
                          text: text,
                        );
                  },
                  child: const Text('Send reply'),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (mounted) {
      progress.forward();
      videoController?.play();
    }
  }

  Future<void> showViewersSheet() async {
    progress.stop();
    videoController?.pause();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        final viewers = story.seenBy.keys.toList();
        final reactions = story.reactions;
        final comments = story.comments;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  '${viewers.length} views',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                if (viewers.isEmpty)
                  const Text(
                    'No views yet.',
                    style: TextStyle(color: Color(0xFFA7A7A7)),
                  ),
                ...viewers.map(
                  (uid) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: AppDatabase.instance.table('users').doc(uid).snapshots(),
                    builder: (context, userSnap) {
                      final data = userSnap.data?.data() ?? {};
                      final username = data['username'] as String? ?? uid;
                      final photoUrl = data['photoUrl'] as String?;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.white,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null ? const Icon(Icons.person, color: Colors.black) : null,
                        ),
                        title: Text(username),
                        subtitle: Text(
                          reactions[uid] != null
                              ? 'Reacted ${reactions[uid]}'
                              : 'Viewed',
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Color(0xFF202024)),
                const Text(
                  'Replies',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (comments.isEmpty)
                  const Text(
                    'No replies yet.',
                    style: TextStyle(color: Color(0xFFA7A7A7)),
                  ),
                ...comments.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.comment_outlined),
                    title: Text(c.userName ?? c.userId),
                    subtitle: Text(c.text),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted) {
      progress.forward();
      videoController?.play();
    }
  }

  Future<void> reshare() async {
    HapticFeedback.mediumImpact();

    await ref.read(statusRepositoryProvider).reshareStatus(story);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status reshared')),
      );
    }
  }

  @override
  void dispose() {
    _statusRealtimeSub?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    try {
      _reactionStreamController.close();
    } catch (_) {}
    try {
      _commentStreamController.close();
    } catch (_) {}
    progress.dispose();
    videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AppAuth.instance.currentUser?.uid;
    final isVideo = story.type == StatusType.video;
    final storedReaction =
        currentUid == null ? null : story.reactions[currentUid];
    final displayReaction = instantReaction ?? storedReaction;
    final currentUserProfile = ref.watch(currentUserProfileProvider).value;
    final readReceiptsEnabled = currentUserProfile?['readReceiptsEnabled'] ?? true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CombinedMultiFingerDetector(
          onTwoFingerScroll: _handleTwoFingerScrollOnStatus,
          onThreeFingerScroll: _handleThreeFingerScrollOnStatus,
          child: GestureDetector(
            onTapUp: (details) {
            final width = MediaQuery.of(context).size.width;

            if (details.localPosition.dx < width * 0.35) {
              previousStory();
            } else {
              nextStory();
            }
          },
          onLongPressStart: (_) {
            progress.stop();
            videoController?.pause();
            _audioPlayer.pause();
          },
          onLongPressEnd: (_) {
            progress.forward();
            videoController?.play();
            if (story.musicTitle != null || story.type == StatusType.audio) {
              _audioPlayer.resume();
            }
          },
          child: Builder(
            builder: (context) {
              final win = isWindowsApp;
              final textFontSize = win ? 18.0 : 32.0;
              final textPad = win
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
                  : const EdgeInsets.symmetric(horizontal: 24, vertical: 40);
              final voiceCardPad = win ? 14.0 : 30.0;
              final voiceAvatarR = win ? 28.0 : 50.0;
              final voicePulseBase = win ? 56.0 : 120.0;
              final voicePulseGrow = win ? 28.0 : 60.0;
              final voiceTitleSize = win ? 14.0 : 22.0;
              final voiceIconSize = win ? 16.0 : 22.0;

              TextStyle getStatusTextStyle(String? fontFamily, double baseFontSize) {
                switch (fontFamily) {
                  case 'Serif':
                    return TextStyle(fontFamily: 'Georgia', fontSize: baseFontSize, color: Colors.white, height: 1.4);
                  case 'Monospace':
                    return TextStyle(fontFamily: 'Courier', fontSize: baseFontSize - 6, color: Colors.white, height: 1.4);
                  case 'Handwriting':
                    return TextStyle(fontFamily: 'Cursive', fontSize: baseFontSize, color: Colors.white, height: 1.4);
                  case 'Impact':
                    return TextStyle(fontWeight: FontWeight.w900, fontSize: baseFontSize + 6, color: Colors.white, height: 1.3);
                  default:
                    return TextStyle(fontWeight: FontWeight.w600, fontSize: baseFontSize, color: Colors.white, height: 1.4);
                }
              }

              return Stack(
            children: [
              Center(
                child: story.type == StatusType.text
                    ? Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Color(story.textBgColor ?? 0xFF1E1E1E),
                        padding: textPad,
                        alignment: Alignment.center,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                story.caption ?? '',
                                textAlign: TextAlign.center,
                                style: getStatusTextStyle(story.fontFamily, textFontSize),
                              ),
                              if (LinkPreviewHelper.extractUrl(story.caption ?? '') != null) ...[
                                const SizedBox(height: 24),
                                LinkPreviewWidget(
                                  url: LinkPreviewHelper.extractUrl(story.caption ?? '')!,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : story.type == StatusType.audio
                        ? Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Color(story.textBgColor ?? 0xFF8E24AA),
                            padding: textPad,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                    onTap: () {
                                      if (story.musicTitle != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🎵 ${story.musicTitle} - ${story.musicArtist}'),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: Colors.black87,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(voiceCardPad),
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * (win ? 0.55 : 0.85),
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(win ? 18 : 30),
                                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                                        boxShadow: win
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 20,
                                                ),
                                              ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              AnimatedBuilder(
                                                animation: progress,
                                                builder: (context, child) {
                                                  final pulseValue = (progress.value * 20) % 1.0;
                                                  return Container(
                                                    width: voicePulseBase + voicePulseGrow * pulseValue,
                                                    height: voicePulseBase + voicePulseGrow * pulseValue,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white.withOpacity(0.08 * (1.0 - pulseValue)),
                                                    ),
                                                  );
                                                },
                                              ),
                                              AnimatedBuilder(
                                                animation: progress,
                                                builder: (context, child) {
                                                  final pulseValue2 = ((progress.value * 20) + 0.5) % 1.0;
                                                  return Container(
                                                    width: voicePulseBase + voicePulseGrow * pulseValue2,
                                                    height: voicePulseBase + voicePulseGrow * pulseValue2,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white.withOpacity(0.08 * (1.0 - pulseValue2)),
                                                    ),
                                                  );
                                                },
                                              ),
                                              CircleAvatar(
                                                radius: voiceAvatarR,
                                                backgroundColor: Colors.white24,
                                                backgroundImage: story.ownerPhotoUrl != null
                                                    ? NetworkImage(story.ownerPhotoUrl!)
                                                    : null,
                                                child: story.ownerPhotoUrl == null
                                                    ? Icon(story.musicTitle != null ? Icons.music_note : Icons.mic_none_rounded, color: Colors.white, size: win ? 22 : 40)
                                                    : null,
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: win ? 12 : 24),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                story.musicTitle != null ? Icons.music_note : (story.podcastTitle != null ? Icons.podcasts : Icons.mic),
                                                color: Colors.white,
                                                size: voiceIconSize,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  story.musicTitle != null ? '${story.musicTitle}' : (story.podcastTitle != null ? 'Podcast' : 'Voice Status'),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: voiceTitleSize,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            story.musicTitle != null ? '${story.musicArtist}' : (story.podcastTitle ?? 'Playing voice note...'),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: story.musicTitle != null ? Colors.white70 : (story.podcastTitle != null ? Colors.yellowAccent : Colors.white60),
                                              fontSize: win ? 11 : 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: win ? 10 : 20),
                                          AnimatedBuilder(
                                            animation: progress,
                                            builder: (context, child) {
                                              return Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: List.generate(20, (i) {
                                                  final time = progress.value * 50;
                                                  final offset = i * 0.2;
                                                  final waveHeight = 5.0 + 15.0 * (0.5 * (1 + math.sin(time + offset)));
                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                    width: 3.5,
                                                    height: waveHeight,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.8),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                  );
                                                }),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          AnimatedBuilder(
                                            animation: progress,
                                            builder: (context, child) {
                                              return LinearProgressIndicator(
                                                value: progress.value,
                                                minHeight: 2,
                                                backgroundColor: Colors.white10,
                                                color: Colors.white54,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Optional Caption below card
                                if (story.caption != null && story.caption!.isNotEmpty) ...[
                                  const SizedBox(height: 30),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      story.caption!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : isVideo
                            ? videoController != null &&
                                    videoController!.value.isInitialized
                                ? AspectRatio(
                                    aspectRatio: videoController!.value.aspectRatio,
                                    child: VideoPlayer(videoController!),
                                  )
                                : const CircularProgressIndicator()
                            : CachedNetworkImage(
                                imageUrl: story.mediaUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) =>
                                    const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                    const Center(child: Icon(Icons.error)),
                              ),
              ),



              if (instantReaction != null)
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1.3),
                    duration: const Duration(milliseconds: 250),
                    builder: (_, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Text(
                      instantReaction!,
                      style: const TextStyle(fontSize: 82),
                    ),
                  ),
                ),

              Positioned(
                top: 10,
                left: 8,
                right: 8,
                child: Row(
                  children: List.generate(_stories.length, (i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: progress,
                          builder: (_, __) {
                            double value;

                            if (i < index) {
                              value = 1;
                            } else if (i == index) {
                              value = progress.value;
                            } else {
                              value = 0;
                            }

                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 3,
                              backgroundColor: Colors.white30,
                              color: Colors.white,
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),

              Positioned(
                top: 28,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          progress.stop();
                          videoController?.pause();
                          _audioPlayer.pause();

                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactDetailScreen(otherUid: story.ownerId),
                            ),
                          );

                          progress.forward();
                          videoController?.play();
                          if (story.musicTitle != null || story.type == StatusType.audio) {
                            _audioPlayer.resume();
                          }
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              backgroundImage: story.ownerPhotoUrl != null
                                  ? NetworkImage(story.ownerPhotoUrl!)
                                  : null,
                              child: story.ownerPhotoUrl == null
                                  ? const Icon(Icons.person, color: Colors.black)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          story.ownerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (story.isOwnerVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, size: 14, color: Colors.blueAccent),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        _formatTimeAgo(story.createdAt),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (story.musicTitle != null && story.type != StatusType.audio) ...[
                                        const SizedBox(width: 4),
                                        const Text('•', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                        const SizedBox(width: 4),
                                        const _AnimatedMusicWaves(),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: GestureDetector(
                                            onTap: () => _showReuseAudioSheet(story),
                                            behavior: HitTestBehavior.opaque,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    '${story.musicArtist} ${story.musicTitle}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                const Icon(Icons.chevron_right, color: Colors.white70, size: 14),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          await AppDatabase.instance.table('statuses').doc(story.id).delete();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status deleted')));
                          Navigator.pop(context);
                        } else if (value == 'mute') {
                          final currentUid = AppAuth.instance.currentUser!.uid;
                          await AppDatabase.instance.table('users').doc(currentUid).table('muted_statuses').doc(story.ownerId).set({'mutedAt': FieldValue.serverTimestamp()});
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status muted')));
                          Navigator.pop(context);
                        } else if (value == 'edit') {
                          showEditStatusSheet();
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return [
                          if (widget.isMine) ...[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edit status text'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                          if (!widget.isMine)
                            const PopupMenuItem<String>(
                              value: 'mute',
                              child: Text('Mute Status'),
                            ),
                        ];
                      },
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              if (story.resharedFromOwnerName != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 116,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.repeat, color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Reshared from ${story.resharedFromOwnerName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (story.type != StatusType.text && story.caption != null && story.caption!.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: LinkPreviewHelper.extractUrl(story.caption!) != null ? 84 : 78,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        story.caption!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (LinkPreviewHelper.extractUrl(story.caption!) != null) ...[
                        const SizedBox(height: 10),
                        LinkPreviewWidget(
                          url: LinkPreviewHelper.extractUrl(story.caption!)!,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                ),

              if (_isMediaBuffering)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // Bottom Interaction Bar
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {},
                  child: SafeArea(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: widget.isMine ? MainAxisAlignment.center : MainAxisAlignment.spaceEvenly,
                            children: [
                              if (widget.isMine && readReceiptsEnabled)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: showViewersSheet,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 24),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${story.seenBy.length} Views',
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              if (widget.isMine && !readReceiptsEnabled)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Turn on read receipts to see who viewed your status')),
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(Icons.visibility_off_rounded, color: Colors.white54, size: 24),
                                      SizedBox(width: 8),
                                      Text(
                                        'Views hidden',
                                        style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!widget.isMine) ...[
                                _buildGlassActionButton(
                                  icon: displayReaction ?? '♡',
                                  label: 'React',
                                  isEmoji: displayReaction != null,
                                  onTap: showReactionSheet,
                                ),
                                Container(height: 24, width: 1, color: Colors.white.withOpacity(0.2)),
                                _buildGlassActionButton(
                                  icon: Icons.maps_ugc_rounded,
                                  label: 'Reply',
                                  onTap: showCommentSheet,
                                ),
                                Container(height: 24, width: 1, color: Colors.white.withOpacity(0.2)),
                                _buildGlassActionButton(
                                  icon: Icons.screen_share_outlined,
                                  label: 'Reshare',
                                  onTap: reshare,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Emojis Canvas
              FloatingReactionsCanvas(reactionStream: _reactionStreamController.stream),

              // Floating Comments Canvas
              FloatingCommentsOverlay(commentStream: _commentStreamController.stream),
            ],
          );
            },
          ),
        ),
      ),
    ),
    );
  }

  void _showReuseAudioSheet(StatusStory story) {
    if (_currentStatusTrack == null) return;
    
    // Pause audio while sheet is open
    _audioPlayer.pause();
    final wasPlaying = _audioPlayer.state == PlayerState.playing;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note, color: Colors.greenAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _currentStatusTrack!.title,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _currentStatusTrack!.artist,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    Navigator.pop(context); // Close viewer
                    
                    final selectedMusic = SelectedMusicTrack(
                      track: _currentStatusTrack!,
                      startTime: Duration(milliseconds: story.musicStartTimeMs ?? 0),
                      endTime: story.musicEndTimeMs != null ? Duration(milliseconds: story.musicEndTimeMs!) : null,
                    );
                    
                    // You can customize which creation screen to push to here.
                    // Let's push CreateTextStatusScreen by default with the selected music
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateTextStatusScreen(initialMusic: selectedMusic),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Use this Audio'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (wasPlaying && mounted) {
        _audioPlayer.resume();
      }
    });
  }

  Future<void> showEditStatusSheet() async {
    final controller = TextEditingController(text: story.caption ?? '');

    progress.stop();
    videoController?.pause();
    _audioPlayer.pause();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.of(sheetContext).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit status text',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Edit caption/text...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF17171A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFB2),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final text = controller.text.trim();
                        HapticFeedback.lightImpact();
                        
                        try {
                          await ref.read(statusRepositoryProvider).updateStatusCaption(
                                statusId: story.id,
                                newCaption: text,
                              );
                          _stories[index] = story.copyWith(caption: text);
                          if (mounted) setState(() {});
                          
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Status updated successfully')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update status: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Save changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (mounted) {
      progress.forward();
      videoController?.play();
      if (story.musicTitle != null || story.type == StatusType.audio) {
        _audioPlayer.resume();
      }
    }
  }

  void _handleTwoFingerScrollOnStatus() {
    reshare();
  }

  void _handleThreeFingerScrollOnStatus() {
    if (widget.isMine) {
      _deleteCurrentStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own status updates')),
      );
    }
  }

  Future<void> _deleteCurrentStatus() async {
    HapticFeedback.mediumImpact();
    final statusId = story.id;
    try {
      await AppDatabase.instance.table('statuses').doc(statusId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status deleted')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete status: $e')));
      }
    }
  }
  Widget _buildGlassActionButton({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    bool isEmoji = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          if (icon is IconData)
            Icon(icon, color: Colors.white, size: 22)
          else if (icon is String)
            Text(icon, style: TextStyle(fontSize: isEmoji ? 22 : 24, color: Colors.white)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class CombinedMultiFingerDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTwoFingerScroll;
  final VoidCallback? onThreeFingerScroll;
  final double threshold;

  const CombinedMultiFingerDetector({
    super.key,
    required this.child,
    this.onTwoFingerScroll,
    this.onThreeFingerScroll,
    this.threshold = 40.0,
  });

  @override
  State<CombinedMultiFingerDetector> createState() => _CombinedMultiFingerDetectorState();
}

class _CombinedMultiFingerDetectorState extends State<CombinedMultiFingerDetector> {
  final Map<int, Offset> _pointerPositions = {};
  final Map<int, Offset> _pointerStarts = {};
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _pointerPositions[event.pointer] = event.position;
        _pointerStarts[event.pointer] = event.position;
      },
      onPointerMove: (event) {
        _pointerPositions[event.pointer] = event.position;

        if (!_triggered) {
          final count = _pointerPositions.length;
          if (count == 2 || count == 3) {
            double totalDisplacement = 0.0;
            for (final id in _pointerPositions.keys) {
              final start = _pointerStarts[id];
              final current = _pointerPositions[id];
              if (start != null && current != null) {
                totalDisplacement += (current - start).distance;
              }
            }
            final averageDisplacement = totalDisplacement / count;
            if (averageDisplacement > widget.threshold) {
              _triggered = true;
              if (count == 2 && widget.onTwoFingerScroll != null) {
                widget.onTwoFingerScroll!();
              } else if (count == 3 && widget.onThreeFingerScroll != null) {
                widget.onThreeFingerScroll!();
              }
            }
          }
        }
      },
      onPointerUp: (event) {
        _pointerPositions.remove(event.pointer);
        _pointerStarts.remove(event.pointer);
        if (_pointerPositions.isEmpty) {
          _triggered = false;
        }
      },
      onPointerCancel: (event) {
        _pointerPositions.remove(event.pointer);
        _pointerStarts.remove(event.pointer);
        if (_pointerPositions.isEmpty) {
          _triggered = false;
        }
      },
      child: widget.child,
    );
  }
}

class _AnimatedMusicWaves extends StatefulWidget {
  const _AnimatedMusicWaves({super.key});

  @override
  State<_AnimatedMusicWaves> createState() => _AnimatedMusicWavesState();
}

class _AnimatedMusicWavesState extends State<_AnimatedMusicWaves>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      width: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = index * (math.pi / 2);
              final t = _controller.value * 2 * math.pi;
              final sineVal = (math.sin(t + phase) + 1.0) / 2.0;
              final height = 3.0 + sineVal * 9.0;

              return Container(
                width: 2.2,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(0.5),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}