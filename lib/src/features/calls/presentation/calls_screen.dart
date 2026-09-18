import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/features/calls/data/call_repository.dart';
import 'package:a_chatz/src/features/calls/providers/call_providers.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/features/profile/presentation/verification_info_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _markMissedCallsViewed();
    // Auto-clear missed call badges when user views the Missed tab
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _markMissedCallsViewed();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markMissedCallsViewed() async {
    final currentUid = AppAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    try {
      final batch = AppDatabase.instance.batch();
      final snap = await AppDatabase.instance
          .table('call_history')
          .where('receiverIds', arrayContains: currentUid)
          .where('viewed', isEqualTo: false)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final isMissed = status == 'missed' ||
            status == 'declined' ||
            status == 'ringing' ||
            status == 'outgoing';
        if (isMissed) {
          batch.update(doc.reference, {'viewed': true});
        }
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUid = AppAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return const LuxuryScaffold(
        child: Center(child: Text('Not logged in')),
      );
    }

    return LuxuryScaffold(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Calls',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined),
                tooltip: 'New Call',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Search for a contact to call'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Tab Bar ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              padding: const EdgeInsets.all(4),
              tabs: [
                const Tab(text: 'All Calls'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Missed'),
                      const SizedBox(width: 6),
                      _MissedBadge(currentUid: currentUid),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Tab Views ─────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CallsList(currentUid: currentUid, missedOnly: false),
                _CallsList(currentUid: currentUid, missedOnly: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Missed Badge ────────────────────────────────────────────────────────────

class _MissedBadge extends StatelessWidget {
  const _MissedBadge({required this.currentUid});
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AppDatabase.instance
          .table('call_history')
          .where('receiverIds', arrayContains: currentUid)
          .where('viewed', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        final allDocs = snap.data?.docs ?? [];
        final missedCount = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          return status == 'missed' ||
              status == 'declined' ||
              status == 'ringing';
        }).length;

        if (missedCount == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$missedCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

// ── Calls List ──────────────────────────────────────────────────────────────

class _CallsList extends StatelessWidget {
  const _CallsList({required this.currentUid, required this.missedOnly});
  final String currentUid;
  final bool missedOnly;

  bool _isMissedCall(Map<String, dynamic> data, String currentUid) {
    final callerId = data['callerId'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final isOutgoing = callerId == currentUid;
    return status == 'missed' ||
        (!isOutgoing && (status == 'declined' || status == 'ringing'));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AppDatabase.instance
          .table('call_history')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        var calls = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final callerId = data['callerId'] as String? ?? '';
          final receiverIds = List<String>.from(data['receiverIds'] ?? []);
          return callerId == currentUid || receiverIds.contains(currentUid);
        }).toList();

        if (missedOnly) {
          calls = calls.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return _isMissedCall(data, currentUid);
          }).toList();
        }

        if (calls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  missedOnly ? Icons.call_missed : Icons.call_outlined,
                  size: 64,
                  color: missedOnly
                      ? Colors.red.withOpacity(0.4)
                      : const Color(0xFF3A3A3A),
                ),
                const SizedBox(height: 16),
                Text(
                  missedOnly ? 'No missed calls 🎉' : 'No recent calls yet.',
                  style: const TextStyle(
                    color: Color(0xFFA7A7A7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  missedOnly
                      ? 'All your calls were answered.'
                      : 'Your call history will appear here.',
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: calls.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, index) {
            final data = calls[index].data() as Map<String, dynamic>;
            final docId = calls[index].id;
            return Dismissible(
              key: ValueKey(docId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) async {
                try {
                  await AppDatabase.instance.table('call_history').doc(docId).delete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Call deleted')),
                    );
                  }
                } catch (e) {
                  // Handle error quietly
                }
              },
              child: _CallHistoryTile(
                data: data,
                currentUid: currentUid,
                docId: docId,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Call History Tile ───────────────────────────────────────────────────────

class _CallHistoryTile extends ConsumerWidget {
  const _CallHistoryTile({super.key, required this.data, required this.currentUid, required this.docId});

  final Map<String, dynamic> data;
  final String currentUid;
  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callerId = data['callerId'] as String? ?? '';
    final receiverIds = List<String>.from(data['receiverIds'] ?? []);
    final type = data['type'] as String? ?? 'voice';
    final status = data['status'] as String? ?? 'outgoing';
    final createdAtRaw = data['createdAt'];

    final isOutgoing = callerId == currentUid;
    final otherUserId =
        isOutgoing ? (receiverIds.isNotEmpty ? receiverIds.first : '') : callerId;

    DateTime? createdAt;
    try {
      createdAt = createdAtRaw?.toDate() as DateTime?;
    } catch (_) {}

    final isMissed = status == 'missed' ||
        (!isOutgoing && (status == 'declined' || status == 'ringing'));

    final IconData callIcon;
    final Color iconColor;

    if (isMissed) {
      callIcon = Icons.call_missed;
      iconColor = Colors.red;
    } else if (isOutgoing) {
      callIcon = Icons.call_made;
      iconColor = Colors.green;
    } else {
      callIcon = Icons.call_received;
      iconColor = Colors.green;
    }

    return FutureBuilder<DocumentSnapshot>(
      future: AppDatabase.instance.table('users').doc(otherUserId).get(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final username = userData?['username'] ?? 'Unknown';
        final photoUrl = userData?['photoUrl'] as String?;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isMissed
                ? Colors.red.withOpacity(0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white10,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isMissed ? Colors.red : Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Icon(callIcon, size: 8, color: Colors.white),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isMissed ? Colors.red : null,
                    ),
                  ),
                ),
                if (userData?['isVerified'] == true || otherUserId == 'official_a_chatz') ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => showVerificationInfoDialog(context),
                    child: const Icon(Icons.verified, size: 14, color: Colors.blueAccent),
                  ),
                ],
              ],
            ),
            subtitle: Row(
              children: [
                Icon(callIcon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  isMissed
                      ? 'Missed'
                      : isOutgoing
                          ? 'Outgoing'
                          : 'Incoming',
                  style: TextStyle(
                    fontSize: 12,
                    color: isMissed ? Colors.red.withOpacity(0.7) : Colors.grey,
                  ),
                ),
                if (createdAt != null) ...[
                  const Text(' · ', style: TextStyle(color: Colors.grey)),
                  Text(
                    _formatTime(createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(
                  type == 'video' ? Icons.videocam : Icons.call,
                  size: 13,
                  color: Colors.grey,
                ),
              ],
            ),
            onLongPress: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text('Delete Call Record', style: TextStyle(color: Colors.white)),
                  content: const Text('Are you sure you want to delete this call record?', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await AppDatabase.instance.table('call_history').doc(docId).delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call deleted')));
                          }
                        } catch (_) {}
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
            onTap: () async {
                String chatId = data['chatId'] as String? ?? '';
                if (chatId.isEmpty) {
                  // Fallback: Create or find chat via ChatRepository
                  final chatRepo = ref.read(chatRepositoryProvider);
                  chatId = await chatRepo.createPrivateChat(otherUserId);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Calling $username...')),
                );

                // Fetch current chat members to set as receivers
                final chatDoc = await AppDatabase.instance.table('chats').doc(chatId).get();
                final chatData = chatDoc.data() ?? {};
                final members = List<String>.from(chatData['memberIds'] ?? []);
                final receivers = members.where((id) => id != currentUid).toList();
                if (receivers.isEmpty && otherUserId.isNotEmpty) {
                  receivers.add(otherUserId);
                }

                final isVideo = type == 'video';
                final chatTitle = chatData['title'] ?? username;

                final callId = await ref.read(callRepositoryProvider).startCall(
                      chatId: chatId,
                      receiverIds: receivers,
                      isVideo: isVideo,
                      chatName: chatTitle,
                );

                if (context.mounted) {
                  final nameParam = Uri.encodeComponent(chatTitle);
                  final photoParam = photoUrl != null ? Uri.encodeComponent(photoUrl) : '';
                  context.push('/call-room/$callId?caller=true&video=$isVideo&name=$nameParam&photoUrl=$photoParam');
                }
            },
            trailing: IconButton(
              icon: Icon(
                type == 'video' ? Icons.videocam : Icons.call,
                color: const Color(0xFFFF6B35),
              ),
              onPressed: () async {
                // Web restriction removed

                String chatId = data['chatId'] as String? ?? '';
                if (chatId.isEmpty) {
                  final chatRepo = ref.read(chatRepositoryProvider);
                  chatId = await chatRepo.createPrivateChat(otherUserId);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Calling $username...')),
                );

                // Fetch current chat members to set as receivers
                final chatDoc = await AppDatabase.instance.table('chats').doc(chatId).get();
                final chatData = chatDoc.data() ?? {};
                final members = List<String>.from(chatData['memberIds'] ?? []);
                final receivers = members.where((id) => id != currentUid).toList();
                if (receivers.isEmpty && otherUserId.isNotEmpty) {
                  receivers.add(otherUserId);
                }

                final isVideo = type == 'video';
                final chatTitle = chatData['title'] ?? username;

                final callId = await ref.read(callRepositoryProvider).startCall(
                      chatId: chatId,
                      receiverIds: receivers,
                      isVideo: isVideo,
                      chatName: chatTitle,
                );

                if (context.mounted) {
                  final nameParam = Uri.encodeComponent(chatTitle);
                  final photoParam = photoUrl != null ? Uri.encodeComponent(photoUrl) : '';
                  context.push('/call-room/$callId?caller=true&video=$isVideo&name=$nameParam&photoUrl=$photoParam');
                }
              },
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat.jm().format(dt);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(dt);
    }
    return DateFormat.MMMd().format(dt);
  }
}