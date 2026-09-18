import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:a_chatz/src/core/services/ai_tools_service.dart';
import 'package:a_chatz/src/features/chat/data/chat_repository.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';

class AIStickerCreatorSheet extends ConsumerStatefulWidget {
  final String chatId;

  const AIStickerCreatorSheet({super.key, required this.chatId});

  @override
  ConsumerState<AIStickerCreatorSheet> createState() => _AIStickerCreatorSheetState();
}

class _AIStickerCreatorSheetState extends ConsumerState<AIStickerCreatorSheet> {
  final TextEditingController _promptController = TextEditingController();
  bool _loading = false;
  String? _stickerUrl;
  String? _error;

  Future<void> _generateSticker() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _stickerUrl = null;
    });

    try {
      final url = await AIToolsService.instance.generateSticker(prompt);
      if (url != null) {
        setState(() {
          _stickerUrl = url;
        });
      } else {
        setState(() {
          _error = "Failed to generate sticker. Ensure your OpenAI key is configured.";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _sendSticker() async {
    if (_stickerUrl == null) return;

    setState(() {
      _loading = true;
    });

    try {
      // 1. Download sticker to temp file
      final response = await http.get(Uri.parse(_stickerUrl!));
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/sticker_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(response.bodyBytes);

      // 2. Send media via ChatRepository
      await ref.read(chatRepositoryProvider).sendMedia(
            chatId: widget.chatId,
            file: file,
            type: MessageType.sticker,
            caption: "",
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sticker sent!'), backgroundColor: Colors.purpleAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to send: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131316),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Sticker Generator',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Sticker Preview Frame
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: _stickerUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(_stickerUrl!, fit: BoxFit.contain),
                    )
                  : _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face_retouching_natural, color: Colors.white24, size: 40),
                            SizedBox(height: 8),
                            Text('Preview', style: TextStyle(color: Colors.white24, fontSize: 12)),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 20),

          // Prompt Input
          TextField(
            controller: _promptController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Sticker description...',
              labelStyle: const TextStyle(color: Colors.grey),
              hintText: 'e.g., A funny screaming potato',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF1E1E22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                    foregroundColor: Colors.purpleAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _generateSticker,
                  child: const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (_stickerUrl != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _loading ? null : _sendSticker,
                    child: const Text('Send Sticker', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
