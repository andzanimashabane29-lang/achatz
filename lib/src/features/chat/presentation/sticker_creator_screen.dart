import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:a_chatz/src/features/chat/data/chat_repository.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';

class StickerCreatorScreen extends ConsumerStatefulWidget {
  final String chatId;

  const StickerCreatorScreen({super.key, required this.chatId});

  @override
  ConsumerState<StickerCreatorScreen> createState() => _StickerCreatorScreenState();
}

class _StickerCreatorScreenState extends ConsumerState<StickerCreatorScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  bool _isVideo = false;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  
  // Sticker editing
  final List<StickerElement> _elements = [];
  final TextEditingController _textController = TextEditingController();
  int _selectedElementIndex = -1;
  
  bool _processing = false;

  @override
  void dispose() {
    _videoController?.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedFile = File(image.path);
        _isVideo = false;
        _elements.clear();
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedFile = File(video.path);
        _isVideo = true;
        _elements.clear();
      });
      _initVideoController();
    }
  }

  Future<void> _initVideoController() async {
    if (_selectedFile == null || !_isVideo) return;
    
    _videoController = VideoPlayerController.file(_selectedFile!);
    await _videoController!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  void _addText() {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      _elements.add(StickerElement(
        type: ElementType.text,
        text: _textController.text,
        position: const Offset(100, 100),
        color: Colors.white,
        fontSize: 24,
      ));
      _textController.clear();
    });
  }

  void _addEmoji(String emoji) {
    setState(() {
      _elements.add(StickerElement(
        type: ElementType.emoji,
        text: emoji,
        position: const Offset(150, 150),
        fontSize: 48,
      ));
    });
  }

  void _deleteSelectedElement() {
    if (_selectedElementIndex >= 0 && _selectedElementIndex < _elements.length) {
      setState(() {
        _elements.removeAt(_selectedElementIndex);
        _selectedElementIndex = -1;
      });
    }
  }

  Future<void> _createAndSendSticker() async {
    if (_selectedFile == null) return;

    setState(() => _processing = true);

    try {
      File stickerFile;
      
      if (_isVideo) {
        // Extract frame from video
        stickerFile = await _extractFrameFromVideo();
      } else {
        stickerFile = await _processImageWithElements(_selectedFile!);
      }

      // Send as sticker
      await ref.read(chatRepositoryProvider).sendMedia(
        chatId: widget.chatId,
        file: stickerFile,
        type: MessageType.sticker,
        caption: "",
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sticker sent!'), backgroundColor: Colors.greenAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<File> _extractFrameFromVideo() async {
    if (_selectedFile == null) throw Exception('Video not initialized');
    // Video frame extraction is not natively supported by VideoPlayerController,
    // so we return the raw video file as fallback.
    return _selectedFile!;
  }

  Future<File> _processImageWithElements(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) throw Exception('Failed to decode image');
    
    // Draw text and emoji elements
    for (final element in _elements) {
      if (element.type == ElementType.text) {
        final color = element.color ?? Colors.white;
        img.drawString(
          image,
          element.text,
          font: img.arial24,
          x: element.position.dx.toInt(),
          y: element.position.dy.toInt(),
          color: img.ColorRgb8(color.red, color.green, color.blue),
        );
      }
    }
    
    final outputBytes = img.encodePng(image);
    
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/sticker_${DateTime.now().millisecondsSinceEpoch}.png';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(outputBytes);
    
    return outputFile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Create Sticker', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedElementIndex >= 0)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteSelectedElement,
            ),
        ],
      ),
      body: Column(
        children: [
          // Media preview area
          Expanded(
            child: _selectedFile == null
                ? _buildPlaceholder()
                : _buildMediaPreview(),
          ),
          
          // Editing tools
          if (_selectedFile != null) _buildEditingTools(),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_photo_alternate, color: Colors.white54, size: 80),
          const SizedBox(height: 16),
          const Text(
            'Create a Sticker',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose an image or video to start',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.videocam),
                label: const Text('Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Stack(
      children: [
        Center(
          child: _isVideo && _videoController != null
              ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
              : Image.file(_selectedFile!),
        ),
        
        // Overlay elements
        ..._elements.asMap().entries.map((entry) {
          final index = entry.key;
          final element = entry.value;
          return Positioned(
            left: element.position.dx,
            top: element.position.dy,
            child: GestureDetector(
              onPanStart: (_) {
                setState(() => _selectedElementIndex = index);
              },
              onPanUpdate: (details) {
                setState(() {
                  _elements[index] = element.copyWith(
                    position: element.position + details.delta,
                  );
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: _selectedElementIndex == index
                      ? Border.all(color: Colors.greenAccent, width: 2)
                      : null,
                ),
                child: Text(
                  element.text,
                  style: TextStyle(
                    fontSize: element.fontSize.toDouble(),
                    color: element.color ?? Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
        
        // Video controls
        if (_isVideo && _videoController != null)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                      _isPlaying = !_isPlaying;
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEditingTools() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E22),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Text input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Add text...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF2C2C30),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.greenAccent),
                onPressed: _addText,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Emoji picker (simplified)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildEmojiButton('😀'),
                _buildEmojiButton('😂'),
                _buildEmojiButton('❤️'),
                _buildEmojiButton('🔥'),
                _buildEmojiButton('👍'),
                _buildEmojiButton('🎉'),
                _buildEmojiButton('💯'),
                _buildEmojiButton('✨'),
                _buildEmojiButton('😍'),
                _buildEmojiButton('🤔'),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Send button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _processing ? null : _createAndSendSticker,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _processing
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Send Sticker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () => _addEmoji(emoji),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}

enum ElementType { text, emoji }

class StickerElement {
  final ElementType type;
  final String text;
  final Offset position;
  final Color? color;
  final int fontSize;

  StickerElement({
    required this.type,
    required this.text,
    required this.position,
    this.color,
    required this.fontSize,
  });

  StickerElement copyWith({
    ElementType? type,
    String? text,
    Offset? position,
    Color? color,
    int? fontSize,
  }) {
    return StickerElement(
      type: type ?? this.type,
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}
