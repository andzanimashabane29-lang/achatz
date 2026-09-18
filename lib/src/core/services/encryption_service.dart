import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static final Map<String, String> decryptedCache = {};

  final _storage = const FlutterSecureStorage();
  final _algorithm = AesGcm.with256bits();
  final _keyExchange = X25519();

  String get _privateKeyStoreKey {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid != null) {
      return 'e2ee_private_key_$uid';
    }
    return 'e2ee_private_key';
  }

  static String? _memoryPrivateKey;

  /// Generates a new X25519 key pair and saves the private key securely.
  /// Returns the public key as a base64 string.
  Future<String> generateAndStoreKeyPair() async {
    final keyPair = await _keyExchange.newKeyPair();
    final privateKey = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    final privateKeyB64 = base64Encode(privateKey);
    try {
      await _storage.write(
        key: _privateKeyStoreKey,
        value: privateKeyB64,
      );
    } catch (_) {
      _memoryPrivateKey = privateKeyB64;
    }

    return base64Encode(publicKey.bytes);
  }

  /// Retrieves the stored private key.
  Future<SimpleKeyPair?> getStoredKeyPair() async {
    String? privateKeyB64;
    try {
      privateKeyB64 = await _storage.read(key: _privateKeyStoreKey);
    } catch (_) {}
    
    privateKeyB64 ??= _memoryPrivateKey;
    if (privateKeyB64 == null) return null;

    try {
      final privateKeyBytes = base64Decode(privateKeyB64);
      return await _keyExchange.newKeyPairFromSeed(privateKeyBytes);
    } catch (_) {
      return null;
    }
  }

  /// Derives a shared secret from our private key and their public key.
  Future<SecretKey> _deriveSharedSecret(
    SimpleKeyPair myKeyPair,
    String theirPublicKeyB64,
  ) async {
    final theirPublicKey = SimplePublicKey(
      base64Decode(theirPublicKeyB64),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: theirPublicKey,
    );

    return sharedSecret;
  }

  /// Encrypts plain text for a recipient.
  Future<String> encrypt(String plainText, String recipientPublicKeyB64) async {
    final myKeyPair = await getStoredKeyPair();
    if (myKeyPair == null) throw Exception('No local key pair found');

    final secretKey = await _deriveSharedSecret(myKeyPair, recipientPublicKeyB64);

    final clearText = utf8.encode(plainText);
    final secretBox = await _algorithm.encrypt(
      clearText,
      secretKey: secretKey,
    );

    // Combine nonce and cipher text for storage
    final cipher = base64Encode(secretBox.concatenation());
    decryptedCache[cipher] = plainText;
    return cipher;
  }

  /// Decrypts cipher text from a sender.
  Future<String> decrypt(String cipherTextB64, String senderPublicKeyB64) async {
    if (decryptedCache.containsKey(cipherTextB64)) {
      return decryptedCache[cipherTextB64]!;
    }
    try {
      final myKeyPair = await getStoredKeyPair();
      if (myKeyPair == null) throw Exception('No local key pair found');

      final secretKey = await _deriveSharedSecret(myKeyPair, senderPublicKeyB64);

      final combined = base64Decode(cipherTextB64);
      final secretBox = SecretBox.fromConcatenation(
        combined,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );

      final clearText = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      final plain = utf8.decode(clearText);
      decryptedCache[cipherTextB64] = plain;
      return plain;
    } catch (e) {
      return '[Decryption Error]';
    }
  }

  /// Group Encryption: Encrypts a symmetric key for a member.
  Future<String> encryptGroupKey(String groupSymmetricKeyB64, String memberPublicKeyB64) async {
     return encrypt(groupSymmetricKeyB64, memberPublicKeyB64);
  }

  /// Group Decryption: Decrypts the group symmetric key.
  Future<String> decryptGroupKey(String encryptedGroupKeyB64, String adminPublicKeyB64) async {
     return decrypt(encryptedGroupKeyB64, adminPublicKeyB64);
  }

  /// Encrypts data using a symmetric key (for group messages).
  Future<String> encryptSymmetric(String plainText, String symmetricKeyB64) async {
    final secretKey = SecretKey(base64Decode(symmetricKeyB64));
    final clearText = utf8.encode(plainText);
    final secretBox = await _algorithm.encrypt(
      clearText,
      secretKey: secretKey,
    );
    final cipher = base64Encode(secretBox.concatenation());
    decryptedCache[cipher] = plainText;
    return cipher;
  }

  /// Decrypts data using a symmetric key (for group messages).
  Future<String> decryptSymmetric(String cipherTextB64, String symmetricKeyB64) async {
    if (decryptedCache.containsKey(cipherTextB64)) {
      return decryptedCache[cipherTextB64]!;
    }
    try {
      final secretKey = SecretKey(base64Decode(symmetricKeyB64));
      final combined = base64Decode(cipherTextB64);
      final secretBox = SecretBox.fromConcatenation(
        combined,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      final clearText = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      final plain = utf8.decode(clearText);
      decryptedCache[cipherTextB64] = plain;
      return plain;
    } catch (e) {
      return '[Decryption Error]';
    }
  }

  /// Automatically ensures that local keys exist and updates Firestore if newly generated.
  Future<void> ensureKeysExistAndSync(String currentUid) async {
    try {
      final myKeyPair = await getStoredKeyPair();
      if (myKeyPair == null) {
        final newPublicKey = await generateAndStoreKeyPair();
        await AppDatabase.instance.table('users').doc(currentUid).update({
          'publicKey': newPublicKey,
        });
      }
    } catch (_) {}
  }

  /// Generates a random 256-bit symmetric key
  String generateSymmetricKey() {
    final bytes = List<int>.generate(32, (i) => Random.secure().nextInt(256));
    return base64Encode(bytes);
  }

  /// Encrypts file bytes using a symmetric key
  Future<List<int>> encryptFileBytes(List<int> fileBytes, String symmetricKeyB64) async {
    final secretKey = SecretKey(base64Decode(symmetricKeyB64));
    final secretBox = await _algorithm.encrypt(
      fileBytes,
      secretKey: secretKey,
    );
    return secretBox.concatenation();
  }

  /// Decrypts file bytes using a symmetric key
  Future<List<int>> decryptFileBytes(List<int> encryptedBytes, String symmetricKeyB64) async {
    try {
      final secretKey = SecretKey(base64Decode(symmetricKeyB64));
      final secretBox = SecretBox.fromConcatenation(
        encryptedBytes,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      return await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
    } catch (e) {
      throw Exception('Failed to decrypt file bytes');
    }
  }
}
