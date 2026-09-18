import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PasscodeLockScreen extends StatefulWidget {
  final bool isSetupMode; // true if setting up passcode, false if unlocking
  final ValueChanged<String>? onPasscodeSet; // callback when setup completes
  final VoidCallback? onUnlockSuccess; // callback when unlocked successfully

  const PasscodeLockScreen({
    super.key,
    this.isSetupMode = false,
    this.onPasscodeSet,
    this.onUnlockSuccess,
  });

  @override
  State<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends State<PasscodeLockScreen> {
  String _input = '';
  String _setupFirstInput = '';
  String _message = 'Enter your 4-digit passcode';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    if (widget.isSetupMode) {
      _message = 'Choose a 4-digit passcode';
    }
  }

  void _onKeyPress(String key) {
    if (_input.length >= 4) return;

    setState(() {
      _input += key;
      _isError = false;
    });

    if (_input.length == 4) {
      // Small delay to let the user see the 4th digit selection
      Timer(const Duration(milliseconds: 150), _processPasscode);
    }
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _isError = false;
    });
  }

  Future<void> _processPasscode() async {
    if (widget.isSetupMode) {
      if (_setupFirstInput.isEmpty) {
        // First step of setup completed
        setState(() {
          _setupFirstInput = _input;
          _input = '';
          _message = 'Confirm your passcode';
        });
      } else {
        // Confirm step
        if (_input == _setupFirstInput) {
          widget.onPasscodeSet?.call(_input);
        } else {
          setState(() {
            _input = '';
            _setupFirstInput = '';
            _message = 'Passcodes did not match. Start over.';
            _isError = true;
          });
        }
      }
    } else {
      // Unlock mode
      final uid = AppAuth.instance.currentUser?.uid;
      if (uid == null) {
        widget.onUnlockSuccess?.call();
        return;
      }

      final doc = await AppDatabase.instance.table('users').doc(uid).get();
      final savedPasscode = doc.data()?['appPasscode'] as String?;

      if (savedPasscode == null || _input == savedPasscode) {
        widget.onUnlockSuccess?.call();
      } else {
        setState(() {
          _input = '';
          _message = 'Incorrect passcode';
          _isError = true;
        });
      }
    }
  }

  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Reset App Lock?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'If you forgot your passcode, you will need to sign out and log back in to your account.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AppAuth.instance.signOut();
      // Navigate to onboarding / login
      context.go('/onboarding');
      widget.onUnlockSuccess?.call(); // dismiss overlay
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Title & App Icon
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'A-Chatz Security',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _message,
              style: TextStyle(
                color: _isError ? Colors.redAccent : Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // Passcode dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final active = index < _input.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.redAccent : Colors.transparent,
                    border: Border.all(
                      color: active ? Colors.redAccent : Colors.white30,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const Spacer(),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  for (var row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: row.map((key) => _buildKeypadButton(key)).toList(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left utility button: Reset or cancel
                        widget.isSetupMode
                            ? _buildUtilityButton(
                                icon: Icons.close,
                                onTap: () => Navigator.pop(context),
                              )
                            : _buildUtilityButton(
                                text: 'Reset',
                                onTap: _handleReset,
                              ),
                        _buildKeypadButton('0'),
                        _buildUtilityButton(
                          icon: Icons.backspace_outlined,
                          onTap: _onBackspace,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return GestureDetector(
      onTap: () => _onKeyPress(digit),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUtilityButton({
    String? text,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        color: Colors.transparent,
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white70, size: 24)
              : Text(
                  text ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
