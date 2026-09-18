import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/features/calls/data/live_repository.dart';
import 'package:a_chatz/src/features/chat/providers/contacts_provider.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class GoLiveSetupScreen extends ConsumerStatefulWidget {
  const GoLiveSetupScreen({super.key});

  @override
  ConsumerState<GoLiveSetupScreen> createState() => _GoLiveSetupScreenState();
}

class _GoLiveSetupScreenState extends ConsumerState<GoLiveSetupScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _cameraInitialized = false;
  bool _isLoading = false;
  final _titleController = TextEditingController();
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      setState(() => _cameraInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isGranted) {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          await _selectCamera(_cameras[_cameraIndex]);
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize camera in setup: $e');
    }
  }

  Future<void> _selectCamera(CameraDescription camera) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _controller = controller;

    controller.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _cameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Failed to select camera in setup: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _cameraInitialized = false;
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    await _selectCamera(_cameras[_cameraIndex]);
  }

  Future<void> _startLiveStream() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for your live stream'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final liveRepo = ref.read(liveRepositoryProvider);

      final myUid = authRepo.uid!;
      final userDoc = await AppDatabase.instance.table('users').doc(myUid).get();
      final myName = userDoc.data()?['username'] ?? 'User';
      final myPhotoUrl = userDoc.data()?['photoUrl'] as String?;

      final contactsAsync = ref.read(myContactsProvider);
      final contacts = contactsAsync.value ?? [];
      final friendUids = contacts.map((c) => c.uid).toList();

      final sessionId = await liveRepo.createLiveSession(
        title: title,
        hostName: myName,
        hostPhotoUrl: myPhotoUrl,
        friendUids: friendUids,
      );

      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      if (mounted) {
        context.pushReplacement('/live/host/$sessionId');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start live: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return LuxuryScaffold(
      appBar: AppBar(
        title: const Text('Go Live Setup', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _cameraInitialized && _controller != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.previewSize?.height ?? size.width,
                      height: _controller!.value.previewSize?.width ?? size.height,
                      child: CameraPreview(_controller!),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F0F12), Color(0xFF1F1023), Color(0xFF00121A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FFB2).withOpacity(0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.2), width: 1.5),
                            ),
                            child: const Icon(
                              Icons.sensors,
                              color: Color(0xFF00FFB2),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Live Stream Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Starting in mock mode (Camera inactive)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_cameras.length > 1)
                      Align(
                        alignment: Alignment.topRight,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                            onPressed: _toggleCamera,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'STREAM DETAILS',
                            style: TextStyle(
                              color: Color(0xFF00FFB2),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _titleController,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Enter stream title... (e.g. cooking session! 🍳)',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 15),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            maxLength: 60,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFB2),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 8,
                        shadowColor: const Color(0xFF00FFB2).withOpacity(0.45),
                      ),
                      onPressed: _isLoading ? null : _startLiveStream,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.videocam, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'GO LIVE NOW',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
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
