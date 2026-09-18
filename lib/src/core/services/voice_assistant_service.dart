import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';

import 'package:a_chatz/src/core/services/gemini_service.dart';
import 'package:a_chatz/src/features/chat/data/chat_repository.dart';
import 'package:a_chatz/src/features/calls/data/call_repository.dart';
import 'package:a_chatz/src/features/chat/domain/contact_model.dart';
import 'package:a_chatz/src/core/router/app_router.dart';

class VoiceAssistantService {
  static final VoiceAssistantService instance = VoiceAssistantService._();
  VoiceAssistantService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;
  bool _isListening = false;
  bool _isOverlayOpen = false;

  stt.SpeechToText get speech => _speech;

  VoidCallback? onSpeechStatusNotListening;
  void Function(String)? onSpeechError;

  void initialize() async {
    if (_initialized) return;
    try {
      // Register global desktop hotkey handler (Ctrl + Space)
      HardwareKeyboard.instance.addHandler((event) {
        if (event is KeyDownEvent) {
          final isControlPressed = HardwareKeyboard.instance.isControlPressed;
          if (isControlPressed && event.logicalKey == LogicalKeyboardKey.space) {
            _triggerAssistant();
            return true;
          }
        }
        return false;
      });

      // Check if we are running on mobile before initializing speech recognition
      final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android;
      if (!isMobile) {
        _initialized = true; // Mark as initialized to allow overlay fallback triggers
        return;
      }

      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'notListening') {
            if (onSpeechStatusNotListening != null) {
              onSpeechStatusNotListening!();
            } else if (_isListening && !_isOverlayOpen) {
              // Pause 1.5 seconds to let the OS fully reset the microphone resource
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (_isListening && !_isOverlayOpen) {
                  _startWakeWordListening();
                }
              });
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech error: $errorNotification');
          if (onSpeechError != null) {
            onSpeechError!(errorNotification.errorMsg);
          } else if (_isListening && !_isOverlayOpen) {
            // Delay 4 seconds on error to prevent fast loops
            Future.delayed(const Duration(seconds: 4), () {
              if (_isListening && !_isOverlayOpen) {
                _startWakeWordListening();
              }
            });
          }
        },
      );
      if (available) {
        _initialized = true;
        _startWakeWordListening();
      }
    } catch (e) {
      debugPrint('Voice assistant initialization failed: $e');
    }
  }

  void start() {
    _isListening = true;
    if (_initialized) {
      _startWakeWordListening();
    } else {
      initialize();
    }
  }

  void stop() {
    _isListening = false;
    _speech.stop();
  }

  // Exposed method to trigger the assistant manually or via UI keyboard shortcut on Desktop
  void triggerManual() {
    _triggerAssistant();
  }

  void _startWakeWordListening() async {
    if (!_isListening || _isOverlayOpen) return;
    final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    if (!isMobile) return;

    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase();
          debugPrint('Heard for wake word: $text');
          
          // Use RegExp with word boundaries to match "hey hello ai chat" or "hello ai chat"
          final regex = RegExp(r'\b(hey\s+hello\s+ai\s+chat|hello\s+ai\s+chat)\b', caseSensitive: false);
          if (regex.hasMatch(text)) {
            _triggerAssistant();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 10),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('Error in wake word listen loop: $e');
    }
  }

  void _triggerAssistant() async {
    _isListening = false; // Temporarily stop wake word listening state to release mic cleanly
    await _speech.stop();
    _playChime();
    // Wait a brief delay for the speech-to-text mic resource to fully release
    await Future.delayed(const Duration(milliseconds: 250));
    _showAssistantOverlay();
  }

  Future<void> _playChime() async {
    try {
      await _audioPlayer.play(AssetSource('chime.wav'));
    } catch (e) {
      debugPrint('Error playing chime: $e');
    }
  }

  void _showAssistantOverlay() {
    final context = rootNavigatorKey.currentContext;
    if (context == null || _isOverlayOpen) return;

    _isOverlayOpen = true;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Assistant',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _AssistantOverlayWidget(
          onCommandFinished: () {
            _isOverlayOpen = false;
            _isListening = true;
            _startWakeWordListening();
          },
        );
      },
    ).then((_) {
      _isOverlayOpen = false;
      _isListening = true;
      _startWakeWordListening();
    });
  }
}

class _AssistantOverlayWidget extends StatefulWidget {
  final VoidCallback onCommandFinished;

  const _AssistantOverlayWidget({
    required this.onCommandFinished,
  });

  @override
  State<_AssistantOverlayWidget> createState() => _AssistantOverlayWidgetState();
}

class _AssistantOverlayWidgetState extends State<_AssistantOverlayWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  String _statusText = 'Listening...';
  String _recognizedText = '';
  bool _speechInitialized = false;
  bool _processing = false;
  String _assistantName = 'there';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Register callbacks
    VoiceAssistantService.instance.onSpeechStatusNotListening = _onSpeechFinished;
    VoiceAssistantService.instance.onSpeechError = _onSpeechError;

    _loadGreetingName();
    _startCommandListening();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    VoiceAssistantService.instance.onSpeechStatusNotListening = null;
    VoiceAssistantService.instance.onSpeechError = null;
    _textController.dispose();
    super.dispose();
  }

  void _onSpeechFinished() {
    if (!mounted) return;
    if (_recognizedText.trim().isEmpty) {
      setState(() {
        _statusText = "I didn't catch that.";
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } else if (!_processing) {
      _processVoiceCommand();
    }
  }

  void _onSpeechError(String errorMsg) {
    if (mounted) {
      setState(() {
        _statusText = 'Speech Error: $errorMsg';
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _loadGreetingName() async {
    final myUid = AppAuth.instance.currentUser?.uid;
    if (myUid != null) {
      final doc = await AppDatabase.instance.table('users').doc(myUid).get();
      if (doc.exists && mounted) {
        setState(() {
          _assistantName = doc.data()?['username'] ?? 'User';
        });
      }
    }
  }

  void _startCommandListening() async {
    final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    if (!isMobile) {
      if (mounted) {
        setState(() {
          _speechInitialized = false;
          _statusText = 'Type your command below, $_assistantName:';
        });
      }
      return;
    }

    try {
      final speech = VoiceAssistantService.instance.speech;
      if (speech.isAvailable && mounted) {
        setState(() {
          _speechInitialized = true;
          _statusText = 'Hey $_assistantName, I\'m listening...';
        });
        await speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _recognizedText = result.recognizedWords;
              });
            }
          },
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 4),
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
          ),
        );
      } else {
        if (mounted) {
          setState(() {
            _speechInitialized = false;
            _statusText = 'Type your command below, $_assistantName:';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _speechInitialized = false;
          _statusText = 'Type your command below, $_assistantName:';
        });
      }
    }
  }

  void _processVoiceCommand() async {
    if (_recognizedText.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _statusText = 'I didn\'t catch that.';
        });
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    setState(() {
      _processing = true;
      _statusText = 'Analyzing command...';
    });

    final systemPrompt = '''
You are the voice command interpreter for the A-Chatz app.
The user will give you a transcribed voice command.
You must parse this command and return ONLY a JSON block containing the structural action. Do not add any formatting other than the JSON itself. Do not use Markdown block syntax (no ```json).

The JSON format must be:
{
  "action": "text" | "call" | "unknown",
  "contactName": "name of contact to message or call" | null,
  "message": "message content if text action" | null
}

Examples:
1. Command: "Text Anzani say hello to Anzani"
Response: {"action": "text", "contactName": "Anzani", "message": "hello to Anzani"}
2. Command: "call John"
Response: {"action": "call", "contactName": "John", "message": null}
3. Command: "how is the weather?"
Response: {"action": "unknown", "contactName": null, "message": null}
''';

    try {
      final responseText = await GeminiService.instance.generateText(
        '$systemPrompt\n\nCommand: "$_recognizedText"'
      );

      String cleanJson = responseText.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }

      final parsed = jsonDecode(cleanJson.trim());
      final action = parsed['action'] as String? ?? 'unknown';
      final contactName = parsed['contactName'] as String?;
      final message = parsed['message'] as String?;

      if (action == 'text' && contactName != null && message != null) {
        await _executeTextCommand(contactName, message);
      } else if (action == 'call' && contactName != null) {
        await _executeCallCommand(contactName);
      } else {
        _failWith('Could not understand voice command.');
      }
    } catch (e) {
      _failWith('Failed to process command: $e');
    }
  }

  Future<Map<String, dynamic>?> _findUserInDirectory(String searchName) async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final contactsQuery = await AppDatabase.instance
        .table('users')
        .doc(uid)
        .table('contacts')
        .get();

    for (final doc in contactsQuery.docs) {
      final name = doc.data()['displayName'] as String? ?? '';
      if (name.toLowerCase().contains(searchName.toLowerCase())) {
        return {'uid': doc.id, 'displayName': name};
      }
    }

    final usersQuery = await AppDatabase.instance
        .table('users')
        .get();

    for (final doc in usersQuery.docs) {
      final username = doc.data()['username'] as String?;
      if (username != null && username.toLowerCase().contains(searchName.toLowerCase())) {
        return {'uid': doc.id, 'displayName': username};
      }
    }

    return null;
  }

  Future<void> _executeTextCommand(String contactName, String message) async {
    if (mounted) {
      setState(() {
        _statusText = 'Looking up $contactName...';
      });
    }

    final target = await _findUserInDirectory(contactName);
    if (target == null) {
      _failWith('Could not find contact "$contactName"');
      return;
    }

    final targetUid = target['uid']!;
    final targetName = target['displayName']!;

    if (mounted) {
      setState(() {
        _statusText = 'Sending to $targetName...';
      });
    }

    try {
      final chatRepo = ChatRepository(AppDatabase.instance, AppAuth.instance);
      final chatId = await chatRepo.createPrivateChat(targetUid);
      await chatRepo.sendText(chatId, message);
      
      _successWith('Sent: "$message" to $targetName');
    } catch (e) {
      _failWith('Error sending message: $e');
    }
  }

  Future<void> _executeCallCommand(String contactName) async {
    if (mounted) {
      setState(() {
        _statusText = 'Looking up $contactName...';
      });
    }

    final target = await _findUserInDirectory(contactName);
    if (target == null) {
      _failWith('Could not find contact "$contactName"');
      return;
    }

    final targetUid = target['uid']!;
    final targetName = target['displayName']!;

    if (mounted) {
      setState(() {
        _statusText = 'Starting call with $targetName...';
      });
    }

    try {
      final chatRepo = ChatRepository(AppDatabase.instance, AppAuth.instance);
      final chatId = await chatRepo.createPrivateChat(targetUid);

      final callRepo = CallRepository(AppDatabase.instance, AppAuth.instance);
      final callId = await callRepo.startCall(
        chatId: chatId,
        receiverIds: [targetUid],
        isVideo: false,
        chatName: targetName,
      );

      final nameParam = Uri.encodeComponent(targetName);
      if (mounted) {
        Navigator.pop(context);
        rootNavigatorKey.currentContext?.push('/call-room/$callId?caller=true&video=false&name=$nameParam');
      }
    } catch (e) {
      _failWith('Error starting call: $e');
    }
  }

  void _successWith(String text) {
    if (mounted) {
      setState(() {
        _statusText = text;
      });
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _failWith(String text) {
    if (mounted) {
      setState(() {
        _statusText = text;
      });
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 32,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnim.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00FFB2).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF00FFB2), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFB2).withOpacity(0.35),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Color(0xFF00FFB2),
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (!_speechInitialized && !_processing) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. Text Anzani say Hello',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF00FFB2)),
                      onPressed: () {
                        if (_textController.text.trim().isNotEmpty) {
                          setState(() {
                            _recognizedText = _textController.text;
                          });
                          _processVoiceCommand();
                        }
                      },
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      setState(() {
                        _recognizedText = val;
                      });
                      _processVoiceCommand();
                    }
                  },
                ),
              ],
              if (_recognizedText.isNotEmpty && _speechInitialized) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _recognizedText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
