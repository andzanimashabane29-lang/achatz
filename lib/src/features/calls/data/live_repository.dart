import 'package:a_chatz/src/features/calls/domain/live_session.dart';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LiveRepository {
  LiveRepository(this.db, this.auth);

  final AppDatabase db;
  final AppAuth auth;

  String get uid => auth.currentUser!.uid;

  // Create live session
  Future<String> createLiveSession({
    required String title,
    required String hostName,
    String? hostPhotoUrl,
    required List<String> friendUids,
  }) async {
    // 1. End any active live sessions by this user
    final activeQuery = await db
        .table('live_sessions')
        .where('hostId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    for (final doc in activeQuery.docs) {
      await doc.reference.update({'status': 'ended'});
    }

    // 2. Create the live session
    final sessionRef = db.table('live_sessions').doc();
    final newSession = LiveSession(
      id: sessionRef.id,
      hostId: uid,
      hostName: hostName,
      hostPhotoUrl: hostPhotoUrl,
      title: title,
      viewerCount: 0,
      status: 'active',
      createdAt: DateTime.now(),
    );

    await sessionRef.set(newSession.toMap());

    // 3. Write to live_notifications so Cloud Functions can trigger push notifications
    if (friendUids.isNotEmpty) {
      await db.table('live_notifications').add({
        'hostId': uid,
        'hostName': hostName,
        'title': title,
        'friendUids': friendUids,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return sessionRef.id;
  }

  // End live session
  Future<void> endLiveSession(String sessionId) async {
    await db.table('live_sessions').doc(sessionId).update({
      'status': 'ended',
    });
  }

  // Join live session (increment viewer count)
  Future<void> joinLiveSession(String sessionId) async {
    final sessionRef = db.table('live_sessions').doc(sessionId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(sessionRef);
      if (snapshot.exists) {
        final currentCount = snapshot.data()?['viewerCount'] as int? ?? 0;
        transaction.update(sessionRef, {'viewerCount': currentCount + 1});
      }
    });
  }

  // Leave live session (decrement viewer count)
  Future<void> leaveLiveSession(String sessionId) async {
    final sessionRef = db.table('live_sessions').doc(sessionId);
    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(sessionRef);
      if (snapshot.exists) {
        final data = snapshot.data();
        final currentCount = data?['viewerCount'] as int? ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;
        
        final updates = <String, dynamic>{'viewerCount': newCount};
        
        // If the person leaving is the co-host, clear their co-host status
        if (data?['coHostId'] == uid) {
          updates['coHostId'] = FieldValue.delete();
          updates['coHostName'] = FieldValue.delete();
          updates['coHostPhotoUrl'] = FieldValue.delete();
          updates['coHostStatus'] = FieldValue.delete();
        }
        
        transaction.update(sessionRef, updates);
      }
    });
  }

  // Send a comment in live stream
  Future<void> sendComment({
    required String sessionId,
    required String text,
    required String userName,
    String? userPhotoUrl,
  }) async {
    final commentRef = db
        .table('live_sessions')
        .doc(sessionId)
        .table('comments')
        .doc();

    final newComment = LiveComment(
      id: commentRef.id,
      userId: uid,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      text: text,
      createdAt: DateTime.now(),
    );

    await commentRef.set(newComment.toMap());
  }

  // Send a reaction in live stream
  Future<void> sendReaction({
    required String sessionId,
    required String type,
  }) async {
    await db
        .table('live_sessions')
        .doc(sessionId)
        .table('reactions')
        .add({
      'userId': uid,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream active live sessions hosted by contacts/friends
  Stream<List<LiveSession>> watchActiveSessions(List<String> contactUids) {
    if (contactUids.isEmpty) {
      return Stream.value([]);
    }

    // Firestore `whereIn` limit is 30. If contacts > 30, we take top 30
    final limitedUids = contactUids.length > 30 ? contactUids.sublist(0, 30) : contactUids;

    return db
        .table('live_sessions')
        .where('hostId', whereIn: limitedUids)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LiveSession.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Stream single live session
  Stream<LiveSession?> watchSession(String sessionId) {
    return db
        .table('live_sessions')
        .doc(sessionId)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return null;
          return LiveSession.fromMap(snap.id, snap.data()!);
        });
  }

  // Stream comments in real-time
  Stream<List<LiveComment>> watchComments(String sessionId) {
    return db
        .table('live_sessions')
        .doc(sessionId)
        .table('comments')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LiveComment.fromMap(doc.id, doc.data()))
            .toList()
            .reversed // Display oldest first
            .toList());
  }

  // Stream reactions in real-time
  Stream<QuerySnapshot<Map<String, dynamic>>> watchReactions(String sessionId) {
    return db
        .table('live_sessions')
        .doc(sessionId)
        .table('reactions')
        .snapshots();
  }

  // Stream invited co-host sessions
  Stream<List<LiveSession>> watchInvitedCoHostSessions() {
    return db
        .table('live_sessions')
        .where('coHostId', isEqualTo: uid)
        .where('coHostStatus', isEqualTo: 'invited')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LiveSession.fromMap(doc.id, doc.data()))
            .toList());
  }

  // --- CO-HOST JOIN LOGIC ---

  Future<void> requestToJoinLive({
    required String sessionId,
    required String userName,
    String? userPhotoUrl,
  }) async {
    await db
        .table('live_sessions')
        .doc(sessionId)
        .table('join_requests')
        .doc(uid)
        .set({
      'userId': uid,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchJoinRequests(String sessionId) {
    return db
        .table('live_sessions')
        .doc(sessionId)
        .table('join_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Future<void> approveJoinRequest(String sessionId, String requestUid) async {
    // 1. Update the request status
    await db
        .table('live_sessions')
        .doc(sessionId)
        .table('join_requests')
        .doc(requestUid)
        .update({'status': 'approved'});
        
    // 2. Add to co_hosts subcollection
    await db
        .table('live_sessions')
        .doc(sessionId)
        .table('co_hosts')
        .doc(requestUid)
        .set({
      'userId': requestUid,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<String>> watchApprovedCoHosts(String sessionId) {
    return db
        .table('live_sessions')
        .doc(sessionId)
        .table('co_hosts')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }

  Future<void> removeCoHost(String sessionId, String coHostUid) async {
    await db
        .table('live_sessions')
        .doc(sessionId)
        .table('co_hosts')
        .doc(coHostUid)
        .delete();
    
    await db
        .table('live_sessions')
        .doc(sessionId)
        .table('join_requests')
        .doc(coHostUid)
        .delete();
  }
}

// Providers
final liveRepositoryProvider = Provider<LiveRepository>((ref) {
  return LiveRepository(
    AppDatabase.instance,
    AppAuth.instance,
  );
});

final activeLiveSessionsProvider = StreamProvider.family<List<LiveSession>, List<String>>((ref, contactUids) {
  return ref.watch(liveRepositoryProvider).watchActiveSessions(contactUids);
});

final liveSessionStreamProvider = StreamProvider.family<LiveSession?, String>((ref, sessionId) {
  return ref.watch(liveRepositoryProvider).watchSession(sessionId);
});

final liveCommentsStreamProvider = StreamProvider.family<List<LiveComment>, String>((ref, sessionId) {
  return ref.watch(liveRepositoryProvider).watchComments(sessionId);
});

final invitedCoHostSessionsProvider = StreamProvider<List<LiveSession>>((ref) {
  return ref.watch(liveRepositoryProvider).watchInvitedCoHostSessions();
});

final approvedCoHostsProvider = StreamProvider.family<List<String>, String>((ref, sessionId) {
  return ref.watch(liveRepositoryProvider).watchApprovedCoHosts(sessionId);
});

final joinRequestsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, sessionId) {
  return ref.watch(liveRepositoryProvider).watchJoinRequests(sessionId);
});
