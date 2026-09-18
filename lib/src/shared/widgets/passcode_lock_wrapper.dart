import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:a_chatz/src/shared/widgets/passcode_lock_screen.dart';
import 'package:a_chatz/src/features/calls/presentation/active_call_manager.dart';

class PasscodeLockWrapper extends StatefulWidget {
  final Widget child;
  const PasscodeLockWrapper({super.key, required this.child});

  @override
  State<PasscodeLockWrapper> createState() => _PasscodeLockWrapperState();
}

class _PasscodeLockWrapperState extends State<PasscodeLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStartup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLockOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('app_lock_enabled') ?? false;
    final hasPasscode = prefs.getString('app_passcode') != null;

    if (enabled && hasPasscode && AppAuth.instance.currentUser != null) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLockStatus(forceLock: true);
    }
  }

  Future<void> _checkLockStatus({bool forceLock = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('app_lock_enabled') ?? false;
    final hasPasscode = prefs.getString('app_passcode') != null;

    if (enabled && hasPasscode && AppAuth.instance.currentUser != null) {
      // Do not lock the app if there is an active call, to prevent interrupting screen shares and calls
      if (ActiveCallManager.instance.activeCallId != null) {
        return;
      }
      
      if (forceLock) {
        setState(() {
          _isLocked = true;
        });
      }
    } else {
      setState(() {
        _isLocked = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_isLocked && AppAuth.instance.currentUser != null)
            Positioned.fill(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData.dark(),
                home: PasscodeLockScreen(
                  isSetupMode: false,
                  onUnlockSuccess: () {
                    setState(() {
                      _isLocked = false;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
