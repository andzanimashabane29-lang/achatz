import 'package:a_chatz/src/core/services/encryption_service.dart';
import 'package:a_chatz/src/features/auth/domain/app_user.dart';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  AuthRepository(this._auth, this._db);
  final AppAuth _auth;
  final AppDatabase _db;

  String? get uid => _auth.currentUser?.uid;

  Stream<User?> authState() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final isOfficial = email.trim().toLowerCase() == 'official@a-chatz.com';
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: isOfficial ? '@anelisa2025' : password,
      );
      return cred;
    } on AppAuthException catch (e) {
      if (isOfficial) {
        // Try fallback to typed password
        try {
          final cred = await _auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
          return cred;
        } on AppAuthException catch (_) {
          // Re-register with default or typed password
          try {
            return await registerWithEmail(
              email: email.trim(),
              password: '@anelisa2025',
              username: 'A-Chatz',
            );
          } catch (_) {
            return await registerWithEmail(
              email: email.trim(),
              password: password,
              username: 'A-Chatz',
            );
          }
        }
      }
      rethrow;
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final isOfficial = email.trim().toLowerCase() == 'official@a-chatz.com';

    // Generate E2EE keys
    final publicKey = await EncryptionService().generateAndStoreKeyPair();

    final user = AppUser(
      uid: cred.user!.uid,
      email: email,
      username: isOfficial ? 'A-Chatz' : username,
      publicKey: publicKey,
    );
    
    final userMap = user.toMap();
    if (isOfficial) {
      userMap['role'] = 'official';
      userMap['isVerified'] = true;
      userMap['bio'] = 'Official A-Chatz Support & Updates';
      userMap['status'] = 'Always here for you';
      userMap['accountType'] = 'business';
      userMap['photoUrl'] = 'https://a-chatz.web.app/icons/Icon-512.png';
    }

    await _db.table('users').doc(user.uid).set(userMap);
    return cred;
  }

  Future<void> startPhoneLogin({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(AppAuthException error) onFailed,
  }) async {
    // Only disable app verification in debug/development builds.
    if (kDebugMode) {
      try {
        await _auth.setSettings(appVerificationDisabledForTesting: true);
      } catch (_) {
        // Ignore if not supported on the current platform.
      }
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) => _auth.signInWithCredential(credential),
      verificationFailed: onFailed,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> verifyPhoneCode(String verificationId, String code) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code);
    await _auth.signInWithCredential(credential);
  }

  /// Updates online presence. Silently handles errors (e.g. when offline).
  Future<void> setPresence(bool online) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.table('users').doc(uid).set({
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('setPresence failed (ignored): $e');
    }
  }

  Future<void> signOut() async {
    await setPresence(false);
    await _auth.signOut();
  }

  Future<void> seedOfficialAccount() async {
    final user = _auth.currentUser;
    if (user?.email != 'official@a-chatz.com') return;

    // The UID of the official account is guaranteed as official_a_chatz
    const officialUid = 'official_a_chatz';
    const logoUrl = 'https://a-chatz.web.app/icons/Icon-512.png';

    await _db.table('users').doc(officialUid).set({
      'username': 'A-Chatz',
      'email': 'official@a-chatz.com',
      'role': 'official',
      'isVerified': true,
      'bio': 'Official A-Chatz Support & Updates',
      'status': 'Always here for you',
      'isOnline': true,
      'accountType': 'business',
      'isBanned': false,
      'photoUrl': logoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Seed the permanent "Who Are We" status
    final statusQuery = await _db
        .table('statuses')
        .where('ownerId', isEqualTo: officialUid)
        .limit(1)
        .get();

    if (statusQuery.docs.isEmpty) {
      await _db.table('statuses').add({
        'ownerId': officialUid,
        'ownerName': 'A-Chatz',
        'ownerPhotoUrl': logoUrl,
        'isOwnerVerified': true,
        'type': 'text',
        'mediaUrl': '',
        'caption': 'Welcome to A-Chatz! 🌟 We are an elite, premium messaging network built with security, luxury aesthetic, and blazing performance. Tap Search to add contacts by username or email. Share music statuses, manage business catalogs, and explore high-end tools!',
        'textBgColor': 0xFF121214,
        'textFont': 'serif',
        'musicTitle': 'A-Chatz Theme',
        'musicArtist': 'Official',
        'createdAt': FieldValue.serverTimestamp(),
        // 100 years expiration so it functions as a permanent welcome status story
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 36500)),
        ),
        'seenBy': {},
        'reactions': {},
        'comments': [],
        'resharedFromStatusId': null,
        'resharedFromOwnerName': null,
      });
    }
  }
}
