import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-clear all unread notifications when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final batch = AppDatabase.instance.batch();
      final snap = await AppDatabase.instance
          .table('notifications')
          .where('recipientUid', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .get();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _clearAll() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1F),
        title: const Text('Clear Notifications', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete all notifications.', style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final batch = AppDatabase.instance.batch();
      final snap = await AppDatabase.instance
          .table('notifications')
          .where('recipientUid', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _clearAll,
            child: const Text(
              'Clear all',
              style: TextStyle(color: Color(0xFFFF6B35)),
            ),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<QuerySnapshot>(
              stream: AppDatabase.instance
                  .table('notifications')
                  .where('recipientUid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: Colors.white24,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'All caught up! 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No new notifications right now.',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _NotificationTile(data: data, docId: docs[i].id);
                  },
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.data, required this.docId});

  final Map<String, dynamic> data;
  final String docId;

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'general';
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final read = data['read'] as bool? ?? true;
    final createdAtRaw = data['createdAt'];

    DateTime? createdAt;
    try {
      createdAt = createdAtRaw?.toDate() as DateTime?;
    } catch (_) {}

    final icon = _iconForType(type);
    final color = _colorForType(type);

    return Container(
      decoration: BoxDecoration(
        color: read
            ? Colors.white.withOpacity(0.04)
            : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: read ? Colors.white.withOpacity(0.06) : color.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: read ? FontWeight.w500 : FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            if (!read)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                _formatTime(createdAt),
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      case 'call':
        return Icons.call_outlined;
      case 'missed_call':
        return Icons.call_missed;
      case 'status':
        return Icons.circle_outlined;
      case 'mention':
        return Icons.alternate_email;
      case 'reaction':
        return Icons.favorite_border;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'security':
        return Icons.shield_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'message':
        return const Color(0xFF34B7F1);
      case 'call':
        return Colors.green;
      case 'missed_call':
        return Colors.red;
      case 'status':
        return const Color(0xFF9B5CF6);
      case 'mention':
        return const Color(0xFFFF8E53);
      case 'reaction':
        return Colors.pink;
      case 'warning':
        return Colors.orange;
      case 'security':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat.E().format(dt);
    return DateFormat.MMMd().format(dt);
  }
}
