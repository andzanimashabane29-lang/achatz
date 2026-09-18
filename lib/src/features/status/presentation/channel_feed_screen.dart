import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'dart:io';
import 'package:a_chatz/src/features/status/domain/channel_models.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:a_chatz/src/features/chat/presentation/chat_room_screen.dart'
    show VoiceNoteBubble, ImagePreviewScreen;
import 'package:a_chatz/src/features/chat/presentation/media_preview_send_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/in_app_camera_capture_screen.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/features/profile/presentation/verification_info_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

class ChannelFeedScreen extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelFeedScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChannelFeedScreen> createState() => _ChannelFeedScreenState();
}

class _ChannelFeedScreenState extends ConsumerState<ChannelFeedScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isSending = false;
  bool _uploading = false;

  XFile? _attachedImage;
  XFile? _attachedVideo;
  XFile? _attachedFile;
  String? _attachedFileName;
  String? _pendingCaption;

  bool _recording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  Timer? _secondsTimer;
  final List<double> _liveWaveform = [];
  StreamSubscription<Amplitude>? _ampSub;

  String get _timerLabel {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _msgController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startVoiceRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    HapticFeedback.mediumImpact();

    _liveWaveform.clear();
    _recordingSeconds = 0;

    // Amplitude monitoring not available in current record package version
    // Using timer-based placeholder for waveform visualization
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        _liveWaveform.add(0.5); // Placeholder value
        if (_liveWaveform.length > 60) _liveWaveform.removeAt(0);
      });
    });

    _secondsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });

    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopAndSendVoiceNote(String channelName) async {
    _secondsTimer?.cancel();
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    if (mounted) setState(() => _recording = false);
    if (path == null) return;

    setState(() {
      _attachedFile = XFile(path);
      _attachedFileName = path.split('/').last;
    });
    await _postMessage(channelName);
  }

  void _cancelRecording() async {
    _ampSub?.cancel();
    _recordingTimer?.cancel();
    await _recorder.stop();
    if (mounted) {
      setState(() {
        _recording = false;
        _recordingSeconds = 0;
        _liveWaveform.clear();
      });
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _pickPhotoFromGallery() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 100,
      maxWidth: 4096,
      maxHeight: 4096,
    );
    if (picked.isEmpty || !mounted) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPreviewSendScreen(
          xFile: picked.first,
          isVideo: false,
        ),
      ),
    );

    if (result != null && mounted) {
      final editedPath = result['editedFile'] as String?;
      final xFile = editedPath != null ? XFile(editedPath) : picked.first;
      final caption = result['caption'] as String?;
      await _uploadMediaDirectly(xFile, MessageType.image, caption: caption);
    }
  }

  Future<void> _pickPhotoFromCamera() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const InAppCameraCaptureScreen(isVideoMode: false),
      ),
    );
    if (result != null && result['file'] != null && mounted) {
      final file = result['file'] as File;
      final caption = result['caption'] as String?;
      await _uploadMediaDirectly(XFile(file.path), MessageType.image, caption: caption);
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
    if (picked == null || !mounted) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPreviewSendScreen(
          xFile: picked,
          isVideo: true,
        ),
      ),
    );

    if (result != null && mounted) {
      final editedPath = result['editedFile'] as String?;
      final xFile = editedPath != null ? XFile(editedPath) : picked;
      final caption = result['caption'] as String?;
      await _uploadMediaDirectly(xFile, MessageType.video, caption: caption);
    }
  }

  Future<void> _pickVideoFromCamera() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const InAppCameraCaptureScreen(isVideoMode: true),
      ),
    );
    if (result != null && result['file'] != null && mounted) {
      final file = result['file'] as File;
      final caption = result['caption'] as String?;
      await _uploadMediaDirectly(XFile(file.path), MessageType.video, caption: caption);
    }
  }

  XFile _platformFileToXFile(PlatformFile platformFile) {
    if (kIsWeb) {
      return XFile.fromData(platformFile.bytes!, name: platformFile.name);
    } else {
      return XFile(platformFile.path!);
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && mounted) {
      final xFile = _platformFileToXFile(result.files.single);
      await _uploadMediaDirectly(xFile, MessageType.document);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && mounted) {
      final xFile = _platformFileToXFile(result.files.single);
      await _uploadMediaDirectly(xFile, MessageType.voice);
    }
  }

  void _clearAttachments() {
    setState(() {
      _attachedImage = null;
      _attachedVideo = null;
      _attachedFile = null;
      _attachedFileName = null;
      _pendingCaption = null;
    });
  }

  bool get _hasAttachment =>
      _attachedImage != null ||
      _attachedVideo != null ||
      _attachedFile != null;

  Future<void> _postMessage(String channelName) async {
    final text = _pendingCaption ?? _msgController.text.trim();
    
    // Send text message if no attachment
    if (text.isNotEmpty && !_hasAttachment) {
      await _sendTextMessage(text);
      return;
    }
    
    // Send media directly to channel posts collection
    if (_attachedImage != null) {
      await _uploadMediaDirectly(_attachedImage!, MessageType.image, caption: text);
    } else if (_attachedVideo != null) {
      await _uploadMediaDirectly(_attachedVideo!, MessageType.video, caption: text);
    } else if (_attachedFile != null) {
      final name = _attachedFileName ?? '';
      final isVoice = name.endsWith('.m4a') || name.endsWith('.mp3') || name.endsWith('.wav');
      await _uploadMediaDirectly(_attachedFile!, isVoice ? MessageType.voice : MessageType.document);
    }
  }

  Future<void> _sendTextMessage(String text) async {
    setState(() => _isSending = true);
    try {
      await AppDatabase.instance
          .table('channels')
          .doc(widget.channelId)
          .table('posts')
          .add({
        'content': text,
        'type': 'text',
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': AppAuth.instance.currentUser?.uid,
      });
      ref.read(channelRepositoryProvider).sendPostNotification(widget.channelId, text);
      _msgController.clear();
      _clearAttachments();
    } catch (e) {
      debugPrint('Error sending text: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _uploadMediaDirectly(XFile file, MessageType type, {String? caption}) async {
    if (_uploading) return;
    setState(() => _uploading = true);

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final storageRef = AppStorage.instance.ref().child('chat_media/${widget.channelId}/$fileName');

      final isVoice = file.name.endsWith('.m4a') || file.name.endsWith('.mp3') || file.name.endsWith('.wav') || type == MessageType.voice;
      final metadata = SettableMetadata(
        contentType: type == MessageType.image ? 'image/jpeg' : 
                     type == MessageType.video ? 'video/mp4' : 
                     (type == MessageType.voice || isVoice) ? 'audio/mpeg' : 'application/octet-stream',
      );

      final UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        uploadTask = storageRef.putData(bytes, metadata);
      } else {
        uploadTask = storageRef.putFile(File(file.path), metadata);
      }
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final myUid = AppAuth.instance.currentUser?.uid;

      final postData = <String, dynamic>{
        'content': caption ?? '',
        'caption': caption ?? '',
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': myUid,
        'mediaUrl': downloadUrl,
      };

      if (type == MessageType.image) {
        postData['imageUrl'] = downloadUrl;
        postData['type'] = 'image';
      } else if (type == MessageType.video) {
        postData['videoUrl'] = downloadUrl;
        postData['type'] = 'video';
      } else if (type == MessageType.voice || isVoice) {
        postData['fileUrl'] = downloadUrl;
        postData['fileName'] = file.name;
        postData['type'] = 'voice';
      } else {
        postData['fileUrl'] = downloadUrl;
        postData['fileName'] = file.name;
        postData['type'] = 'document';
      }

      await AppDatabase.instance
          .table('channels')
          .doc(widget.channelId)
          .table('posts')
          .add(postData);
      ref.read(channelRepositoryProvider).sendPostNotification(widget.channelId, caption ?? 'Shared a new media post');

      _msgController.clear();
      _clearAttachments();

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error uploading media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteChannelPost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        title: const Text('Delete Post?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this post for everyone?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AppDatabase.instance
            .table('channels')
            .doc(widget.channelId)
            .table('posts')
            .doc(postId)
            .update({
          'deletedByAdmin': true,
          'type': 'text',
          'content': 'This post was deleted by Admin',
          'mediaUrl': null,
          'imageUrl': null,
          'videoUrl': null,
          'fileUrl': null,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        debugPrint('Error deleting channel post: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete post: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  void _reactToPost(String postId, Map<String, dynamic> currentReactions,
      String emoji) async {
    final myUid = AppAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final reactionsMap = Map<String, dynamic>.from(currentReactions);
    final List<dynamic> users =
        List<dynamic>.from(reactionsMap[emoji] ?? []);

    if (users.contains(myUid)) {
      users.remove(myUid);
    } else {
      users.add(myUid);
    }

    if (users.isEmpty) {
      reactionsMap.remove(emoji);
    } else {
      reactionsMap[emoji] = users;
    }

    try {
      await AppDatabase.instance
          .table('channels')
          .doc(widget.channelId)
          .table('posts')
          .doc(postId)
          .update({'reactions': reactionsMap});
    } catch (e) {
      debugPrint('Error reacting: $e');
    }
  }

  void _showReactionSheet(
      String postId, Map<String, dynamic> currentReactions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFB16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '🎉', '🙌', '💯'];
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'React to Broadcast',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: emojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        _reactToPost(postId, currentReactions, emoji);
                        Navigator.pop(ctx);
                      },
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 34)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _castChannelVote(String postId, int optionIndex) async {
    final myUid = AppAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final postRef = AppDatabase.instance
        .table('channels')
        .doc(widget.channelId)
        .table('posts')
        .doc(postId);

    try {
      await AppDatabase.instance
          .runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) return;

        final pollVotes = Map<String, dynamic>.from(
            snapshot.data()?['pollVotes'] ?? {});
        final optionKey = optionIndex.toString();

        pollVotes.forEach((key, list) {
          final List<dynamic> uids = List<dynamic>.from(list);
          if (key == optionKey) {
            if (!uids.contains(myUid)) uids.add(myUid);
          } else {
            uids.remove(myUid);
          }
          pollVotes[key] = uids;
        });

        transaction.update(postRef, {'pollVotes': pollVotes});
      });
    } catch (e) {
      debugPrint('Error casting vote: $e');
    }
  }

  void _showCreateChannelPollDialog() {
    showDialog(
      context: context,
      builder: (context) => const _CreatePollDialog(),
    ).then((result) async {
      if (result != null && result is Map<String, dynamic>) {
        final question = result['question'] as String;
        final options = result['options'] as List<String>;
        final votes = <String, List<String>>{};
        for (int i = 0; i < options.length; i++) {
          votes[i.toString()] = [];
        }

        setState(() => _isSending = true);
        try {
          await AppDatabase.instance
              .table('channels')
              .doc(widget.channelId)
              .table('posts')
              .add({
            'type': 'poll',
            'pollQuestion': question,
            'pollOptions': options,
            'pollVotes': votes,
            'reactions': {},
            'createdAt': FieldValue.serverTimestamp(),
          });
          ref.read(channelRepositoryProvider).sendPostNotification(widget.channelId, 'Poll: $question');
        } catch (e) {
          debugPrint('Error creating poll: $e');
        } finally {
          if (mounted) setState(() => _isSending = false);
        }
      }
    });
  }

  void _showChannelMediaOptions(String channelName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add to Broadcast',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose what to attach to your broadcast.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _MediaOptionTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF5E9EFF),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickPhotoFromCamera();
                    },
                  ),
                  _MediaOptionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF9B5EFF),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickPhotoFromGallery();
                    },
                  ),
                  _MediaOptionTile(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: const Color(0xFFFF5E5E),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showVideoSourceSheet();
                    },
                  ),
                  _MediaOptionTile(
                    icon: Icons.music_note_rounded,
                    label: 'Music',
                    color: const Color(0xFFFF5EBA),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAudio();
                    },
                  ),
                  _MediaOptionTile(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    color: const Color(0xFF5EFF9E),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickDocument();
                    },
                  ),
                  _MediaOptionTile(
                    icon: Icons.poll_rounded,
                    label: 'Poll',
                    color: const Color(0xFFFFCA5E),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateChannelPollDialog();
                    },
                  ),
                  _MediaOptionTile(
                    icon: Icons.mic_rounded,
                    label: 'Voice',
                    color: const Color(0xFF5EFFCA),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startVoiceRecording();
                    },
                  ),
                  _MediaOptionTile(
                    icon: Icons.gif_box_rounded,
                    label: 'GIF',
                    color: const Color(0xFFFF9B5E),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('GIF picker coming soon!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showVideoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.blueAccent),
                title: const Text('Record Video',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideoFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library,
                    color: Colors.purpleAccent),
                title: const Text('Choose from Gallery',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideoFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChannelProfile(
      BuildContext context,
      String name,
      String description,
      int followersCount,
      String? ownerId,
      bool isAdmin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16161A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(name,
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description,
                style:
                    const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Text('$followersCount subscribers',
                style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('Channel QR Code',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data:
                      'achatz://channel/${widget.channelId}',
                  version: QrVersions.auto,
                  size: 150.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManageMembersDialog(
                  context, widget.channelId, ownerId ?? '');
            },
            child: Text(isAdmin ? 'Manage Subscribers' : 'View Members',
                style:
                    const TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsDashboard(BuildContext context, String channelName, int followers) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '$channelName - Analytics',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.insights, color: Colors.blueAccent),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCard('Subscribers', '$followers', Icons.people_outline),
                    _buildMetricCard('Reach (Last 7d)', '${(followers * 1.45).toInt()}', Icons.visibility_outlined),
                    _buildMetricCard('Engagement', '12.4%', Icons.favorite_border),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Subscriber Growth (Mock)', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildGrowthBar('Mon', 20),
                      _buildGrowthBar('Tue', 35),
                      _buildGrowthBar('Wed', 55),
                      _buildGrowthBar('Thu', 45),
                      _buildGrowthBar('Fri', 75),
                      _buildGrowthBar('Sat', 90),
                      _buildGrowthBar('Sun', 110),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF232329),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthBar(String day, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  void _showManageMembersDialog(
      BuildContext context, String channelId, String ownerId) {
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance
              .table('channels')
              .doc(channelId)
              .table('followers')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: Colors.blueAccent));
            }
            final members = snapshot.data!.docs;
            final currentUid = AppAuth.instance.currentUser?.uid;
            String myRole = 'member';
            for (final doc in members) {
              if (doc.data()['uid'] == currentUid) {
                myRole = doc.data()['role'] ?? 'member';
                break;
              }
            }
            final isOwnerOrAdmin = (currentUid == ownerId) || (myRole == 'admin');

            return AlertDialog(
              backgroundColor: const Color(0xFF16161A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: const Text('Channel Subscribers',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: members.isEmpty
                  ? const Text('No subscribers yet.',
                      style: TextStyle(color: Colors.white54))
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: members.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10),
                        itemBuilder: (context, index) {
                          final memberData = members[index].data();
                          final memberUid = memberData['uid'] ?? '';
                          final role = memberData['role'] ?? 'member';
                          return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: AppDatabase.instance
                                .table('users')
                                .doc(memberUid)
                                .snapshots(),
                            builder: (context, userSnap) {
                              final userData = userSnap.data?.data();
                              final name =
                                  userData?['username'] ?? 'Subscriber';
                              final photoUrl =
                                  userData?['photoUrl'] as String?;
                              final isOwner = memberUid == ownerId;
                              final isAdmin = role == 'admin';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.white10,
                                  backgroundImage: photoUrl != null
                                      ? CachedNetworkImageProvider(
                                          photoUrl,
                                          maxWidth: 100,
                                        )
                                      : null,
                                  child: photoUrl == null
                                      ? const Icon(Icons.person,
                                          color: Colors.white54)
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    if (userData?['isVerified'] == true || memberUid == 'official_a_chatz') ...[
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => showVerificationInfoDialog(context),
                                        child: const Icon(Icons.verified, size: 14, color: Colors.blueAccent),
                                      ),
                                    ],
                                    if (isOwner) ...[
                                      const SizedBox(width: 8),
                                      _RoleBadge(
                                          label: 'OWNER',
                                          color: Colors.blueAccent),
                                    ] else if (isAdmin) ...[
                                      const SizedBox(width: 8),
                                      _RoleBadge(
                                          label: 'ADMIN',
                                          color: Colors.redAccent),
                                    ],
                                  ],
                                ),
                                trailing: (isOwnerOrAdmin && !isOwner && memberUid != currentUid)
                                    ? PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.white70),
                                        color: const Color(0xFF1E1E1E),
                                        onSelected: (val) async {
                                          if (val == 'promote') {
                                            await ref
                                                .read(
                                                    channelRepositoryProvider)
                                                .updateMemberRole(channelId,
                                                    memberUid, 'admin');
                                          } else if (val == 'demote') {
                                            await ref
                                                .read(
                                                    channelRepositoryProvider)
                                                .updateMemberRole(channelId,
                                                    memberUid, 'member');
                                          } else if (val == 'remove') {
                                            await ref
                                                .read(
                                                    channelRepositoryProvider)
                                                .removeMember(
                                                    channelId, memberUid);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (!isAdmin)
                                            const PopupMenuItem(
                                              value: 'promote',
                                              child: Text(
                                                  'Make Admin',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          if (isAdmin)
                                            const PopupMenuItem(
                                              value: 'demote',
                                              child: Text(
                                                  'Remove Admin',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          const PopupMenuItem(
                                            value: 'remove',
                                            child: Text('Remove Subscriber',
                                                style: TextStyle(
                                                    color:
                                                        Colors.redAccent)),
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AppAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppDatabase.instance
          .table('channels')
          .doc(widget.channelId)
          .snapshots(),
      builder: (context, channelSnap) {
        if (!channelSnap.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child:
                    CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }
        final channelData = channelSnap.data!.data();
        if (channelData == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: Text('Channel not found',
                    style: TextStyle(color: Colors.white))),
          );
        }

        final name = channelData['name'] ?? 'Channel';
        final description = channelData['description'] ?? '';
        final photoUrl = channelData['photoUrl'] as String?;
        final ownerId = channelData['ownerId'] as String?;
        final isVerified = channelData['isVerified'] ?? false;
        final followersCount = channelData['followersCount'] ?? 0;

        final followedRoles =
            ref.watch(followedChannelsRolesProvider).value ??
                <String, String>{};
        final userRole = followedRoles[widget.channelId] ?? '';
        final isAdmin = ownerId == currentUid ||
            userRole == 'owner' ||
            userRole == 'admin';

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F11),
          appBar: AppBar(
            backgroundColor: const Color(0xDD1A1A1E),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _showChannelProfile(context, name, description, followersCount, ownerId, isAdmin),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white10,
                    backgroundImage: photoUrl != null
                        ? CachedNetworkImageProvider(
                            photoUrl,
                            maxWidth: 100,
                          )
                        : null,
                    child: photoUrl == null
                        ? const Icon(Icons.campaign, color: Colors.blueAccent)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => showVerificationInfoDialog(context),
                                child: const Icon(Icons.verified,
                                    color: Colors.blueAccent, size: 14),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '$followersCount subscribers',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.analytics_outlined, color: Colors.white70),
                  onPressed: () {
                    _showAnalyticsDashboard(context, name, followersCount);
                  },
                ),
              IconButton(
                icon:
                    const Icon(Icons.info_outline, color: Colors.white70),
                onPressed: () {
                  _showChannelProfile(context, name, description, followersCount, ownerId, isAdmin);
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: AppDatabase.instance
                      .table('channels')
                      .doc(widget.channelId)
                      .table('posts')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, postsSnap) {
                    if (!postsSnap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.blueAccent));
                    }

                    final posts = postsSnap.data!.docs;

                    if (posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.campaign_outlined,
                                color: Colors.white24, size: 64),
                            const SizedBox(height: 12),
                            Text(
                              'Welcome to $name!',
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Broadcasts will appear here.',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 16),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final data = post.data();
                        final isSender = currentUid == data['senderId'];
                        return _ChannelPostBubble(
                          postId: post.id,
                          data: data,
                          currentUid: currentUid,
                          onReact: _showReactionSheet,
                          onVote: _castChannelVote,
                          onDelete: (isSender || isAdmin) ? () => _deleteChannelPost(post.id) : null,
                        );
                      },
                    );
                  },
                ),
              ),
              if (_hasAttachment && !_recording)
                Container(
                  color: const Color(0xFF1E1E22),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _attachedImage != null
                            ? Icons.image
                            : _attachedVideo != null
                                ? Icons.videocam
                                : Icons.insert_drive_file,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _attachedImage != null
                              ? 'Photo attached'
                              : _attachedVideo != null
                                  ? 'Video attached'
                                  : (_attachedFileName ?? 'File attached'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: _clearAttachments,
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF16161A),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: isAdmin
                    ? _recording
                        ? _buildRecordingRow(name)
                        : _buildComposeRow(name)
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, color: Colors.white38, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Only Admins can write to this channel.',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComposeRow(String channelName) {
    final hasContent =
        _msgController.text.isNotEmpty || _hasAttachment;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () => _showChannelMediaOptions(channelName),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4, right: 6),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.15),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.blueAccent.withOpacity(0.4)),
            ),
            child:
                const Icon(Icons.add, color: Colors.blueAccent, size: 20),
          ),
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _msgController,
              maxLines: null,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Broadcast a message...',
                hintStyle:
                    TextStyle(color: Colors.white30, fontSize: 14),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            if (hasContent) {
              await _postMessage(channelName);
            } else {
              await _startVoiceRecording();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: hasContent ? Colors.blueAccent : Colors.blueAccent.withOpacity(0.7),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: _isSending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Icon(
                    hasContent
                        ? Icons.send_rounded
                        : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingRow(String channelName) {
    final heights = _liveWaveform.isEmpty
        ? List<double>.filled(22, 4.0)
        : _liveWaveform.map((v) {
            final h = 4.0 + v * 26.0;
            return h.clamp(4.0, 30.0);
          }).toList();

    return Row(
      children: [
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            ),
            child: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 36,
            child: CustomPaint(
              painter: _LiveWaveformPainter(
                heights: heights,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _timerLabel,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _stopAndSendVoiceNote(channelName),
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  _LiveWaveformPainter({required this.heights, required this.color});

  final List<double> heights;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.fill;

    final barCount = heights.length;
    const barWidth = 3.5;
    final spacing = barCount > 1
        ? (size.width - barCount * barWidth) / (barCount - 1)
        : 0.0;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final h = heights[i].clamp(4.0, size.height);
      final left = i * (barWidth + spacing.clamp(1.0, double.infinity));
      final opacity = (i / barCount) * 0.7 + 0.3;
      paint.color = color.withOpacity(opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, centerY - h / 2, left + barWidth,
              centerY + h / 2),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveWaveformPainter old) => true;
}

class _ChannelPostBubble extends StatelessWidget {
  const _ChannelPostBubble({
    required this.postId,
    required this.data,
    required this.currentUid,
    required this.onReact,
    required this.onVote,
    this.onDelete,
  });

  final String postId;
  final Map<String, dynamic> data;
  final String? currentUid;
  final void Function(String, Map<String, dynamic>) onReact;
  final void Function(String, int) onVote;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final postType = data['type'] as String? ?? 'text';
    final content = data['content'] as String? ?? data['caption'] as String? ?? '';
    final mediaUrl = data['mediaUrl'] as String?;
    final imageUrl = postType == 'image' ? (mediaUrl ?? data['imageUrl'] as String?) : null;
    final videoUrl = postType == 'video' ? (mediaUrl ?? data['videoUrl'] as String?) : null;
    final fileUrl = (postType == 'file' || postType == 'document' || postType == 'voice') ? (mediaUrl ?? data['fileUrl'] as String?) : null;
    final fileName = data['fileName'] as String?;
    final reactions =
        data['reactions'] as Map<String, dynamic>? ?? {};
    final ts = data['createdAt'] as Timestamp?;
    final timeLabel = ts != null
        ? _formatTime(ts.toDate())
        : '';

    final isVoice = postType == 'voice' || (fileName != null &&
        (fileName.endsWith('.m4a') ||
            fileName.endsWith('.mp3') ||
            fileName.endsWith('.wav')));

    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.isNotEmpty && postType != 'poll')
            Text(
              content,
              style: TextStyle(
                color: data['deletedByAdmin'] == true ? Colors.white60 : Colors.white,
                fontSize: 15,
                height: 1.4,
                fontStyle: data['deletedByAdmin'] == true ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          if (postType == 'poll')
            _PollBubbleWidget(
              question: data['pollQuestion'] as String? ?? '',
              options: List<String>.from(data['pollOptions'] ?? []),
              pollVotes:
                  Map<String, dynamic>.from(data['pollVotes'] ?? {}),
              onVote: (idx) => onVote(postId, idx),
            ),
          if (imageUrl != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImagePreviewScreen(imageUrl: imageUrl),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 180,
                    color: Colors.white10,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Loading image...',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.white10,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white38, size: 32),
                        SizedBox(height: 4),
                        Text(
                          'Failed to load',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  memCacheWidth: 800,
                  maxWidthDiskCache: 800,
                ),
              ),
            ),
          ],
          if (videoUrl != null) ...[
            const SizedBox(height: 10),
            _InlineVideoPlayer(url: videoUrl),
          ],
          if (fileUrl != null && fileName != null) ...[
            const SizedBox(height: 10),
            if (isVoice)
              VoiceNoteBubble(url: fileUrl, mine: false, fileName: fileName)
            else
              _DocumentRow(fileName: fileName, fileUrl: fileUrl),
          ],
          if (timeLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                timeLabel,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () => onReact(postId, reactions),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_reaction_outlined,
                      color: Colors.white70, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: reactions.entries.map((entry) {
                    final emoji = entry.key;
                    final List<dynamic> users = entry.value;
                    final count = users.length;
                    final hasReacted = users.contains(currentUid);
                    return GestureDetector(
                      onTap: () => onReact(postId, reactions),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasReacted
                              ? Colors.blueAccent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasReacted
                                ? Colors.blueAccent.withOpacity(0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '$count',
                              style: TextStyle(
                                color: hasReacted
                                    ? Colors.blueAccent
                                    : Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1) {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({required this.url});
  final String url;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _hasError = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      }).catchError((error) {
        if (mounted) setState(() => _hasError = true);
      });
    _ctrl.setLooping(false);
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: _initialized ? _ctrl.value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_hasError)
              Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load video',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Check your connection',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else if (_initialized)
              VideoPlayer(_ctrl)
            else
              Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                      SizedBox(height: 12),
                      Text(
                        'Loading video...',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_hasError && _initialized)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _ctrl.value.isPlaying
                        ? _ctrl.pause()
                        : _ctrl.play();
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _ctrl.value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
            if (_initialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: VideoProgressIndicator(
                          _ctrl,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          colors: const VideoProgressColors(
                            playedColor: Colors.blueAccent,
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() => _muted = !_muted);
                          _ctrl.setVolume(_muted ? 0 : 1);
                        },
                        child: Icon(
                          _muted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.fileName, required this.fileUrl});
  final String fileName;
  final String fileUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file,
              color: Colors.blueAccent, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new,
                color: Colors.white54, size: 18),
            onPressed: () {
            },
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _MediaOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PollBubbleWidget extends StatelessWidget {
  const _PollBubbleWidget({
    required this.question,
    required this.options,
    required this.pollVotes,
    required this.onVote,
  });

  final String question;
  final List<String> options;
  final Map<String, dynamic> pollVotes;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final currentUid = AppAuth.instance.currentUser?.uid;

    int totalVotes = 0;
    final Map<int, List<String>> optionVoters = {};
    for (int i = 0; i < options.length; i++) {
      final voters = List<String>.from(pollVotes[i.toString()] ?? []);
      optionVoters[i] = voters;
      totalVotes += voters.length;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.poll, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(options.length, (index) {
            final voters = optionVoters[index] ?? [];
            final count = voters.length;
            final isSelected = voters.contains(currentUid);
            final ratio = totalVotes > 0 ? count / totalVotes : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onVote(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              color: isSelected
                                  ? Colors.blueAccent.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blueAccent.withOpacity(0.5)
                                : Colors.white.withOpacity(0.08),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(options[index],
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              count == 1 ? '1 vote' : '$count votes',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (totalVotes > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                totalVotes == 1
                    ? '1 total vote'
                    : '$totalVotes total votes',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreatePollDialog extends StatefulWidget {
  const _CreatePollDialog();

  @override
  State<_CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<_CreatePollDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16161A),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Create Poll',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _questionController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Question',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Options',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            ...List.generate(_optionControllers.length, (index) {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[index],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Option ${index + 1}',
                        labelStyle:
                            const TextStyle(color: Colors.white30),
                        enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white12)),
                        focusedBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.blueAccent)),
                      ),
                    ),
                  ),
                  if (_optionControllers.length > 2)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _optionControllers[index].dispose();
                          _optionControllers.removeAt(index);
                        });
                      },
                    ),
                ],
              );
            }),
            const SizedBox(height: 12),
            if (_optionControllers.length < 10)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _optionControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add, color: Colors.blueAccent),
                label: const Text('Add Option',
                    style: TextStyle(color: Colors.blueAccent)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () {
            final question = _questionController.text.trim();
            final options = _optionControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            if (question.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Question is required')));
              return;
            }
            if (options.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('At least 2 options are required')));
              return;
            }
            Navigator.pop(context, {'question': question, 'options': options});
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}
