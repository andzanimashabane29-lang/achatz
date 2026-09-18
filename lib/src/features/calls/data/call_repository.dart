import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/foundation.dart';

class CallRepository {
  CallRepository(this.db, this.auth);

  final AppDatabase db;
  final AppAuth auth;

  String get uid => auth.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingCalls() {
    return db
        .table('calls')
        .where('ringingUids', arrayContains: uid)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> callStream(String callId) {
    return db.table('calls').doc(callId).snapshots();
  }

  Future<String> startCall({
    required String chatId,
    required List<String> receiverIds,
    required bool isVideo,
    String? chatName,
  }) async {
    final limitedReceivers = receiverIds.length > 49
        ? receiverIds.sublist(0, 49)
        : receiverIds;

    final callRef = db.table('calls').doc();

    // Get caller's name and photo for notifications
    final callerDoc = await db.table('users').doc(uid).get();
    final callerData = callerDoc.data() ?? {};
    final callerName = callerData['username'] as String? ?? 'A-Chatz User';
    final callerPhotoUrl = callerData['photoUrl'] as String?;

    await callRef.set({
      'id': callRef.id,
      'chatId': chatId,
      'callerId': uid,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'receiverIds': limitedReceivers,
      'ringingUids': limitedReceivers,
      'answeredUids': [],
      'activeParticipants': [uid],
      'chatName': chatName,
      'type': isVideo ? 'video' : 'voice',
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
      'answeredAt': null,
      'endedAt': null,
    });

    await db.table('call_history').add({
      'callId': callRef.id,
      'chatId': chatId,
      'callerId': uid,
      'receiverIds': limitedReceivers,
      'type': isVideo ? 'video' : 'voice',
      'status': 'outgoing',
      'createdAt': FieldValue.serverTimestamp(),
      'viewed': false,
    });

    final typeStr = isVideo ? 'Video Call' : 'Voice Call';
    await _postCallSystemMessage(
      chatId: chatId,
      text: '📞 Started $typeStr',
    );

    return callRef.id;
  }

  Future<Map<String, dynamic>?> joinScheduledCall(String meetingId) async {
    final snap = await db.table('scheduled_calls').doc(meetingId).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    final chatId = data['chatId'] as String? ?? '';
    final callType = data['callType'] as String? ?? 'video';
    final title = data['title'] as String? ?? 'Meeting';

    String? activeCallId = data['activeCallId'] as String?;
    bool isCallActive = false;
    if (activeCallId != null && activeCallId.isNotEmpty) {
      final callSnap = await db.table('calls').doc(activeCallId).get();
      if (callSnap.exists) {
        final callStatus = callSnap.data()?['status'] as String?;
        if (callStatus == 'ringing' || callStatus == 'answered') {
          isCallActive = true;
        }
      }
    }

    if (isCallActive) {
      await answerCall(activeCallId!);
      final nameParam = Uri.encodeComponent(title);
      return {
        'callId': activeCallId,
        'caller': false,
        'video': callType == 'video',
        'name': nameParam,
      };
    } else {
      // Start a new call
      final chatSnap = await db.table('chats').doc(chatId).get();
      if (!chatSnap.exists) return null;
      final chatData = chatSnap.data()!;
      final members = List<String>.from(chatData['memberIds'] ?? []);
      final receivers = members.where((id) => id != uid).toList();

      final callId = await startCall(
        chatId: chatId,
        receiverIds: receivers,
        isVideo: callType == 'video',
      );

      await db.table('scheduled_calls').doc(meetingId).update({
        'activeCallId': callId,
      });

      final nameParam = Uri.encodeComponent(title);
      return {
        'callId': callId,
        'caller': true,
        'video': callType == 'video',
        'name': nameParam,
      };
    }
  }

  Future<void> answerCall(String callId) async {
    final snapshot = await db.table('calls').doc(callId).get();
    if (!snapshot.exists) return;
    final data = snapshot.data() ?? {};
    final chatId = data['chatId'] as String?;
    final type = data['type'] as String? ?? 'voice';

    final ringingUids = List<String>.from(data['ringingUids'] ?? []);
    ringingUids.remove(uid);

    final answeredUids = List<String>.from(data['answeredUids'] ?? []);
    if (!answeredUids.contains(uid)) {
      answeredUids.add(uid);
    }

    await db.table('calls').doc(callId).update({
      'ringingUids': ringingUids,
      'answeredUids': answeredUids,
      'status': 'answered',
      'answeredAt': FieldValue.serverTimestamp(),
      'activeParticipants': FieldValue.arrayUnion([uid]),
    });

    await _updateCallHistoryStatus(callId, 'answered');

    if (chatId != null) {
      final typeStr = type == 'video' ? 'Video Call' : 'Voice Call';
      await _postCallSystemMessage(
        chatId: chatId,
        text: '📞 Answered $typeStr',
      );
    }
  }

  Future<void> declineCall(String callId) async {
    final snapshot = await db.table('calls').doc(callId).get();
    if (!snapshot.exists) return;
    final data = snapshot.data() ?? {};
    final chatId = data['chatId'] as String?;
    final type = data['type'] as String? ?? 'voice';

    final ringingUids = List<String>.from(data['ringingUids'] ?? []);
    ringingUids.remove(uid);

    final answeredUids = List<String>.from(data['answeredUids'] ?? []);
    final isLastRingingAndNoneAnswered = ringingUids.isEmpty && answeredUids.isEmpty;

    await db.table('calls').doc(callId).update({
      'ringingUids': ringingUids,
      'status': isLastRingingAndNoneAnswered ? 'declined' : data['status'] ?? 'ringing',
      'endedAt': isLastRingingAndNoneAnswered ? FieldValue.serverTimestamp() : null,
    });

    await _updateCallHistoryStatus(callId, 'declined');

    if (chatId != null && isLastRingingAndNoneAnswered) {
      final typeStr = type == 'video' ? 'Video Call' : 'Voice Call';
      await _postCallSystemMessage(
        chatId: chatId,
        text: '📞 Missed $typeStr',
      );
    }
  }

  Future<void> endCall(String callId) async {
    final snapshot = await db.table('calls').doc(callId).get();
    if (!snapshot.exists) return;
    final data = snapshot.data() ?? {};
    final chatId = data['chatId'] as String?;
    final type = data['type'] as String? ?? 'voice';

    final activeParticipants = List<String>.from(data['activeParticipants'] ?? []);
    activeParticipants.remove(uid);

    final answeredUids = List<String>.from(data['answeredUids'] ?? []);
    answeredUids.remove(uid);

    if (activeParticipants.length <= 1) {
      await db.table('calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'ringingUids': [],
        'answeredUids': answeredUids,
        'activeParticipants': activeParticipants,
      });
    } else {
      await db.table('calls').doc(callId).update({
        'answeredUids': answeredUids,
        'activeParticipants': activeParticipants,
      });
    }

    await _updateCallHistoryStatus(callId, 'ended');

    if (chatId != null) {
      final typeStr = type == 'video' ? 'Video Call' : 'Voice Call';
      String durationStr = '';
      final answeredAt = data['answeredAt'] as Timestamp?;
      if (answeredAt != null) {
        final start = answeredAt.toDate();
        final diff = DateTime.now().difference(start);
        final min = diff.inMinutes;
        final sec = diff.inSeconds % 60;
        durationStr = ' ($min min $sec sec)';
      }

      await _postCallSystemMessage(
        chatId: chatId,
        text: '📞 Ended $typeStr$durationStr',
      );
    }

    try {
      final scheduledQuery = await db
          .table('scheduled_calls')
          .where('activeCallId', isEqualTo: callId)
          .get();
      for (final doc in scheduledQuery.docs) {
        await doc.reference.update({'status': 'completed'});
      }
    } catch (_) {}
  }

  Future<void> saveOffer(String callId, Map<String, dynamic> offer) {
    return db.table('calls').doc(callId).set({
      'offer': offer,
    }, SetOptions(merge: true));
  }

  Future<void> saveAnswer(String callId, Map<String, dynamic> answer) {
    return db.table('calls').doc(callId).set({
      'answer': answer,
    }, SetOptions(merge: true));
  }

  Future<void> addIceCandidate({
    required String callId,
    required Map<String, dynamic> candidate,
    required bool caller,
  }) {
    return db
        .table('calls')
        .doc(callId)
        .table(caller ? 'callerCandidates' : 'receiverCandidates')
        .add(candidate);
  }

  Future<void> _updateCallHistoryStatus(String callId, String newStatus) async {
    final query = await db.table('call_history').where('callId', isEqualTo: callId).get();
    for (final doc in query.docs) {
      await doc.reference.update({'status': newStatus});
    }
  }

  Future<void> _postCallSystemMessage({
    required String chatId,
    required String text,
  }) async {
    final senderId = auth.currentUser?.uid ?? 'system';

    // 1. Add call event to chat messages
    await db.table('chats').doc(chatId).table('messages').add({
      'senderId': senderId,
      'type': 'system',
      'cipherText': text,
      'mediaUrl': null,
      'fileName': null,
      'durationMs': null,
      'replyToMessageId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'editedAt': null,
      'deletedFor': [],
      'seenBy': {},
      'isEncrypted': false,
    });

    // 2. Update the chat room lastMessage
    await db.table('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }
}