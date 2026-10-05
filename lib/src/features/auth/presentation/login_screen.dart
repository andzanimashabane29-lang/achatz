import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:a_chatz/src/core/services/linked_accounts_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:a_chatz/src/shared/utils/business_utils.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final username = TextEditingController();
  final phoneNumber = TextEditingController();
  bool loading = false;
  bool isRegistering = false;
  String accountType = 'personal'; // 'personal' or 'business'

  bool _usePairingCodeLogin = false;
  String? _pairingRequestId;
  final _pairingCode = TextEditingController();

  bool get _isWebOrDesktop => kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux;
  late bool _useQrLogin = _isWebOrDesktop;
  String? _qrSessionId;
  StreamSubscription? _qrSessionSub;

  final _localAuth = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage();
  bool _canCheckBiometrics = false;
  bool _hasBiometricsSaved = false;

  void _startQrSession() async {
    _qrSessionSub?.cancel();
    final newSessionId = AppDatabase.instance.table('qr_logins').doc().id;
    setState(() {
      _qrSessionId = newSessionId;
    });

    await AppDatabase.instance.table('qr_logins').doc(newSessionId).set({
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    _qrSessionSub = AppDatabase.instance
        .table('qr_logins')
        .doc(newSessionId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      if (data['status'] == 'authenticated') {
        _qrSessionSub?.cancel();
        
        final customToken = data['customToken'] as String?;
        if (customToken == null) {
          _startQrSession();
          return;
        }

        setState(() {
          loading = true;
        });

        try {
          await AppAuth.instance.signInWithCustomToken(customToken);
          final uid = AppAuth.instance.currentUser?.uid;

          if (uid != null) {
            // Register web device session
            try {
              final deviceId = await _secureStorage.read(key: 'device_id') ?? AppDatabase.instance.table('users').doc().id;
              await _secureStorage.write(key: 'device_id', value: deviceId);
              
              await AppDatabase.instance
                  .table('users')
                  .doc(uid)
                  .table('devices')
                  .doc(deviceId)
                  .set({
                'deviceName': 'Web Client',
                'lastActive': FieldValue.serverTimestamp(),
                'platform': 'web',
                'sessionId': newSessionId,
              }, SetOptions(merge: true));
            } catch (_) {}
          }

          if (mounted) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context, true);
            } else {
              context.go('/home');
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              loading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('QR Login failed: ${getCleanErrorMessage(e)}')),
            );
            _startQrSession();
          }
        }
      }
    });
  }

  void _stopQrSession() {
    _qrSessionSub?.cancel();
    if (_qrSessionId != null) {
      AppDatabase.instance.table('qr_logins').doc(_qrSessionId).delete().catchError((_) {});
    }
  }

  Future<void> _requestPairingCode() async {
    final identifier = email.text.trim();
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email or phone number.')));
      return;
    }

    setState(() => loading = true);
    try {
      final callable = AppFunctions.instance.httpsCallable('requestDeviceLinking');
      final result = await callable.call({'identifier': identifier});
      setState(() {
        _pairingRequestId = result.data['requestId'];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to request code: ${getCleanErrorMessage(e)}')));
    }
  }

  Future<void> _verifyPairingCode() async {
    final code = _pairingCode.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter the 6-digit code.')));
      return;
    }

    setState(() => loading = true);
    try {
      final callable = AppFunctions.instance.httpsCallable('verifyDeviceLinking');
      final result = await callable.call({
        'requestId': _pairingRequestId,
        'code': code,
      });

      if (result.data['success'] == true) {
        final customToken = result.data['customToken'];
        await AppAuth.instance.signInWithCustomToken(customToken);
        if (mounted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          } else {
            context.go('/home');
          }
        }
      }
    } catch (e) {
      _pairingCode.clear();
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().contains('Incorrect code') ? 'Incorrect code. A new code has been generated and sent to your phone.' : 'Failed to verify code: ${getCleanErrorMessage(e)}'),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    _initBiometrics();
    if (_useQrLogin) {
      _startQrSession();
    }
  }

  Future<void> _initBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final hasSavedEmail = await _secureStorage.containsKey(key: 'bio_email');
      final hasSavedPass = await _secureStorage.containsKey(key: 'bio_password');
      
      setState(() {
        _canCheckBiometrics = canCheck;
        _hasBiometricsSaved = hasSavedEmail && hasSavedPass;
      });

      // If biometrics are active and credentials exist, auto-trigger biometric unlock
      if (canCheck && hasSavedEmail && hasSavedPass) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _authenticateWithBiometrics();
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate with fingerprint to access A-Chatz',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final savedEmail = await _secureStorage.read(key: 'bio_email');
        final savedPass = await _secureStorage.read(key: 'bio_password');

        if (savedEmail != null && savedPass != null) {
          setState(() {
            email.text = savedEmail;
            password.text = savedPass;
            loading = true;
          });
          
          await submit();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometric auth failed: $e')),
        );
      }
    }
  }

  Future<void> _signInWithDrixelId() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      final launched = await ref
          .read(authRepositoryProvider)
          .signInWithDrixelId();
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Drixel ID sign-in.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Drixel ID sign-in failed: ${getCleanErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    setState(() => loading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      String targetEmail = email.text.trim();

      if (isRegistering) {
        await authRepo.registerWithEmail(
          email: targetEmail,
          password: password.text.trim(),
          username: username.text.trim().isEmpty ? 'User' : username.text.trim(),
        );

        if (authRepo.uid != null) {
          await AppDatabase.instance
              .table('users')
              .doc(authRepo.uid)
              .update({
            'accountType': accountType,
            'phoneNumber': phoneNumber.text.trim(),
          });
        }
      } else {
        if (!targetEmail.contains('@')) {
          final querySnap = await AppDatabase.instance
              .table('users')
              .where('phoneNumber', isEqualTo: targetEmail)
              .limit(1)
              .get();

          if (querySnap.docs.isEmpty) {
            throw Exception('No account found with this phone number.');
          }
          targetEmail = querySnap.docs.first.data()['email'] as String;
        }

        await authRepo.signInWithEmail(
          targetEmail,
          password.text.trim(),
        );
      }

      await _secureStorage.write(key: 'bio_email', value: email.text.trim());
      await _secureStorage.write(key: 'bio_password', value: password.text.trim());

      if (authRepo.uid != null) {
        await AppDatabase.instance
            .table('users')
            .doc(authRepo.uid)
            .set({
          'accountType': accountType,
          'email': targetEmail,
          'updatedAt': FieldValue.serverTimestamp(),
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (authRepo.uid != null) {
        final userDoc = await AppDatabase.instance.table('users').doc(authRepo.uid).get();
        final userData = userDoc.data() ?? {};
        await LinkedAccountsManager.addAccount(
          email: targetEmail,
          password: password.text.trim(),
          uid: authRepo.uid!,
          username: userData['username'] ?? 'A-Chatz User',
          photoUrl: userData['photoUrl'],
        );

        // Register device session
        try {
          String deviceName = 'Unknown Device';
          if (kIsWeb) {
            deviceName = 'Web Client';
          } else {
            if (defaultTargetPlatform == TargetPlatform.android) {
              deviceName = 'Android Device';
            } else if (defaultTargetPlatform == TargetPlatform.iOS) {
              deviceName = 'iOS Device';
            } else if (defaultTargetPlatform == TargetPlatform.macOS) {
              deviceName = 'Mac Device';
            } else if (defaultTargetPlatform == TargetPlatform.windows) {
              deviceName = 'Windows Device';
            } else {
              deviceName = 'Mobile Device';
            }
          }
          
          final deviceId = await _secureStorage.read(key: 'device_id') ?? AppDatabase.instance.table('users').doc().id;
          await _secureStorage.write(key: 'device_id', value: deviceId);

          await AppDatabase.instance
              .table('users')
              .doc(authRepo.uid)
              .table('devices')
              .doc(deviceId)
              .set({
            'deviceName': deviceName,
            'lastActive': FieldValue.serverTimestamp(),
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = getCleanErrorMessage(e);
        if (e is AppAuthException && e.code == 'email-not-verified') {
          msg = e.message ?? msg;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'Resend',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    final tempCred = await AppAuth.instance.signInWithEmailAndPassword(
                      email: email.text.trim(),
                      password: password.text.trim(),
                    );
                    await tempCred.user?.sendEmailVerification();
                    await AppAuth.instance.signOut();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification email resent! Please check your inbox.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (resendError) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error resending email: $resendError'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      }
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    _stopQrSession();
    email.dispose();
    password.dispose();
    username.dispose();
    phoneNumber.dispose();
    _pairingCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isWebOrDesktop) return _buildWebDesktopLayout();
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              borderRadius: BorderRadius.circular(34),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('A-Chatz',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  _useQrLogin
                      ? 'Link with QR Code'
                      : (isRegistering ? 'Create your account' : 'Sign in to continue'),
                  style: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Web/Desktop QR Code Tabs
                if (_isWebOrDesktop) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _useQrLogin = false;
                            _stopQrSession();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_useQrLogin ? Colors.white : const Color(0xFF1A1A1A),
                          foregroundColor: !_useQrLogin ? Colors.black : Colors.white54,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.email_outlined, size: 16),
                        label: const Text('Email Login', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _useQrLogin = true;
                            isRegistering = false;
                          });
                          _startQrSession();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _useQrLogin ? Colors.redAccent : const Color(0xFF1A1A1A),
                          foregroundColor: _useQrLogin ? Colors.white : Colors.white54,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.qr_code_2, size: 16),
                        label: const Text('QR Login', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                if (_useQrLogin) ...[
                  if (_qrSessionId == null)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: QrImageView(
                        data: '{"action":"web_login","sessionId":"$_qrSessionId"}',
                        version: QrVersions.auto,
                        size: 180.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Scan this QR code from your phone\'s Profile Settings (Link Web Client) to log in instantly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '{"action":"web_login","sessionId":"$_qrSessionId"}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pairing payload copied to clipboard!')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                      label: const Text('Copy Pairing Payload', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ] else ...[
                  // Account Type Selector
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Account Type', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => accountType = 'personal'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: accountType == 'personal' ? Colors.white : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: accountType == 'personal' ? Colors.white : Colors.white.withOpacity(0.1),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.person_outline, color: accountType == 'personal' ? Colors.black : Colors.white54, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  'Personal',
                                  style: TextStyle(
                                    color: accountType == 'personal' ? Colors.black : Colors.white54,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => accountType = 'business'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: accountType == 'business' ? Colors.redAccent : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: accountType == 'business' ? Colors.redAccent : Colors.white.withOpacity(0.1),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.business_center_outlined, color: accountType == 'business' ? Colors.white : Colors.white54, size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  'Business',
                                  style: TextStyle(
                                    color: accountType == 'business' ? Colors.white : Colors.white54,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (isRegistering) ...[
                    TextField(
                      controller: username,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isRegistering ? 'Email' : 'Email or Phone Number',
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isRegistering) ...[
                    TextField(
                      controller: phoneNumber,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: password,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 58,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: accountType == 'business' ? Colors.redAccent : Colors.white,
                              foregroundColor: accountType == 'business' ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            onPressed: loading ? null : submit,
                            child: loading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accountType == 'business' ? Colors.white : Colors.black,
                                    ),
                                  )
                                : Text(
                                    isRegistering ? 'Create Account' : 'Sign In',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                          ),
                        ),
                      ),
                      if (!isRegistering && _canCheckBiometrics && _hasBiometricsSaved) ...[
                        const SizedBox(width: 12),
                        Container(
                          height: 58,
                          width: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: IconButton(
                            onPressed: _authenticateWithBiometrics,
                            icon: const Icon(Icons.fingerprint, color: Colors.greenAccent, size: 28),
                            tooltip: 'Biometric Login',
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!_isWebOrDesktop && !isRegistering) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : _signInWithDrixelId,
                        icon: const Icon(Icons.account_circle_outlined, size: 19),
                        label: const Text('Continue with Drixel ID'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (!_isWebOrDesktop) ...[
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => setState(() => isRegistering = !isRegistering),
                      child: Text(
                        isRegistering ? 'Already have an account? Login' : "Don't have an account? Register",
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep dark background
      body: Stack(
        children: [
          // Dark premium header strip
          Container(
            height: 220,
            width: double.infinity,
            color: const Color(0xFF1A1A1A),
          ),
          
          Positioned(
            top: 32,
            left: 32,
            child: Row(
              children: [
                Image.asset('assets/logo_transparent.png', height: 36, width: 36),
                const SizedBox(width: 12),
                const Text(
                  'A-Chatz Web',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
              child: SizedBox(
                width: 900,
                child: Column(
                  children: [
                    // Top Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS 
                                  ? Icons.apple 
                                  : (defaultTargetPlatform == TargetPlatform.android ? Icons.android : Icons.desktop_windows_outlined), 
                              size: 28, 
                              color: Colors.white
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  defaultTargetPlatform == TargetPlatform.iOS 
                                      ? 'Install A-Chatz on iPad/iPhone'
                                      : defaultTargetPlatform == TargetPlatform.android 
                                          ? 'Install A-Chatz on Android'
                                          : 'Download A-Chatz for ${defaultTargetPlatform == TargetPlatform.macOS ? 'Mac' : 'Windows'}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android
                                      ? 'Tap the Share menu and select "Add to Home Screen" to install the app natively.'
                                      : 'Get extra features like voice and video calling, screen sharing and more.',
                                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          FilledButton(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text('Download', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                SizedBox(width: 8),
                                Icon(Icons.download, size: 18),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Main Login Card
                    Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12, width: 0.5),
                      ),
                      child: _usePairingCodeLogin
                          ? _buildWebPairingCodeView()
                          : (_useQrLogin ? _buildWebQrView() : _buildWebEmailForm()),
                    ),
                    
                    const SizedBox(height: 48),
                    // Bottom links
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an A-Chatz account? ", style: TextStyle(color: Colors.white54, fontSize: 15)),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _useQrLogin = false;
                              isRegistering = true;
                            });
                          },
                          child: const Text('Get started ↗', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lock_outline, size: 14, color: Colors.white54),
                        SizedBox(width: 6),
                        Text('Your personal messages are end-to-end encrypted', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
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

  Widget _buildWebPairingCodeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Link with Pairing Code',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: Colors.white),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _usePairingCodeLogin = false;
                  _useQrLogin = true;
                  _startQrSession();
                });
              },
              child: const Text('Scan QR Code instead >', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                if (_pairingRequestId == null) ...[
                  const Text('Enter your account phone number or email to receive a code on your phone.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Email or Phone Number',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.account_circle_outlined, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: loading ? null : _requestPairingCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ] else ...[
                  const Text('Enter the 6-digit code shown on your phone.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pairingCode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: loading ? null : _verifyPairingCode,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Verify Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _pairingRequestId = null;
                        _pairingCode.clear();
                      });
                    },
                    child: const Text('Use a different account', style: TextStyle(color: Colors.white54)),
                  )
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebQrView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Side: Instructions
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan to log in',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: Colors.white),
              ),
              const SizedBox(height: 40),
              _buildInstructionStep('1', 'Scan the QR code with your phone\'s camera'),
              const SizedBox(height: 20),
              _buildInstructionStep('2', 'Tap the link to open A-Chatz'),
              const SizedBox(height: 20),
              _buildInstructionStep('3', 'Scan the QR code again to link to your account'),
              const SizedBox(height: 40),
              InkWell(
                onTap: () {},
                child: const Text('Need help? ↗', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500, fontSize: 14)),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: true, 
                          onChanged: (v) {},
                          activeColor: Colors.blueAccent,
                          checkColor: Colors.white,
                          side: const BorderSide(color: Colors.white54, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Stay logged in on this browser', style: TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(width: 8),
                      const Icon(Icons.info_outline, size: 16, color: Colors.white54),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _useQrLogin = false;
                        _usePairingCodeLogin = true;
                        isRegistering = false;
                        _stopQrSession();
                      });
                    },
                    child: const Text('Link with phone number >', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500, fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 60),
        // Right Side: QR Code
        if (_qrSessionId == null)
          const SizedBox(
            width: 264,
            height: 264,
            child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          )
        else
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: '{"action":"web_login","sessionId":"$_qrSessionId"}',
                      version: QrVersions.auto,
                      size: 264.0,
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset('assets/logo_transparent.png', height: 32, width: 32),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '{"action":"web_login","sessionId":"$_qrSessionId"}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pairing payload copied!')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  foregroundColor: Colors.white70,
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Pairing Payload'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54, width: 1.5),
          ),
          child: Center(
            child: Text(number, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildWebEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isRegistering ? 'Create your account' : 'Log in with Email/Phone',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: Colors.white),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _useQrLogin = true;
                  _startQrSession();
                });
              },
              child: const Text('Scan QR Code instead >', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500, fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                if (isRegistering) ...[
                  TextField(
                    controller: username,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Username',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: isRegistering ? 'Email' : 'Email or Phone Number',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                if (isRegistering) ...[
                  TextField(
                    controller: phoneNumber,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Phone Number',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: password,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isRegistering ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (kIsWeb && !isRegistering) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _signInWithDrixelId,
                      icon: const Icon(Icons.account_circle_outlined, size: 19),
                      label: const Text('Continue with Drixel ID'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
