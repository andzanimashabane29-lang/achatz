import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/shared/widgets/qr_account_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
/// Scan contact / group / channel QR codes from the Chats screen.
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openScanner());
  }

  Future<void> _openScanner() async {
    if (_busy || !mounted) return;
    _busy = true;

    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrAccountScannerScreen()),
    );

    if (!mounted) return;
    _busy = false;

    if (raw == null || raw.isEmpty) {
      context.pop();
      return;
    }

    await _handleScannedValue(raw);
  }

  Future<void> _handleScannedValue(String rawValue) async {
    if (rawValue.startsWith('achatz://')) {
      final uri = Uri.parse(rawValue);
      final pathSegments = uri.pathSegments;

      if (uri.host == 'user' && pathSegments.isNotEmpty) {
        await _handleUserQrCode(pathSegments.first);
      } else if (uri.host == 'group' && pathSegments.isNotEmpty) {
        final groupId = pathSegments.first;
        if (mounted) {
          context.push('/contact-info/$groupId/group').then((_) {
            if (mounted) context.pop();
          });
        }
      } else if (uri.host == 'channel' && pathSegments.isNotEmpty) {
        final channelId = pathSegments.first;
        if (mounted) {
          context.push('/channel/$channelId').then((_) {
            if (mounted) context.pop();
          });
        }
      } else {
        _showError('Invalid A-Chatz QR code');
      }
      return;
    }

    _showError('Unsupported QR code. Use an A-Chatz contact QR (achatz://user/...).');
  }

  Future<void> _handleUserQrCode(String scannedUserId) async {
    final myUid = AppAuth.instance.currentUser?.uid;
    if (myUid == null) {
      _showError('You must be logged in.');
      return;
    }

    if (scannedUserId == myUid) {
      _showError("That's your own QR code!");
      return;
    }

    try {
      final userDoc = await AppDatabase.instance
          .table('users')
          .doc(scannedUserId)
          .get();

      if (!userDoc.exists) {
        _showError('User not found.');
        return;
      }

      final userData = userDoc.data()!;
      final name = userData['username'] ?? userData['email'] ?? 'A-Chatz User';
      final photoUrl = userData['photoUrl'] as String?;
      final email = userData['email'] as String? ?? '';

      if (!mounted) return;
      _showAddContactDialog(
        userId: scannedUserId,
        name: name,
        email: email,
        photoUrl: photoUrl,
      );
    } catch (e) {
      _showError('Could not fetch user details.');
    }
  }

  void _showAddContactDialog({
    required String userId,
    required String name,
    required String email,
    String? photoUrl,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFF2A2A2E),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              const Text(
                'Add Contact?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (mounted) _openScanner();
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _addContactAndOpenChat(
                          userId: userId,
                          name: name,
                          email: email,
                          photoUrl: photoUrl,
                        );
                      },
                      child: const Text('Add Contact'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addContactAndOpenChat({
    required String userId,
    required String name,
    required String email,
    String? photoUrl,
  }) async {
    final myUid = AppAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    try {
      await AppDatabase.instance
          .table('users')
          .doc(myUid)
          .table('contacts')
          .doc(userId)
          .set({
        'displayName': name,
        'email': email,
        'photoUrl': photoUrl ?? '',
        'addedAt': FieldValue.serverTimestamp(),
      });

      final chatsRef = AppDatabase.instance.table('chats');
      final existing = await chatsRef
          .where('participants', arrayContains: myUid)
          .get();

      String? chatId;
      for (final doc in existing.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(userId) && participants.length == 2) {
          chatId = doc.id;
          break;
        }
      }

      chatId ??= (await chatsRef.add({
        'participants': [myUid, userId],
        'memberIds': [myUid, userId],
        'createdAt': FieldValue.serverTimestamp(),
        'isGroup': false,
      }))
          .id;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name added to contacts!')),
        );
        context.pushReplacement('/chat/$chatId');
      }
    } catch (e) {
      _showError('Could not add contact: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _openScanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(color: Color(0xFF00FFB2)),
      ),
    );
  }
}
