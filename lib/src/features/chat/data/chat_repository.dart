import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:a_chatz/src/core/services/encryption_service.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/shared/utils/business_utils.dart';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:a_chatz/src/shared/services/local_media_cache.dart';
import 'package:pdfx/pdfx.dart';

class ChatRepository {
  ChatRepository(this._db, this._auth);

  final AppDatabase _db;
  final AppAuth _auth;

  String get uid => _auth.currentUser!.uid;

  Stream<List<ChatThread>> myChats() {
    return _db
        .table('chats')
        .where('memberIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final threads = snap.docs
          .map((d) => ChatThread.fromMap(d.id, d.data()))
          .where((chat) {
            if (chat.archivedBy.contains(uid)) return false;
            final deletedTime = chat.deletedAt[uid];
            if (deletedTime != null) {
              if (chat.lastMessageAt == null || !chat.lastMessageAt!.isAfter(deletedTime)) {
                return false;
              }
            }
            return true;
          })
          .toList();
      _markUndeliveredForThreads(threads);
      return threads;
    });
  }

  Stream<List<ChatThread>> archivedChats() {
    return _db
        .table('chats')
        .where('memberIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final threads = snap.docs
          .map((d) => ChatThread.fromMap(d.id, d.data()))
          .where((chat) {
            if (!chat.archivedBy.contains(uid)) return false;
            final deletedTime = chat.deletedAt[uid];
            if (deletedTime != null) {
              if (chat.lastMessageAt == null || !chat.lastMessageAt!.isAfter(deletedTime)) {
                return false;
              }
            }
            return true;
          })
          .toList();
      _markUndeliveredForThreads(threads);
      return threads;
    });
  }

  Stream<List<ChatMessage>> messages(String chatId) {
    return _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots(includeMetadataChanges: true)
        .map((snap) {
      final now = DateTime.now();
      return snap.docs
          .map((d) => ChatMessage.fromMap(d.id, d.data(), hasPendingWrites: d.metadata.hasPendingWrites))
          .where((msg) {
            if (msg.deletedFor.contains(uid)) return false;
            // Prevent recipient from seeing the message while it's uploading on the sender's side
            if (msg.senderId != uid && msg.isUploading) return false;
            if (msg.selfDestructDuration != null && msg.selfDestructDuration! > 0) {
              final expiryTime = msg.createdAt.add(Duration(seconds: msg.selfDestructDuration!));
              if (now.isAfter(expiryTime)) {
                _db.table('chats')
                    .doc(chatId)
                    .table('messages')
                    .doc(msg.id)
                    .delete()
                    .catchError((_) {});
                return false;
              }
            }
            return true;
          })
          .toList();
    });
  }

  Future<String> createPrivateChat(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    final currentUid = currentUser.uid;
    final members = [currentUid, otherUserId]..sort();

    final existing = await _db
        .table('chats')
        .where('type', isEqualTo: 'private')
        .where('memberIds', arrayContains: currentUid)
        .get();

    for (final doc in existing.docs) {
      final ids = List<String>.from(doc.data()['memberIds'] ?? [])..sort();
      if (ids.length == 2 && ids[0] == members[0] && ids[1] == members[1]) {
        return doc.id;
      }
    }

    final otherUserDoc = await _db.table('users').doc(otherUserId).get();
    final otherUserData = otherUserDoc.data();
    final otherUsername = otherUserData?['username'] ?? 'A-Chatz User';

    final chatRef = _db.table('chats').doc();

    await chatRef.set({
      'type': 'private',
      'title': otherUsername,
      'description': '',
      'photoUrl': null,
      'memberIds': members,
      'admins': [currentUid],
      'createdBy': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageSenderId': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'typing': {},
      'mutedBy': [],
      'archivedBy': [],
      'pinnedMessageIds': [],
    });

    return chatRef.id;
  }

  Future<String> createGroupChat({
    required String title,
    required List<String> memberIds,
    File? photoFile,
    XFile? photoXFile,
    String? description,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    final currentUid = currentUser.uid;
    final members = <String>{currentUid, ...memberIds}.toList();

    final chatRef = _db.table('chats').doc();

    String? photoUrl;

    final targetXFile = photoXFile ?? (photoFile != null ? XFile(photoFile.path) : null);
    if (targetXFile != null) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${targetXFile.name}';

      final storageRef = AppStorage.instance.ref().child(
            'group_photos/${chatRef.id}/$fileName',
          );

      final bytes = await targetXFile.readAsBytes();
      final uploadTask = storageRef.putData(bytes);
      final snapshot = await uploadTask;
      photoUrl = await snapshot.ref.getDownloadURL();
    }

    await chatRef.set({
      'type': 'group',
      'title': title.trim(),
      'description': description ?? '',
      'photoUrl': photoUrl,
      'memberIds': members,
      'admins': [currentUid],
      'createdBy': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Group created',
      'lastMessageSenderId': currentUid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'typing': {},
      'mutedBy': [],
      'archivedBy': [],
      'pinnedMessageIds': [],
    });

    await chatRef.table('messages').add({
      'senderId': currentUid,
      'type': 'system',
      'cipherText': 'Group created',
      'mediaUrl': null,
      'fileName': null,
      'durationMs': null,
      'replyToMessageId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': {
        currentUid: FieldValue.serverTimestamp(),
      },
      'readBy': {
        currentUid: FieldValue.serverTimestamp(),
      },
    });

    return chatRef.id;
  }

  Future<void> sendText(
    String chatId,
    String plainText, {
    String? replyToMessageId,
    int? selfDestructDuration,
  }) async {
    final chatDoc = await _db.table('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final type = chatData['type'];
    final disappearingDuration = chatData['disappearingDuration'] as int?;

    String cipherText = plainText;
    bool isEncrypted = false;
    String? senderPublicKey;
    String? recipientPublicKey;

    if (type == 'private') {
      final memberIds = List<String>.from(chatData['memberIds'] ?? []);
      final otherUid = memberIds.firstWhere((id) => id != uid, orElse: () => uid);
      
      final otherUserDoc = await _db.table('users').doc(otherUid).get();
      recipientPublicKey = otherUserDoc.data()?['publicKey'];

      final myUserDoc = await _db.table('users').doc(uid).get();
      senderPublicKey = myUserDoc.data()?['publicKey'];

      if (recipientPublicKey != null && senderPublicKey != null) {
        try {
          cipherText = await EncryptionService().encrypt(plainText, recipientPublicKey!);
          isEncrypted = true;
        } catch (_) {
          cipherText = plainText;
          isEncrypted = false;
        }
      }
    }

    final deliveredTo = await _buildDeliveredTo(chatId, type ?? 'private');

    final batch = _db.batch();

    final message =
        _db.table('chats').doc(chatId).table('messages').doc();

    batch.set(message, {
      'senderId': uid,
      'type': 'text',
      'cipherText': cipherText,
      'mediaUrl': null,
      'fileName': null,
      'durationMs': null,
      'replyToMessageId': replyToMessageId,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': deliveredTo,
      'readBy': {
        uid: FieldValue.serverTimestamp(),
      },
      'isEncrypted': isEncrypted,
      'senderPublicKey': senderPublicKey,
      'recipientPublicKey': recipientPublicKey,
      'selfDestructDuration': selfDestructDuration ?? disappearingDuration,
    });

    batch.update(_db.table('chats').doc(chatId), {
      'lastMessage': plainText,
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageDeliveredTo': deliveredTo,
    });

    await batch.commit();

    try {
      _triggerBusinessAutoReply(chatId, plainText);
    } catch (_) {}
  }

  Future<void> sendPoll(
    String chatId,
    String question,
    List<String> options,
  ) async {
    final chatDoc = await _db.table('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final type = chatData['type'];
    final disappearingDuration = chatData['disappearingDuration'] as int?;

    String cipherText = '';
    bool isEncrypted = false;
    String? senderPublicKey;
    String? recipientPublicKey;

    final pollData = {
      'question': question,
      'options': options,
    };
    final plainText = jsonEncode(pollData);

    if (type == 'private') {
      final memberIds = List<String>.from(chatData['memberIds'] ?? []);
      final otherUid = memberIds.firstWhere((id) => id != uid, orElse: () => uid);

      final otherUserDoc = await _db.table('users').doc(otherUid).get();
      recipientPublicKey = otherUserDoc.data()?['publicKey'];

      final myUserDoc = await _db.table('users').doc(uid).get();
      senderPublicKey = myUserDoc.data()?['publicKey'];

      if (recipientPublicKey != null && senderPublicKey != null) {
        try {
          cipherText = await EncryptionService().encrypt(plainText, recipientPublicKey!);
          isEncrypted = true;
        } catch (_) {
          cipherText = plainText;
          isEncrypted = false;
        }
      } else {
        cipherText = plainText;
      }
    } else {
      cipherText = plainText;
    }

    final deliveredTo = await _buildDeliveredTo(chatId, type ?? 'private');

    final batch = _db.batch();

    final message =
        _db.table('chats').doc(chatId).table('messages').doc();

    final votes = <String, List<String>>{};
    for (int i = 0; i < options.length; i++) {
      votes[i.toString()] = [];
    }

    batch.set(message, {
      'senderId': uid,
      'type': 'poll',
      'cipherText': cipherText,
      'mediaUrl': null,
      'fileName': null,
      'durationMs': null,
      'replyToMessageId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': deliveredTo,
      'readBy': {
        uid: FieldValue.serverTimestamp(),
      },
      'isEncrypted': isEncrypted,
      'senderPublicKey': senderPublicKey,
      'recipientPublicKey': recipientPublicKey,
      'selfDestructDuration': disappearingDuration,
      'pollQuestion': question,
      'pollOptions': options,
      'pollVotes': votes,
    });

    batch.update(_db.table('chats').doc(chatId), {
      'lastMessage': '📊 Poll: $question',
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> castVote(
    String chatId,
    String messageId,
    int optionIndex,
  ) async {
    final messageRef = _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(messageRef);
      if (!snapshot.exists) return;

      final pollVotes = Map<String, dynamic>.from(snapshot.data()?['pollVotes'] ?? {});
      final optionKey = optionIndex.toString();

      pollVotes.forEach((key, list) {
        final List<dynamic> uids = List<dynamic>.from(list);
        if (key == optionKey) {
          if (!uids.contains(uid)) {
            uids.add(uid);
          }
        } else {
          uids.remove(uid);
        }
        pollVotes[key] = uids;
      });

      transaction.update(messageRef, {'pollVotes': pollVotes});
    });
  }

  Future<void> sendMedia({
    required String chatId,
    File? file,
    XFile? xFile,
    required MessageType type,
    String? replyToMessageId,
    int? durationMs,
    String? caption,
    String? music,
    bool isViewOnce = false,
    bool isHD = false,
  }) async {
    final chatDoc = await _db.table('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final chatType = chatData['type'];
    final disappearingDuration = chatData['disappearingDuration'] as int?;

    String cipherText = caption ?? '';
    bool isEncrypted = false;
    String? senderPublicKey;
    String? recipientPublicKey;
    String? encryptedMediaKey;
    String? symmetricKeyB64;

    if (chatType == 'private') {
      final memberIds = List<String>.from(chatData['memberIds'] ?? []);
      final otherUid = memberIds.firstWhere((id) => id != uid, orElse: () => uid);
      
      final otherUserDoc = await _db.table('users').doc(otherUid).get();
      recipientPublicKey = otherUserDoc.data()?['publicKey'];

      final myUserDoc = await _db.table('users').doc(uid).get();
      senderPublicKey = myUserDoc.data()?['publicKey'];

      if (recipientPublicKey != null && senderPublicKey != null) {
        // Encrypt the caption
        if (caption != null && caption.isNotEmpty) {
          try {
            cipherText = await EncryptionService().encrypt(caption, recipientPublicKey!);
            isEncrypted = true;
          } catch (_) {
            cipherText = caption;
            isEncrypted = false;
          }
        }
        
        // Generate symmetric key and encrypt it for media
        try {
           symmetricKeyB64 = EncryptionService().generateSymmetricKey();
           encryptedMediaKey = await EncryptionService().encrypt(symmetricKeyB64, recipientPublicKey!);
        } catch (_) {}
      }
    }

    final targetXFile = xFile ?? XFile(file!.path);
    final fileName = targetXFile.name;
    final extension = path.extension(fileName);

    final messageRef = _db.table('chats').doc(chatId).table('messages').doc();

    final baseLastMsg = _lastMessageFor(type);
    final lastMessage = isViewOnce 
        ? '➀ ${baseLastMsg.replaceAll('📷 ', '').replaceAll('🎥 ', '').replaceAll('🎙️ ', '')}' 
        : baseLastMsg;

    final deliveredTo = await _buildDeliveredTo(chatId, chatType ?? 'private');

    // 1. Optimistic Write: Save to Firestore immediately
    await messageRef.set({
      'senderId': uid,
      'type': type.name,
      'cipherText': cipherText,
      'mediaUrl': null, // null until upload finishes
      'localFilePath': kIsWeb ? null : targetXFile.path,
      'isUploading': true,
      'encryptedMediaKey': encryptedMediaKey,
      'fileName': fileName.isEmpty ? 'File$extension' : fileName,
      'durationMs': durationMs,
      'caption': caption,
      'music': music,
      'replyToMessageId': replyToMessageId,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': deliveredTo,
      'readBy': {
        uid: FieldValue.serverTimestamp(),
      },
      'isEncrypted': isEncrypted,
      'senderPublicKey': senderPublicKey,
      'recipientPublicKey': recipientPublicKey,
      'isViewOnce': isViewOnce,
      'isHD': isHD,
      'openedBy': [],
      'selfDestructDuration': disappearingDuration,
    });

    await _db.table('chats').doc(chatId).update({
      'lastMessage': lastMessage,
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageDeliveredTo': deliveredTo,
    });

    try {
      _triggerBusinessAutoReply(chatId, lastMessage);
    } catch (_) {}

    // 2. Background Upload & Encryption
    try {
      final storageRef = AppStorage.instance.ref().child(
        'chat_media/$chatId/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      final metadata = SettableMetadata(
        contentType: type == MessageType.image ? 'image/jpeg' : 
                     type == MessageType.video ? 'video/mp4' : 
                     type == MessageType.voice ? 'audio/mpeg' : 'application/octet-stream',
      );

      String? mediaUrl;

      if (symmetricKeyB64 != null) {
         // Encrypt the file
         final fileBytes = await targetXFile.readAsBytes();
         final encryptedBytes = await EncryptionService().encryptFileBytes(fileBytes, symmetricKeyB64);
         
         // Upload encrypted bytes
         final uploadTask = storageRef.putData(Uint8List.fromList(encryptedBytes), metadata);
         final snapshot = await uploadTask;
         mediaUrl = await snapshot.ref.getDownloadURL();
         
         String? thumbnailUrl;
         if (type == MessageType.document && extension.toLowerCase() == '.pdf' && !kIsWeb) {
           try {
             final document = await PdfDocument.openFile(targetXFile.path);
             final page = await document.getPage(1);
             final pageImage = await page.render(width: page.width, height: page.height);
             await page.close();
             await document.close();
             
             if (pageImage != null) {
               final thumbRef = AppStorage.instance.ref().child('chat_media/$chatId/${DateTime.now().millisecondsSinceEpoch}_thumb.png');
               final encThumb = await EncryptionService().encryptFileBytes(pageImage.bytes, symmetricKeyB64);
               final tTask = await thumbRef.putData(Uint8List.fromList(encThumb), SettableMetadata(contentType: 'image/png'));
               thumbnailUrl = await tTask.ref.getDownloadURL();
             }
           } catch (e) {
             debugPrint('PDF thumbnail error: $e');
           }
         }

         await messageRef.update({
            'mediaUrl': mediaUrl,
            if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
            'isUploading': false,
         });
      } else {
         // Upload normally if no encryption (e.g. group chats)
         final UploadTask uploadTask;
         if (kIsWeb) {
           final bytes = await targetXFile.readAsBytes();
           uploadTask = storageRef.putData(bytes, metadata);
         } else {
           uploadTask = storageRef.putFile(File(targetXFile.path), metadata);
         }
         final snapshot = await uploadTask;
         mediaUrl = await snapshot.ref.getDownloadURL();

         String? thumbnailUrl;
         if (type == MessageType.document && extension.toLowerCase() == '.pdf' && !kIsWeb) {
           try {
             final document = await PdfDocument.openFile(targetXFile.path);
             final page = await document.getPage(1);
             final pageImage = await page.render(width: page.width, height: page.height);
             await page.close();
             await document.close();
             
             if (pageImage != null) {
               final thumbRef = AppStorage.instance.ref().child('chat_media/$chatId/${DateTime.now().millisecondsSinceEpoch}_thumb.png');
               final tTask = await thumbRef.putData(pageImage.bytes, SettableMetadata(contentType: 'image/png'));
               thumbnailUrl = await tTask.ref.getDownloadURL();
             }
           } catch (e) {
             debugPrint('PDF thumbnail error: $e');
           }
         }

         await messageRef.update({
            'mediaUrl': mediaUrl,
            if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
            'isUploading': false,
         });
      }

      // Pre-cache uploaded media file locally
      if (mediaUrl != null) {
        try {
          final cachePath = await LocalMediaCache.instance.getLocalPath(mediaUrl);
          final cacheFile = File(cachePath);
          if (!await cacheFile.exists()) {
            final origFile = File(targetXFile.path);
            if (await origFile.exists()) {
              await origFile.copy(cachePath);
              debugPrint('Successfully pre-cached uploaded voice note/media to $cachePath');
            }
          }
        } catch (e) {
          debugPrint('Failed to pre-cache uploaded media locally: $e');
        }
      }
    } catch (_) {
      // In case of error, update isUploading to false so UI doesn't hang forever
      await messageRef.update({'isUploading': false});
    }
  }

  /// Upload multiple images as a single [imageGroup] message — WhatsApp style.
  /// Shows a single bubble with a thumbnail grid and "+N more" overlay.
  Future<void> sendMultipleImages({
    required String chatId,
    required List<File> files,
    String? caption,
    bool isViewOnce = false,
  }) async {
    if (files.isEmpty) return;

    final chatDoc = await _db.table('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final disappearingDuration = chatData['disappearingDuration'] as int?;

    final localPaths = files.map((f) => f.path).toList();
    final messageRef = _db.table('chats').doc(chatId).table('messages').doc();

    final deliveredTo = await _buildDeliveredTo(chatId, chatData['type'] ?? 'private');

    // 1. Optimistic write — local paths visible immediately
    await messageRef.set({
      'senderId': uid,
      'type': 'imageGroup',
      'cipherText': caption ?? '',
      'mediaUrl': null,
      'mediaUrls': [],
      'localFilePaths': localPaths,
      'isUploading': true,
      'replyToMessageId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': deliveredTo,
      'readBy': {uid: FieldValue.serverTimestamp()},
      'isEncrypted': false,
      'isViewOnce': isViewOnce,
      'openedBy': [],
      'selfDestructDuration': disappearingDuration,
    });

    await _db.table('chats').doc(chatId).update({
      'lastMessage': '📷 ${files.length} Photos',
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageDeliveredTo': deliveredTo,
    });

    // 2. Upload all images in parallel, then update message
    try {
      final uploadFutures = files.asMap().entries.map((entry) async {
        final index = entry.key;
        final file = entry.value;
        final fileName = path.basename(file.path);
        final storageRef = AppStorage.instance.ref().child(
          'chat_media/$chatId/${DateTime.now().millisecondsSinceEpoch}_${index}_$fileName',
        );
        final uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      });

      final urls = await Future.wait(uploadFutures);

      // Pre-cache all uploaded images locally
      for (int i = 0; i < files.length; i++) {
        try {
          final url = urls[i];
          final file = files[i];
          final cachePath = await LocalMediaCache.instance.getLocalPath(url);
          final cacheFile = File(cachePath);
          if (!await cacheFile.exists()) {
            if (await file.exists()) {
              await file.copy(cachePath);
            }
          }
        } catch (e) {
          debugPrint('Failed to pre-cache uploaded image $i locally: $e');
        }
      }

      await messageRef.update({
        'mediaUrls': urls,
        'mediaUrl': urls.first, // keep single URL for legacy compat
        'localFilePaths': FieldValue.delete(),
        'isUploading': false,
      });
    } catch (_) {
      await messageRef.update({'isUploading': false});
    }
  }

  Future<void> sendMultipleVideos({
    required String chatId,
    required List<File> files,
    String? caption,
  }) async {
    if (files.isEmpty) return;

    final chatDoc = await _db.table('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final disappearingDuration = chatData['disappearingDuration'] as int?;

    final localPaths = files.map((f) => f.path).toList();
    final messageRef = _db.table('chats').doc(chatId).table('messages').doc();

    final deliveredTo = await _buildDeliveredTo(chatId, chatData['type'] ?? 'private');

    // 1. Optimistic write — local paths visible immediately
    await messageRef.set({
      'senderId': uid,
      'type': 'video',
      'cipherText': caption ?? '',
      'mediaUrl': null,
      'mediaUrls': [],
      'localFilePaths': localPaths,
      'isUploading': true,
      'replyToMessageId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': deliveredTo,
      'readBy': {uid: FieldValue.serverTimestamp()},
      'isEncrypted': false,
      'isViewOnce': false,
      'openedBy': [],
      'selfDestructDuration': disappearingDuration,
    });

    await _db.table('chats').doc(chatId).update({
      'lastMessage': '🎥 ${files.length} Videos',
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageDeliveredTo': deliveredTo,
    });

    // 2. Upload all videos in parallel, then update message
    try {
      final uploadFutures = files.asMap().entries.map((entry) async {
        final index = entry.key;
        final file = entry.value;
        final fileName = path.basename(file.path);
        final storageRef = AppStorage.instance.ref().child(
          'chat_media/$chatId/${DateTime.now().millisecondsSinceEpoch}_${index}_$fileName',
        );
        final uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: 'video/mp4'),
        );
        final snapshot = await uploadTask;
        return await snapshot.ref.getDownloadURL();
      });

      final urls = await Future.wait(uploadFutures);

      // Pre-cache all uploaded videos locally
      for (int i = 0; i < files.length; i++) {
        try {
          final url = urls[i];
          final file = files[i];
          final cachePath = await LocalMediaCache.instance.getLocalPath(url);
          final cacheFile = File(cachePath);
          if (!await cacheFile.exists()) {
            if (await file.exists()) {
              await file.copy(cachePath);
            }
          }
        } catch (e) {
          debugPrint('Failed to pre-cache uploaded video $i locally: $e');
        }
      }

      await messageRef.update({
        'mediaUrls': urls,
        'mediaUrl': urls.first,
        'localFilePaths': FieldValue.delete(),
        'isUploading': false,
      });
    } catch (_) {
      await messageRef.update({'isUploading': false});
    }
  }

  Future<void> markViewOnceOpened(String chatId, String messageId) {
    return _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId)
        .update({
      'openedBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<String> sendLocation({
    required String chatId,
    required double latitude,
    required double longitude,
    bool isLive = false,
    DateTime? liveUntil,
    String? replyToMessageId,
  }) async {
    final chatDoc = await _db.table('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final disappearingDuration = chatData['disappearingDuration'] as int?;

    final messageRef = _db.table('chats').doc(chatId).table('messages').doc();

    final deliveredTo = await _buildDeliveredTo(chatId, chatData['type'] ?? 'private');

    await messageRef.set({
      'senderId': uid,
      'type': 'location',
      'cipherText': isLive ? 'Live Location' : 'Location',
      'latitude': latitude,
      'longitude': longitude,
      'isLive': isLive,
      'liveUntil': liveUntil != null ? Timestamp.fromDate(liveUntil) : null,
      'replyToMessageId': replyToMessageId,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': deliveredTo,
      'readBy': {
        uid: FieldValue.serverTimestamp(),
      },
      'selfDestructDuration': disappearingDuration,
    });

    await _db.table('chats').doc(chatId).update({
      'lastMessage': isLive ? '📍 Live Location' : '📍 Location',
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    try {
      _triggerBusinessAutoReply(chatId, isLive ? '📍 Live Location' : '📍 Location');
    } catch (_) {}

    return messageRef.id;
  }

  Future<void> updateLocation(String chatId, String messageId, double lat, double lng) async {
    await _db.table('chats').doc(chatId).table('messages').doc(messageId).update({
      'latitude': lat,
      'longitude': lng,
    });
  }



  String _lastMessageFor(MessageType type) {
    if (type == MessageType.image) return '📷 Photo';
    if (type == MessageType.video) return '🎥 Video';
    if (type == MessageType.voice) return '🎙️ Voice note';
    if (type == MessageType.document) return '📄 Document';
    if (type == MessageType.sticker) return '💟 Sticker';
    return 'Message';
  }

  Future<void> updateGroupInfo({
    required String chatId,
    String? title,
    String? description,
    File? photoFile,
  }) async {
    await _ensureAdmin(chatId);

    final updates = <String, dynamic>{};

    if (title != null && title.trim().isNotEmpty) {
      updates['title'] = title.trim();
    }

    if (description != null) {
      updates['description'] = description.trim();
    }

    if (photoFile != null) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(photoFile.path)}';

      final storageRef = AppStorage.instance.ref().child(
            'group_photos/$chatId/$fileName',
          );

      final uploadTask = await storageRef.putFile(photoFile);
      updates['photoUrl'] = await uploadTask.ref.getDownloadURL();
    }

    if (updates.isEmpty) return;

    await _db.table('chats').doc(chatId).update(updates);
  }

  Future<void> addGroupMembers({
    required String chatId,
    required List<String> userIds,
  }) async {
    await _ensureAdmin(chatId);

    await _db.table('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayUnion(userIds),
      'lastMessage': 'Members added',
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeGroupMember({
    required String chatId,
    required String userId,
  }) async {
    await _ensureAdmin(chatId);

    final chatDoc = await _db.table('chats').doc(chatId).get();
    final data = chatDoc.data() ?? {};

    if (userId == data['createdBy']) {
      throw Exception('You cannot remove the group creator');
    }

    await _db.table('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'admins': FieldValue.arrayRemove([userId]),
      'lastMessage': 'A member was removed',
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> makeGroupAdmin({
    required String chatId,
    required String userId,
  }) async {
    await _ensureAdmin(chatId);

    await _db.table('chats').doc(chatId).update({
      'admins': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> dismissGroupAdmin({
    required String chatId,
    required String userId,
  }) async {
    await _ensureAdmin(chatId);

    final chatDoc = await _db.table('chats').doc(chatId).get();
    final data = chatDoc.data() ?? {};

    if (data['createdBy'] == userId) {
      throw Exception('You cannot dismiss the group creator');
    }

    await _db.table('chats').doc(chatId).update({
      'admins': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> leaveGroup(String chatId) async {
    await _db.table('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
      'lastMessage': 'A member left the group',
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureAdmin(String chatId) async {
    final doc = await _db.table('chats').doc(chatId).get();

    if (!doc.exists) throw Exception('Group not found');

    final data = doc.data() ?? {};
    final type = data['type'];
    final admins = List<String>.from(data['admins'] ?? []);

    if (type != 'group') throw Exception('This is not a group chat');

    if (!admins.contains(uid)) {
      throw Exception('Only group admins can do this');
    }
  }

  Future<void> setTyping(String chatId, bool isTyping) {
    return _db.table('chats').doc(chatId).set({
      'typing': {
        uid: isTyping,
      },
    }, SetOptions(merge: true));
  }

  Future<void> clearUnreadCount(String chatId) async {
    final myUid = uid;
    if (myUid == null) return;
    await _db.table('chats').doc(chatId).update({
      'unreadCount.$myUid': 0,
    });
  }

  Future<void> markRead(String chatId, String messageId) async {
    final userDoc = await _db.table('users').doc(uid).get();
    final readReceipts = userDoc.data()?['readReceiptsEnabled'] ?? true;
    final blockedUsers = List<String>.from(userDoc.data()?['blockedUsers'] ?? []);
    
    if (!readReceipts) return;

    final msgDoc = await _db.table('chats').doc(chatId).table('messages').doc(messageId).get();
    if (!msgDoc.exists) return;
    
    final senderId = msgDoc.data()?['senderId'] as String?;
    if (senderId != null && blockedUsers.contains(senderId)) return;

    await _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId)
        .set({
      'readBy': {
        uid: FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> editMessage(
    String chatId,
    String messageId,
    String newText,
  ) async {
    final doc =
        _db.table('chats').doc(chatId).table('messages').doc(messageId);

    final snapshot = await doc.get();

    if (!snapshot.exists) return;

    await doc.update({
      'cipherText': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteForMe(String chatId, String messageId) {
    return _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId)
        .update({
      'deletedFor': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> deleteForEveryone(String chatId, String messageId) async {
    final chatDoc = await _db.table('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    final ownerId = chatData['ownerId'] as String?;
    final adminIds = List<String>.from(chatData['adminIds'] ?? []);
    final isGroupAdmin = ownerId == uid || adminIds.contains(uid);

    return _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId)
        .update({
      'cipherText': '',
      'mediaUrl': null,
      'deletedForEveryone': true,
      'deletedByAdmin': isGroupAdmin,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> react(String chatId, String messageId, String emoji) {
    return _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId)
        .set({
      'reactions': {
        uid: emoji,
      },
    }, SetOptions(merge: true));
  }

  Future<void> toggleStarMessage(
    String chatId,
    String messageId,
    bool isStarred,
  ) {
    return _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId)
        .update({
      'starredBy': isStarred
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> pinMessage(String chatId, String messageId) {
    return _db.table('chats').doc(chatId).update({
      'pinnedMessageIds': FieldValue.arrayUnion([messageId]),
    });
  }

  Future<void> forwardMessage({
    required ChatMessage message,
    required String decryptedText,
    required String toChatId,
  }) async {
    final chatDoc = await _db.table('chats').doc(toChatId).get();
    final chatData = chatDoc.data() ?? {};
    final chatType = chatData['type'];
    final disappearingDuration = chatData['disappearingDuration'] as int?;

    String cipherText = decryptedText;
    bool isEncrypted = false;
    String? senderPublicKey;
    String? recipientPublicKey;

    if (chatType == 'private' && decryptedText.isNotEmpty) {
      final memberIds = List<String>.from(chatData['memberIds'] ?? []);
      final otherUid = memberIds.firstWhere((id) => id != uid, orElse: () => uid);
      
      final otherUserDoc = await _db.table('users').doc(otherUid).get();
      recipientPublicKey = otherUserDoc.data()?['publicKey'];

      final myUserDoc = await _db.table('users').doc(uid).get();
      senderPublicKey = myUserDoc.data()?['publicKey'];

      if (recipientPublicKey != null && senderPublicKey != null) {
        try {
          cipherText = await EncryptionService().encrypt(decryptedText, recipientPublicKey!);
          isEncrypted = true;
        } catch (_) {
          cipherText = decryptedText;
          isEncrypted = false;
        }
      }
    }

    final deliveredTo = await _buildDeliveredTo(toChatId, chatType ?? 'private');

    final batch = _db.batch();
    final messageRef = _db.table('chats').doc(toChatId).table('messages').doc();

    batch.set(messageRef, {
      'senderId': uid,
      'type': message.type.name,
      'cipherText': cipherText,
      'mediaUrl': message.mediaUrl,
      'fileName': message.fileName,
      'durationMs': message.durationMs,
      'replyToMessageId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': deliveredTo,
      'readBy': {
        uid: FieldValue.serverTimestamp(),
      },
      'isEncrypted': isEncrypted,
      'senderPublicKey': senderPublicKey,
      'recipientPublicKey': recipientPublicKey,
      'selfDestructDuration': disappearingDuration,
      'isForwarded': true,
      'isViewOnce': message.isViewOnce,
      'latitude': message.latitude,
      'longitude': message.longitude,
    });

    String lastMessageStr = decryptedText;
    if (message.type == MessageType.image) lastMessageStr = '📷 Photo';
    if (message.type == MessageType.video) lastMessageStr = '🎥 Video';
    if (message.type == MessageType.voice) lastMessageStr = '🎙️ Voice note';
    if (message.type == MessageType.document) lastMessageStr = '📄 Document';
    if (message.type == MessageType.location) lastMessageStr = '📍 Location';
    if (message.type == MessageType.sticker) lastMessageStr = '💟 Sticker';

    batch.update(_db.table('chats').doc(toChatId), {
      'lastMessage': lastMessageStr,
      'lastMessageSenderId': uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> archiveChat(String chatId) {
    return _db.table('chats').doc(chatId).update({
      'archivedBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> unarchiveChat(String chatId) {
    return _db.table('chats').doc(chatId).update({
      'archivedBy': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> toggleMuteChat(String chatId, bool isMuted) {
    return _db.table('chats').doc(chatId).update({
      'mutedBy': isMuted
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> sendSystemMessage(String chatId, String text) async {
    await _db.table('chats').doc(chatId).table('messages').add({
      'senderId': 'system',
      'type': 'system',
      'cipherText': text,
      'mediaUrl': null,
      'fileName': null,
      'durationMs': null,
      'replyToMessageId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'deletedForEveryone': false,
      'reactions': {},
      'starredBy': [],
      'deliveredTo': {},
      'readBy': {},
    });

    await _db.table('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageSenderId': 'system',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveGroupChat(String chatId, String currentUserName) async {
    await _db.table('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
    });
    await sendSystemMessage(chatId, '$currentUserName left the group');
  }

  Future<void> removeMemberFromGroup(String chatId, String memberUid, String memberName, String adminName) async {
    await _db.table('chats').doc(chatId).update({
      'memberIds': FieldValue.arrayRemove([memberUid]),
    });
    await sendSystemMessage(chatId, '$adminName removed $memberName from the group');
  }

  Future<void> promoteToAdmin(String chatId, String memberUid, String memberName, String adminName) async {
    await _db.table('chats').doc(chatId).update({
      'admins': FieldValue.arrayUnion([memberUid]),
    });
    await sendSystemMessage(chatId, '$adminName promoted $memberName to Admin');
  }

  Future<void> demoteFromAdmin(String chatId, String memberUid, String memberName, String adminName) async {
    await _db.table('chats').doc(chatId).update({
      'admins': FieldValue.arrayRemove([memberUid]),
    });
    await sendSystemMessage(chatId, '$adminName removed $memberName from Admins');
  }

  Future<void> clearGroupChatHistory(String chatId) async {
    final messagesSnap = await _db.table('chats').doc(chatId).table('messages').get();
    final batch = _db.batch();
    for (final doc in messagesSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    await sendSystemMessage(chatId, 'Chat history cleared by admin');
  }

  Future<void> deleteGroupChat(String chatId) async {
    final messagesSnap = await _db.table('chats').doc(chatId).table('messages').get();
    final batch = _db.batch();
    for (final doc in messagesSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    await _db.table('chats').doc(chatId).delete();
  }

  Future<void> pinChat(String chatId) {
    return _db.table('users').doc(uid).set({
      'pinnedChats': FieldValue.arrayUnion([chatId]),
    }, SetOptions(merge: true));
  }

  Future<void> unpinChat(String chatId) {
    return _db.table('users').doc(uid).set({
      'pinnedChats': FieldValue.arrayRemove([chatId]),
    }, SetOptions(merge: true));
  }

  Future<void> deleteChat(String chatId) async {
    // Hide the chat by setting the deletedAt timestamp for the user
    await _db.table('chats').doc(chatId).set({
      'deletedAt': {
        uid: FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));

    // Delete the existing messages for the user so they don't see them if the chat reappears
    final messagesSnap = await _db.table('chats').doc(chatId).table('messages').get();
    final batch = _db.batch();
    for (final doc in messagesSnap.docs) {
      final deletedFor = List<String>.from(doc.data()['deletedFor'] ?? []);
      if (!deletedFor.contains(uid)) {
        deletedFor.add(uid);
        batch.update(doc.reference, {'deletedFor': deletedFor});
      }
    }
    await batch.commit();

    // Ensure it's not pinned or archived anymore
    await unpinChat(chatId);
    await _db.table('chats').doc(chatId).update({
      'archivedBy': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> toggleFavorite(String chatId, bool isFavorite) {
    return _db.table('users').doc(uid).set({
      'favoriteChats': isFavorite
          ? FieldValue.arrayRemove([chatId])
          : FieldValue.arrayUnion([chatId]),
    }, SetOptions(merge: true));
  }

  Future<void> toggleLockChat(String chatId, bool isLocked) {
    return _db.table('chats').doc(chatId).update({
      'lockedBy': isLocked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> toggleGhostChat(String chatId, bool isGhost) {
    return _db.table('chats').doc(chatId).update({
      'isGhost': isGhost,
    });
  }

  Future<String> createSelfChat() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    final currentUid = currentUser.uid;

    // Check if self-chat already exists
    final existing = await _db
        .table('chats')
        .where('type', isEqualTo: 'private')
        .where('memberIds', isEqualTo: [currentUid])
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final userDoc = await _db.table('users').doc(currentUid).get();
    final username = userDoc.data()?['username'] ?? 'You';

    final chatRef = _db.table('chats').doc();

    await chatRef.set({
      'type': 'private',
      'title': '$username (You)',
      'description': 'Message yourself',
      'photoUrl': null,
      'memberIds': [currentUid],
      'admins': [currentUid],
      'createdBy': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Message yourself',
      'lastMessageSenderId': currentUid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'typing': {},
      'mutedBy': [],
      'archivedBy': [],
      'pinnedMessageIds': [],
      'isSelfChat': true,
    });

    return chatRef.id;
  }

  Future<void> addReaction(String chatId, String messageId, String emoji) {
    return _db.table('chats').doc(chatId).table('messages').doc(messageId).update({
      'reactions.$uid': emoji,
    });
  }

  Future<void> addImageReaction(String chatId, String messageId, int imageIndex, String emoji) {
    return _db.table('chats').doc(chatId).table('messages').doc(messageId).update({
      'imageReactions.$imageIndex.$uid': emoji,
    });
  }

  Future<void> clearChat(String chatId) async {
    final snap = await _db.table('chats').doc(chatId).table('messages').get();
    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    await _db.table('chats').doc(chatId).update({
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(String otherUid) async {
    await _db.table('users').doc(uid).update({
      'blockedUsers': FieldValue.arrayUnion([otherUid]),
    });
  }

  Future<void> unblockUser(String otherUid) async {
    await _db.table('users').doc(uid).update({
      'blockedUsers': FieldValue.arrayRemove([otherUid]),
    });
  }

  Stream<bool> isBlocked(String otherUid) {
    return _db.table('users').doc(uid).snapshots().map((snap) {
      final blocked = snap.data()?['blockedUsers'] as List<dynamic>? ?? [];
      return blocked.contains(otherUid);
    });
  }

  Future<void> broadcastOfficialMessage(
    String text, {
    String type = 'text',
    String? mediaUrl,
    int? durationMs,
    String? fileName,
  }) async {
    const officialUid = 'official_a_chatz';
    
    // Security check: Only official or admin can broadcast
    final me = await _db.table('users').doc(uid).get();
    final role = me.data()?['role'];
    if (uid != officialUid && role != 'admin' && role != 'official') {
      throw Exception('Unauthorized broadcast');
    }

    final usersSnap = await _db.table('users').get();
    
    // Determine last message text to show in the list view
    String lastMsg = text;
    if (type == 'image') {
      lastMsg = '📷 Image';
    } else if (type == 'video') {
      lastMsg = '🎥 Video';
    } else if (type == 'audio') {
      lastMsg = '🎙️ Voice note';
    }

    for (final userDoc in usersSnap.docs) {
      final targetUid = userDoc.id;
      if (targetUid == officialUid) continue;

      final members = [officialUid, targetUid]..sort();
      
      // Find or create chat
      final chatQuery = await _db
          .table('chats')
          .where('type', isEqualTo: 'private')
          .where('memberIds', isEqualTo: members)
          .get();

      String chatId;
      if (chatQuery.docs.isEmpty) {
        final chatRef = _db.table('chats').doc();
        await chatRef.set({
          'type': 'private',
          'title': 'A-Chatz',
          'description': 'Official A-Chatz Updates',
          'photoUrl': null,
          'memberIds': members,
          'admins': [officialUid],
          'createdBy': officialUid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': lastMsg,
          'lastMessageSenderId': officialUid,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'typing': {},
          'mutedBy': [],
          'archivedBy': [],
          'pinnedMessageIds': [],
          'isOfficial': true,
        });
        chatId = chatRef.id;
      } else {
        chatId = chatQuery.docs.first.id;
      }

      // Send message
      await _db.table('chats').doc(chatId).table('messages').add({
        'senderId': officialUid,
        'type': type,
        'cipherText': text,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (durationMs != null) 'durationMs': durationMs,
        if (fileName != null) 'fileName': fileName,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': {},
        'deliveredTo': {},
        'isEncrypted': false,
      });

      await _db.table('chats').doc(chatId).update({
        'lastMessage': lastMsg,
        'lastMessageSenderId': officialUid,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> _triggerBusinessAutoReply(String chatId, String plainText) async {
    final chatDoc = await _db.table('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};
    if (chatData['type'] != 'private') return;

    final memberIds = List<String>.from(chatData['memberIds'] ?? []);
    final otherUid = memberIds.firstWhere((id) => id != uid, orElse: () => uid);
    if (otherUid == uid) return;

    final otherUserDoc = await _db.table('users').doc(otherUid).get();
    final otherUserData = otherUserDoc.data() ?? {};
    if (otherUserData['accountType'] != 'business') return;

    final businessHours = otherUserData['businessHours'] as Map<String, dynamic>?;
    final businessHoursEnabled = otherUserData['businessHoursEnabled'] as bool? ?? false;
    final bool isOpen = isBusinessOpen(businessHours, businessHoursEnabled);

    final autoResponderEnabled = otherUserData['autoResponderEnabled'] as bool? ?? false;
    final autoResponderMessage = otherUserData['autoResponderMessage'] as String? ?? '';
    
    // Only send auto responder if the business is offline/away, or just rely on autoResponderEnabled toggle
    final bool isOfflineOrAway = !isOpen || autoResponderEnabled;

    if (isOfflineOrAway && autoResponderEnabled && autoResponderMessage.trim().isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1500), () async {
        // Send auto-reply text
        final msgRef = _db.table('chats').doc(chatId).table('messages').doc();
        await msgRef.set({
          'senderId': otherUid,
          'type': 'text',
          'cipherText': autoResponderMessage,
          'mediaUrl': null,
          'fileName': null,
          'durationMs': null,
          'replyToMessageId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'editedAt': null,
          'deletedFor': [],
          'deletedForEveryone': false,
          'reactions': {},
          'starredBy': [],
          'deliveredTo': {
            otherUid: FieldValue.serverTimestamp(),
          },
          'readBy': {
            otherUid: FieldValue.serverTimestamp(),
          },
          'isEncrypted': false,
        });

        await _db.table('chats').doc(chatId).update({
          'lastMessage': autoResponderMessage,
          'lastMessageSenderId': otherUid,
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      });
      return;
    }

    final greetingEnabled = otherUserData['greetingEnabled'] as bool? ?? false;
    final greetingMessage = otherUserData['greetingMessage'] as String? ?? '';

    if (greetingEnabled && greetingMessage.trim().isNotEmpty) {
      final messagesSnap = await _db
          .table('chats')
          .doc(chatId)
          .table('messages')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      
      bool sentRecently = false;
      final now = DateTime.now();
      for (final doc in messagesSnap.docs) {
        final data = doc.data();
        if (doc.id == messagesSnap.docs.first.id) continue;
        final senderId = data['senderId'] as String?;
        final createdAtRaw = data['createdAt'];
        if (senderId == uid && createdAtRaw != null) {
          final createdAt = (createdAtRaw as Timestamp).toDate();
          if (now.difference(createdAt).inHours < 24) {
            sentRecently = true;
            break;
          }
        }
      }

      if (!sentRecently) {
        Future.delayed(const Duration(milliseconds: 1500), () async {
          final msgRef = _db.table('chats').doc(chatId).table('messages').doc();
          await msgRef.set({
            'senderId': otherUid,
            'type': 'text',
            'cipherText': greetingMessage,
            'mediaUrl': null,
            'fileName': null,
            'durationMs': null,
            'replyToMessageId': null,
            'createdAt': FieldValue.serverTimestamp(),
            'editedAt': null,
            'deletedFor': [],
            'deletedForEveryone': false,
            'reactions': {},
            'starredBy': [],
            'deliveredTo': {
              otherUid: FieldValue.serverTimestamp(),
            },
            'readBy': {
              otherUid: FieldValue.serverTimestamp(),
            },
            'isEncrypted': false,
          });

          await _db.table('chats').doc(chatId).update({
            'lastMessage': greetingMessage,
            'lastMessageSenderId': otherUid,
            'lastMessageAt': FieldValue.serverTimestamp(),
          });
        });
      }
    }
  }

  Future<void> setRecording(String chatId, bool isRecording) {
    return _db.table('chats').doc(chatId).set({
      'recording': {
        uid: isRecording,
      },
    }, SetOptions(merge: true));
  }

  Future<void> markDelivered(String chatId, String messageId) async {
    await _db
        .table('chats')
        .doc(chatId)
        .table('messages')
        .doc(messageId)
        .set({
      'deliveredTo': {
        uid: FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));

    await _db.table('chats').doc(chatId).update({
      'lastMessageDeliveredTo.$uid': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Future<Map<String, dynamic>> _buildDeliveredTo(String chatId, String chatType) async {
    final Map<String, dynamic> deliveredTo = {
      uid: FieldValue.serverTimestamp(),
    };
    try {
      if (chatType == 'private') {
        final chatDoc = await _db.table('chats').doc(chatId).get();
        final memberIds = List<String>.from(chatDoc.data()?['memberIds'] ?? []);
        final otherUid = memberIds.firstWhere((id) => id != uid, orElse: () => uid);
        if (otherUid != uid) {
          final otherUserDoc = await _db.table('users').doc(otherUid).get();
          if (otherUserDoc.data()?['isOnline'] == true) {
            deliveredTo[otherUid] = FieldValue.serverTimestamp();
          }
        }
      }
    } catch (_) {}
    return deliveredTo;
  }

  void _markUndeliveredForThreads(List<ChatThread> threads) {
    _db.table('users').doc(uid).get().then((userDoc) {
      final blockedUsers = List<String>.from(userDoc.data()?['blockedUsers'] ?? []);
      
      for (final chat in threads) {
        _db
            .table('chats')
            .doc(chat.id)
            .table('messages')
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get()
            .then((snap) {
          for (final doc in snap.docs) {
            final data = doc.data();
            final senderId = data['senderId'] as String?;
            final deliveredTo = data['deliveredTo'] as Map<String, dynamic>? ?? {};
            if (senderId != uid && senderId != null && !blockedUsers.contains(senderId) && !deliveredTo.containsKey(uid)) {
              doc.reference.set({
                'deliveredTo': {
                  uid: FieldValue.serverTimestamp(),
                }
              }, SetOptions(merge: true)).catchError((_) {});

              _db.table('chats').doc(chat.id).update({
                'lastMessageDeliveredTo.$uid': FieldValue.serverTimestamp(),
              }).catchError((_) {});
            }
          }
        }).catchError((_) {});
      }
    }).catchError((_) {});
  }
}