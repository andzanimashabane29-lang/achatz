import 'dart:io';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/features/status/domain/channel_models.dart';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/foundation.dart';

class ChannelRepository {
  ChannelRepository(this._db, this._auth);

  final AppDatabase _db;
  final AppAuth _auth;

  String get uid => _auth.currentUser!.uid;

  Stream<List<Channel>> allChannels() {
    return _db.table('channels').orderBy('followersCount', descending: true).snapshots().map(
          (snap) => snap.docs.map((doc) => Channel.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Future<void> createChannel({
    required String name,
    required String description,
    File? photoFile,
  }) async {
    final channel = Channel(
      id: '', // Firestore will generate this
      ownerId: uid,
      name: name,
      description: description,
      followersCount: 1, // Include owner as a follower
      createdAt: DateTime.now(),
      photoUrl: null,
    );

    final docRef = await _db.table('channels').add(channel.toMap());
    final channelId = docRef.id;

    if (photoFile != null) {
      final storageRef = AppStorage.instance.ref().child('channel_photos/$channelId.jpg');
      final bytes = await photoFile.readAsBytes();
      final uploadTask = await storageRef.putData(bytes);
      final url = await uploadTask.ref.getDownloadURL();
      await docRef.update({'photoUrl': url});
    }

    // Add creator to followed channels list
    await _db.table('users').doc(uid).table('followedChannels').doc(channelId).set({
      'followedAt': FieldValue.serverTimestamp(),
      'role': 'owner',
    });

    // Add creator to channel's followers subcollection
    await _db.table('channels').doc(channelId).table('followers').doc(uid).set({
      'uid': uid,
      'role': 'owner',
      'followedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> followChannel(String channelId) async {
    final channelRef = _db.table('channels').doc(channelId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(channelRef);
      if (!snapshot.exists) return;

      final followersCount = (snapshot.data()?['followersCount'] ?? 0) + 1;
      transaction.update(channelRef, {'followersCount': followersCount});
      
      // Add to user's followed channels
      final userFollowRef = _db.table('users').doc(uid).table('followedChannels').doc(channelId);
      transaction.set(userFollowRef, {
        'followedAt': FieldValue.serverTimestamp(),
        'role': 'member',
      });

      // Add to channel's followers subcollection
      final followerRef = _db.table('channels').doc(channelId).table('followers').doc(uid);
      transaction.set(followerRef, {
        'uid': uid,
        'role': 'member',
        'followedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> unfollowChannel(String channelId) async {
    final channelRef = _db.table('channels').doc(channelId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(channelRef);
      if (!snapshot.exists) return;

      int followersCount = (snapshot.data()?['followersCount'] ?? 0) - 1;
      if (followersCount < 0) followersCount = 0;
      transaction.update(channelRef, {'followersCount': followersCount});
      
      // Remove from user's followed channels
      final userFollowRef = _db.table('users').doc(uid).table('followedChannels').doc(channelId);
      transaction.delete(userFollowRef);

      // Remove from channel's followers subcollection
      final followerRef = _db.table('channels').doc(channelId).table('followers').doc(uid);
      transaction.delete(followerRef);
    });
  }

  Future<void> updateMemberRole(String channelId, String memberId, String role) async {
    final followerRef = _db.table('channels').doc(channelId).table('followers').doc(memberId);
    final userFollowRef = _db.table('users').doc(memberId).table('followedChannels').doc(channelId);

    await _db.runTransaction((transaction) async {
      transaction.update(followerRef, {'role': role});
      transaction.update(userFollowRef, {'role': role});
    });
  }

  Future<void> removeMember(String channelId, String memberId) async {
    final channelRef = _db.table('channels').doc(channelId);
    final followerRef = channelRef.table('followers').doc(memberId);
    final userFollowRef = _db.table('users').doc(memberId).table('followedChannels').doc(channelId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(channelRef);
      if (!snapshot.exists) return;

      int followersCount = (snapshot.data()?['followersCount'] ?? 0) - 1;
      if (followersCount < 0) followersCount = 0;
      transaction.update(channelRef, {'followersCount': followersCount});

      transaction.delete(followerRef);
      transaction.delete(userFollowRef);
    });
  }

  Future<void> sendPostNotification(String channelId, String postText) async {
    try {
      final channelDoc = await _db.table('channels').doc(channelId).get();
      final channelName = channelDoc.data()?['name'] ?? 'Channel';
      final followersSnap = await _db.table('channels').doc(channelId).table('followers').get();
      
      final batch = _db.batch();
      for (final doc in followersSnap.docs) {
        final followerUid = doc.id;
        if (followerUid == uid) continue;
        
        final notifRef = _db.table('users').doc(followerUid).table('notifications').doc();
        batch.set(notifRef, {
          'title': 'New post in $channelName',
          'body': postText.isNotEmpty ? postText : 'Shared a new media post',
          'type': 'channel_post',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to send channel post notifications: $e');
    }
  }

  /// Forwards a [ChatMessage] to a channel's posts subcollection.
  /// Reuses the existing media URL without re-uploading.
  Future<void> forwardToChannel(String channelId, ChatMessage message, String decryptedText) async {
    final postData = <String, dynamic>{
      'senderId': uid,
      'content': decryptedText,
      'caption': decryptedText,
      'reactions': {},
      'createdAt': FieldValue.serverTimestamp(),
      'isForwarded': true,
    };

    if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
      postData['mediaUrl'] = message.mediaUrl;
    }

    switch (message.type) {
      case MessageType.image:
        postData['type'] = 'image';
        postData['imageUrl'] = message.mediaUrl ?? '';
      case MessageType.video:
        postData['type'] = 'video';
        postData['videoUrl'] = message.mediaUrl ?? '';
      case MessageType.voice:
        postData['type'] = 'voice';
        postData['fileUrl'] = message.mediaUrl ?? '';
        postData['fileName'] = message.fileName ?? '';
      case MessageType.document:
        postData['type'] = 'document';
        postData['fileUrl'] = message.mediaUrl ?? '';
        postData['fileName'] = message.fileName ?? '';
      default:
        postData['type'] = 'text';
    }

    await _db
        .table('channels')
        .doc(channelId)
        .table('posts')
        .add(postData);

    await sendPostNotification(
      channelId,
      decryptedText.isNotEmpty ? decryptedText : _postTypeLabel(message.type),
    );
  }

  String _postTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.image:   return '📷 Photo';
      case MessageType.video:   return '🎥 Video';
      case MessageType.voice:   return '🎙️ Voice note';
      case MessageType.document: return '📄 Document';
      default: return 'Forwarded a message';
    }
  }
}
