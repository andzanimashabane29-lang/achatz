import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:a_chatz/src/core/services/encryption_service.dart';

class LocalMediaCache {
  static final LocalMediaCache instance = LocalMediaCache._();
  LocalMediaCache._();

  Future<String> getLocalPath(String url) async {
    String filename = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    if (filename.length > 150) {
      filename = filename.substring(filename.length - 150);
    }
    
    final directory = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${directory.path}/cached_media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    
    // Preserve file extension
    String ext = '';
    final uri = Uri.parse(url);
    if (uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      if (lastSegment.contains('.')) {
        ext = '.${lastSegment.split('.').last.split('?').first}';
      }
    }
    
    return '${mediaDir.path}/$filename$ext';
  }

  Future<File?> getCachedFile(String url) async {
    try {
      final localPath = await getLocalPath(url);
      final file = File(localPath);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      debugPrint('Error getting cached file: $e');
    }
    return null;
  }

  Future<File> downloadAndCache(String url, {String? encryptedMediaKey, String? senderPublicKey}) async {
    final localPath = await getLocalPath(url);
    final file = File(localPath);
    if (await file.exists()) {
      return file;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<int> bytes = response.bodyBytes;
        
        if (encryptedMediaKey != null && senderPublicKey != null) {
          try {
            final symmetricKeyB64 = await EncryptionService().decrypt(encryptedMediaKey, senderPublicKey);
            bytes = await EncryptionService().decryptFileBytes(bytes, symmetricKeyB64);
          } catch (e) {
            debugPrint('Failed to decrypt media: $e');
            throw Exception('Decryption error');
          }
        }

        await file.writeAsBytes(bytes);
        return file;
      } else {
        throw Exception('Failed to download media (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error downloading and caching media: $e');
      rethrow;
    }
  }
}
