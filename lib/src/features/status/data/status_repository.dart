import 'dart:io';

import 'package:a_chatz/src/features/chat/data/chat_repository.dart';
import 'package:a_chatz/src/features/status/domain/status_models.dart';
import 'package:a_chatz/src/features/status/data/link_preview_service.dart';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;

class StatusRepository {
  StatusRepository(this._db, this._auth);

  final AppDatabase _db;
  final AppAuth _auth;

  String get uid => _auth.currentUser!.uid;

  Stream<List<StatusStory>> statuses() {
    return _db
        .table('statuses')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map(
          (snap) {
            final list = snap.docs
                .map((doc) => StatusStory.fromMap(doc.id, doc.data()))
                .where((story) {
                  if (story.ownerId == uid) return true;
                  final privacy = story.privacyOption;
                  if (privacy == 'onlyShareWith') {
                    return story.allowedIds.contains(uid);
                  } else if (privacy == 'contactsExcept') {
                    return !story.excludedIds.contains(uid);
                  }
                  // Fallback for legacy stories
                  if (story.excludedIds.contains(uid)) return false;
                  if (story.allowedIds.isNotEmpty && !story.allowedIds.contains(uid)) return false;
                  return true;
                })
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          },
        );
  }

  Stream<List<StatusStory>> myStatuses() {
    return _db
        .table('statuses')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) {
            final now = Timestamp.now();
            final list = snap.docs
                .map((doc) => StatusStory.fromMap(doc.id, doc.data()))
                .where((story) => story.expiresAt.isAfter(now.toDate()))
                .toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          },
        );
  }

  Future<void> uploadStatus({
    File? file,
    XFile? xFile,
    required StatusType type,
    String? caption,
    String? musicTitle,
    String? musicArtist,
    String? musicPreviewUrl,
    Duration? musicStartTime,
    Duration? musicEndTime,
    int? textBgColor,
    String? podcastTitle,
    int? musicStickerStyle,
    double? musicStickerX,
    double? musicStickerY,
    double? musicStickerScale,
    String? musicLyrics,
    int? musicLyricsOffsetMs,
    bool isPromoted = false,
    List<String>? mentions,
    List<String>? excludedIds,
    List<String>? allowedIds,
    String? privacyOption,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userDoc = await _db.table('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};

    final targetXFile = xFile ?? XFile(file!.path);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${targetXFile.name}';

    final ref = AppStorage.instance
        .ref()
        .child('status_stories/${user.uid}/$fileName');

    final metadata = SettableMetadata(
      contentType: type == StatusType.video
          ? 'video/mp4'
          : (type == StatusType.audio ? 'audio/m4a' : 'image/jpeg'),
    );

    final UploadTask uploadTask;
    if (kIsWeb) {
      final bytes = await targetXFile.readAsBytes();
      uploadTask = ref.putData(bytes, metadata);
    } else {
      uploadTask = ref.putFile(File(targetXFile.path), metadata);
    }
    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();

    final docRef = await _db.table('statuses').add({
      'ownerId': user.uid,
      'ownerName': data['username'] ?? user.email ?? 'A-Chatz User',
      'ownerPhotoUrl': data['photoUrl'],
      'isOwnerVerified': data['isVerified'] ?? false,
      'type': type.name,
      'mediaUrl': url,
      'caption': caption,
      'musicTitle': musicTitle,
      'musicArtist': musicArtist,
      'musicPreviewUrl': musicPreviewUrl,
      'musicStartTimeMs': musicStartTime?.inMilliseconds,
      'musicEndTimeMs': musicEndTime?.inMilliseconds,
      'textBgColor': textBgColor,
      'podcastTitle': podcastTitle,
      'musicStickerStyle': musicStickerStyle,
      'musicStickerX': musicStickerX,
      'musicStickerY': musicStickerY,
      'musicStickerScale': musicStickerScale,
      'musicLyrics': musicLyrics,
      'musicLyricsOffsetMs': musicLyricsOffsetMs,
      'isPromoted': isPromoted,
      'privacyOption': privacyOption,

      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(isPromoted ? const Duration(days: 30) : const Duration(hours: 24)),
      ),
      'seenBy': {},
      'reactions': {},
      'comments': [],
      'resharedFromStatusId': null,
      'resharedFromOwnerName': null,
      'mentions': mentions ?? [],
      'excludedIds': excludedIds ?? [],
      'allowedIds': allowedIds ?? [],
    });

    if (mentions != null && mentions.isNotEmpty) {
      for (final mentionId in mentions) {
        await _db.table('status_notifications').add({
          'type': 'mention',
          'statusId': docRef.id,
          'statusOwnerId': user.uid,
          'actorId': user.uid,
          'actorName': data['username'] ?? user.email ?? 'A-Chatz User',
          'message': '${data['username'] ?? user.email ?? 'Someone'} mentioned you privately',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'notifiedUserId': mentionId, 
        });
      }
    }
  }

  Future<void> uploadTextStatus({
    required String text,
    required int bgColor,
    String? textFont,
    String? musicTitle,
    String? musicArtist,
    String? musicPreviewUrl,
    Duration? musicStartTime,
    Duration? musicEndTime,
    int? musicStickerStyle,
    double? musicStickerX,
    double? musicStickerY,
    double? musicStickerScale,
    String? musicLyrics,
    int? musicLyricsOffsetMs,
    bool isPromoted = false,
    List<String>? mentions,
    List<String>? excludedIds,
    List<String>? allowedIds,
    String? privacyOption,
    String? linkPreviewUrl,
    String? linkPreviewTitle,
    String? linkPreviewDescription,
    String? linkPreviewImage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.table('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};

    final docRef = await _db.table('statuses').add({
      'ownerId': user.uid,
      'ownerName': data['username'] ?? user.email ?? 'A-Chatz User',
      'ownerPhotoUrl': data['photoUrl'],
      'isOwnerVerified': data['isVerified'] ?? false,
      'type': StatusType.text.name,
      'mediaUrl': '',
      'caption': text,
      'textBgColor': bgColor,
      'textFont': textFont,
      'musicTitle': musicTitle,
      'musicArtist': musicArtist,
      'musicPreviewUrl': musicPreviewUrl,
      'musicStartTimeMs': musicStartTime?.inMilliseconds,
      'musicEndTimeMs': musicEndTime?.inMilliseconds,
      'musicStickerStyle': musicStickerStyle,
      'musicStickerX': musicStickerX,
      'musicStickerY': musicStickerY,
      'musicStickerScale': musicStickerScale,
      'musicLyrics': musicLyrics,
      'musicLyricsOffsetMs': musicLyricsOffsetMs,
      'isPromoted': isPromoted,
      'privacyOption': privacyOption,
      'linkPreviewUrl': linkPreviewUrl,
      'linkPreviewTitle': linkPreviewTitle,
      'linkPreviewDescription': linkPreviewDescription,
      'linkPreviewImage': linkPreviewImage,

      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(isPromoted ? const Duration(days: 30) : const Duration(hours: 24)),
      ),
      'seenBy': {},
      'reactions': {},
      'comments': [],
      'resharedFromStatusId': null,
      'resharedFromOwnerName': null,
      'mentions': mentions ?? [],
      'excludedIds': excludedIds ?? [],
      'allowedIds': allowedIds ?? [],
    });

    if (mentions != null && mentions.isNotEmpty) {
      for (final mentionId in mentions) {
        await _db.table('status_notifications').add({
          'type': 'mention',
          'statusId': docRef.id,
          'statusOwnerId': user.uid,
          'actorId': user.uid,
          'actorName': data['username'] ?? user.email ?? 'A-Chatz User',
          'message': '${data['username'] ?? user.email ?? 'Someone'} mentioned you privately',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'notifiedUserId': mentionId, 
        });
      }
    }
  }

  Future<void> markSeen(String statusId) async {
    await _db.table('statuses').doc(statusId).set({
      'seenBy': {
        uid: FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> reactToStatus({
    required StatusStory story,
    required String emoji,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.table('statuses').doc(story.id).set({
      'reactions': {
        uid: emoji,
      },
    }, SetOptions(merge: true));

    if (story.ownerId != uid) {
      await _db.table('status_notifications').add({
        'type': 'reaction',
        'statusId': story.id,
        'statusOwnerId': story.ownerId,
        'actorId': uid,
        'actorName': user.displayName ?? user.email ?? 'A-Chatz User',
        'emoji': emoji,
        'message': '${user.displayName ?? user.email ?? 'Someone'} reacted $emoji to your status',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  Future<void> commentOnStatus({
    required StatusStory story,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.table('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final senderName = data['username'] ?? user.email ?? 'A-Chatz User';

    // Public comments disabled - now sending via private chat directly.
    if (story.ownerId == uid) return;

    final chatRepo = ChatRepository(_db, _auth);
    final chatId = await chatRepo.createPrivateChat(story.ownerId);

    await chatRepo.sendText(
      chatId,
      'Replied to your status: ${text.trim()}',
    );

    await _db.table('status_notifications').add({
      'type': 'comment',
      'statusId': story.id,
      'statusOwnerId': story.ownerId,
      'actorId': uid,
      'actorName': senderName,
      'comment': text.trim(),
      'message': '$senderName replied to your status',
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> reshareStatus(StatusStory story) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.table('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final actorName = data['username'] ?? user.email ?? 'A-Chatz User';

    final docRef = await _db.table('statuses').add({
      'ownerId': user.uid,
      'ownerName': actorName,
      'ownerPhotoUrl': data['photoUrl'],
      'isOwnerVerified': data['isVerified'] ?? false,
      'type': story.type.name,
      'mediaUrl': story.mediaUrl,
      'caption': story.caption,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
      'seenBy': {},
      'reactions': {},
      'comments': [],
      'resharedFromStatusId': story.id,
      'resharedFromOwnerName': story.ownerName,
      'musicTitle': story.musicTitle,
      'musicArtist': story.musicArtist,
      'musicPreviewUrl': story.musicPreviewUrl,
      'musicStartTimeMs': story.musicStartTimeMs,
      'musicEndTimeMs': story.musicEndTimeMs,
      'textBgColor': story.textBgColor,
      'podcastTitle': story.podcastTitle,
      'musicStickerStyle': story.musicStickerStyle,
      'musicStickerX': story.musicStickerX,
      'musicStickerY': story.musicStickerY,
      'musicStickerScale': story.musicStickerScale,
      'musicLyrics': story.musicLyrics,
      'musicLyricsOffsetMs': story.musicLyricsOffsetMs,
    });

    if (story.ownerId != uid) {
      await _db.table('status_notifications').add({
        'type': 'reshare',
        'statusId': story.id,
        'statusOwnerId': story.ownerId,
        'actorId': uid,
        'actorName': actorName,
        'message': '$actorName reshared your status',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  Future<void> updateStatusCaption({
    required String statusId,
    required String newCaption,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final docRef = _db.table('statuses').doc(statusId);
    final doc = await docRef.get();
    if (!doc.exists) throw Exception('Status not found');
    if (doc.data()?['ownerId'] != user.uid) {
      throw Exception('You can only edit your own status');
    }

    await docRef.update({
      'caption': newCaption.trim(),
    });
  }
}