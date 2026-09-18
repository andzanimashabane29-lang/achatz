import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class InAppCameraCaptureScreen extends StatefulWidget {
  const InAppCameraCaptureScreen({
    super.key,
    required this.isVideoMode,
  });

  final bool isVideoMode;

  @override
  State<InAppCameraCaptureScreen> createState() => _InAppCameraCaptureScreenState();
}

class _InAppCameraCaptureScreenState extends State<InAppCameraCaptureScreen> {
  late bool _isVideo;
  File? _capturedFile;
  VideoPlayerController? _videoController;
  
  bool _isViewOnce = false;
  final _captionController = TextEditingController();
  bool _isPlaying = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isVideo = widget.isVideoMode;
    // Launch the camera capture automatically on open to preserve natural camera feel!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureMedia();
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _captureMedia() async {
    setState(() {
      _loading = true;
    });

    try {
      final picker = ImagePicker();
      if (_isVideo) {
        final XFile? video = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );
        if (video != null) {
          _capturedFile = File(video.path);
          _videoController = VideoPlayerController.file(_capturedFile!)
            ..initialize().then((_) {
              setState(() {
                _videoController!.setLooping(true);
                _videoController!.play();
                _isPlaying = true;
              });
            });
        } else {
          // User backed out
          if (mounted) Navigator.pop(context);
          return;
        }
      } else {
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (image != null) {
          _capturedFile = File(image.path);
        } else {
          // User backed out
          if (mounted) Navigator.pop(context);
          return;
        }
      }
    } catch (e) {
      debugPrint("Camera capture error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _togglePlayVideo() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  void _sendMedia() {
    if (_capturedFile == null) return;
    
    // Return captured media data to chat screen
    Navigator.pop(context, {
      'file': _capturedFile,
      'isVideo': _isVideo,
      'isViewOnce': _isViewOnce,
      'caption': _captionController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isVideo ? "Video Studio" : "Photo Studio",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_capturedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _videoController?.dispose();
                _videoController = null;
                setState(() {
                  _capturedFile = null;
                });
                _captureMedia();
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Viewport or Media Preview
          Center(
            child: _loading
                ? const CircularProgressIndicator(color: Colors.redAccent)
                : (_capturedFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_off, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text("No media captured yet", style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _captureMedia,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            child: const Text("Launch Camera"),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.65,
                          ),
                          child: _isVideo
                              ? (_videoController != null && _videoController!.value.isInitialized
                                  ? GestureDetector(
                                      onTap: _togglePlayVideo,
                                      child: AspectRatio(
                                        aspectRatio: _videoController!.value.aspectRatio,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            VideoPlayer(_videoController!),
                                            if (!_isPlaying)
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                                              ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : const CircularProgressIndicator(color: Colors.redAccent))
                              : Image.file(_capturedFile!),
                        ),
                      )),
          ),

          // Glowing Studio controls
          if (_capturedFile != null && !_loading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caption and View-Once Row
                    Row(
                      children: [
                        // View Once (1) Privacy Toggle Button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isViewOnce = !_isViewOnce;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _isViewOnce ? const Color(0xFF00A884) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isViewOnce ? Colors.transparent : Colors.white70,
                                width: 2,
                              ),
                              boxShadow: _isViewOnce
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00A884).withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: const Center(
                              child: Text(
                                "1",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Caption Field
                        Expanded(
                          child: TextField(
                            controller: _captionController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: _isViewOnce ? "View-once caption..." : "Add a caption...",
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white10,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Send button
                    Align(
                      alignment: Alignment.centerRight,
                      child: FloatingActionButton(
                        onPressed: _sendMedia,
                        backgroundColor: Colors.redAccent,
                        child: const Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
