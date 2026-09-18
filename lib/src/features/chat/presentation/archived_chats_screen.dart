import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:a_chatz/src/shared/widgets/ambient_background.dart';

class ArchivedChatsScreen extends ConsumerStatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  ConsumerState<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends ConsumerState<ArchivedChatsScreen> {
  @override
  Widget build(BuildContext context) {
    final archivedChatsAsync = ref.watch(archivedChatsProvider);

    return AmbientBackground(
      theme: ChatThemePreset.neonEclipse,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Archived Chats',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
            ),
          ),
        ),
        body: archivedChatsAsync.when(
          skipLoadingOnReload: true,
          data: (chats) {
            if (chats.isEmpty) {
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
                      child: const Icon(Icons.archive_outlined, color: Colors.white38, size: 48),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No archived chats',
                      style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chats you archive will appear here.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: chats.length,
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(left: 80),
                child: Divider(color: Colors.white10, height: 1),
              ),
              itemBuilder: (_, index) {
                final chat = chats[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF2A2A2D),
                        backgroundImage: chat.photoUrl != null && chat.photoUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(chat.photoUrl!)
                            : null,
                        child: chat.photoUrl == null || chat.photoUrl!.isEmpty
                            ? Icon(chat.isGroup ? Icons.group_outlined : Icons.person_outline, color: Colors.white54, size: 26)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.archive, size: 10, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    chat.title.isEmpty ? 'Private Chat' : chat.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    chat.lastMessage?.isNotEmpty == true ? chat.lastMessage! : 'Archived thread',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  onTap: () {
                    context.push('/chat/${chat.id}');
                  },
                  onLongPress: () => _showArchivedOptions(chat),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
        ),
      ),
    );
  }

  void _showArchivedOptions(ChatThread chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.unarchive_outlined, color: Colors.greenAccent),
                title: const Text('Unarchive Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(chatRepositoryProvider).unarchiveChat(chat.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chat unarchived successfully'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete Chat', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
                      content: const Text('Are you sure you want to permanently delete this chat thread and all its messages?', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(chatRepositoryProvider).deleteChat(chat.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chat deleted'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
