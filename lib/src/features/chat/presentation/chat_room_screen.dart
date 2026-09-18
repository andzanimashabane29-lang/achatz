import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/shared/widgets/invoice_receipt_card.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/features/chat/data/chat_repository.dart';
import 'package:a_chatz/src/features/chat/presentation/media_preview_send_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/in_app_camera_capture_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/quick_reply_sheet.dart';
import 'package:a_chatz/src/features/chat/presentation/decrypted_text.dart';
import 'package:a_chatz/src/features/chat/presentation/contact_detail_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/location_viewer_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/verification_info_screen.dart';
import 'package:a_chatz/src/shared/widgets/link_preview_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:a_chatz/src/features/calls/providers/call_providers.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:a_chatz/src/core/services/encryption_service.dart';
import 'package:a_chatz/src/shared/widgets/cached_media_wrapper.dart';
import 'package:a_chatz/src/shared/services/local_media_cache.dart';
import 'package:a_chatz/src/shared/widgets/wallpaper_background.dart';
import 'package:a_chatz/src/core/services/gemini_service.dart';
import 'package:a_chatz/src/core/services/ai_tools_service.dart';
import 'package:a_chatz/src/features/chat/presentation/ai_sticker_creator_sheet.dart';
import 'package:a_chatz/src/features/chat/presentation/sticker_creator_screen.dart';
import 'package:a_chatz/src/shared/widgets/premium_avatar.dart';
import 'package:a_chatz/src/features/chat/presentation/tipping_sheet.dart';
import 'package:a_chatz/src/features/chat/presentation/game_board_screen.dart';
import 'package:a_chatz/src/features/calls/presentation/schedule_call_sheet.dart';
import 'package:a_chatz/src/shared/widgets/scheduled_call_card.dart';
import 'package:a_chatz/src/shared/widgets/logo_doodle_background.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:a_chatz/src/features/status/data/channel_repository.dart';


class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final input = TextEditingController();
  final recorder = AudioRecorder();
  final _chimePlayer = AudioPlayer();

  ChatMessage? replyingTo;

  bool sending = false;
  bool uploading = false;
  bool recording = false;
  bool _viewOnceVoice = false;
  bool _enterIsSend = false;
  String? _wallpaperPath;
  Timer? _locationTimer;
  late final FocusNode _chatInputFocusNode;


  int? _activeSelfDestructSeconds;
  final Map<String, String> _localTranslations = {};
  List<String> _smartSuggestions = [];
  String? _lastSuggestedMsgId;
  String? _activePreviewUrl;
  LinkMetadata? _previewMetadata;
  String? _dismissedPreviewUrl;

  Future<void> _generateSmartSuggestions(ChatMessage lastMsg) async {
    if (_lastSuggestedMsgId == lastMsg.id) return;
    _lastSuggestedMsgId = lastMsg.id;

    // Fast local defaults
    final txt = lastMsg.cipherText.toLowerCase();
    List<String> localReplies = ["Sounds good!", "Got it, thanks!", "Let's do it!"];
    if (txt.contains('?')) {
      localReplies = ["Yes, absolutely!", "I'm not sure yet.", "Let me check."];
    } else if (txt.contains('hello') || txt.contains('hi ') || txt.contains('hey')) {
      localReplies = ["Hey! How's it going?", "Hello! Hope you're well.", "Hey there!"];
    } else if (txt.contains('meeting') || txt.contains('time') || txt.contains('when')) {
      localReplies = ["Sure, what time?", "Sounds good to me!", "Let's meet later."];
    }

    if (mounted) {
      setState(() {
        _smartSuggestions = localReplies;
      });
    }

    // Background Gemini Suggestions
    try {
      final prompt = "Based on this message: \"${lastMsg.cipherText}\", generate exactly 3 short, natural, conversational reply suggestions (maximum 4 words each). Output ONLY the 3 suggestions as a JSON array of strings, e.g. [\"Reply 1\", \"Reply 2\", \"Reply 3\"]. Do not add markdown backticks or any other text.";
      final response = await GeminiService.instance.generateText(prompt);
      
      final cleanJson = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> parsed = jsonDecode(cleanJson);
      final list = parsed.map((e) => e.toString()).toList();
      if (list.length == 3 && mounted) {
        setState(() {
          _smartSuggestions = list;
        });
      }
    } catch (_) {}
  }


  Widget _buildSmartSuggestions() {
    if (_smartSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _smartSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final suggestion = _smartSuggestions[idx];
          return GestureDetector(
            onTap: () {
              input.text = suggestion;
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purpleAccent.withOpacity(0.15),
                    Colors.blueAccent.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.purpleAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  suggestion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  bool _isTypingLocal = false;
  String? _superReactionEmoji;

  void _triggerSuperReaction(String emoji) {
    if (mounted) {
      setState(() {
        _superReactionEmoji = emoji;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
    input.addListener(_onTextChanged);
    _chatInputFocusNode = FocusNode();
    _chatInputFocusNode.onKeyEvent = (node, event) {
      if (_enterIsSend &&
          event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        send();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).clearUnreadCount(widget.chatId);
    });
  }

  void _onTextChanged() {
    final text = input.text;
    final url = LinkPreviewHelper.extractUrl(text);

    if (url == null) {
      if (_activePreviewUrl != null) {
        setState(() {
          _activePreviewUrl = null;
          _previewMetadata = null;
        });
      }
      return;
    }

    if (url == _dismissedPreviewUrl) {
      return;
    }

    if (url != _activePreviewUrl) {
      setState(() {
        _activePreviewUrl = url;
        _previewMetadata = null;
      });

      LinkPreviewHelper.fetchMetadata(url).then((metadata) {
        if (mounted && _activePreviewUrl == url) {
          setState(() {
            _previewMetadata = metadata;
          });
        }
      });
    }
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _enterIsSend = prefs.getBool('enter_is_send') ?? false;
        _wallpaperPath = prefs.getString('chat_wallpaper_path');
      });
    }
  }

  @override
  void dispose() {
    ref.read(chatRepositoryProvider).setTyping(widget.chatId, false);
    ref.read(chatRepositoryProvider).setRecording(widget.chatId, false);
    input.removeListener(_onTextChanged);
    input.dispose();
    recorder.dispose();
    _chimePlayer.dispose();
    _locationTimer?.cancel();
    _chatInputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _playSendChime() async {
    try {
      await _chimePlayer.setAsset('assets/chime.wav');
      await _chimePlayer.play();
    } catch (e) {
      debugPrint('Error playing send chime: $e');
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;

    setState(() {
      sending = true;
      _isTypingLocal = false;
      _dismissedPreviewUrl = null;
      _activePreviewUrl = null;
      _previewMetadata = null;
    });
    input.clear();

    try {
      await ref.read(chatRepositoryProvider).setTyping(widget.chatId, false);

      // Check if it's an AI trigger message!
      if (text.startsWith('@ai') || text.startsWith('@gemini')) {
        // 1. First post the user's prompt as a standard text message
        await ref.read(chatRepositoryProvider).sendText(
              widget.chatId,
              text,
              replyToMessageId: replyingTo?.id,
              selfDestructDuration: _activeSelfDestructSeconds,
            );

        if (mounted) {
          setState(() {
            replyingTo = null;
          });
        }
        _playSendChime();
        HapticFeedback.lightImpact();

        // 2. Fetch the prompt text (exclude the '@ai' or '@gemini' keyword)
        final prompt = text.replaceFirst(RegExp(r'^@(ai|gemini)\s*'), '');

        // 3. Post a transient "AI is thinking..." bubble
        final aiMessageRef = AppDatabase.instance
            .table('chats')
            .doc(widget.chatId)
            .table('messages')
            .doc();

        await aiMessageRef.set({
          'senderId': 'ai_bot', // Custom ID for AI response bubble!
          'type': 'text',
          'cipherText': '🤖 *AI is thinking...*',
          'mediaUrl': null,
          'fileName': null,
          'durationMs': null,
          'createdAt': FieldValue.serverTimestamp(),
          'editedAt': null,
          'deletedFor': [],
          'deletedForEveryone': false,
          'reactions': {},
          'starredBy': [],
          'deliveredTo': {},
          'readBy': {},
          'isEncrypted': false,
        });

        // 4. Query Gemini API in the background
        final aiResponse = await GeminiService.instance.generateText(prompt);

        // 5. Update the bubble with the final AI response!
        await aiMessageRef.update({
          'cipherText': '🤖 *A-Chatz AI*:\n\n$aiResponse',
        });
      } else {
        // Standard message sending with optional self-destruct property
        await ref.read(chatRepositoryProvider).sendText(
              widget.chatId,
              text,
              replyToMessageId: replyingTo?.id,
              selfDestructDuration: _activeSelfDestructSeconds,
            );
        if (mounted) {
          setState(() {
            replyingTo = null;
          });
        }
        _playSendChime();
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }

    if (mounted) setState(() => sending = false);
  }

  Future<void> _goToContactDetails() async {
    final chatDoc = await AppDatabase.instance.table('chats').doc(widget.chatId).get();
    final chatData = chatDoc.data() ?? {};
    final isGroup = chatData['type'] == 'group';

    if (isGroup && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactDetailScreen(otherUid: 'group', chatId: widget.chatId),
        ),
      );
      return;
    }

    final currentUid = ref.read(chatRepositoryProvider).uid;
    final members = List<String>.from(chatData['memberIds'] ?? []);
    String otherUid = '';
    for (final id in members) {
      if (id != currentUid) {
        otherUid = id;
        break;
      }
    }
    if (otherUid.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactDetailScreen(otherUid: otherUid, chatId: widget.chatId),
        ),
      );
    }
  }

  Future<void> _showBlockDialog() async {
    final currentUid = ref.read(chatRepositoryProvider).uid;
    final chatDoc = await AppDatabase.instance.table('chats').doc(widget.chatId).get();
    final members = List<String>.from(chatDoc.data()?['memberIds'] ?? []);
    String otherUid = '';
    for (final id in members) {
      if (id != currentUid) {
        otherUid = id;
        break;
      }
    }
    if (otherUid.isEmpty) return;

    if (mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Block User', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to block this user?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm == true) {
        await ref.read(chatRepositoryProvider).blockUser(otherUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
          Navigator.pop(context);
        }
      }
    }
  }

  void _handleAppBarMenuSelected(String value) async {
    if (value == 'clear') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to clear this chat?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm == true) {
        await ref.read(chatRepositoryProvider).clearChat(widget.chatId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared')));
      }
    } else if (value == 'block') {
      _showBlockDialog();
    } else if (value == 'view') {
      _goToContactDetails();
    }
  }

  Future<void> startVoiceRecording() async {
    final hasPermission = await recorder.hasPermission();

    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() {
        recording = true;
        _viewOnceVoice = false;
      });
    }
    ref.read(chatRepositoryProvider).setRecording(widget.chatId, true);
  }

  Future<void> stopAndSendVoiceNote() async {
    final path = await recorder.stop();

    if (mounted) {
      setState(() => recording = false);
    }
    ref.read(chatRepositoryProvider).setRecording(widget.chatId, false);

    if (path == null) return;

    await uploadMedia(File(path), MessageType.voice, isViewOnce: _viewOnceVoice);
  }

  Future<void> sendImageFromGallery() async {
    Navigator.pop(context);

    final List<XFile> pickedFiles = await ImagePicker().pickMultiImage(
      imageQuality: 100,
      maxWidth: 4096,
      maxHeight: 4096,
    );

    if (pickedFiles.isNotEmpty) {
      if (!mounted) return;
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => MediaPreviewSendScreen(xFile: pickedFiles.first, isVideo: false),
        ),
      );
      if (result != null) {
        final editedPath = result['editedFile'] as String?;
        final editedXFile = editedPath != null ? XFile(editedPath) : pickedFiles.first;

        if (pickedFiles.length == 1) {
          await uploadMedia(null, MessageType.image, xFile: editedXFile, caption: result['caption'], music: result['music'], isViewOnce: result['isViewOnce'] ?? false, isHD: result['isHD'] ?? false);
        } else {
          final List<File> files = [];
          files.add(File(editedXFile.path));
          for (int i = 1; i < pickedFiles.length; i++) {
            files.add(File(pickedFiles[i].path));
          }

          setState(() => uploading = true);
          try {
            await ref.read(chatRepositoryProvider).sendMultipleImages(
              chatId: widget.chatId,
              files: files,
              caption: result['caption'],
              isViewOnce: result['isViewOnce'] ?? false,
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Upload failed: $e')),
              );
            }
          } finally {
            if (mounted) {
              setState(() => uploading = false);
            }
          }
        }
      }
    }
  }

  Future<void> sendImageFromCamera() async {
    Navigator.pop(context);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const InAppCameraCaptureScreen(isVideoMode: false),
      ),
    );

    if (result != null && result['file'] != null) {
      await uploadMedia(
        result['file'] as File,
        MessageType.image,
        caption: result['caption'] as String?,
        isViewOnce: result['isViewOnce'] as bool? ?? false,
      );
    }
  }

  Future<void> sendVideoFromGallery() async {
    Navigator.pop(context);

    try {
      final pickedFile = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (!mounted) return;
        final sendResult = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => MediaPreviewSendScreen(xFile: pickedFile, isVideo: true),
          ),
        );
        if (sendResult != null) {
          await uploadMedia(
            file,
            MessageType.video,
            caption: sendResult['caption'],
            music: sendResult['music'],
            isViewOnce: sendResult['isViewOnce'] ?? false,
            isHD: sendResult['isHD'] ?? false,
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking videos: $e');
    }
  }

  Future<void> sendVideoFromCamera() async {
    Navigator.pop(context);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const InAppCameraCaptureScreen(isVideoMode: true),
      ),
    );

    if (result != null && result['file'] != null) {
      await uploadMedia(
        result['file'] as File,
        MessageType.video,
        caption: result['caption'] as String?,
        isViewOnce: result['isViewOnce'] as bool? ?? false,
      );
    }
  }

  Future<void> sendDocument() async {
    Navigator.pop(context);

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    final filePath = result?.files.single.path;

    if (filePath != null) {
      await uploadMedia(File(filePath), MessageType.document);
    }
  }

  Future<void> sendMusic() async {
    Navigator.pop(context);

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.audio,
    );

    final filePath = result?.files.single.path;

    if (filePath != null) {
      await uploadMedia(File(filePath), MessageType.voice);
    }
  }

  Future<void> uploadMedia(File? file, MessageType type, {XFile? xFile, String? caption, String? music, bool isViewOnce = false, bool isHD = false}) async {
    if (uploading) return;

    setState(() => uploading = true);

    try {
      await ref.read(chatRepositoryProvider).sendMedia(
            chatId: widget.chatId,
            file: file,
            xFile: xFile,
            type: type,
            replyToMessageId: replyingTo?.id,
            caption: caption,
            music: music,
            isViewOnce: isViewOnce,
            isHD: isHD,
          );

      if (mounted) {
        setState(() => replyingTo = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => uploading = false);
    }
  }

  Future<void> shareLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission permanently denied')));
        return;
      }

      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.my_location, color: Colors.blue),
                title: const Text('Send Your Current Location', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, 'current'),
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: Colors.green),
                title: const Text('Share Live Location', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Updates in real-time as you move', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () => Navigator.pop(context, 'live'),
              ),
            ],
          ),
        ),
      );

      if (choice == null) return;

      final position = await Geolocator.getCurrentPosition();
      
      if (choice == 'live') {
        // For Live Location, we'll share for 1 hour by default
        final until = DateTime.now().add(const Duration(hours: 1));
        final messageId = await ref.read(chatRepositoryProvider).sendLocation(
          chatId: widget.chatId,
          latitude: position.latitude,
          longitude: position.longitude,
          isLive: true,
          liveUntil: until,
          replyToMessageId: replyingTo?.id,
        );

        // Start real-time updates
        _locationTimer?.cancel();
        _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
          if (DateTime.now().isAfter(until)) {
            timer.cancel();
            return;
          }
          try {
            final p = await Geolocator.getCurrentPosition();
            await ref.read(chatRepositoryProvider).updateLocation(widget.chatId, messageId, p.latitude, p.longitude);
          } catch (_) {}
        });
      } else {
        await ref.read(chatRepositoryProvider).sendLocation(
          chatId: widget.chatId,
          latitude: position.latitude,
          longitude: position.longitude,
          isLive: false,
          replyToMessageId: replyingTo?.id,
        );
      }

      if (mounted) {
        setState(() => replyingTo = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(choice == 'live' ? 'Live location shared!' : 'Location shared!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  Future<void> sendTipMessage(double amount) async {
    final invoiceString = '🧾 RECEIPT | Product: Support Tip | Price: \$${amount.toStringAsFixed(2)} | Qty: 1 | Total: \$${amount.toStringAsFixed(2)} | Method: Card Simulator';
    try {
      await ref.read(chatRepositoryProvider).sendText(
            widget.chatId,
            invoiceString,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post tip invoice: $e')),
        );
      }
    }
  }

  Future<void> _showTicTacToeInvitationSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gamepad_outlined, color: Colors.purpleAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Play Tic-Tac-Toe',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a real-time multiplayer invitation to this chat room.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _createTicTacToeGame();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScheduleCallSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleCallSheet(chatId: widget.chatId),
    );
  }

  Future<void> _createTicTacToeGame() async {
    final currentUid = AppAuth.instance.currentUser?.uid ?? '';
    final gameRef = AppDatabase.instance.table('games').doc();
    
    String myName = 'Player X';
    try {
      final userDoc = await AppDatabase.instance.table('users').doc(currentUid).get();
      myName = userDoc.data()?['username'] ?? 'Player X';
    } catch (_) {}

    final gameData = {
      'chatId': widget.chatId,
      'gameId': gameRef.id,
      'status': 'waiting',
      'playerX': currentUid,
      'playerXName': myName,
      'playerO': '',
      'playerOName': '',
      'turn': currentUid,
      'board': List.filled(9, ''),
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await gameRef.set(gameData);
      
      final invitationMessage = '🎮 GAME_INVITATION | gameId: ${gameRef.id} | creator: $myName';
      await ref.read(chatRepositoryProvider).sendText(widget.chatId, invitationMessage);

      // Open the Game Board directly for the creator
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameBoardScreen(gameId: gameRef.id, chatId: widget.chatId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start game: $e')),
        );
      }
    }
  }

  Future<void> downloadAndOpenFile(
    String url, {
    String fileName = 'a_chatz_file',
    String? encryptedMediaKey,
    String? senderPublicKey,
  }) async {
    try {
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final directory = await getTemporaryDirectory();
      final targetFile = File('${directory.path}/$safeName');

      final cachedFile = await LocalMediaCache.instance.getCachedFile(url)
          ?? await LocalMediaCache.instance.downloadAndCache(
               url,
               encryptedMediaKey: encryptedMediaKey,
               senderPublicKey: senderPublicKey,
             );

      // Copy to the desired safe name so OpenFilex uses the correct extension/name
      if (!await targetFile.exists()) {
        await cachedFile.copy(targetFile.path);
      }

      await OpenFilex.open(targetFile.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  Future<void> showMediaOptions() async {
    final currentUserProfile = ref.read(currentUserProfileProvider).value;
    final isBusiness = currentUserProfile?['accountType'] == 'business';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3D),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Send media',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    children: [
                    _MediaOption(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: sendImageFromGallery,
                    ),
                    _MediaOption(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      onTap: sendImageFromCamera,
                    ),
                    _MediaOption(
                      icon: Icons.video_library_outlined,
                      label: 'Video',
                      onTap: sendVideoFromGallery,
                    ),
                    _MediaOption(
                      icon: Icons.videocam_outlined,
                      label: 'Record',
                      onTap: sendVideoFromCamera,
                    ),
                    _MediaOption(
                      icon: Icons.description_outlined,
                      label: 'Document',
                      onTap: sendDocument,
                    ),
                    _MediaOption(
                      icon: Icons.music_note_outlined,
                      label: 'Audio/Music',
                      onTap: sendMusic,
                    ),
                    _MediaOption(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      onTap: () {
                        Navigator.pop(context);
                        shareLocation();
                      },
                    ),
                     _MediaOption(
                      icon: Icons.face_retouching_natural,
                      label: 'AI Sticker',
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => AIStickerCreatorSheet(chatId: widget.chatId),
                        );
                      },
                    ),
                    _MediaOption(
                      icon: Icons.sentiment_satisfied_alt_outlined,
                      label: 'Stickers',
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => StickersPickerSheet(chatId: widget.chatId),
                        );
                      },
                    ),
                    _MediaOption(
                      icon: Icons.favorite,
                      label: 'Send Tip',
                      onTap: () async {
                        Navigator.pop(context);
                        String partnerName = 'Creator';
                        bool hasPaymentIntegration = false;
                        bool iHavePaymentIntegration = false;
                        
                        try {
                          final currentUid = AppAuth.instance.currentUser?.uid;
                          if (currentUid != null) {
                            final myDoc = await AppDatabase.instance.table('users').doc(currentUid).get();
                            final myPaymentMap = myDoc.data()?['paymentIntegration'] as Map<String, dynamic>?;
                            if (myPaymentMap != null && myPaymentMap['isVerified'] == true) {
                              iHavePaymentIntegration = true;
                            }
                          }

                          final doc = await AppDatabase.instance.table('chats').doc(widget.chatId).get();
                          final data = doc.data() ?? {};
                          final isGroup = data['type'] == 'group';
                          if (!isGroup) {
                            final members = List<String>.from(data['memberIds'] ?? []);
                            final otherUid = members.firstWhere((id) => id != currentUid, orElse: () => '');
                            if (otherUid.isNotEmpty) {
                              final userDoc = await AppDatabase.instance.table('users').doc(otherUid).get();
                              partnerName = userDoc.data()?['username'] ?? 'Creator';

                              final paymentMap = userDoc.data()?['paymentIntegration'] as Map<String, dynamic>?;
                              if (paymentMap != null && paymentMap['isVerified'] == true) {
                                hasPaymentIntegration = true;
                              }
                            }
                          } else {
                            final createdBy = data['createdBy'] as String?;
                            if (createdBy != null) {
                              final userDoc = await AppDatabase.instance.table('users').doc(createdBy).get();
                              partnerName = userDoc.data()?['username'] ?? 'Group Creator';
                              
                              final paymentMap = userDoc.data()?['paymentIntegration'] as Map<String, dynamic>?;
                              if (paymentMap != null && paymentMap['isVerified'] == true) {
                                hasPaymentIntegration = true;
                              }
                            } else {
                              partnerName = data['title'] ?? 'Group Creator';
                            }
                          }
                        } catch (_) {}

                        if (mounted) {
                          if (!iHavePaymentIntegration) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                title: const Text('Payment Integration Missing', style: TextStyle(color: Colors.white)),
                                content: const Text('You must link and verify a payment integration on your profile before you can send tips.', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK', style: TextStyle(color: Colors.greenAccent)),
                                  ),
                                ],
                              ),
                            );
                          } else if (!hasPaymentIntegration) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                title: const Text('Payment Integration Missing', style: TextStyle(color: Colors.white)),
                                content: Text('$partnerName does not have an active payment integration setup. You cannot send them a tip right now.', style: const TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK', style: TextStyle(color: Colors.greenAccent)),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => TippingSheet(
                                chatPartnerName: partnerName,
                                onTipSuccess: (amount) => sendTipMessage(amount),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    _MediaOption(
                      icon: Icons.gamepad_outlined,
                      label: 'Tic-Tac-Toe',
                      onTap: () {
                        Navigator.pop(context);
                        _showTicTacToeInvitationSheet();
                      },
                    ),
                    _MediaOption(
                      icon: Icons.event_outlined,
                      label: 'Schedule\nCall',
                      onTap: () {
                        Navigator.pop(context);
                        _showScheduleCallSheet();
                      },
                    ),
                    _MediaOption(
                      icon: _activeSelfDestructSeconds != null ? Icons.timer : Icons.timer_outlined,
                      label: 'Disappearing',
                      onTap: () {
                        Navigator.pop(context);
                        _showSelfDestructSelector();
                      },
                    ),
                    if (isBusiness)
                      _MediaOption(
                        icon: Icons.flash_on,
                        label: 'Fast Reply',
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => QuickReplySheet(
                              onSelect: (reply) {
                                input.text = reply;
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                      _MediaOption(
                        icon: Icons.poll_outlined,
                        label: 'Poll',
                        onTap: () {
                          Navigator.pop(context);
                          _showCreatePollDialog();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
    );
  }

  Future<void> markVisibleMessagesAsRead(List<ChatMessage> messages) async {
    final repo = ref.read(chatRepositoryProvider);

    for (final msg in messages) {
      if (msg.senderId != repo.uid && !msg.readBy.containsKey(repo.uid)) {
        await repo.markRead(widget.chatId, msg.id);
      }
    }
  }

  String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String formatLastSeen(dynamic lastSeen) {
    if (lastSeen == null) return 'offline';

    try {
      final date = lastSeen.toDate() as DateTime;
      final diff = DateTime.now().difference(date);

      if (diff.inMinutes < 1) return 'last seen just now';
      if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
      if (diff.inHours < 24) return 'last seen ${diff.inHours} hrs ago';

      return 'last seen ${diff.inDays} days ago';
    } catch (_) {
      return 'offline';
    }
  }

  Future<void> showMessageInfoDialog(ChatMessage msg) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: AppDatabase.instance.table('chats').doc(widget.chatId).get(),
              builder: (context, chatSnap) {
                if (!chatSnap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                }

                final chatData = chatSnap.data!.data() ?? {};
                final memberIds = List<String>.from(chatData['memberIds'] ?? []);

                return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  future: AppDatabase.instance
                      .table('users')
                      .where(FieldPath.documentId, whereIn: memberIds)
                      .get(),
                  builder: (context, usersSnap) {
                    if (!usersSnap.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                    }

                    final users = usersSnap.data!.docs.map((doc) {
                      final data = doc.data();
                      data['uid'] = doc.id;
                      return data;
                    }).toList();

                    final readList = <Map<String, dynamic>>[];
                    final unreadList = <Map<String, dynamic>>[];

                    for (final user in users) {
                      final uid = user['uid'] as String;
                      if (uid == msg.senderId) continue; // Skip sender

                      final readTime = msg.readBy[uid];
                      if (readTime != null) {
                        readList.add({
                          'name': user['displayName'] ?? 'User',
                          'photoUrl': user['photoUrl'],
                          'time': readTime,
                        });
                      } else {
                        unreadList.add({
                          'name': user['displayName'] ?? 'User',
                          'photoUrl': user['photoUrl'],
                        });
                      }
                    }

                    // Sort read list by latest first
                    readList.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFF303030),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Message Info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'See who has read your message',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFF2C2C2E)),
                        const SizedBox(height: 10),
                        
                        // Message Preview Bubble
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF2C2C2E)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.cipherText,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sent at ${DateFormat.jm().format(msg.createdAt)}',
                                style: const TextStyle(color: Colors.white30, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Read By List
                        Row(
                          children: [
                            const Icon(Icons.done_all, color: Color(0xFF34B7F1), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Read by (${readList.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (readList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No one has read this message yet.',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: readList.length,
                            itemBuilder: (context, idx) {
                              final item = readList[idx];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                                      ? NetworkImage(item['photoUrl'])
                                      : null,
                                  child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                                      ? const Icon(Icons.person, color: Colors.white54)
                                      : null,
                                ),
                                title: Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  'Read ${DateFormat.jm().format(item['time'])}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        // Delivered To List
                        Row(
                          children: [
                            const Icon(Icons.done_all, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Delivered to (${unreadList.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (unreadList.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'All members have read this message!',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: unreadList.length,
                            itemBuilder: (context, idx) {
                              final item = unreadList[idx];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty
                                      ? NetworkImage(item['photoUrl'])
                                      : null,
                                  child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                                      ? const Icon(Icons.person, color: Colors.white54)
                                      : null,
                                ),
                                title: Text(item['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: const Text(
                                  'Delivered',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }



  void _showSelfDestructSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF303030),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Self-Destruct Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Messages will automatically vanish after they are sent',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined, color: Colors.white54),
                  title: const Text('Off (Keep Permanently)', style: TextStyle(color: Colors.white)),
                  trailing: _activeSelfDestructSeconds == null ? const Icon(Icons.check, color: Colors.greenAccent) : null,
                  onTap: () {
                    setState(() => _activeSelfDestructSeconds = null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(color: Color(0xFF2C2C2E)),
                _buildSelfDestructTile(10, '10 Seconds'),
                _buildSelfDestructTile(30, '30 Seconds'),
                _buildSelfDestructTile(60, '1 Minute'),
                _buildSelfDestructTile(300, '5 Minutes'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelfDestructTile(int seconds, String label) {
    final isSelected = _activeSelfDestructSeconds == seconds;
    return ListTile(
      leading: const Icon(Icons.timer_outlined, color: Colors.redAccent),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.greenAccent) : null,
      onTap: () {
        setState(() => _activeSelfDestructSeconds = seconds);
        Navigator.pop(context);
      },
    );
  }

  void _showTranslationSheet(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF303030),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Translate Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select a target language to translate instantly using AI',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _buildTranslationLanguageTile(msg, 'English'),
                _buildTranslationLanguageTile(msg, 'Spanish'),
                _buildTranslationLanguageTile(msg, 'French'),
                _buildTranslationLanguageTile(msg, 'Mandarin Chinese'),
                _buildTranslationLanguageTile(msg, 'Zulu'),
                _buildTranslationLanguageTile(msg, 'Afrikaans'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranslationLanguageTile(ChatMessage msg, String language) {
    return ListTile(
      leading: const Icon(Icons.language_rounded, color: Colors.greenAccent),
      title: Text(language, style: const TextStyle(color: Colors.white)),
      onTap: () async {
        Navigator.pop(context);
        _performTranslation(msg, language);
      },
    );
  }

  Future<void> _performTranslation(ChatMessage msg, String language) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.greenAccent),
              const SizedBox(height: 18),
              Text(
                'Translating to $language...',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final decryptedText = await _getDecryptedText(msg);
      final result = await GeminiService.instance.translate(decryptedText, language);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        setState(() {
          _localTranslations[msg.id] = result;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translated to $language successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _performTranscription(ChatMessage msg) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.greenAccent),
              SizedBox(height: 18),
              Text(
                'Transcribing audio...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await GeminiService.instance.transcribeAudio(msg.mediaUrl!);
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        setState(() {
          _localTranslations[msg.id] = result;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcription successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcription failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String> _getDecryptedText(ChatMessage msg) async {
    if (!msg.isEncrypted) return msg.cipherText;
    try {
      final currentUid = AppAuth.instance.currentUser?.uid;
      if (currentUid == null) return msg.cipherText;
      String? targetPublicKey = (msg.senderId == currentUid) ? msg.recipientPublicKey : msg.senderPublicKey;
      if (targetPublicKey == null) {
        String targetKeyUid = msg.senderId;
        if (msg.senderId == currentUid) {
          final chatDoc = await AppDatabase.instance.table('chats').doc(widget.chatId).get();
          final members = List<String>.from(chatDoc.data()?['memberIds'] ?? []);
          final otherUid = members.firstWhere((id) => id != currentUid, orElse: () => currentUid);
          targetKeyUid = otherUid;
        }
        final userDoc = await AppDatabase.instance.table('users').doc(targetKeyUid).get();
        targetPublicKey = userDoc.data()?['publicKey'];
      }
      if (targetPublicKey == null) return msg.cipherText;
      return await EncryptionService().decrypt(msg.cipherText, targetPublicKey);
    } catch (_) {
      return msg.cipherText;
    }
  }

  Future<void> showMessageActions(ChatMessage msg) async {
    final repo = ref.read(chatRepositoryProvider);
    final mine = msg.senderId == repo.uid;
    final isStarred = msg.starredBy.contains(repo.uid);
    final isMedia = msg.mediaUrl != null;

    final chatDoc = await AppDatabase.instance.table('chats').doc(widget.chatId).get();
    final isGroup = chatDoc.data()?['type'] == 'group';

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3D),
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                const SizedBox(height: 18),
                // Premium Reactions Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['❤️', '😂', '😮', '😢', '🙏', '👍', '🔥', '✨'].map((emoji) {
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          HapticFeedback.lightImpact();
                          await repo.addReaction(widget.chatId, msg.id, emoji);
                          _triggerSuperReaction(emoji);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1D1F),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF2C2C2E)),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFF202024)),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.reply,
                  label: 'Reply',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() => replyingTo = msg);
                  },
                ),
                if (!msg.isViewOnce)
                  _ActionTile(
                    icon: Icons.shortcut,
                    label: 'Forward message',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showForwardSheet(msg);
                    },
                  ),
                if (msg.type == MessageType.text) ...[
                  _ActionTile(
                    icon: Icons.auto_awesome,
                    label: 'AI Actions Menu',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showAIActions(msg);
                    },
                  ),
                  _ActionTile(
                    icon: Icons.translate_rounded,
                    label: 'AI Translate Message',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showTranslationSheet(msg);
                    },
                  ),
                  _ActionTile(
                    icon: Icons.auto_fix_high,
                    label: 'AI Rewrite (Professional)',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _processAIAction(msg, 'rewrite');
                    },
                  ),
                  _ActionTile(
                    icon: Icons.quickreply,
                    label: 'AI Suggest Replies',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _processAIAction(msg, 'reply');
                    },
                  ),
                ],
                if (msg.type == MessageType.voice && msg.mediaUrl != null)
                  _ActionTile(
                    icon: Icons.transcribe_rounded,
                    label: 'Transcribe Voice',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _performTranscription(msg);
                    },
                  ),
                if (isMedia)
                  _ActionTile(
                    icon: Icons.download_rounded,
                    label: 'Download / Open',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      downloadAndOpenFile(
                        msg.mediaUrl!,
                        fileName:
                            msg.fileName ?? msg.mediaUrl!.split('/').last,
                        encryptedMediaKey: msg.encryptedMediaKey,
                        senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
                      );
                    },
                  ),
                if (isGroup)
                  _ActionTile(
                    icon: Icons.info_outline,
                    label: 'Message Info',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showMessageInfoDialog(msg);
                    },
                  ),
                _ActionTile(
                  icon: isStarred ? Icons.star : Icons.star_border,
                  label: isStarred ? 'Unstar message' : 'Star message',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await repo.toggleStarMessage(
                      widget.chatId,
                      msg.id,
                      isStarred,
                    );
                  },
                ),
                _ActionTile(
                  icon: Icons.push_pin_outlined,
                  label: 'Pin message',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await repo.pinMessage(widget.chatId, msg.id);
                  },
                ),
                if (mine && msg.type == MessageType.text)
                  _ActionTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit message',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await Future.delayed(const Duration(milliseconds: 200));

                      if (mounted) showEditDialog(msg);
                    },
                  ),
                _ActionTile(
                  icon: Icons.delete_outline,
                  label: 'Delete for me',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await repo.deleteForMe(widget.chatId, msg.id);
                  },
                ),
                if (mine || msg.senderId != repo.uid && repo.uid == 'official_a_chatz')
                  _ActionTile(
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete for everyone',
                    danger: true,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await repo.deleteForEveryone(widget.chatId, msg.id);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showAIActions(ChatMessage msg) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3D),
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '🤖 AI Tools',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF202024)),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.short_text,
                  label: 'Summarize Message',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processAIAction(msg, 'summarize');
                  },
                ),
                _ActionTile(
                  icon: Icons.auto_fix_high,
                  label: 'Rewrite Professionally',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processAIAction(msg, 'rewrite');
                  },
                ),
                _ActionTile(
                  icon: Icons.security,
                  label: 'Check for Scam/Fraud',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processAIAction(msg, 'scam');
                  },
                ),
                _ActionTile(
                  icon: Icons.psychology,
                  label: 'Explain this Message',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processAIAction(msg, 'explain');
                  },
                ),
                _ActionTile(
                  icon: Icons.quickreply,
                  label: 'Suggest Replies',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _processAIAction(msg, 'reply');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _processAIAction(ChatMessage msg, String actionType) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final aiTools = AIToolsService.instance;
      String resultText = '';
      
      switch (actionType) {
        case 'summarize':
          resultText = await aiTools.summarizeChat(msg.cipherText);
          break;
        case 'rewrite':
          resultText = await aiTools.rewriteMessage(msg.cipherText, 'professional');
          break;
        case 'scam':
          resultText = await aiTools.detectScam(msg.cipherText);
          break;
        case 'explain':
          resultText = await aiTools.explainMessage(msg.cipherText);
          break;
        case 'reply':
          final replies = await aiTools.suggestReplies(msg.cipherText);
          resultText = 'Here are 3 suggested replies:\n\n- ' + replies.join('\n- ');
          break;
      }

      if (!mounted) return;
      Navigator.pop(context); // hide loading

      // Show result
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E22),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              Text(
                'AI Result',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              resultText,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.purpleAccent)),
            ),
            if (actionType == 'rewrite')
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  input.text = resultText;
                },
                child: const Text('Use Text', style: TextStyle(color: Colors.purpleAccent)),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Action failed: \$e')),
      );
    }
  }

  Future<void> showEditDialog(ChatMessage msg) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return EditMessageSheet(
          chatId: widget.chatId,
          message: msg,
          editMessageFn: (chatId, messageId, newText) {
            return ref.read(chatRepositoryProvider).editMessage(
                  chatId,
                  messageId,
                  newText,
                );
          },
        );
      },
    );
  }

  Future<void> _showForwardSheet(ChatMessage msg) async {
    final currentUid = ref.read(chatRepositoryProvider).uid;
    final chatRepo   = ref.read(chatRepositoryProvider);
    final chanRepo   = ref.read(channelRepositoryProvider);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        // ── local state lives inside StatefulBuilder ──────────────────────
        final Set<String> selectedChatIds    = {};
        final Set<String> selectedChannelIds = {};
        final searchController = TextEditingController();
        String searchQuery = '';

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // ── helpers ──────────────────────────────────────────────────
            bool isChatSelected(String id)    => selectedChatIds.contains(id);
            bool isChannelSelected(String id) => selectedChannelIds.contains(id);

            void toggleChat(String id) => setSheetState(() {
              if (!selectedChatIds.remove(id)) selectedChatIds.add(id);
            });

            void toggleChannel(String id) => setSheetState(() {
              if (!selectedChannelIds.remove(id)) selectedChannelIds.add(id);
            });

            final totalSelected = selectedChatIds.length + selectedChannelIds.length;

            // ── selection checkbox widget ─────────────────────────────────
            Widget selectionDot(bool selected) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? const Color(0xFF00C6AE) : Colors.transparent,
                  border: Border.all(
                    color: selected ? const Color(0xFF00C6AE) : const Color(0xFF555558),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              );
            }

            // ── chat tile ─────────────────────────────────────────────────
            Widget chatTile(ChatThread chat, String title, String? photoUrl) {
              if (chat.id == widget.chatId) return const SizedBox.shrink();
              if (searchQuery.isNotEmpty &&
                  !title.toLowerCase().contains(searchQuery.toLowerCase())) {
                return const SizedBox.shrink();
              }
              final selected = isChatSelected(chat.id);
              return InkWell(
                onTap: () => toggleChat(chat.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF1D1D1F),
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? Icon(
                                chat.isGroup ? Icons.group_rounded : Icons.person_rounded,
                                color: Colors.white38,
                                size: 22,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      selectionDot(selected),
                    ],
                  ),
                ),
              );
            }

            // ── channel tile ──────────────────────────────────────────────
            Widget channelTile(String channelId, String name, String? photoUrl) {
              if (searchQuery.isNotEmpty &&
                  !name.toLowerCase().contains(searchQuery.toLowerCase())) {
                return const SizedBox.shrink();
              }
              final selected = isChannelSelected(channelId);
              return InkWell(
                onTap: () => toggleChannel(channelId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF1A1A2E),
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null || photoUrl.isEmpty
                            ? const Icon(Icons.campaign_rounded, color: Colors.white38, size: 22)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Channel',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      selectionDot(selected),
                    ],
                  ),
                ),
              );
            }

            // ── section header ────────────────────────────────────────────
            Widget sectionHeader(String label) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF00C6AE),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            );

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // ── handle ────────────────────────────────────────────
                    const SizedBox(height: 12),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3D),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── title ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Forward to...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(sheetContext),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white54, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── search bar ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        onChanged: (v) => setSheetState(() => searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search chats & channels...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                          filled: true,
                          fillColor: const Color(0xFF1C1C1E),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ── scrollable list ───────────────────────────────────
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 100),
                        children: [
                          // ── CHATS section ──────────────────────────────
                          sectionHeader('CHATS'),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: AppDatabase.instance
                                .table('chats')
                                .where('memberIds', arrayContains: currentUid)
                                .orderBy('lastMessageAt', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final docs = snapshot.data!.docs;
                              if (docs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No chats available',
                                      style: TextStyle(color: Colors.white38)),
                                );
                              }
                              return Column(
                                children: docs.map((doc) {
                                  final chat = ChatThread.fromMap(doc.id, doc.data());
                                  if (chat.id == widget.chatId) return const SizedBox.shrink();

                                  if (!chat.isGroup) {
                                    final otherUid = chat.memberIds.firstWhere(
                                      (id) => id != currentUid,
                                      orElse: () => currentUid,
                                    );
                                    return Consumer(
                                      builder: (context, ref, _) {
                                        final profileAsync = ref.watch(userProfileProvider(otherUid));
                                        return profileAsync.when(
                                          data: (user) {
                                            final title   = user?['username'] ?? chat.title;
                                            final photo   = user?['photoUrl'] ?? chat.photoUrl;
                                            return chatTile(chat, title, photo);
                                          },
                                          loading: () => const SizedBox.shrink(),
                                          error: (_, __) => chatTile(chat, chat.title, chat.photoUrl),
                                        );
                                      },
                                    );
                                  }
                                  return chatTile(chat, chat.title, chat.photoUrl);
                                }).toList(),
                              );
                            },
                          ),

                          // ── CHANNELS section ───────────────────────────
                          sectionHeader('CHANNELS  (admin / owner)'),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: AppDatabase.instance
                                .table('users')
                                .doc(currentUid)
                                .table('followedChannels')
                                .where('role', whereIn: ['owner', 'admin'])
                                .snapshots(),
                            builder: (context, rolesSnap) {
                              if (!rolesSnap.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final docs = rolesSnap.data!.docs;
                              if (docs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                                  child: Text(
                                    'No channels where you are admin or owner',
                                    style: TextStyle(color: Colors.white38, fontSize: 13),
                                  ),
                                );
                              }
                              return Column(
                                children: docs.map((doc) {
                                  final channelId = doc.id;
                                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                    future: AppDatabase.instance
                                        .table('channels')
                                        .doc(channelId)
                                        .get(),
                                    builder: (context, chanSnap) {
                                      if (!chanSnap.hasData) return const SizedBox.shrink();
                                      final data = chanSnap.data?.data();
                                      if (data == null) return const SizedBox.shrink();
                                      final name     = data['name'] as String? ?? 'Channel';
                                      final photoUrl = data['photoUrl'] as String?;
                                      return channelTile(channelId, name, photoUrl);
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── sticky send button ────────────────────────────────
                    AnimatedSlide(
                      offset: totalSelected > 0 ? Offset.zero : const Offset(0, 1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: totalSelected > 0 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: SafeArea(
                          minimum: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00C6AE),
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                Navigator.pop(sheetContext);
                                final decryptedText = msg.cipherText;
                                int count = 0;

                                // ── forward to chats ─────────────────────
                                for (final chatId in selectedChatIds) {
                                  try {
                                    await chatRepo.forwardMessage(
                                      message: msg,
                                      decryptedText: decryptedText,
                                      toChatId: chatId,
                                    );
                                    count++;
                                  } catch (e) {
                                    debugPrint('Forward to chat $chatId failed: $e');
                                  }
                                }

                                // ── forward to channels ───────────────────
                                for (final channelId in selectedChannelIds) {
                                  try {
                                    await chanRepo.forwardToChannel(
                                      channelId,
                                      msg,
                                      decryptedText,
                                    );
                                    count++;
                                  } catch (e) {
                                    debugPrint('Forward to channel $channelId failed: $e');
                                  }
                                }

                                if (mounted) {
                                  final label = count == 1
                                      ? '1 chat / channel'
                                      : '$count chats / channels';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Forwarded to $label'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.shortcut_rounded, size: 20),
                              label: Text(
                                'Send to $totalSelected',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReactionsBadge(Map<String, String> reactions, bool mine) {
    final emojis = reactions.values.toSet().toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emojis.take(3).join(''), style: const TextStyle(fontSize: 10)),
          if (reactions.length > 1) ...[
            const SizedBox(width: 2),
            Text('${reactions.length}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildViewOnceBubble(ChatMessage msg, bool mine) {
    final currentUid = ref.read(chatRepositoryProvider).uid;
    final isOpened = mine 
        ? msg.openedBy.isNotEmpty 
        : msg.openedBy.contains(currentUid);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final activeColor = const Color(0xFF007AFF); // Apple iOS Blue Accent
    final labelColor = mine 
        ? (isDark ? Colors.white : Colors.black87) 
        : (isDark ? Colors.white : Colors.black87);
    final iconColor = isOpened 
        ? Colors.grey 
        : activeColor;
    
    String label = '';
    IconData icon = Icons.looks_one_outlined;
    if (msg.type == MessageType.image) {
      label = isOpened ? 'Opened' : 'Photo';
      icon = isOpened ? Icons.photo_library_outlined : Icons.photo_camera_outlined;
    } else if (msg.type == MessageType.video) {
      label = isOpened ? 'Opened' : 'Video';
      icon = isOpened ? Icons.video_library_outlined : Icons.videocam_outlined;
    } else if (msg.type == MessageType.voice) {
      label = isOpened ? 'Opened' : 'Voice note';
      icon = isOpened ? Icons.volume_mute_outlined : Icons.mic_none_outlined;
    }

    return GestureDetector(
      onTap: (isOpened || mine)
          ? () {
              if (mine) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("View-once media cannot be viewed by the sender."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          : () async {
              await ref.read(chatRepositoryProvider).markViewOnceOpened(widget.chatId, msg.id);

              if (!mounted) return;

              if (msg.type == MessageType.image) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImagePreviewScreen(
                      imageUrl: msg.mediaUrl!, 
                      isViewOnce: true,
                      encryptedMediaKey: msg.encryptedMediaKey,
                      senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
                    ),
                  ),
                );
              } else if (msg.type == MessageType.video) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPreviewScreen(
                      videoUrl: msg.mediaUrl!, 
                      isViewOnce: true,
                      encryptedMediaKey: msg.encryptedMediaKey,
                      senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
                    ),
                  ),
                );
              } else if (msg.type == MessageType.voice) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        title: const Text('View-Once Voice Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      body: Center(
                        child: VoiceNoteBubble(
                          key: ValueKey(msg.mediaUrl!), 
                          url: msg.mediaUrl!, 
                          mine: false, 
                          fileName: msg.fileName,
                          encryptedMediaKey: msg.encryptedMediaKey,
                          senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine 
              ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.05))
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOpened 
                ? Colors.transparent 
                : activeColor.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isOpened ? Colors.grey.withOpacity(0.15) : activeColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: isOpened ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentPreview(ChatMessage msg, bool mine) {
    if (msg.thumbnailUrl != null) {
      return Container(
        height: 140,
        width: double.infinity,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        clipBehavior: Clip.hardEdge,
        child: CachedMediaWrapper(
          url: msg.thumbnailUrl!,
          encryptedMediaKey: msg.encryptedMediaKey,
          senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
          builder: (context, file) => Image.file(
            file,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          loadingBuilder: (context) => const Center(
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white30)),
          ),
        ),
      );
    }

    final ext = (msg.fileName ?? 'document.pdf').split('.').last.toLowerCase();
    Color badgeColor = Colors.grey.shade700;
    List<Color> gradientColors = [Colors.grey.shade800, Colors.grey.shade900];

    if (ext == 'pdf') {
      badgeColor = const Color(0xFFE53935); // Crimson
      gradientColors = [const Color(0xFFC62828).withOpacity(0.85), const Color(0xFFB71C1C).withOpacity(0.7)];
    } else if (ext == 'doc' || ext == 'docx') {
      badgeColor = const Color(0xFF1E88E5); // Blue
      gradientColors = [const Color(0xFF1565C0).withOpacity(0.85), const Color(0xFF0D47A1).withOpacity(0.7)];
    } else if (ext == 'xls' || ext == 'xlsx') {
      badgeColor = const Color(0xFF43A047); // Green
      gradientColors = [const Color(0xFF2E7D32).withOpacity(0.85), const Color(0xFF1B5E20).withOpacity(0.7)];
    } else if (ext == 'ppt' || ext == 'pptx') {
      badgeColor = const Color(0xFFEF6C00); // Orange
      gradientColors = [const Color(0xFFE65100).withOpacity(0.85), const Color(0xFFD84315).withOpacity(0.7)];
    }

    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 4),
                Container(width: 80, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 4),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Text(
                ext.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMessageContent(ChatMessage msg, bool mine) {
    Widget content = _buildMainContent(msg, mine);

    if (_localTranslations.containsKey(msg.id)) {
      final aiText = _localTranslations[msg.id]!;
      final isTranscription = msg.type == MessageType.voice;

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mine ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isTranscription ? Icons.transcribe : Icons.g_translate, size: 12, color: Colors.greenAccent),
                    const SizedBox(width: 6),
                    Text(
                      isTranscription ? 'Transcribed via AI' : 'Translated via AI',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  aiText,
                  style: TextStyle(
                    color: mine ? Colors.black87 : Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (msg.isForwarded) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shortcut, size: 12, color: mine ? Colors.black54 : Colors.white54),
              const SizedBox(width: 4),
              Text(
                'Forwarded',
                style: TextStyle(
                  color: mine ? Colors.black54 : Colors.white54,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          content,
        ],
      );
    }
    
    return content;
  }

  String? _getMentionQuery() {
    final text = input.text;
    final selection = input.selection;
    if (!selection.isValid) return null;

    final cursorPosition = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);

    final lastAt = textBeforeCursor.lastIndexOf('@');
    if (lastAt == -1) return null;

    final segment = textBeforeCursor.substring(lastAt + 1);
    if (segment.contains(' ')) return null;

    return segment.toLowerCase();
  }

  void _insertMention(String username) {
    final text = input.text;
    final selection = input.selection;
    if (!selection.isValid) return;

    final cursorPosition = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final textAfterCursor = text.substring(cursorPosition);

    final lastAt = textBeforeCursor.lastIndexOf('@');
    if (lastAt == -1) return;

    final newTextBeforeCursor = textBeforeCursor.substring(0, lastAt) + '@$username ';

    input.text = newTextBeforeCursor + textAfterCursor;
    input.selection = TextSelection.fromPosition(
      TextPosition(offset: newTextBeforeCursor.length),
    );
    setState(() {});
  }

  Widget _buildMentionSelector(String query, List<String> memberIds) {
    if (memberIds.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppDatabase.instance
          .table('users')
          .where(FieldPath.documentId, whereIn: memberIds.take(10).toList())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final currentUid = AppAuth.instance.currentUser?.uid;
        final users = snapshot.data!.docs
            .map((doc) => doc.data())
            .where((u) {
              final uid = u['uid'] ?? '';
              if (uid == currentUid) return false;
              final username = (u['username'] ?? '').toString().toLowerCase();
              return username.contains(query);
            })
            .toList();

        if (users.isEmpty) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: const BoxDecoration(
            color: Color(0xFF141416),
            border: Border(top: BorderSide(color: Color(0xFF202024))),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final username = user['username'] ?? 'User';
              final photoUrl = user['photoUrl'];
              final uid = user['uid'];

              return ListTile(
                dense: true,
                leading: PremiumAvatar(
                  userId: uid,
                  photoUrl: photoUrl,
                  radius: 14,
                ),
                title: Text(
                  '@$username',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  user['email'] ?? '',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 11),
                ),
                onTap: () {
                  _insertMention(username);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGroupSenderHeader(String senderId) {
    return Consumer(
      builder: (context, ref, _) {
        final profileAsync = ref.watch(userProfileProvider(senderId));
        return profileAsync.when(
          data: (user) {
            if (user == null) return const SizedBox.shrink();
            final currentUid = ref.read(chatRepositoryProvider).uid;
            
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AppDatabase.instance
                  .table('users')
                  .doc(currentUid)
                  .table('contacts')
                  .doc(senderId)
                  .snapshots(),
              builder: (context, contactSnap) {
                final hasContactSaved = contactSnap.data?.exists ?? false;
                final contactData = contactSnap.data?.data();
                
                String displayName = '';
                bool isUnsaved = false;
                
                if (hasContactSaved) {
                  displayName = contactData?['displayName'] as String? ?? user['username'] ?? 'User';
                } else {
                  isUnsaved = true;
                  final profileUsername = user['username'] as String?;
                  if (profileUsername != null && profileUsername.isNotEmpty) {
                    displayName = '~$profileUsername';
                  } else {
                    displayName = user['phoneNumber'] ?? user['email'] ?? 'Unsaved User';
                  }
                }
                
                final isVerified = user['isVerified'] == true;
                final isOfficial = senderId == 'official_a_chatz';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          color: isUnsaved 
                              ? (Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isUnsaved ? FontWeight.normal : FontWeight.bold,
                          fontStyle: isUnsaved ? FontStyle.italic : FontStyle.normal,
                          fontSize: 12,
                        ),
                      ),
                      if (isUnsaved) ...[
                        const SizedBox(width: 4),
                        const Text(
                          '(Unsaved)',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                      if (isOfficial) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => showVerificationInfoDialog(context),
                          child: const Icon(Icons.verified, size: 12, color: Colors.blueAccent),
                        ),
                      ] else if (isVerified) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => showVerificationInfoDialog(context),
                          child: const Icon(
                            Icons.verified,
                            size: 12,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildMessageText(String text, bool mine, {TextStyle? style}) {
    final baseStyle = (style ?? const TextStyle()).copyWith(
      color: mine ? Colors.black : Colors.white,
      fontSize: style?.fontSize ?? 13,
      height: style?.height ?? 1.25,
    );

    if (!text.contains('@')) {
      return Text(text, style: baseStyle);
    }

    final matches = RegExp(r'@[a-zA-Z0-9_\.\-]+').allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final mentionText = match.group(0)!;
      spans.add(TextSpan(
        text: mentionText,
        style: baseStyle.copyWith(
          color: mine ? Colors.blueAccent : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildMainContent(ChatMessage msg, bool mine) {
    if (msg.cipherText.startsWith('🎮 GAME_INVITATION')) {
      return _InteractiveGameInvitationCard(
        text: msg.cipherText,
        chatId: widget.chatId,
        mine: mine,
      );
    }

    if (msg.isViewOnce) {
      return _buildViewOnceBubble(msg, mine);
    }
    if (msg.deletedForEveryone) {
      return Text(
        msg.deletedByAdmin ? 'This message was deleted by Admin' : 'This message was deleted',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      );
    }

    if (msg.type == MessageType.sticker) {
      final hasLocalFile = msg.localFilePath != null && File(msg.localFilePath!).existsSync();
      final hasUrl = msg.mediaUrl != null;

      if (hasLocalFile) {
        return Image.file(
          File(msg.localFilePath!),
          width: 140,
          height: 140,
          fit: BoxFit.contain,
        );
      } else if (hasUrl) {
        return CachedMediaWrapper(
          url: msg.mediaUrl!,
          encryptedMediaKey: msg.encryptedMediaKey,
          senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
          builder: (context, file) {
            return Image.file(
              file,
              width: 140,
              height: 140,
              fit: BoxFit.contain,
            );
          },
          loadingBuilder: (context) {
            return const SizedBox(
              width: 140,
              height: 140,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                ),
              ),
            );
          },
        );
      } else {
        return const SizedBox(
          width: 140,
          height: 140,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
            ),
          ),
        );
      }
    }

    if (msg.type == MessageType.system) {
      return Text(
        msg.cipherText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFA7A7A7),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (msg.type == MessageType.voice) {
      final hasLocalFile = msg.localFilePath != null && File(msg.localFilePath!).existsSync();
      final hasUrl = msg.mediaUrl != null;

      if (!hasLocalFile && !hasUrl) {
         return Container(
           margin: const EdgeInsets.only(top: 4, bottom: 4),
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: mine ? const Color(0xFF673AB7).withOpacity(0.5) : const Color(0xFF303030).withOpacity(0.5),
             borderRadius: BorderRadius.circular(16),
           ),
           child: const SizedBox(
             width: 24, height: 24,
             child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
           ),
         );
      }

      final urlToPlay = hasLocalFile ? msg.localFilePath! : msg.mediaUrl!;

      return VoiceNoteBubble(
        key: ValueKey(urlToPlay), 
        url: urlToPlay, 
        mine: mine, 
        fileName: msg.fileName,
        isUploading: msg.isUploading,
        encryptedMediaKey: msg.encryptedMediaKey,
        senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
      );
    }

    if (msg.type == MessageType.image || msg.type == MessageType.imageGroup) {
      final List<String> imageUrls = msg.mediaUrls.isNotEmpty
          ? msg.mediaUrls
          : (msg.mediaUrl != null ? [msg.mediaUrl!] : []);
      final List<String> localPaths = msg.localFilePaths;
      
      final images = <dynamic>[];
      for (final p in localPaths) {
        if (p.isNotEmpty) {
          images.add(File(p));
        }
      }
      for (final u in imageUrls) {
        if (u.isNotEmpty && !images.contains(u)) {
          images.add(u);
        }
      }

      final hasLocalFile = msg.localFilePath != null && File(msg.localFilePath!).existsSync();
      final hasUrl = msg.mediaUrl != null;

      if (images.isEmpty && !hasLocalFile && !hasUrl) {
         return Container(
           margin: const EdgeInsets.only(top: 4, bottom: 4),
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: mine ? const Color(0xFF673AB7).withOpacity(0.5) : const Color(0xFF303030).withOpacity(0.5),
             borderRadius: BorderRadius.circular(16),
           ),
           child: const SizedBox(
             width: 24, height: 24,
             child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
           ),
         );
      }

      final Widget imageWidget;
      if (images.length > 1) {
        imageWidget = _buildMultiImageLayout(msg, images, mine);
      } else {
        imageWidget = GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MultiImagePreviewScreen(
                  msg: msg,
                  images: images,
                  initialIndex: 0,
                  chatId: widget.chatId,
                  repo: ref.read(chatRepositoryProvider),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                    maxHeight: 400,
                  ),
                  child: hasLocalFile
                    ? Image.file(
                        File(msg.localFilePath!),
                        fit: BoxFit.contain,
                      )
                    : CachedMediaWrapper(
                        url: msg.mediaUrl!,
                        encryptedMediaKey: msg.encryptedMediaKey,
                        senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
                        builder: (context, file) {
                          return Image.file(
                            file,
                            fit: BoxFit.contain,
                          );
                        },
                        loadingBuilder: (context) {
                          return Container(
                            width: MediaQuery.of(context).size.width * 0.66,
                            height: 260,
                            color: Colors.black.withOpacity(0.04),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                              ),
                            ),
                          );
                        },
                      ),
                ),
                if (msg.isUploading)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                if (msg.isHD)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white70, width: 0.5),
                      ),
                      child: const Text('HD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          imageWidget,
          if (msg.cipherText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: msg.isEncrypted
                  ? DecryptedText(
                      cipherText: msg.cipherText,
                      senderId: msg.senderId,
                      mine: mine,
                      chatId: widget.chatId,
                      senderPublicKey: msg.senderPublicKey,
                      recipientPublicKey: msg.recipientPublicKey,
                      builder: (text) => _buildMessageText(
                        text,
                        mine,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : _buildMessageText(
                      msg.cipherText,
                      mine,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
            ),
        ],
      );
    }

    if (msg.type == MessageType.video) {
      final hasLocalFile = msg.localFilePath != null && File(msg.localFilePath!).existsSync();
      final hasUrl = msg.mediaUrl != null;

      if (!hasLocalFile && !hasUrl) {
         return Container(
           margin: const EdgeInsets.only(top: 4, bottom: 4),
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: mine ? const Color(0xFF673AB7).withOpacity(0.5) : const Color(0xFF303030).withOpacity(0.5),
             borderRadius: BorderRadius.circular(16),
           ),
           child: const SizedBox(
             width: 24, height: 24,
             child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
           ),
         );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (hasUrl) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPreviewScreen(
                      videoUrl: msg.mediaUrl!,
                      encryptedMediaKey: msg.encryptedMediaKey,
                      senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
                    ),
                  ),
                );
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.66,
                  height: 245,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                if (!msg.isUploading)
                  const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 58,
                  )
                else
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                if (msg.isHD)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white70, width: 0.5),
                      ),
                      child: const Text('HD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          if (msg.cipherText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: msg.isEncrypted
                  ? DecryptedText(
                      cipherText: msg.cipherText,
                      senderId: msg.senderId,
                      mine: mine,
                      chatId: widget.chatId,
                      senderPublicKey: msg.senderPublicKey,
                      recipientPublicKey: msg.recipientPublicKey,
                      builder: (text) => _buildMessageText(
                        text,
                        mine,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : _buildMessageText(
                      msg.cipherText,
                      mine,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                      ),
                    ),
            ),
        ],
      );
    }

    if (msg.type == MessageType.document && msg.mediaUrl != null) {
      return GestureDetector(
        onTap: () => downloadAndOpenFile(
          msg.mediaUrl!,
          fileName: msg.fileName ?? 'a_chatz_document',
          encryptedMediaKey: msg.encryptedMediaKey,
          senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.66,
          decoration: BoxDecoration(
            color: mine
                ? Colors.black.withOpacity(0.06)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDocumentPreview(msg, mine),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 20, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        msg.fileName ?? 'Document',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.download_rounded, size: 18, color: Colors.white54),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (msg.type == MessageType.location) {
      return _LocationBubble(msg: msg, mine: mine, chatId: widget.chatId);
    }

    if (msg.type == MessageType.poll) {
      if (msg.isEncrypted) {
        return DecryptedText(
          key: ValueKey(msg.id),
          cipherText: msg.cipherText,
          senderId: msg.senderId,
          mine: mine,
          chatId: widget.chatId,
          senderPublicKey: msg.senderPublicKey,
          recipientPublicKey: msg.recipientPublicKey,
          builder: (decryptedJson) {
            try {
              final Map<String, dynamic> data = jsonDecode(decryptedJson);
              final question = data['question'] as String? ?? '';
              final options = List<String>.from(data['options'] ?? []);
              return _PollBubbleWidget(
                question: question,
                options: options,
                pollVotes: msg.pollVotes ?? {},
                onVote: (idx) => ref.read(chatRepositoryProvider).castVote(widget.chatId, msg.id, idx),
              );
            } catch (e) {
              return Text('Failed to load encrypted poll: $decryptedJson');
            }
          },
        );
      } else {
        // Plain text (group/public chat)
        final question = msg.pollQuestion ?? '';
        final options = msg.pollOptions ?? [];
        return _PollBubbleWidget(
          question: question,
          options: options,
          pollVotes: msg.pollVotes ?? {},
          onVote: (idx) => ref.read(chatRepositoryProvider).castVote(widget.chatId, msg.id, idx),
        );
      }
    }

    if (msg.isEncrypted) {
      return DecryptedText(
        key: ValueKey(msg.id),
        cipherText: msg.cipherText,
        senderId: msg.senderId,
        mine: mine,
        chatId: widget.chatId,
        senderPublicKey: msg.senderPublicKey,
        recipientPublicKey: msg.recipientPublicKey,
        builder: (text) {
          if (text.startsWith('📅 SCHEDULED_CALL')) {
            return ScheduledCallCard(text: text, mine: mine);
          }
          if (text.startsWith('🎮 GAME_INVITATION')) {
            return _InteractiveGameInvitationCard(
              text: text,
              chatId: widget.chatId,
              mine: mine,
            );
          }
          return null;
        },
      );
    }

    final url = LinkPreviewHelper.extractUrl(msg.cipherText);
    if (url != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMessageText(
            msg.cipherText,
            mine,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              height: 1.25,
            ),
          ),
          LinkPreviewWidget(url: url, compact: true),
        ],
      );
    }

    if (msg.cipherText.startsWith('🧾 RECEIPT')) {
      return InvoiceReceiptCard(text: msg.cipherText, mine: mine);
    }

    if (msg.cipherText.startsWith('📅 SCHEDULED_CALL')) {
      return ScheduledCallCard(text: msg.cipherText, mine: mine);
    }

    if (msg.cipherText.startsWith('🎮 GAME_INVITATION')) {
      return _InteractiveGameInvitationCard(
        text: msg.cipherText,
        chatId: widget.chatId,
        mine: mine,
      );
    }

    return _buildMessageText(
      msg.cipherText,
      mine,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 13,
        height: 1.25,
      ),
    );
  }

  Widget _buildMultiImageLayout(ChatMessage msg, List<dynamic> images, bool mine) {
    final count = images.length;
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width * 0.72;

    if (count == 2) {
      return Container(
        width: maxWidth,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(child: _buildSingleImageItem(msg, images[0], mine, index: 0, allImages: images)),
            const SizedBox(width: 4),
            Expanded(child: _buildSingleImageItem(msg, images[1], mine, index: 1, allImages: images)),
          ],
        ),
      );
    } else if (count == 3) {
      return Container(
        width: maxWidth,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildSingleImageItem(msg, images[0], mine, index: 0, allImages: images),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: _buildSingleImageItem(msg, images[1], mine, index: 1, allImages: images)),
                  const SizedBox(height: 4),
                  Expanded(child: _buildSingleImageItem(msg, images[2], mine, index: 2, allImages: images)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: maxWidth,
        height: maxWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildSingleImageItem(msg, images[0], mine, index: 0, allImages: images)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildSingleImageItem(msg, images[1], mine, index: 1, allImages: images)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildSingleImageItem(msg, images[2], mine, index: 2, allImages: images)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildSingleImageItem(msg, images[3], mine, index: 3, allImages: images),
                        if (count > 4)
                          Container(
                            color: Colors.black.withOpacity(0.55),
                            alignment: Alignment.center,
                            child: Text(
                              '+${count - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSingleImageItem(ChatMessage msg, dynamic source, bool mine, {int? index, required List<dynamic> allImages}) {
    final bool isFile = source is File;
    final hasUrl = source is String;
    
    final isVideo = source is String
        ? (source.toLowerCase().contains('.mp4') || source.toLowerCase().contains('.mov'))
        : (source is File && (source.path.toLowerCase().endsWith('.mp4') || source.path.toLowerCase().endsWith('.mov')));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MultiImagePreviewScreen(
              msg: msg,
              images: allImages,
              initialIndex: index ?? 0,
              chatId: widget.chatId,
              repo: ref.read(chatRepositoryProvider),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: isVideo
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.videocam, color: Colors.white54, size: 30),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_filled, color: Colors.white, size: 40),
                  ),
                ],
              )
            : (isFile
                ? Image.file(
                    source,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : CachedMediaWrapper(
                    url: source,
                    encryptedMediaKey: msg.encryptedMediaKey,
                    senderPublicKey: mine ? msg.recipientPublicKey : msg.senderPublicKey,
                    builder: (context, file) {
                      return Image.file(
                        file,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    },
                    loadingBuilder: (context) {
                      return Container(
                        color: Colors.black.withOpacity(0.04),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                          ),
                        ),
                      );
                    },
                  )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.chatId));
    final currentUid = ref.read(chatRepositoryProvider).uid;
    final currentUserProfile = ref.watch(currentUserProfileProvider).value;
    final readReceiptsEnabled = currentUserProfile?['readReceiptsEnabled'] ?? true;
    final chatDetails = ref.watch(chatDetailsProvider(widget.chatId)).value;
    final isGroup = chatDetails != null && chatDetails['type'] == 'group';
    
    final hasText = input.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Luxury Background
          Positioned.fill(
            child: _wallpaperPath != null 
                ? WallpaperBackground(wallpaperPath: _wallpaperPath!) 
                : const LogoDoodleBackground(),
          ),

          Positioned.fill(
            child: messages.when(
              skipLoadingOnReload: true,
              data: (items) {
                if (items.isNotEmpty) {
                  final latestMsg = items.first;
                  if (latestMsg.senderId != currentUid && latestMsg.type == MessageType.text) {
                    Future.microtask(() => _generateSmartSuggestions(latestMsg));
                  } else {
                    if (_smartSuggestions.isNotEmpty) {
                      Future.microtask(() {
                        if (mounted) {
                          setState(() {
                            _smartSuggestions = [];
                          });
                        }
                      });
                    }
                  }
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  markVisibleMessagesAsRead(items);
                });

                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.only(
                    top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
                    bottom: 95.0 + MediaQuery.of(context).padding.bottom + (replyingTo != null ? 50 : 0) + (_activePreviewUrl != null ? 70 : 0),
                    left: 10,
                    right: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final msg = items[i];
                    final mine = msg.senderId == currentUid;
                    final isSystem = msg.type == MessageType.system;

                    if (isSystem) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.background,
                            border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 1.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: buildMessageContent(msg, mine),
                        ),
                      );
                    }

                    final isSticker = msg.type == MessageType.sticker;

                    final messageBubble = Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      padding: isSticker ? EdgeInsets.zero : const EdgeInsets.all(6),
                      decoration: isSticker
                          ? const BoxDecoration(color: Colors.transparent)
                          : BoxDecoration(
                              color: mine ? Colors.white : const Color(0xFF1E1E1E),
                              border: Border.all(color: Colors.white24, width: 1),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(mine ? 16 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 16),
                              ),
                            ),
                      child: Column(
                        crossAxisAlignment: isSticker
                            ? (mine ? CrossAxisAlignment.end : CrossAxisAlignment.start)
                            : CrossAxisAlignment.start,
                        children: [
                          if (isGroup && !mine)
                            _buildGroupSenderHeader(msg.senderId),
                          if (msg.replyToMessageId != null && !isSticker)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Replying to message',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              buildMessageContent(msg, mine),
                              if (msg.reactions.isNotEmpty)
                                Positioned(
                                  bottom: -15,
                                  right: mine ? null : 0,
                                  left: mine ? 0 : null,
                                  child: _buildReactionsBadge(msg.reactions, mine),
                                ),
                            ],
                          ),
                          if (msg.selfDestructDuration != null && !msg.deletedForEveryone && !isSticker)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: SelfDestructCountdownWidget(
                                msg: msg,
                                onExpire: () async {
                                  await ref.read(chatRepositoryProvider).deleteMessage(widget.chatId, msg.id);
                                },
                              ),
                            ),
                          if (isSticker)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(top: 4, right: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (msg.editedAt != null)
                                    const Text('edited  ', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                  Text(
                                    formatTime(msg.createdAt),
                                    style: const TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                  if (mine)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Builder(
                                        builder: (_) {
                                          final isRead = readReceiptsEnabled && msg.readBy.keys.any((id) => id != currentUid);
                                          final isDelivered = msg.deliveredTo.keys.any((id) => id != currentUid);
                                          
                                          if (isRead) {
                                            return const Icon(Icons.done_all, size: 14, color: Color(0xFF34B7F1));
                                          } else if (isDelivered) {
                                            return const Icon(Icons.done_all, size: 14, color: Colors.white70);
                                          } else if (msg.hasPendingWrites || msg.isUploading) {
                                            return const Icon(Icons.access_time, size: 14, color: Colors.white70);
                                          } else {
                                            return const Icon(Icons.done, size: 14, color: Colors.white70);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else ...[
                            const SizedBox(height: 3),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (msg.editedAt != null)
                                    Text('edited  ', style: TextStyle(fontSize: 10, color: mine ? Colors.black45 : Colors.grey)),
                                  Text(
                                    formatTime(msg.createdAt),
                                    style: TextStyle(fontSize: 10, color: mine ? Colors.black54 : Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                                  ),
                                  if (mine)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Builder(
                                        builder: (_) {
                                          final isRead = readReceiptsEnabled && msg.readBy.keys.any((id) => id != currentUid);
                                          final isDelivered = msg.deliveredTo.keys.any((id) => id != currentUid);
                                          
                                          if (isRead) {
                                            return const Icon(Icons.done_all, size: 16, color: Color(0xFF34B7F1));
                                          } else if (isDelivered) {
                                            return Icon(Icons.done_all, size: 16, color: mine ? Colors.black45 : Colors.grey);
                                          } else if (msg.hasPendingWrites || msg.isUploading) {
                                            return Icon(Icons.access_time, size: 16, color: mine ? Colors.black45 : Colors.grey);
                                          } else {
                                            return Icon(Icons.done, size: 16, color: mine ? Colors.black45 : Colors.grey);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );

                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () => showMessageActions(msg),
                        child: messageBubble,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white54,
                  ),
                ),
              ),
              error: (e, st) {
                debugPrint('Messages error: $e');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load messages',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.toString(),
                        maxLines: 3,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(messagesProvider(widget.chatId)),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Translucent Blurry AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xD3000000)
                      : const Color(0xD3FFFFFF),
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      titleSpacing: 8,
                      title: _ChatHeader(
                        chatId: widget.chatId,
                        currentUid: currentUid,
                        formatLastSeen: formatLastSeen,
                      ),
                      actions: [
                        _CallButtons(chatId: widget.chatId, currentUid: currentUid),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: _handleAppBarMenuSelected,
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'view', child: Text(isGroup ? 'View Group Info' : 'View Contact')),
                            const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
                            if (!isGroup)
                              const PopupMenuItem(value: 'block', child: Text('Block User', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Translucent Blurry Input Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xD3000000)
                      : const Color(0xD3FFFFFF),
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_activePreviewUrl != null)
                        _buildTypingLinkPreview(),
                      if (replyingTo != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF17171A).withOpacity(0.8)
                              : const Color(0xFFF0F2F5).withOpacity(0.8),
                          child: Row(
                            children: [
                              const Icon(Icons.reply, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Replying to message', maxLines: 1, overflow: TextOverflow.ellipsis)),
                              IconButton(onPressed: () => setState(() => replyingTo = null), icon: const Icon(Icons.close)),
                            ],
                          ),
                        ),
                      _buildInputArea(hasText, currentUserProfile),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_superReactionEmoji != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _SuperReactionAnimation(
                  emoji: _superReactionEmoji!,
                  onComplete: () {
                    if (mounted) {
                      setState(() {
                        _superReactionEmoji = null;
                      });
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingLinkPreview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark 
        ? const Color(0xFF17171A) 
        : const Color(0xFFF0F2F5);
    final textThemeColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        border: const Border(
          top: BorderSide(color: Color(0xFF202024)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_previewMetadata == null) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Loading preview for $_activePreviewUrl...',
                style: TextStyle(color: subtextColor, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            if (_previewMetadata!.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  _previewMetadata!.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _previewMetadata!.siteName?.toUpperCase() ?? Uri.parse(_activePreviewUrl!).host.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _previewMetadata!.title ?? 'Link Preview',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textThemeColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (_previewMetadata!.description != null && _previewMetadata!.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _previewMetadata!.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _dismissedPreviewUrl = _activePreviewUrl;
                _activePreviewUrl = null;
                _previewMetadata = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool hasText, Map<String, dynamic>? currentUserProfile) {
    final currentUid = ref.read(chatRepositoryProvider).uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppDatabase.instance.table('chats').doc(widget.chatId).snapshots(),
      builder: (context, chatSnap) {
        if (!chatSnap.hasData) return const SizedBox.shrink();

        final chatData = chatSnap.data!.data() ?? {};
        final rawType = chatData['type']?.toString().trim().toLowerCase() ?? 'private';
        final isGroup = rawType == 'group';

        if (isGroup) {
          final members = List<String>.from(chatData['memberIds'] ?? []);
          if (!members.contains(currentUid)) {
            return SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                color: const Color(0xFF101012),
                child: const Text(
                  'You have been removed from this group.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_getMentionQuery() != null)
                _buildMentionSelector(_getMentionQuery()!, members),
              _buildInputSafeArea(hasText, currentUserProfile),
            ],
          );
        }

        final members = List<String>.from(chatData['memberIds'] ?? []);
        String otherUid = '';
        for (final id in members) {
          if (id != currentUid) {
            otherUid = id;
            break;
          }
        }

        if (otherUid.isEmpty) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_getMentionQuery() != null)
                _buildMentionSelector(_getMentionQuery()!, members),
              _buildInputSafeArea(hasText, currentUserProfile),
            ],
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance
              .table('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, userSnap) {
            final blockedUsers = List<String>.from(userSnap.data?.data()?['blockedUsers'] ?? []);
            final isBlocked = blockedUsers.contains(otherUid);

            if (isBlocked) {
              return SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: const Text('Unblock User', style: TextStyle(color: Colors.white)),
                        content: const Text('Unblock this contact to send messages?', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unblock', style: TextStyle(color: Colors.greenAccent))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(chatRepositoryProvider).unblockUser(otherUid);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: const Color(0xFF101012),
                    child: const Text(
                      'You blocked this contact. Tap to unblock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_getMentionQuery() != null)
                  _buildMentionSelector(_getMentionQuery()!, members),
                _buildSmartSuggestions(),
                _buildInputSafeArea(hasText, currentUserProfile),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInputSafeArea(bool hasText, Map<String, dynamic>? currentUserProfile) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isSmallScreen ? 6 : 10,
          6,
          isSmallScreen ? 6 : 10,
          8,
        ),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF202024)),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: uploading ? null : showMediaOptions,
              icon: Icon(Icons.add_circle_outline, size: isSmallScreen ? 22 : 24),
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => StickersPickerSheet(chatId: widget.chatId),
                );
              },
              icon: Icon(Icons.sentiment_satisfied_alt_outlined, size: isSmallScreen ? 22 : 24),
            ),
            const SizedBox(width: 10),
             if (recording)
               const Expanded(
                 child: _VoiceRecordingWaveform(),
               )
             else
               Expanded(
                 child: TextField(
                   controller: input,
                   focusNode: _chatInputFocusNode,
                   onChanged: (value) {
                     HapticFeedback.lightImpact();
                     setState(() {});
                     final isNotEmpty = value.trim().isNotEmpty;
                     if (isNotEmpty != _isTypingLocal) {
                       setState(() {
                         _isTypingLocal = isNotEmpty;
                       });
                       ref.read(chatRepositoryProvider).setTyping(
                             widget.chatId,
                             isNotEmpty,
                           );
                     }
                   },
                   minLines: 1,
                   maxLines: 5,
                   textInputAction: _enterIsSend ? TextInputAction.send : TextInputAction.newline,
                   onSubmitted: _enterIsSend ? (_) => send() : null,
                   style: TextStyle(fontSize: isSmallScreen ? 14 : 15),
                   decoration: const InputDecoration(
                     hintText: 'Message...',
                     border: InputBorder.none,
                     contentPadding: EdgeInsets.symmetric(vertical: 8),
                   ),
                 ),
               ),
            if (recording) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _viewOnceVoice = !_viewOnceVoice;
                  });
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _viewOnceVoice ? const Color(0xFF00A884) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _viewOnceVoice ? Colors.transparent : Colors.grey,
                      width: 1.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '1',
                      style: TextStyle(
                        color: _viewOnceVoice ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: sending || uploading
                  ? null
                  : hasText
                      ? send
                      : recording
                          ? stopAndSendVoiceNote
                          : startVoiceRecording,
              icon: Icon(
                hasText
                    ? Icons.send_rounded
                    : recording
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                color: recording ? Colors.redAccent : null,
                size: isSmallScreen ? 22 : 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePollDialog() {
    showDialog(
      context: context,
      builder: (context) => const _CreatePollDialog(),
    ).then((result) async {
      if (result != null && result is Map<String, dynamic>) {
        final question = result['question'] as String;
        final options = result['options'] as List<String>;
        await ref.read(chatRepositoryProvider).sendPoll(widget.chatId, question, options);
      }
    });
  }
}

class _CallButtons extends ConsumerWidget {
  const _CallButtons({required this.chatId, required this.currentUid});
  final String chatId;
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppDatabase.instance.table('chats').doc(chatId).snapshots(),
      builder: (context, chatSnap) {
        if (!chatSnap.hasData) return const SizedBox.shrink();

        final chatData = chatSnap.data!.data() ?? {};
        final rawType = chatData['type']?.toString().trim().toLowerCase() ?? 'private';
        final isGroup = rawType == 'group';

        if (isGroup) {
          final members = List<String>.from(chatData['memberIds'] ?? []);
          if (!members.contains(currentUid)) {
            return const SizedBox.shrink();
          }
          return _buildButtons(context, ref, chatData);
        }

        final members = List<String>.from(chatData['memberIds'] ?? []);
        String otherUid = '';
        for (final id in members) {
          if (id != currentUid) {
            otherUid = id;
            break;
          }
        }

        if (otherUid.isEmpty) return _buildButtons(context, ref, chatData);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance
              .table('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, currentSnap) {
            final currentUserMap = currentSnap.data?.data() ?? {};
            final blockedUsers = List<String>.from(currentUserMap['blockedUsers'] ?? []);
            final isBlockedByMe = blockedUsers.contains(otherUid);

            if (isBlockedByMe) {
              return const SizedBox.shrink();
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AppDatabase.instance
                  .table('users')
                  .doc(otherUid)
                  .snapshots(),
              builder: (context, userSnap) {
                final userMap = userSnap.data?.data() ?? {};
                final otherUserBlockedMe = List<String>.from(userMap['blockedUsers'] ?? []).contains(currentUid);
                
                final username = userMap['username'] ?? userMap['email'] ?? 'User';
                final photoUrl = otherUserBlockedMe ? null : userMap['photoUrl'];

                return _buildButtons(
                  context,
                  ref,
                  chatData,
                  remoteName: username,
                  remotePhotoUrl: photoUrl,
                );
              },
            );
          },
        );
      },
    );
  }

  // Web call restriction dialog removed

  Widget _buildButtons(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> chatData, {
    String? remoteName,
    String? remotePhotoUrl,
  }) {
    final title = remoteName ?? chatData['title'] ?? 'Chat';
    final photoUrl = remotePhotoUrl ?? chatData['photoUrl'];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () async {
            final members = List<String>.from(chatData['memberIds'] ?? []);
            final receivers = members.where((id) => id != currentUid).toList();

            final callId = await ref.read(callRepositoryProvider).startCall(
                  chatId: chatId,
                  receiverIds: receivers,
                  isVideo: false,
                  chatName: title,
                );

            if (context.mounted) {
              final nameParam = Uri.encodeComponent(title);
              final photoParam = photoUrl != null ? Uri.encodeComponent(photoUrl) : '';
              context.push('/call-room/$callId?caller=true&video=false&name=$nameParam&photoUrl=$photoParam');
            }
          },
          icon: const Icon(Icons.call_outlined),
        ),
        IconButton(
          onPressed: () async {
            final members = List<String>.from(chatData['memberIds'] ?? []);
            final receivers = members.where((id) => id != currentUid).toList();

            final callId = await ref.read(callRepositoryProvider).startCall(
                  chatId: chatId,
                  receiverIds: receivers,
                  isVideo: true,
                  chatName: title,
                );

            if (context.mounted) {
              final nameParam = Uri.encodeComponent(title);
              final photoParam = photoUrl != null ? Uri.encodeComponent(photoUrl) : '';
              context.push('/call-room/$callId?caller=true&video=true&name=$nameParam&photoUrl=$photoParam');
            }
          },
          icon: const Icon(Icons.videocam_outlined),
        ),
      ],
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({
    required this.chatId,
    required this.currentUid,
    required this.formatLastSeen,
  });

  final String chatId;
  final String currentUid;
  final String Function(dynamic) formatLastSeen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppDatabase.instance.table('chats').doc(chatId).snapshots(),
      builder: (_, chatSnap) {
        if (!chatSnap.hasData) return const SizedBox.shrink();

        final chat = chatSnap.data!.data() ?? {};

        final rawType =
            chat['type']?.toString().trim().toLowerCase() ?? 'private';
        final isGroup = rawType == 'group';

        final title = (chat['title'] ?? 'Chat').toString();
        final photoUrl = chat['photoUrl'];
        final members = List<String>.from(chat['memberIds'] ?? []);

        if (isGroup) {
          return GestureDetector(
            onTap: () => context.push('/contact-info/$chatId/group'),
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 16, top: 4, bottom: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? const Icon(Icons.groups, color: Colors.black)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Builder(builder: (ctx) {
                          final typingMap = Map<String, dynamic>.from(chat['typing'] ?? {});
                          final recordingMap = Map<String, dynamic>.from(chat['recording'] ?? {});
                          final someoneTyping = typingMap.entries.any((e) => e.key != currentUid && e.value == true);
                          final someoneRecording = recordingMap.entries.any((e) => e.key != currentUid && e.value == true);
                          if (someoneRecording) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.mic, size: 14, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  'recording...',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          } else if (someoneTyping) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_note, size: 14, color: Color(0xFF10B981)),
                                const SizedBox(width: 4),
                                Text(
                                  'typing...',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Text(
                            '${members.length} members',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        String otherUid = '';

        for (final id in members) {
          if (id != currentUid) {
            otherUid = id;
            break;
          }
        }

        if (otherUid.isEmpty) return const Text('Chat');

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance
              .table('users')
              .doc(otherUid)
              .snapshots(),
          builder: (_, userSnap) {
            if (!userSnap.hasData) return const SizedBox.shrink();

            final user = userSnap.data!.data() ?? {};
            final username = user['username'] ?? 'User';
            final blockedUsersList = List<String>.from(user['blockedUsers'] ?? []);
            final otherUserBlockedMe = blockedUsersList.contains(currentUid);
            final profileImage = otherUserBlockedMe ? null : user['photoUrl'];
            final online = user['isOnline'] ?? false;
            final isOfficial = otherUid == 'official_a_chatz';
            final isVerified = user['isVerified'] == true;
            final verificationTier = user['verificationTier'] as String?;
            // Privacy: read the other user's last-seen visibility preference
            final lastSeenVisibility = user['lastSeenVisibility'] as String? ?? 'Everyone';

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AppDatabase.instance
                  .table('users')
                  .doc(currentUid)
                  .table('contacts')
                  .doc(otherUid)
                  .snapshots(),
              builder: (context, contactSnap) {
                final contactData = contactSnap.data?.data();
                final displayName = contactData?['displayName'] as String? ?? username;

                return GestureDetector(
                  onTap: () => context.push('/contact-info/$chatId/$otherUid'),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 16, top: 4, bottom: 4),
                    child: Row(
                      children: [
                        isOfficial
                            ? CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF1E1E24),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.verified_user,
                                      color: Colors.greenAccent,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              )
                            : PremiumAvatar(
                                userId: otherUid,
                                photoUrl: profileImage,
                                radius: 20,
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                              if (isOfficial) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => showVerificationInfoDialog(context),
                                  child: const Icon(Icons.verified, size: 16, color: Colors.blueAccent),
                                ),
                              ] else if (isVerified) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => showVerificationInfoDialog(context),
                                  child: Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: verificationTier == 'tier2'
                                        ? Colors.purpleAccent
                                        : (verificationTier == 'tier3'
                                            ? Colors.amberAccent
                                            : Colors.blueAccent),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Builder(builder: (ctx) {
                            final typingMap = Map<String, dynamic>.from(chat['typing'] ?? {});
                            final recordingMap = Map<String, dynamic>.from(chat['recording'] ?? {});
                            final isOtherRecording = recordingMap[otherUid] == true;
                            final isOtherTyping = typingMap[otherUid] == true;
                            if (isOtherRecording) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.mic, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'recording...',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF10B981),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            } else if (isOtherTyping) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_note, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'typing...',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF10B981),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            }
                            // Respect lastSeenVisibility privacy setting
                            return StreamBuilder<DocumentSnapshot>(
                              stream: AppDatabase.instance
                                  .table('users')
                                  .doc(otherUid)
                                  .table('contacts')
                                  .doc(currentUid)
                                  .snapshots(),
                              builder: (_, theirContactSnap) {
                                final theyHaveMe = theirContactSnap.hasData &&
                                    (theirContactSnap.data?.exists ?? false);

                                // Decide whether to reveal presence
                                final bool showPresence;
                                if (isOfficial) {
                                  showPresence = true;
                                } else if (lastSeenVisibility == 'Nobody') {
                                  showPresence = false;
                                } else if (lastSeenVisibility == 'My contacts') {
                                  showPresence = theyHaveMe;
                                } else {
                                  // 'Everyone'
                                  showPresence = true;
                                }

                                if (!showPresence) {
                                  return const SizedBox.shrink();
                                }

                                return Row(
                                  children: [

                                    Text(
                                      online ? 'Online' : formatLastSeen(user['lastSeen']),
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                );
                              },
                            );
                          }),
                        ],
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
    },
  );
  }
}

class VoiceNoteBubble extends StatefulWidget {
  const VoiceNoteBubble({
    super.key,
    required this.url,
    required this.mine,
    this.fileName,
    this.isUploading = false,
    this.encryptedMediaKey,
    this.senderPublicKey,
  });

  final String url;
  final bool mine;
  final String? fileName;
  final bool isUploading;
  final String? encryptedMediaKey;
  final String? senderPublicKey;

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  final player = AudioPlayer();

  bool loading = false;
  bool playing = false;
  bool prepared = false;
  bool _isDownloaded = false;
  double _playbackSpeed = 1.0;

  String? _transcription;
  bool _transcribing = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  bool get isMusic => widget.fileName != null && !widget.fileName!.startsWith('voice_');

  @override
  void initState() {
    super.initState();
    _checkIfDownloaded();

    player.playerStateStream.listen((state) {
      if (!mounted) return;

      if (state.processingState == ProcessingState.completed) {
        player.seek(Duration.zero);
        player.pause();

        setState(() {
          playing = false;
        });

        return;
      }

      setState(() {
        playing = state.playing;
      });
    });

    _posSub = player.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _durSub = player.durationStream.listen((dur) {
      if (mounted && dur != null) {
        setState(() {
          _duration = dur;
        });
      }
    });
  }

  void _seekToPosition(double localX, double totalWidth) {
    if (_duration == Duration.zero) return;
    double fraction = localX / totalWidth;
    if (fraction < 0.0) fraction = 0.0;
    if (fraction > 1.0) fraction = 1.0;
    final targetPosition = _duration * fraction;
    player.seek(targetPosition);
  }

  Future<void> _checkIfDownloaded() async {
    final cachedFile = await LocalMediaCache.instance.getCachedFile(widget.url);
    if (cachedFile != null && mounted) {
      try {
        await player.setFilePath(cachedFile.path);
        await player.setSpeed(_playbackSpeed);
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            prepared = true;
          });
        }
      } catch (e) {
        debugPrint('Error setting pre-cached file path: $e');
        if (mounted) {
          setState(() {
            _isDownloaded = false;
            prepared = false;
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _isDownloaded = false;
        prepared = false;
      });
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VoiceNoteBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _posSub?.cancel();
      _durSub?.cancel();
      try {
        player.stop();
      } catch (_) {}
      
      setState(() {
        prepared = false;
        playing = false;
        loading = false;
        _isDownloaded = false;
        _transcription = null;
        _transcribing = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });

      _checkIfDownloaded();

      _posSub = player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      });

      _durSub = player.durationStream.listen((dur) {
        if (mounted && dur != null) {
          setState(() {
            _duration = dur;
          });
        }
      });
    }
  }

  Future<void> prepareAudio() async {
    if (prepared || loading) return;

    setState(() => loading = true);

    try {
      final cachedFile = await LocalMediaCache.instance.getCachedFile(widget.url);
      if (cachedFile != null) {
        await player.setFilePath(cachedFile.path);
        _isDownloaded = true;
      } else {
        final downloadedFile = await LocalMediaCache.instance.downloadAndCache(
          widget.url,
          encryptedMediaKey: widget.encryptedMediaKey,
          senderPublicKey: widget.senderPublicKey,
        );
        await player.setFilePath(downloadedFile.path);
        _isDownloaded = true;
      }
      await player.setSpeed(_playbackSpeed);
      prepared = true;
    } catch (_) {
      try {
        await player.setUrl(widget.url);
        await player.setSpeed(_playbackSpeed);
        prepared = true;
        _isDownloaded = true;
      } catch (_) {
        prepared = false;
      }
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> togglePlay() async {
    if (!prepared) {
      await prepareAudio();
    }

    if (!prepared) return;

    if (player.playing) {
      await player.pause();

      if (mounted) setState(() => playing = false);
      return;
    }

    await player.play();

    if (mounted) setState(() => playing = true);
  }

  Future<void> _transcribeAudio() async {
    setState(() {
      _transcribing = true;
      _transcription = null;
    });

    try {
      final cachedFile = await LocalMediaCache.instance.getCachedFile(widget.url)
          ?? await LocalMediaCache.instance.downloadAndCache(
               widget.url,
               encryptedMediaKey: widget.encryptedMediaKey,
               senderPublicKey: widget.senderPublicKey,
             );
      final audioBytes = await cachedFile.readAsBytes();

      final prefs = await SharedPreferences.getInstance();
      String key = prefs.getString('gemini_api_key') ?? '';
      if (key.isEmpty) {
        key = 'AIzaSyD7O-9aZhePi_oumJdbQURk9zuZLbH4NfY';
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: key,
      );

      String mimeType = 'audio/mp3';
      if (widget.url.endsWith('.m4a')) {
        mimeType = 'audio/m4a';
      } else if (widget.url.endsWith('.ogg')) {
        mimeType = 'audio/ogg';
      } else if (widget.url.endsWith('.wav')) {
        mimeType = 'audio/wav';
      } else if (widget.url.endsWith('.aac')) {
        mimeType = 'audio/aac';
      }

      final response = await model.generateContent([
        Content.multi([
          DataPart(mimeType, audioBytes),
          TextPart(
            'Identify the spoken language in this audio voice note. Translate it directly into English and output only the English translation. If the spoken language is already English, output the exact transcription. Make the transcription/translation extremely accurate.',
          ),
        ]),
      ]);

      setState(() {
        _transcription = response.text?.trim() ?? 'Could not transcribe voice note.';
      });
    } catch (e) {
      setState(() {
        _transcription = "🎙️ [A-Chatz Offline AI]: Voice note received. Ensure internet connectivity is active for word-for-word remote transcription.";
      });
    } finally {
      setState(() {
        _transcribing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.mine ? Colors.black : Theme.of(context).colorScheme.onSurface;

    Color buttonBgColor;
    IconData buttonIcon;
    Color buttonIconColor;

    if (isMusic) {
      if (!_isDownloaded) {
        buttonBgColor = widget.mine ? const Color(0xFFFF5722) : const Color(0xFFFF9800);
        buttonIcon = Icons.download_rounded;
        buttonIconColor = Colors.white;
      } else {
        buttonBgColor = widget.mine ? const Color(0xFF673AB7) : const Color(0xFF9C27B0);
        buttonIcon = playing ? Icons.pause : Icons.play_arrow;
        buttonIconColor = Colors.white;
      }
    } else {
      buttonBgColor = widget.mine ? Colors.black : Theme.of(context).colorScheme.onSurface;
      buttonIcon = playing ? Icons.pause : Icons.play_arrow;
      buttonIconColor = widget.mine ? Colors.white : Theme.of(context).colorScheme.background;
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMusic) ...[
            Row(
              children: [
                Icon(
                  Icons.music_note,
                  size: 14,
                  color: barColor.withOpacity(0.8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.fileName ?? 'Audio Track',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              GestureDetector(
                onTap: togglePlay,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: buttonBgColor,
                  child: loading
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: buttonIconColor,
                          ),
                        )
                      : Icon(
                          buttonIcon,
                          color: buttonIconColor,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final progressFraction = _duration.inMilliseconds > 0
                        ? _position.inMilliseconds / _duration.inMilliseconds
                        : 0.0;

                    final activeColor = isMusic
                        ? (widget.mine ? const Color(0xFF673AB7) : const Color(0xFF9C27B0))
                        : barColor.withOpacity(0.95);

                    final inactiveColor = barColor.withOpacity(0.3);

                    final heights = [
                      6.0, 12.0, 18.0, 10.0, 22.0, 16.0, 8.0, 20.0, 14.0, 24.0,
                      10.0, 16.0, 7.0, 18.0, 12.0, 22.0, 8.0, 14.0, 20.0, 11.0,
                      17.0, 9.0
                    ];

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        _seekToPosition(details.localPosition.dx, constraints.maxWidth);
                      },
                      onHorizontalDragUpdate: (details) {
                        _seekToPosition(details.localPosition.dx, constraints.maxWidth);
                      },
                      child: SizedBox(
                        height: 28,
                        child: CustomPaint(
                          painter: _PlaybackWaveformPainter(
                            heights: heights,
                            progressFraction: progressFraction,
                            activeColor: activeColor,
                            inactiveColor: inactiveColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isMusic ? Icons.music_note : Icons.mic,
                size: 15,
                color: barColor.withOpacity(0.65),
              ),
              if (!isMusic) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_playbackSpeed == 1.0) {
                        _playbackSpeed = 1.5;
                      } else if (_playbackSpeed == 1.5) {
                        _playbackSpeed = 2.0;
                      } else {
                        _playbackSpeed = 1.0;
                      }
                      if (prepared) {
                        player.setSpeed(_playbackSpeed);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_playbackSpeed}x',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: barColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _transcribing ? null : _transcribeAudio,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _transcribing
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onSurface,
                              strokeWidth: 1.5,
                            ),
                          )
                        : Icon(
                            Icons.translate,
                            size: 15,
                            color: barColor.withOpacity(0.65),
                          ),
                  ),
                ),
              ],
            ],
          ),
          if (_transcription != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (widget.mine ? Colors.black : Colors.white).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (widget.mine ? Colors.black : Colors.white).withOpacity(0.1),
                ),
              ),
              child: SelectableText(
                _transcription!,
                style: TextStyle(
                  color: widget.mine ? Colors.black87 : Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({
    super.key, 
    required this.imageUrl, 
    this.isViewOnce = false,
    this.encryptedMediaKey,
    this.senderPublicKey,
  });

  final String imageUrl;
  final bool isViewOnce;
  final String? encryptedMediaKey;
  final String? senderPublicKey;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isViewOnce) {
      ScreenProtector.preventScreenshotOn();
    }
  }

  @override
  void dispose() {
    if (widget.isViewOnce) {
      ScreenProtector.preventScreenshotOff();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          if (!widget.isViewOnce)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final mediaVis = prefs.getBool('media_visibility') ?? true;
                  if (!mediaVis) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot save: Media visibility is disabled in Chat Settings.')),
                      );
                    }
                    return;
                  }
                  final cachedFile = await LocalMediaCache.instance.getCachedFile(widget.imageUrl) 
                                   ?? await LocalMediaCache.instance.downloadAndCache(
                                        widget.imageUrl,
                                        encryptedMediaKey: widget.encryptedMediaKey,
                                        senderPublicKey: widget.senderPublicKey,
                                      );
                  await Gal.putImage(cachedFile.path);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                  }
                }
              },
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedMediaWrapper(
            url: widget.imageUrl,
            encryptedMediaKey: widget.encryptedMediaKey,
            senderPublicKey: widget.senderPublicKey,
            builder: (context, file) => Image.file(file),
            loadingBuilder: (context) => const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
            ),
          ),
        ),
      ),
    );
  }
}

class MultiImagePreviewScreen extends StatefulWidget {
  const MultiImagePreviewScreen({
    super.key,
    required this.msg,
    required this.images,
    required this.initialIndex,
    required this.chatId,
    required this.repo,
  });

  final ChatMessage msg;
  final List<dynamic> images;
  final int initialIndex;
  final String chatId;
  final ChatRepository repo;

  @override
  State<MultiImagePreviewScreen> createState() => _MultiImagePreviewScreenState();
}

class _MultiImagePreviewScreenState extends State<MultiImagePreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  bool _isVideoLoading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initVideoIfNecessary();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  bool _isVideoSource(dynamic source) {
    if (source is String) {
      final pathLower = source.toLowerCase();
      return pathLower.contains('.mp4') || pathLower.contains('.mov') || pathLower.contains('.mkv') || pathLower.contains('.avi');
    } else if (source is File) {
      final pathLower = source.path.toLowerCase();
      return pathLower.endsWith('.mp4') || pathLower.endsWith('.mov') || pathLower.endsWith('.mkv') || pathLower.endsWith('.avi');
    }
    return false;
  }

  Future<void> _initVideoIfNecessary() async {
    _videoController?.dispose();
    _videoController = null;
    
    final currentSource = widget.images[_currentIndex];
    if (!_isVideoSource(currentSource)) {
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _isVideoLoading = true;
    });

    try {
      if (currentSource is File) {
        _videoController = VideoPlayerController.file(currentSource);
      } else if (currentSource is String) {
        final cachedFile = await LocalMediaCache.instance.getCachedFile(currentSource)
                         ?? await LocalMediaCache.instance.downloadAndCache(
                              currentSource,
                              encryptedMediaKey: widget.msg.encryptedMediaKey,
                              senderPublicKey: widget.msg.senderId == widget.repo.uid 
                                  ? widget.msg.recipientPublicKey 
                                  : widget.msg.senderPublicKey,
                            );
        _videoController = VideoPlayerController.file(cachedFile);
      }

      await _videoController?.initialize();
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });
        _videoController?.play();
        _videoController?.setLooping(true);
      }
    } catch (e) {
      debugPrint('Error initializing video in slideshow: $e');
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });
      }
    }
  }

  Future<void> _saveCurrentMedia() async {
    final currentSource = widget.images[_currentIndex];
    try {
      final prefs = await SharedPreferences.getInstance();
      final mediaVis = prefs.getBool('media_visibility') ?? true;
      if (!mediaVis) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot save: Media visibility is disabled in Chat Settings.')),
          );
        }
        return;
      }

      File? targetFile;
      if (currentSource is File) {
        targetFile = currentSource;
      } else if (currentSource is String) {
        targetFile = await LocalMediaCache.instance.getCachedFile(currentSource)
                   ?? await LocalMediaCache.instance.downloadAndCache(
                        currentSource,
                        encryptedMediaKey: widget.msg.encryptedMediaKey,
                        senderPublicKey: widget.msg.senderId == widget.repo.uid 
                            ? widget.msg.recipientPublicKey 
                            : widget.msg.senderPublicKey,
                      );
      }

      if (targetFile != null) {
        final isVideo = _isVideoSource(currentSource);
        if (isVideo) {
          await Gal.putVideo(targetFile.path);
        } else {
          await Gal.putImage(targetFile.path);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  void _showReactionPicker() {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text('React to this item', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      widget.repo.addImageReaction(widget.chatId, widget.msg.id, _currentIndex, emoji);
                      Navigator.pop(ctx);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSource = widget.images[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _saveCurrentMedia,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                _initVideoIfNecessary();
              },
              itemBuilder: (context, index) {
                final source = widget.images[index];
                if (_isVideoSource(source)) {
                  if (_currentIndex == index && _videoController != null && _videoController!.value.isInitialized) {
                    return Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_videoController!),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                              child: Icon(
                                _videoController!.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                size: 64,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                      ),
                    );
                  }
                } else {
                  return InteractiveViewer(
                    child: Center(
                      child: source is File
                          ? Image.file(source)
                          : CachedMediaWrapper(
                              url: source as String,
                              encryptedMediaKey: widget.msg.encryptedMediaKey,
                              senderPublicKey: widget.msg.senderId == widget.repo.uid 
                                  ? widget.msg.recipientPublicKey 
                                  : widget.msg.senderPublicKey,
                              builder: (context, file) => Image.file(file),
                              loadingBuilder: (context) => const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                              ),
                            ),
                    ),
                  );
                }
              },
            ),
          ),
          
          StreamBuilder<DocumentSnapshot>(
            stream: AppDatabase.instance
                .table('chats')
                .doc(widget.chatId)
                .table('messages')
                .doc(widget.msg.id)
                .snapshots(),
            builder: (context, snapshot) {
              final Map<String, dynamic> imageReactions = snapshot.hasData && snapshot.data!.exists
                  ? (snapshot.data!.data() as Map<String, dynamic>? ?? {})['imageReactions'] as Map<String, dynamic>? ?? {}
                  : {};

              final Map<String, String> currentReactions = Map<String, String>.from(
                  imageReactions[_currentIndex.toString()] ?? {});

              return Container(
                color: const Color(0xFF16161A),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (currentReactions.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: currentReactions.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Chip(
                                backgroundColor: const Color(0xFF2C2C32),
                                padding: EdgeInsets.zero,
                                label: Text(entry.value, style: const TextStyle(fontSize: 14)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ...['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                            final hasReacted = currentReactions[widget.repo.uid] == emoji;
                            return GestureDetector(
                              onTap: () {
                                widget.repo.addImageReaction(
                                    widget.chatId,
                                    widget.msg.id,
                                    _currentIndex,
                                    hasReacted ? "" : emoji);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: hasReacted ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 22)),
                              ),
                            );
                          }).toList(),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white70),
                            onPressed: _showReactionPicker,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  const VideoPreviewScreen({
    super.key, 
    required this.videoUrl, 
    this.isViewOnce = false,
    this.encryptedMediaKey,
    this.senderPublicKey,
  });

  final String videoUrl;
  final bool isViewOnce;
  final String? encryptedMediaKey;
  final String? senderPublicKey;

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isViewOnce) {
      ScreenProtector.preventScreenshotOn();
    }
    _initController();
  }

  Future<void> _initController() async {
    try {
      final cachedFile = await LocalMediaCache.instance.getCachedFile(widget.videoUrl)
                       ?? await LocalMediaCache.instance.downloadAndCache(
                            widget.videoUrl,
                            encryptedMediaKey: widget.encryptedMediaKey,
                            senderPublicKey: widget.senderPublicKey,
                          );
      controller = VideoPlayerController.file(cachedFile);
    } catch (_) {
      controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    }

    try {
      await controller.initialize();
    } catch (e) {
      debugPrint('Error initializing video controller: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      controller.play();
    }
  }

  @override
  void dispose() {
    if (widget.isViewOnce) {
      ScreenProtector.preventScreenshotOff();
    }
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = !_isLoading && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          if (initialized)
            TextButton(
              onPressed: () {
                double newSpeed = controller.value.playbackSpeed == 1.0
                    ? 1.5
                    : controller.value.playbackSpeed == 1.5
                        ? 2.0
                        : 1.0;
                controller.setPlaybackSpeed(newSpeed);
                setState(() {});
              },
              child: Text(
                '${controller.value.playbackSpeed}x',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          if (!widget.isViewOnce)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final mediaVis = prefs.getBool('media_visibility') ?? true;
                  if (!mediaVis) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot save: Media visibility is disabled in Chat Settings.')),
                      );
                    }
                    return;
                  }
                  final cachedFile = await LocalMediaCache.instance.getCachedFile(widget.videoUrl) 
                                   ?? await LocalMediaCache.instance.downloadAndCache(
                                        widget.videoUrl,
                                        encryptedMediaKey: widget.encryptedMediaKey,
                                        senderPublicKey: widget.senderPublicKey,
                                      );
                  await Gal.putVideo(cachedFile.path);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved to Gallery')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save: $e')));
                  }
                }
              },
            ),
        ],
      ),
      body: Center(
        child: initialized
            ? GestureDetector(
                onTap: () {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                  setState(() {});
                },
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            : const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
              ),
      ),
      floatingActionButton: initialized
          ? FloatingActionButton(
              onPressed: () {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
                setState(() {});
              },
              child: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}

class _MediaOption extends StatelessWidget {
  const _MediaOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  List<Color> _getGradientColors(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;
    return [themeColor, themeColor.withOpacity(0.8)];
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getGradientColors(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.35),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : Colors.white;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({required this.msg, required this.mine, required this.chatId});

  final ChatMessage msg;
  final bool mine;
  final String chatId;

  @override
  Widget build(BuildContext context) {
    if (msg.latitude == null || msg.longitude == null) return const Text('Location unavailable');

    final color = mine ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocationViewerScreen(
              chatId: chatId,
              messageId: msg.id,
              senderId: msg.senderId,
              initialLatitude: msg.latitude!,
              initialLongitude: msg.longitude!,
              isLive: msg.isLive,
            ),
          ),
        );
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.66,
        decoration: BoxDecoration(
          color: mine ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: DecorationImage(
                  image: NetworkImage('https://static-maps.yandex.ru/1.x/?lang=en_US&ll=${msg.longitude},${msg.latitude}&z=14&l=map&size=450,200&pt=${msg.longitude},${msg.latitude},pm2rdl'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Center(
                child: Icon(Icons.location_on, color: mine ? Colors.red : Colors.blue, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(msg.isLive ? Icons.sensors : Icons.location_on, size: 16, color: msg.isLive ? Colors.red : Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        msg.isLive ? 'Live Location' : 'Current Location',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                  if (msg.isLive && msg.liveUntil != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Live until ${DateFormat.jm().format(msg.liveUntil!)}',
                      style: TextStyle(fontSize: 11, color: color.withOpacity(0.6)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Tap to view on map',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditMessageSheet extends StatefulWidget {
  const EditMessageSheet({
    super.key,
    required this.chatId,
    required this.message,
    required this.editMessageFn,
  });

  final String chatId;
  final ChatMessage message;
  final Future<void> Function(String chatId, String messageId, String newText) editMessageFn;

  @override
  State<EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<EditMessageSheet> {
  late final TextEditingController _editController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.message.cipherText);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edit message',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _editController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Update message...',
                filled: true,
                fillColor: const Color(0xFF17171A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _saving
                        ? null
                        : () async {
                            final newText = _editController.text.trim();
                            if (newText.isEmpty) return;

                            setState(() => _saving = true);

                            try {
                              await widget.editMessageFn(
                                widget.chatId,
                                widget.message.id,
                                newText,
                              );

                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              if (mounted) {
                                setState(() => _saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Edit failed: $e')),
                                );
                              }
                            }
                          },
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SelfDestructCountdownWidget extends StatefulWidget {
  final ChatMessage msg;
  final VoidCallback onExpire;

  const SelfDestructCountdownWidget({
    Key? key,
    required this.msg,
    required this.onExpire,
  }) : super(key: key);

  @override
  State<SelfDestructCountdownWidget> createState() => _SelfDestructCountdownWidgetState();
}

class _SelfDestructCountdownWidgetState extends State<SelfDestructCountdownWidget> {
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    final duration = widget.msg.selfDestructDuration ?? 10;
    final elapsed = DateTime.now().difference(widget.msg.createdAt).inSeconds;
    final remaining = duration - elapsed;

    if (remaining <= 0) {
      _timer?.cancel();
      widget.onExpire();
    } else {
      setState(() {
        _remainingSeconds = remaining;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();

    final duration = widget.msg.selfDestructDuration ?? 10;
    final percent = _remainingSeconds / duration;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              value: percent,
              strokeWidth: 2,
              color: Colors.redAccent,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Expires in ${_remainingSeconds}s',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuperReactionAnimation extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const _SuperReactionAnimation({required this.emoji, required this.onComplete});

  @override
  State<_SuperReactionAnimation> createState() => _SuperReactionAnimationState();
}

class _SuperReactionAnimationState extends State<_SuperReactionAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 3.5).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 3.5, end: 4.5).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 4.5, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 20),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: _opacityAnimation.value * 0.4,
              child: Container(color: Colors.black),
            ),
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 60, decoration: TextDecoration.none),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InteractiveGameInvitationCard extends StatelessWidget {
  final String text;
  final String chatId;
  final bool mine;

  const _InteractiveGameInvitationCard({
    required this.text,
    required this.chatId,
    required this.mine,
  });

  static final Map<String, Map<String, dynamic>> _gameCache = {};

  @override
  Widget build(BuildContext context) {
    final parts = text.split('|');
    String gameId = '';
    String creatorName = 'Player';

    for (final part in parts) {
      final kv = part.split(':');
      if (kv.length >= 2) {
        final key = kv[0].trim().toLowerCase();
        final val = kv.sublist(1).join(':').trim();
        if (key.contains('gameid')) {
          gameId = val;
        } else if (key.contains('creator')) {
          creatorName = val;
        }
      }
    }

    if (gameId.isEmpty) {
      return const Card(
        color: Colors.red,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Invalid game invitation configuration.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppDatabase.instance.table('games').doc(gameId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final docData = snapshot.data!.data();
          if (docData != null) {
            _gameCache[gameId] = docData;
          }
        }

        final cached = _gameCache[gameId];
        final data = (snapshot.hasData && snapshot.data?.data() != null)
            ? snapshot.data!.data()!
            : (cached ?? <String, dynamic>{
                'status': 'waiting',
                'playerXName': creatorName,
                'playerOName': 'Player O',
                'playerX': '',
                'playerO': '',
              });

        final status = data['status'] as String? ?? 'waiting';
        final playerXName = data['playerXName'] as String? ?? 'Player X';
        final playerOName = data['playerOName'] as String? ?? 'Player O';
        final winner = data['winner'] as String?;

        String statusText = 'Waiting for opponent...';
        Widget actionButton = const SizedBox.shrink();

        if (status == 'waiting') {
          statusText = 'Challenged by $creatorName';
          if (mine) {
            actionButton = SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameBoardScreen(gameId: gameId, chatId: chatId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.sensor_door_outlined, size: 16),
                label: const Text('Enter Lobby', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            );
          } else {
            actionButton = SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final myUid = AppAuth.instance.currentUser?.uid ?? '';
                  String myName = 'Player O';
                  try {
                    final userDoc = await AppDatabase.instance.table('users').doc(myUid).get();
                    myName = userDoc.data()?['username'] ?? 'Player O';
                  } catch (_) {}

                  await AppDatabase.instance.table('games').doc(gameId).update({
                    'status': 'playing',
                    'playerO': myUid,
                    'playerOName': myName,
                  });

                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => GameBoardScreen(gameId: gameId, chatId: chatId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Accept & Play', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            );
          }
        } else if (status == 'playing') {
          statusText = 'Game in progress...';
          final myUid = AppAuth.instance.currentUser?.uid ?? '';
          if (myUid == data['playerX'] || myUid == data['playerO']) {
            actionButton = SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameBoardScreen(gameId: gameId, chatId: chatId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.gamepad, size: 16),
                label: const Text('Resume Game', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            );
          }
        } else if (status == 'finished') {
          if (winner == 'draw') {
            statusText = 'Draw Match! 🤝';
          } else {
            final winningPlayer = winner == data['playerX'] ? playerXName : playerOName;
            statusText = 'Winner: $winningPlayer 🏆';
          }
        } else if (status == 'aborted') {
          statusText = 'Game Cancelled ❌';
        }

        return Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: mine 
                ? (isDark ? const Color(0xFF1E1C24) : const Color(0xFFF2EEF8))
                : (isDark ? const Color(0xFF141416) : const Color(0xFFF2F2F7)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: mine 
                  ? Colors.purpleAccent.withOpacity(0.3) 
                  : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videogame_asset, color: Colors.purpleAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tic-Tac-Toe Challenge',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Multiplayer Game',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (actionButton is! SizedBox) ...[
                const SizedBox(height: 12),
                actionButton,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VoiceRecordingWaveform extends StatefulWidget {
  const _VoiceRecordingWaveform();

  @override
  State<_VoiceRecordingWaveform> createState() => _VoiceRecordingWaveformState();
}

class _VoiceRecordingWaveformState extends State<_VoiceRecordingWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = List.generate(24, (index) => 4.0);
  final Random _random = Random();
  Timer? _timer;
  Timer? _durationTimer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          for (int i = 0; i < _heights.length; i++) {
            _heights[i] = 4.0 + _random.nextDouble() * 24.0;
          }
        });
      }
    });

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _controller.value,
              child: const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16),
            );
          },
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_seconds),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 32,
            child: CustomPaint(
              painter: _WaveformPainter(
                heights: _heights,
                color: const Color(0xFF00A884).withOpacity(0.85),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.heights,
    required this.color,
  });

  final List<double> heights;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    int barCount = heights.length;
    double totalWidth = size.width;
    double barWidth = 3.5;
    
    double spacing = 0.0;
    if (barCount > 1) {
      spacing = (totalWidth - (barCount * barWidth)) / (barCount - 1);
      if (spacing < 1.0) {
        spacing = 1.5;
        barWidth = (totalWidth - (spacing * (barCount - 1))) / barCount;
        if (barWidth < 1.0) {
          barWidth = 1.0;
        }
      }
    }

    final double centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      double h = heights[i];
      if (h > size.height) h = size.height;

      double left = i * (barWidth + spacing);
      double top = centerY - h / 2;
      double right = left + barWidth;
      double bottom = centerY + h / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return true;
  }
}

class _PlaybackWaveformPainter extends CustomPainter {
  _PlaybackWaveformPainter({
    required this.heights,
    required this.progressFraction,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> heights;
  final double progressFraction;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    int barCount = heights.length;
    double totalWidth = size.width;
    double barWidth = 3.5;

    double spacing = 0.0;
    if (barCount > 1) {
      spacing = (totalWidth - (barCount * barWidth)) / (barCount - 1);
      if (spacing < 1.0) {
        spacing = 1.0;
        barWidth = (totalWidth - (spacing * (barCount - 1))) / barCount;
        if (barWidth < 1.0) {
          barWidth = 1.0;
        }
      }
    }

    final double centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      double h = heights[i];
      if (h > size.height) h = size.height;

      double left = i * (barWidth + spacing);
      double top = centerY - h / 2;
      double right = left + barWidth;
      double bottom = centerY + h / 2;

      double centerX = left + barWidth / 2;
      bool isActive = (centerX / totalWidth) <= progressFraction;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          const Radius.circular(4),
        ),
        isActive ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlaybackWaveformPainter oldDelegate) {
    return oldDelegate.progressFraction != progressFraction ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

class StickersPickerSheet extends ConsumerStatefulWidget {
  final String chatId;
  const StickersPickerSheet({super.key, required this.chatId});

  @override
  ConsumerState<StickersPickerSheet> createState() => _StickersPickerSheetState();
}

class _StickersPickerSheetState extends ConsumerState<StickersPickerSheet> {
  String? _sendingUrl;

  final List<String> _cuppyStickers = [
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/01_Cuppy_smile.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/02_Cuppy_lol.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/03_Cuppy_love.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/04_Cuppy_sad.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/05_Cuppy_cry.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/06_Cuppy_angry.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/07_Cuppy_shocked.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/08_Cuppy_stars.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/09_Cuppy_thumbsup.webp',
    'https://raw.githubusercontent.com/WhatsApp/stickers/main/Android/app/src/main/assets/1/10_Cuppy_wink.webp',
  ];

  final List<String> _fluentStickers = [
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Heart/3D/heart_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Fire/3D/fire_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Sparkles/3D/sparkles_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Alien/3D/alien_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Ghost/3D/ghost_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Unicorn/3D/unicorn_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Rocket/3D/rocket_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Party%20popper/3D/party_popper_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Zany%20face/3D/zany_face_3d.png',
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets/Clapping%20hands/3D/clapping_hands_3d.png',
  ];

  Future<void> _sendStickerUrl(String url) async {
    if (_sendingUrl != null) return;
    setState(() {
      _sendingUrl = url;
    });

    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to download sticker');
      }

      final directory = await getTemporaryDirectory();
      final ext = url.endsWith('.webp') ? '.webp' : '.png';
      final file = File('${directory.path}/sticker_${DateTime.now().millisecondsSinceEpoch}$ext');
      await file.writeAsBytes(response.bodyBytes);

      await ref.read(chatRepositoryProvider).sendMedia(
        chatId: widget.chatId,
        file: file,
        type: MessageType.sticker,
        caption: "",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sticker sent!'), backgroundColor: Colors.purpleAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send sticker: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingUrl = null;
        });
      }
    }
  }

  Future<void> _pickAndCreateCustomSticker() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    setState(() {
      _sendingUrl = "custom_sticker"; // Show loading indicator overlay
    });

    try {
      final bytes = await xFile.readAsBytes();
      
      // Decode the image
      final original = img.decodeImage(bytes);
      if (original == null) throw Exception('Failed to decode image');

      // Calculate target dimensions keeping aspect ratio (max 512x512)
      int targetWidth = 512;
      int targetHeight = 512;
      if (original.width > original.height) {
        targetHeight = (original.height * 512 / original.width).round();
      } else {
        targetWidth = (original.width * 512 / original.height).round();
      }
      
      final scaled = img.copyResize(original, width: targetWidth, height: targetHeight);
      final finalBytes = img.encodePng(scaled);

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/custom_sticker_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(finalBytes);

      await ref.read(chatRepositoryProvider).sendMedia(
        chatId: widget.chatId,
        file: file,
        type: MessageType.sticker,
        caption: "",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom Sticker sent!'), backgroundColor: Colors.purpleAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create sticker: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingUrl = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: const BoxDecoration(
        color: Color(0xFF131316),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3D),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            const TabBar(
              indicatorColor: Colors.purpleAccent,
              labelColor: Colors.purpleAccent,
              unselectedLabelColor: Colors.white54,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(icon: Icon(Icons.star), text: 'AI'),
                Tab(text: 'Cuppy'),
                Tab(text: 'Fluent'),
                Tab(text: 'Custom'),
              ],
            ),
            const Divider(height: 1, color: Color(0xFF2A2A2D)),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAIStickerTab(),
                  _buildStickerGrid(_cuppyStickers),
                  _buildStickerGrid(_fluentStickers),
                  _buildCustomStickerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerGrid(List<String> urls) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: urls.length,
      itemBuilder: (context, index) {
        final url = urls[index];
        final isSending = _sendingUrl == url;

        return GestureDetector(
          onTap: () => _sendStickerUrl(url),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.broken_image_outlined, color: Colors.white24);
                  },
                ),
              ),
              if (isSending)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomStickerTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library, size: 40, color: Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          const Text(
            'Custom Stickers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn any image from your gallery into a sticker instantly!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close the picker sheet
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StickerCreatorScreen(chatId: widget.chatId),
                ),
              );
            },
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Create Sticker (Video/Image)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIStickerTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 48),
          const SizedBox(height: 16),
          const Text(
            'AI Sticker Generator',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create unique, custom stickers instantly using artificial intelligence.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AIStickerCreatorSheet(chatId: widget.chatId),
                );
              },
              child: const Text('Launch Creator', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Create Poll', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Options', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            ...List.generate(_optionControllers.length, (index) {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[index],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Option ${index + 1}',
                        labelStyle: const TextStyle(color: Colors.white30),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                      ),
                    ),
                  ),
                  if (_optionControllers.length > 2)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
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
                label: const Text('Add Option', style: TextStyle(color: Colors.blueAccent)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () {
            final question = _questionController.text.trim();
            final options = _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
            if (question.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Question is required')));
              return;
            }
            if (options.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least 2 options are required')));
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
    
    // Calculate total votes
    int totalVotes = 0;
    final Map<int, List<String>> optionVoters = {};
    for (int i = 0; i < options.length; i++) {
      final voters = List<String>.from(pollVotes[i.toString()] ?? []);
      optionVoters[i] = voters;
      totalVotes += voters.length;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(options.length, (index) {
            final voters = optionVoters[index] ?? [];
            final count = voters.length;
            final isSelected = voters.contains(currentUid);
            final ratio = totalVotes > 0 ? (count / totalVotes) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onVote(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Progress bar fill
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
                      // Option container border & padding
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                              color: isSelected ? Colors.blueAccent : Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                options[index],
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              count == 1 ? '1 vote' : '$count votes',
                              style: TextStyle(
                                color: isSelected ? Colors.blueAccent : Colors.white54,
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
                totalVotes == 1 ? '1 total vote' : '$totalVotes total votes',
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
