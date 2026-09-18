import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:a_chatz/src/features/calls/presentation/call_effects_panel.dart';

class BuiltInCameraScreen extends StatefulWidget {
  final bool initialIsVideo;
  const BuiltInCameraScreen({super.key, this.initialIsVideo = false});

  @override
  State<BuiltInCameraScreen> createState() => _BuiltInCameraScreenState();
}

class _BuiltInCameraScreenState extends State<BuiltInCameraScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isReady = false;
  bool _isRecording = false;
  bool _isVideoMode = false;
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  CallEffectsState _effectsState = CallEffectsState();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isVideoMode = widget.initialIsVideo;
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(cameraController.description);
    }
  }

  Future<void> _initCamera() async {
    try {
      // Request camera and microphone permissions first
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isGranted) {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          // Default to front-facing camera if available for selfie/status preview
          int initialIndex = 0;
          for (int i = 0; i < _cameras.length; i++) {
            if (_cameras[i].lensDirection == CameraLensDirection.front) {
              initialIndex = i;
              break;
            }
          }
          _cameraIndex = initialIndex;
          await _onNewCameraSelected(_cameras[_cameraIndex]);
        } else {
          _showError('No cameras found on this device');
        }
      } else {
        _showError('Camera permission is required to use this feature');
      }
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max, // Maximum quality available (iPhone quality or better)
      enableAudio: _isVideoMode,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = cameraController;

    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(_flashMode);
      // Lock orientation to portrait up so that the camera angle is correct and never rotated/skewed
      try {
        await cameraController.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (e) {
        debugPrint('Could not lock orientation: $e');
      }
      
      if (_isVideoMode) {
        await cameraController.setZoomLevel(1.0);
      }
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _isReady = false;
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    await _onNewCameraSelected(_cameras[_cameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.off;
        break;
      default:
        nextMode = FlashMode.off;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (e) {
      _showError('Error setting flash: $e');
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isVideoMode) {
      if (_isRecording) {
        // Stop recording
        try {
          final file = await _controller!.stopVideoRecording();
          setState(() {
            _isRecording = false;
          });
          if (mounted) {
            Navigator.pop(context, file.path);
          }
        } catch (e) {
          _showError('Failed to stop recording: $e');
        }
      } else {
        // Start recording
        try {
          await _controller!.startVideoRecording();
          setState(() {
            _isRecording = true;
          });
        } catch (e) {
          _showError('Failed to start recording: $e');
        }
      }
    } else {
      // Capture Photo
      try {
        final file = await _controller!.takePicture();
        if (mounted) {
          Navigator.pop(context, file.path);
        }
      } catch (e) {
        _showError('Failed to take photo: $e');
      }
    }
  }

  void _showEffectsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return CallEffectsPanel(
              state: _effectsState,
              onStateChanged: (newState) {
                setSheetState(() {});
                if (mounted) {
                  setState(() {
                    _effectsState = newState;
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Opening Camera...',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview - properly scaled to fill screen with premium live filters & borders
          Positioned.fill(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize?.height ?? size.width,
                  height: _controller!.value.previewSize?.width ?? size.height,
                  child: CallEffectsWrapper(
                    state: _effectsState,
                    showBackground: false,
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
            ),
          ),

          // Built-in Camera HUD overlay with elegant borders
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white24,
                  width: 4,
                ),
              ),
            ),
          ),

          // Top controls
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: Icon(
                    _flashMode == FlashMode.always
                        ? Icons.flash_on
                        : _flashMode == FlashMode.auto
                            ? Icons.flash_auto
                            : Icons.flash_off,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // Bottom Controls HUD
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live filter quick strip
                Container(
                  height: 52,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: kCallFilters.length + 1,
                    itemBuilder: (context, index) {
                      final isNone = index == 0;
                      final filterIndex = index - 1;
                      final isSelected = isNone 
                          ? _effectsState.filterIndex == -1 
                          : _effectsState.filterIndex == filterIndex;
                      
                      final name = isNone ? 'Normal' : kCallFilters[filterIndex].name;
                      final icon = isNone ? '🚫' : kCallFilters[filterIndex].icon;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _effectsState = _effectsState.copyWith(
                              filterIndex: isNone ? -1 : filterIndex,
                            );
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.redAccent.withOpacity(0.85) 
                                : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white12,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(icon, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Mode Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isRecording
                          ? null
                          : () {
                              setState(() {
                                _isVideoMode = false;
                              });
                              _onNewCameraSelected(_cameras[_cameraIndex]);
                            },
                      child: Text(
                        'PHOTO',
                        style: TextStyle(
                          color: !_isVideoMode ? Colors.redAccent : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    TextButton(
                      onPressed: _isRecording
                          ? null
                          : () {
                              setState(() {
                                _isVideoMode = true;
                              });
                              _onNewCameraSelected(_cameras[_cameraIndex]);
                            },
                      child: Text(
                        'VIDEO',
                        style: TextStyle(
                          color: _isVideoMode ? Colors.redAccent : Colors.white60,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Capture Actions row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Flip Camera
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                      onPressed: _isRecording ? null : _toggleCamera,
                    ),

                    // Shutter Button
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        height: 84,
                        width: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: _isRecording ? 36 : 68,
                            width: _isRecording ? 36 : 68,
                            decoration: BoxDecoration(
                              shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: _isRecording ? BorderRadius.circular(8) : null,
                              color: _isVideoMode ? Colors.redAccent : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Premium effects panel trigger
                    IconButton(
                      icon: Icon(
                        Icons.auto_awesome,
                        color: _effectsState.hasAnyEffect ? Colors.redAccent : Colors.white,
                        size: 28,
                      ),
                      onPressed: _showEffectsPanel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
