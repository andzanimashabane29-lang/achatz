import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class DeviceLinkingService {
  static final DeviceLinkingService instance = DeviceLinkingService._internal();

  DeviceLinkingService._internal();

  StreamSubscription? _subscription;
  final Set<String> _processedRequests = {};
  
  // We need a GlobalKey to show dialogs without context if needed, 
  // or we can pass a context. For now, assuming a root navigator key is available,
  // or we just emit an event. Let's provide an initialization with a context 
  // or just use a stream that the root widget can listen to.
  
  // Actually, we can use a provider to listen to it, but a singleton service is easier if we have a global key.
  // Alternatively, we can just use the auth stream to start/stop listening.

  void startListening(BuildContext context) {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _subscription?.cancel();
    _subscription = AppDatabase.instance
        .table('device_linking_requests')
        .where('targetUid', isEqualTo: uid)
        .where('status', whereIn: ['pending', 'failed'])
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final requestId = change.doc.id;
        final code = data['code'] as String?;
        final status = data['status'] as String?;

        // If it's a new request or the code changed (e.g., after a failure)
        if (code != null && (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified)) {
          // Keep track of processed specific codes for this request so we don't show the same popup multiple times
          final uniqueKey = '${requestId}_$code';
          if (!_processedRequests.contains(uniqueKey)) {
            _processedRequests.add(uniqueKey);
            _showCodeDialog(context, code, status == 'failed');
          }
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _processedRequests.clear();
  }

  void _showCodeDialog(BuildContext context, String code, bool isRetry) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.important_devices, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Device Linking Request', style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRetry)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'The previous code was entered incorrectly. Please use this new code.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Someone is trying to link a new device to your account. Enter this code on the other device:',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'If this was not you, please ignore this message.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }
}
