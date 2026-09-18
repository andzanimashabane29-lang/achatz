import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/shared/widgets/ambient_background.dart';

class StarredMessagesScreen extends ConsumerWidget {
  const StarredMessagesScreen({
    super.key,
    required this.chatId,
  });

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = AppAuth.instance.currentUser?.uid ?? '';

    return AmbientBackground(
      theme: ChatThemePreset.neonEclipse,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Starred Messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance
              .table('chats')
              .doc(chatId)
              .table('messages')
              .where('starredBy', arrayContains: currentUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(
                        Icons.star_outline,
                        color: Colors.white30,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Starred Messages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap and hold any message in your chat\nto star it for quick reference.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            final messages = snapshot.data!.docs
                .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final mine = msg.senderId == currentUid;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            future: AppDatabase.instance
                                .table('users')
                                .doc(msg.senderId)
                                .get(),
                            builder: (context, userSnap) {
                              final name = userSnap.data?.data()?['username'] ??
                                  (mine ? 'You' : 'User');
                              return Text(
                                name,
                                style: TextStyle(
                                  color: mine ? Colors.greenAccent : Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.star, color: Colors.amber, size: 20),
                            onPressed: () async {
                              // Unstar message action
                              await ref
                                  .read(chatRepositoryProvider)
                                  .toggleStarMessage(chatId, msg.id, true);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (msg.type == MessageType.text)
                        Text(
                          msg.cipherText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        )
                      else if (msg.type == MessageType.image)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: msg.mediaUrl != null
                              ? Image.network(
                                  msg.mediaUrl!,
                                  fit: BoxFit.cover,
                                  height: 200,
                                  width: double.infinity,
                                )
                              : const SizedBox(),
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              msg.type == MessageType.video
                                  ? Icons.videocam
                                  : msg.type == MessageType.voice
                                      ? Icons.mic
                                      : Icons.attach_file,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              msg.type == MessageType.video
                                  ? 'Shared Video'
                                  : msg.type == MessageType.voice
                                      ? 'Shared Voice Note'
                                      : msg.fileName ?? 'Shared Attachment',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
