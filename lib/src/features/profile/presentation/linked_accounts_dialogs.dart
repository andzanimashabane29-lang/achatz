import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:a_chatz/src/core/services/linked_accounts_manager.dart';
import 'package:a_chatz/src/shared/widgets/qr_account_scanner_screen.dart';

class ShowPairingQrDialog extends StatefulWidget {
  const ShowPairingQrDialog({super.key});

  @override
  State<ShowPairingQrDialog> createState() => _ShowPairingQrDialogState();
}

class _ShowPairingQrDialogState extends State<ShowPairingQrDialog> {
  String? _qrData;
  String? _pairingCode;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generatePayload();
  }

  @override
  void dispose() {
    if (_pairingCode != null) {
      AppDatabase.instance.table('pairing_codes').doc(_pairingCode).delete().catchError((_) {});
    }
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = math.Random();
    final part1 = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    final part2 = String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    return '$part1-$part2';
  }

  Future<void> _generatePayload() async {
    try {
      const storage = FlutterSecureStorage();
      final email = AppAuth.instance.currentUser?.email;
      final password = await storage.read(key: 'bio_password');
      final uid = AppAuth.instance.currentUser?.uid;

      if (email == null || password == null || uid == null) {
        setState(() {
          _errorMessage = "Please enable biometric/saved login first to link accounts securely.";
          _loading = false;
        });
        return;
      }

      final userDoc = await AppDatabase.instance.table('users').doc(uid).get();
      final data = userDoc.data() ?? {};
      final username = data['username'] ?? 'User';
      final photoUrl = data['photoUrl'];

      final payload = {
        'action': 'link_account',
        'email': email,
        'password': password,
        'uid': uid,
        'username': username,
        'photoUrl': photoUrl,
      };

      final code = _generateCode();
      await AppDatabase.instance.table('pairing_codes').doc(code).set({
        ...payload,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _qrData = jsonEncode(payload);
        _pairingCode = code;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error generating pairing code: $e";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101012),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              "My Pairing QR Code",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Scan this QR code from another device or account slot to link this profile.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
              )
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)
            else if (_qrData != null)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("Or enter this pairing code:", style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      _pairingCode ?? '',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.white60, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class UnifiedQrScannerDialog extends StatefulWidget {
  const UnifiedQrScannerDialog({super.key, required this.onSuccess});
  
  final VoidCallback onSuccess;

  @override
  State<UnifiedQrScannerDialog> createState() => _UnifiedQrScannerDialogState();
}

class _UnifiedQrScannerDialogState extends State<UnifiedQrScannerDialog> with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  final _passwordController = TextEditingController();
  final _textCodeController = TextEditingController();
  
  bool _scanning = false;
  bool _scanComplete = false;
  bool _loading = false;
  String? _error;
  bool _needPassword = false;
  String? _scannedSessionId;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    _passwordController.dispose();
    _textCodeController.dispose();
    super.dispose();
  }

  Future<void> _linkWithTextCode() async {
    final code = _textCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final doc = await AppDatabase.instance.table('pairing_codes').doc(code).get();
      if (!doc.exists) {
        throw Exception("Invalid or expired pairing code.");
      }

      final data = doc.data()!;
      // Immediately delete for security
      await AppDatabase.instance.table('pairing_codes').doc(code).delete().catchError((_) {});

      // Verify expiration (5 minutes)
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt != null) {
        if (DateTime.now().difference(createdAt.toDate()).inMinutes > 5) {
          throw Exception("This pairing code has expired.");
        }
      }

      // Convert data to JSON string so _processPayload can parse it exactly like a QR code
      final jsonStr = jsonEncode(data);
      
      if (mounted) {
        setState(() {
          _scanComplete = true; // Show success UI briefly before popping
        });
      }

      await _processPayload(jsonStr);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll("Exception: ", "");
          _loading = false;
        });
      }
    }
  }

  Future<void> _triggerCameraScan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _scanComplete = false;
    });

    try {
      final raw = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const QrAccountScannerScreen()),
      );

      if (!mounted) return;
      if (raw == null || raw.isEmpty) {
        setState(() => _scanning = false);
        return;
      }

      setState(() {
        _scanning = false;
        _scanComplete = true;
      });

      await _processPayload(raw);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
        _scanning = false;
        _scanComplete = false;
      });
    }
  }

  Future<void> _processPayload(String jsonStr) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final decoded = QrScanPayload.tryParse(jsonStr);
      if (decoded == null || decoded['action'] == null) {
        throw Exception("Invalid pairing QR data format.");
      }

      if (decoded['action'] == 'link_account') {
        if (decoded['email'] == null ||
            decoded['password'] == null ||
            decoded['uid'] == null ||
            decoded['username'] == null) {
          throw Exception("Invalid account linking QR data.");
        }

        final success = await LinkedAccountsManager.addAccount(
          email: decoded['email'],
          password: decoded['password'],
          uid: decoded['uid'],
          username: decoded['username'],
          photoUrl: decoded['photoUrl'],
        );

        if (!success) {
          throw Exception("Linked accounts limit reached (max 6 accounts).");
        }

        if (mounted) {
          widget.onSuccess();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Successfully linked account: ${decoded['username']}"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (decoded['action'] == 'web_login') {
        final sessionId = decoded['sessionId'] as String?;
        if (sessionId == null || sessionId.isEmpty) {
          throw Exception('QR code is missing a session id.');
        }

        _scannedSessionId = sessionId;
        await _authenticateWebLink(sessionId);
      } else {
        throw Exception("Unsupported QR code action.");
      }
    } catch (e) {
      setState(() {
        _error = "Error: ${e.toString().replaceAll("Exception: ", "")}";
        _loading = false;
        _scanComplete = false;
      });
    }
  }

  Future<void> _authenticateWebLink(String sessionId) async {
    try {
      final callable = AppFunctions.instance.httpsCallable('approveQrLogin');
      await callable.call({'sessionId': sessionId});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Web client paired and logged in successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
        _loading = false;
        _needPassword = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101012),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Scan QR Code",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _needPassword 
                  ? "Enter your password to secure and authorize web login."
                  : "Scan a Web Login or Profile Pairing QR Code.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            
            if (!_needPassword) ...[
              // Holographic Viewfinder Mockup
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12, width: 2),
                ),
                child: Stack(
                  children: [
                    // Corner Viewfinder Brackets
                    Positioned(
                      top: 16, left: 16,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.redAccent, width: 3), left: BorderSide(color: Colors.redAccent, width: 3)))),
                    ),
                    Positioned(
                      top: 16, right: 16,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.redAccent, width: 3), right: BorderSide(color: Colors.redAccent, width: 3)))),
                    ),
                    Positioned(
                      bottom: 16, left: 16,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.redAccent, width: 3), left: BorderSide(color: Colors.redAccent, width: 3)))),
                    ),
                    Positioned(
                      bottom: 16, right: 16,
                      child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.redAccent, width: 3), right: BorderSide(color: Colors.redAccent, width: 3)))),
                    ),
                    
                    // Scanning Animation laser
                    if (_scanning)
                      Center(
                        child: AnimatedBuilder(
                          animation: _laserController,
                          builder: (context, child) {
                            return Stack(
                              children: [
                                Positioned(
                                  top: 30 + (140 * _laserController.value),
                                  left: 30,
                                  right: 30,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.redAccent.withOpacity(0.8),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      
                    // Live Scanning state text overlay
                    Center(
                      child: _scanning 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)),
                                SizedBox(height: 12),
                                Text("CAMERA ACTIVE", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              ],
                            )
                          : (_scanComplete
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 36),
                                    SizedBox(height: 8),
                                    Text("SCANNED", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                  ],
                                  )
                              : const Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 48)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text("Or Link with Code", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _textCodeController,
                style: const TextStyle(color: Colors.redAccent, fontSize: 18, letterSpacing: 2.0, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E1E22),
                  hintText: 'Enter 8-digit Code (e.g. A4B9-XYZ2)',
                  hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 0, fontWeight: FontWeight.normal, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (_loading || _scanning) ? null : _linkWithTextCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Link with Code", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E1E22),
                  hintText: 'Your Account Password...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
            
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
            ],
            
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_loading || _scanning)
                      ? null 
                      : (_needPassword 
                          ? () => _authenticateWebLink(_scannedSessionId!)
                          : _triggerCameraScan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_needPassword ? "Authorize" : "Scan QR", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
