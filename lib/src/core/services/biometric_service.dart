import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> authenticate(String reason) async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!isAvailable || !isDeviceSupported) {
        return true; // Fallback to allowing access if no biometrics are available on device
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return authenticated;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
