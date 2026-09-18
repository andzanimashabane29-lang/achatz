import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

class ProfilePictureViewerScreen extends StatefulWidget {
  const ProfilePictureViewerScreen({
    super.key,
    required this.photoUrl,
    required this.username,
    required this.heroTag,
    this.isAsset = false,
  });

  final String? photoUrl;
  final String username;
  final String heroTag;
  final bool isAsset;

  @override
  State<ProfilePictureViewerScreen> createState() => _ProfilePictureViewerScreenState();
}

class _ProfilePictureViewerScreenState extends State<ProfilePictureViewerScreen> {
  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(widget.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: widget.heroTag,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF151515),
                      image: widget.photoUrl != null
                          ? (widget.isAsset
                              ? DecorationImage(
                                  image: AssetImage(widget.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : DecorationImage(
                                  image: NetworkImage(widget.photoUrl!),
                                  fit: BoxFit.cover,
                                ))
                          : null,
                    ),
                    child: widget.photoUrl == null
                        ? const Icon(Icons.person, color: Colors.white24, size: 180)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.shield, color: Colors.greenAccent, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Privacy protected',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
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
