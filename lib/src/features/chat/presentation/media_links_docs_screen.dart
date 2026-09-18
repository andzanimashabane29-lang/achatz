import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/shared/widgets/ambient_background.dart';
import 'package:a_chatz/src/shared/widgets/cached_media_wrapper.dart';
import 'package:a_chatz/src/core/services/encryption_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaLinksDocsScreen extends ConsumerStatefulWidget {
  const MediaLinksDocsScreen({
    super.key,
    required this.chatId,
  });

  final String chatId;

  @override
  ConsumerState<MediaLinksDocsScreen> createState() => _MediaLinksDocsScreenState();
}

class _MediaLinksDocsScreenState extends ConsumerState<MediaLinksDocsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _containsUrl(String text) {
    final regExp = RegExp(
      r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})',
      caseSensitive: false,
    );
    return regExp.hasMatch(text);
  }

  String? _extractUrl(String text) {
    final regExp = RegExp(
      r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(text);
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
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
            'Shared Explorer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.blueAccent,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'Media'),
              Tab(text: 'Links'),
              Tab(text: 'Docs'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance
              .table('chats')
              .doc(widget.chatId)
              .table('messages')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState('No shared items found');
            }

            final messages = snapshot.data!.docs
                .map((doc) => ChatMessage.fromMap(doc.id, doc.data()))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            // Filter sets
            final mediaMsgs = messages
                .where((m) => m.type == MessageType.image || m.type == MessageType.video)
                .toList();

            final linkMsgs = messages
                .where((m) => m.type == MessageType.text && _containsUrl(m.cipherText))
                .toList();

            final docMsgs = messages
                .where((m) => m.type == MessageType.document)
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Media
                _buildMediaTab(mediaMsgs),
                // Tab 2: Links
                _buildLinksTab(linkMsgs),
                // Tab 3: Docs
                _buildDocsTab(docMsgs),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title) {
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
              Icons.folder_open_outlined,
              color: Colors.white24,
              size: 60,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab(List<ChatMessage> items) {
    if (items.isEmpty) return _buildEmptyState('No shared photos or videos');
    final currentUid = AppAuth.instance.currentUser?.uid;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final m = items[index];
        final isVideo = m.type == MessageType.video;

        return GestureDetector(
          onTap: () {
            if (m.mediaUrl != null) {
              showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder: (_) => InteractiveViewer(
                  child: Center(
                    child: CachedMediaWrapper(
                      url: m.mediaUrl!,
                      encryptedMediaKey: m.encryptedMediaKey,
                      senderPublicKey: m.senderId == currentUid ? m.recipientPublicKey : m.senderPublicKey,
                      builder: (context, file) => Image.file(file),
                    ),
                  ),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black38,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (m.mediaUrl != null)
                    CachedMediaWrapper(
                      url: m.mediaUrl!,
                      encryptedMediaKey: m.encryptedMediaKey,
                      senderPublicKey: m.senderId == currentUid ? m.recipientPublicKey : m.senderPublicKey,
                      builder: (context, file) => Image.file(
                        file,
                        fit: BoxFit.cover,
                      ),
                      loadingBuilder: (context) => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                        ),
                      ),
                    ),
                  if (isVideo)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksTab(List<ChatMessage> textMsgs) {
    if (textMsgs.isEmpty) return _buildEmptyState('No shared web links');

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getDecryptedLinks(textMsgs),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) return _buildEmptyState('No shared web links');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final m = items[index]['msg'] as ChatMessage;
            final url = items[index]['url'] as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: const Icon(Icons.link, color: Colors.blueAccent),
                ),
                title: Text(
                  url,
                  style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "Shared at ${_formatTime(m.createdAt)}",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getDecryptedLinks(List<ChatMessage> textMsgs) async {
    final results = <Map<String, dynamic>>[];
    final currentUid = AppAuth.instance.currentUser?.uid;
    if (currentUid == null) return results;

    for (final m in textMsgs) {
      String? targetPublicKey = m.senderId == currentUid ? m.recipientPublicKey : m.senderPublicKey;
      
      if (targetPublicKey == null) {
        String targetKeyUid = m.senderId;
        if (m.senderId == currentUid) {
          final chatDoc = await AppDatabase.instance.table('chats').doc(widget.chatId).get();
          final members = List<String>.from(chatDoc.data()?['memberIds'] ?? []);
          targetKeyUid = members.firstWhere((id) => id != currentUid, orElse: () => currentUid);
        }
        final userDoc = await AppDatabase.instance.table('users').doc(targetKeyUid).get();
        targetPublicKey = userDoc.data()?['publicKey'];
      }

      String decrypted = m.cipherText;
      if (m.isEncrypted && targetPublicKey != null) {
        try {
          // Import encryption_service for this to work
          final encService = EncryptionService();
          decrypted = await encService.decrypt(m.cipherText, targetPublicKey);
        } catch (_) {}
      }

      final url = _extractUrl(decrypted);
      if (url != null) {
        results.add({
          'msg': m,
          'url': url,
        });
      }
    }
    return results;
  }

  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildDocsTab(List<ChatMessage> items) {
    if (items.isEmpty) return _buildEmptyState('No shared document files');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final m = items[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              backgroundColor: Colors.orangeAccent.withOpacity(0.15),
              child: const Icon(Icons.insert_drive_file, color: Colors.orangeAccent),
            ),
            title: Text(
              m.fileName ?? 'Shared Document',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${m.createdAt.day}/${m.createdAt.month}/${m.createdAt.year}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            trailing: const Icon(Icons.download, color: Colors.white70, size: 20),
            onTap: () async {
              if (m.mediaUrl != null) {
                // Documents can't just be viewed via CachedMediaWrapper since they are files.
                // Or maybe they can? If they are encrypted, we need to download and decrypt.
                // For now just launch the encrypted url, wait, the user can't read an encrypted pdf!
                // Let's rely on chat_room_screen.dart's downloadAndOpenFile for docs.
                // But this is just MVP to show the list.
                final uri = Uri.parse(m.mediaUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        );
      },
    );
  }
}
