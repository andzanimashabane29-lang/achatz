import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AdvancedMediaPreview extends StatefulWidget {
  const AdvancedMediaPreview({
    super.key,
    required this.file,
    required this.isVideo,
    required this.onSend,
  });

  final File file;
  final bool isVideo;
  final Function(String caption, String? musicId) onSend;

  @override
  State<AdvancedMediaPreview> createState() => _AdvancedMediaPreviewState();
}

class _AdvancedMediaPreviewState extends State<AdvancedMediaPreview> {
  final captionController = TextEditingController();
  VideoPlayerController? _videoController;
  String? selectedMusic;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          setState(() {});
          _videoController?.play();
          _videoController?.setLooping(true);
        });
    }
  }

  @override
  void dispose() {
    captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note, color: Colors.white),
            onPressed: () {
              // Simple music selector mock
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1C1C1E),
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Add Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.music_note),
                      title: const Text('Midnight Jazz'),
                      onTap: () {
                        setState(() => selectedMusic = 'Midnight Jazz');
                        Navigator.pop(ctx);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.music_note),
                      title: const Text('Summer Vibes'),
                      onTap: () {
                        setState(() => selectedMusic = 'Summer Vibes');
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_fields, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.crop, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: widget.isVideo
                ? (_videoController?.value.isInitialized ?? false
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : const CircularProgressIndicator())
                : Image.file(widget.file),
          ),
          if (selectedMusic != null)
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(selectedMusic!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: TextField(
                          controller: captionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add a caption...',
                            hintStyle: TextStyle(color: Colors.white60),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => widget.onSend(captionController.text, selectedMusic),
                      child: const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.send_rounded, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
