import 'package:a_chatz/src/core/supabase/supabase.dart';

class ModerationRepository {
  ModerationRepository(this._db);
  final AppDatabase _db;

  Stream<List<Map<String, dynamic>>> reportedUsers() {
    return _db
        .table('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> banUser(String userId) {
    return _db.table('users').doc(userId).update({
      'isBanned': true,
      'bannedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unbanUser(String userId) {
    return _db.table('users').doc(userId).update({
      'isBanned': false,
      'bannedAt': null,
    });
  }

  Future<void> dismissReport(String reportId) {
    return _db.table('reports').doc(reportId).update({
      'status': 'dismissed',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolveReport(String reportId, String userId) async {
    final batch = _db.batch();
    
    batch.update(_db.table('reports').doc(reportId), {
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.table('users').doc(userId), {
      'isBanned': true,
      'bannedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
  Stream<List<Map<String, dynamic>>> verificationRequests() {
    return _db
        .table('verification_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> approveVerification(String requestId, String userId, String tier) async {
    final batch = _db.batch();
    
    batch.update(_db.table('verification_requests').doc(requestId), {
      'status': 'approved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.table('users').doc(userId), {
      'isVerified': true,
      'verificationTier': tier.isNotEmpty ? tier : 'business_pro',
    });

    await batch.commit();
  }

  Future<void> rejectVerification(String requestId) {
    return _db.table('verification_requests').doc(requestId).update({
      'status': 'rejected',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeVerification(String userId) async {
    final batch = _db.batch();
    
    final requests = await _db.table('verification_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'approved')
        .get();
        
    for (final doc in requests.docs) {
      batch.update(doc.reference, {
        'status': 'removed',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.update(_db.table('users').doc(userId), {
      'isVerified': false,
      'verificationTier': FieldValue.delete(),
    });

    await batch.commit();
  }
}
