import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:zxing2/qrcode.dart' hide BarcodeFormat;

import 'package:a_chatz/src/core/platform/platform_layout.dart';

/// Opens the device camera and returns decoded QR text (JSON payload).
class QrAccountScannerScreen extends StatefulWidget {
  const QrAccountScannerScreen({super.key});

  @override
  State<QrAccountScannerScreen> createState() => _QrAccountScannerScreenState();
}

class _QrAccountScannerScreenState extends State<QrAccountScannerScreen> {
  CameraController? _cameraController;
  ms.MobileScannerController? _mobileController;
  bool _handled = false;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    if (isWindowsApp) {
      await _initWindowsCamera();
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      _mobileController = ms.MobileScannerController(
        detectionSpeed: ms.DetectionSpeed.normal,
        facing: ms.CameraFacing.back,
        formats: const [ms.BarcodeFormat.qrCode],
      );
      if (mounted) {
        setState(() => _initializing = false);
      }
    } else {
      setState(() {
        _initializing = false;
        _error = 'QR camera scan is available on phone and Windows desktop.';
      });
    }
  }

  Future<void> _initWindowsCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera found on this device.');
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _initializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = e.toString();
        });
      }
    }
  }

  void _finishWithCode(String raw) {
    if (_handled || !mounted) return;
    _handled = true;
    Navigator.pop(context, raw.trim());
  }

  void _onBarcode(ms.BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _finishWithCode(raw);
        return;
      }
    }
  }

  Future<void> _windowsCaptureAndDecode() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() => _error = null);
    try {
      final file = await controller.takePicture();
      final bytes = await File(file.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Could not read camera image.');
      }

      final source = RGBLuminanceSource(
        decoded.width,
        decoded.height,
        Int32List.fromList(_rgbaToLuminance(decoded)),
      );
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final result = QRCodeReader().decode(bitmap);
      _finishWithCode(result.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No QR detected. Center the code and try again.';
        });
      }
    }
  }

  List<int> _rgbaToLuminance(img.Image image) {
    final out = List<int>.filled(image.width * image.height, 0);
    var i = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final b = p.b.toInt();
        out[i++] = ((r + g + g + b) >> 2) & 0xFF;
      }
    }
    return out;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _mobileController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan QR code'),
        actions: [
          if (isWindowsApp && _cameraController != null)
            TextButton(
              onPressed: _windowsCaptureAndDecode,
              child: const Text(
                'Scan',
                style: TextStyle(color: Color(0xFF00FFB2), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00FFB2)),
      );
    }

    if (_error != null && _mobileController == null && _cameraController == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_mobileController != null)
          ms.MobileScanner(
            controller: _mobileController!,
            onDetect: _onBarcode,
          )
        else if (_cameraController != null && _cameraController!.value.isInitialized)
          CameraPreview(_cameraController!),
        _ScannerOverlay(error: _error),
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Column(
            children: [
              const Text(
                'Align the account QR code inside the frame',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (isWindowsApp) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _windowsCaptureAndDecode,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFB2),
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          if (error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          Expanded(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00FFB2), width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses scanned QR JSON for account / web login actions.
class QrScanPayload {
  static Map<String, dynamic>? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
