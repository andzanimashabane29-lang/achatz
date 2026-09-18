import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/features/chat/presentation/chats_screen.dart'; // To reuse _ChatListTile if possible, wait, _ChatListTile is private.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/features/chat/presentation/chat_room_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LockedChatsScreen extends ConsumerStatefulWidget {
  const LockedChatsScreen({super.key});

  @override
  ConsumerState<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends ConsumerState<LockedChatsScreen> {
  String? _selectedChatId;

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(myChatsProvider);
    final currentUid = ref.watch(chatRepositoryProvider).uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        title: const Text('Locked Chats', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: chats.when(
        data: (items) {
          final lockedChats = items.where((c) => c.lockedBy.contains(currentUid)).toList();

          if (lockedChats.isEmpty) {
            return const Center(child: Text('No locked chats.', style: TextStyle(color: Colors.white70)));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: lockedChats.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF202024)),
            itemBuilder: (_, i) {
              final chat = lockedChats[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2A2A2D),
                  backgroundImage: chat.photoUrl != null ? CachedNetworkImageProvider(chat.photoUrl!) : null,
                  child: chat.photoUrl == null
                      ? Icon(chat.isGroup ? Icons.group : Icons.person, color: Colors.white54)
                      : null,
                ),
                title: Text(chat.title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Locked', style: TextStyle(color: Colors.white54)),
                onTap: () {
                  context.push('/chat/${chat.id}');
                },
                onLongPress: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text('Unlock Chat', style: TextStyle(color: Colors.white)),
                      content: const Text('This chat will be moved back to the main list.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unlock', style: TextStyle(color: Colors.greenAccent))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(chatRepositoryProvider).toggleLockChat(chat.id, true);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
