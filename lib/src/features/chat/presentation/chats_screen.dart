import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/features/chat/providers/contacts_provider.dart';
import 'package:a_chatz/src/features/chat/domain/contact_model.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:a_chatz/src/shared/widgets/premium_avatar.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:a_chatz/src/features/chat/presentation/chat_room_screen.dart';
import 'package:a_chatz/src/core/services/biometric_service.dart';
import 'package:a_chatz/src/shared/widgets/theme_picker_sheet.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/features/profile/presentation/verification_info_screen.dart';
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  static List<ChatThread>? _cachedChats;
  static Map<String, dynamic>? _cachedProfile;
  
  String? _selectedChatId;
  String _searchQuery = '';
  Set<String> _deepSearchMatches = {};
  bool _showAd = true;

  void _runDeepSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _deepSearchMatches.clear());
      return;
    }
    try {
      final cacheSnap = await AppDatabase.instance
          .collectionGroup('messages')
          .get(const GetOptions(source: Source.cache));
      final matches = <String>{};
      for (var doc in cacheSnap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final text = (data['cipherText'] as String?)?.toLowerCase() ?? '';
        final caption = (data['caption'] as String?)?.toLowerCase() ?? '';
        if (text.contains(query) || caption.contains(query)) {
           final chatDocId = doc.reference.parent.parent?.id;
           if (chatDocId != null) matches.add(chatDocId);
        }
      }
      if (mounted) setState(() => _deepSearchMatches = matches);
    } catch (e) {
      debugPrint('Deep search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(myChatsProvider);
    if (chats.hasValue) {
      _cachedChats = chats.value;
    }
    
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    if (userProfileAsync.hasValue) {
      _cachedProfile = userProfileAsync.value;
    }
    final profileData = userProfileAsync.value ?? _cachedProfile;
    final isBusiness = profileData?['accountType'] == 'business';

    final contacts = ref.watch(myContactsProvider).value ?? [];
    final pinnedChats = ref.watch(pinnedChatsProvider).value ?? [];
    final favoriteChats = ref.watch(favoriteChatsProvider).value ?? [];
    final archivedChats = ref.watch(archivedChatsProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isWebLandscape = screenWidth > 900;

    final sidebar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isBusiness ? 'A-Chatz Business' : 'A-Chatz',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: isBusiness ? Colors.redAccent : null,
                ),
              ),
            ),
            IconButton(
              onPressed: () => context.push('/create-group'),
              icon: Icon(Icons.group_add_outlined),
            ),
            IconButton(
              onPressed: () => context.push('/qr-scanner'),
              icon: Icon(Icons.qr_code_scanner),
            ),
            IconButton(
              onPressed: () => context.push('/search-users'),
              icon: Icon(Icons.search),
            ),
          ],
        ),
        SizedBox(height: 14),
        TextField(
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
            _runDeepSearch(val.toLowerCase());
          },
          decoration: InputDecoration(
            hintText: 'Search people, groups, messages...',
            prefixIcon: Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                      _runDeepSearch('');
                    },
                  )
                : IconButton(
                    icon: Icon(Icons.tune),
                    onPressed: () {},
                  ),
          ),
        ),
        SizedBox(height: 20),
        _ChatFilters(),
        SizedBox(height: 10),
        Expanded(
          child: Builder(
            builder: (context) {
              final displayItems = chats.value ?? _cachedChats;
              if (displayItems == null) {
                if (chats.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load chats',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${chats.error}',
                          maxLines: 3,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  );
                }
                return const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                );
              }

              final items = displayItems;
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No chats yet.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Create a group or start a private conversation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFA7A7A7)),
                      ),
                      SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => context.push('/create-group'),
                        icon: Icon(Icons.group_add_outlined),
                        label: Text('Create group'),
                      ),
                    ],
                  ),
                );
              }

              final currentUid = ref.read(chatRepositoryProvider).uid ?? '';

              var allChats = List<ChatThread>.from(items);
              allChats = allChats.where((c) => !c.isGhost).toList();
              
              // Separate locked chats
              final lockedChats = allChats.where((c) => c.lockedBy.contains(currentUid)).toList();
              var sorted = allChats.where((c) => !c.lockedBy.contains(currentUid)).toList();

              final filter = ref.watch(chatFilterProvider);
              // Apply Filters
              if (filter == ChatFilter.unread) {
                sorted = sorted.where((c) => (c.unreadCount[currentUid] ?? 0) > 0).toList();
              } else if (filter == ChatFilter.favorites) {
                sorted = sorted.where((c) => favoriteChats.contains(c.id)).toList();
              } else if (filter == ChatFilter.groups) {
                sorted = sorted.where((c) => c.isGroup).toList();
              }

              // Apply Search Query
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                sorted = sorted.where((c) {
                  if (c.title.toLowerCase().contains(query)) return true;
                  if (c.description != null && c.description!.toLowerCase().contains(query)) return true;
                  if (c.lastMessage != null && c.lastMessage!.toLowerCase().contains(query)) return true;
                  if (_deepSearchMatches.contains(c.id)) return true;
                  if (!c.isGroup) {
                    final otherUid = c.memberIds.firstWhere((id) => id != currentUid, orElse: () => '');
                    if (otherUid.isNotEmpty) {
                      final contact = contacts.firstWhere(
                        (con) => con.uid == otherUid,
                        orElse: () => AppContact(uid: '', displayName: '', email: '', addedAt: DateTime.now()),
                      );
                      if (contact.uid.isNotEmpty) {
                        if (contact.displayName.toLowerCase().contains(query) ||
                            contact.email.toLowerCase().contains(query) ||
                            (contact.phoneNumber != null && contact.phoneNumber!.contains(query))) {
                          return true;
                        }
                      }
                    }
                  }
                  return false;
                }).toList();
              }

              // Sort: pinned chats first, then by lastMessageAt
              sorted.sort((a, b) {
                final aPinned = pinnedChats.contains(a.id);
                final bPinned = pinnedChats.contains(b.id);
                if (aPinned && !bPinned) return -1;
                if (!aPinned && bPinned) return 1;
                return 0; // preserve existing order within each group
              });

              final archivedCount = archivedChats.value?.length ?? 0;
              final hasLockedChats = lockedChats.isNotEmpty;
              final hasArchivedChats = archivedCount > 0;
              final statusesAsync = ref.watch(filteredStatusesProvider);
              final ads = statusesAsync.value?.where((s) => s.isPromoted).toList() ?? [];
              final adStory = ads.isNotEmpty ? ads.first : null;
              final hasAd = false;

              int headerOffset = 0;
              if (hasLockedChats) headerOffset++;
              if (hasArchivedChats) headerOffset++;
              if (hasAd) headerOffset++;

              final itemCount = sorted.length + headerOffset;

              return ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    int index = i;

                  if (hasAd && index == 0) {
                    return Dismissible(
                      key: const ValueKey('ad_banner'),
                      onDismissed: (_) {
                        setState(() {
                          _showAd = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.primary, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    adStory?.ownerName ?? 'Advertisement',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    adStory?.caption ?? 'Sponsored content. Tap to dismiss.',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (hasAd) index--;

                  if (hasLockedChats && index == 0) {
                    return InkWell(
                      onTap: () async {
                        final auth = await BiometricService.authenticate('Unlock to view your locked chats');
                        if (auth && context.mounted) {
                          context.push('/locked-chats');
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 66,
                              alignment: Alignment.centerLeft,
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.transparent,
                                child: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Locked Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                                  const SizedBox(height: 4),
                                  Text('Tap to unlock', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (hasLockedChats) index--;

                  if (hasArchivedChats && index == 0) {
                    return InkWell(
                      onTap: () => context.push('/archived-chats'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 66,
                              alignment: Alignment.centerLeft,
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.transparent,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(Icons.archive_outlined, color: Theme.of(context).colorScheme.onSurface),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Archived Chats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                                  const SizedBox(height: 4),
                                  Text('$archivedCount chats archived', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.background.withOpacity(0.38), size: 16),
                          ],
                        ),
                      ),
                    );
                  }
                  if (hasArchivedChats) index--;

                  final chat = sorted[index];
                  final isPinned = pinnedChats.contains(chat.id);
                  final isFavorite = favoriteChats.contains(chat.id);
                  return _ChatListTile(
                    chat: chat,
                    currentUid: ref.read(chatRepositoryProvider).uid ?? '',
                    isPinned: isPinned,
                    isFavorite: isFavorite,
                    onPin: () async {
                      final repo = ref.read(chatRepositoryProvider);
                      if (isPinned) {
                        await repo.unpinChat(chat.id);
                      } else {
                        await repo.pinChat(chat.id);
                      }
                    },
                    onToggleFavorite: () async {
                      await ref.read(chatRepositoryProvider).toggleFavorite(chat.id, isFavorite);
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          title: Text('Delete Chat', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          content: Text('This chat will be removed from your list.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.70))),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(chatRepositoryProvider).deleteChat(chat.id);
                        if (_selectedChatId == chat.id) {
                          setState(() {
                            _selectedChatId = null;
                          });
                        }
                      }
                    },
                    onTap: isWebLandscape
                        ? () {
                            setState(() {
                              _selectedChatId = chat.id;
                            });
                          }
                        : null,
                    onLock: () async {
                      final isLocked = chat.lockedBy.contains(ref.read(chatRepositoryProvider).uid);
                      await ref.read(chatRepositoryProvider).toggleLockChat(chat.id, isLocked);
                    },
                    onArchive: () async {
                      await ref.read(chatRepositoryProvider).archiveChat(chat.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chat archived successfully'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    onToggleGhost: () async {
                      final repo = ref.read(chatRepositoryProvider);
                      await repo.toggleGhostChat(chat.id, !chat.isGhost);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(chat.isGhost ? 'Chat revealed!' : 'Chat hidden in Ghost Mode! 👻'),
                            backgroundColor: Colors.purple,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    final aiFloatingButton = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'new_chat_fab',
          onPressed: () => context.push('/search-users'),
          elevation: 2,
          backgroundColor: Colors.white,
          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black, size: 24),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'ai_agent_fab',
          onPressed: () => context.push('/ai-agent'),
          elevation: 2,
          backgroundColor: Theme.of(context).colorScheme.onSurface,
          child: Image.asset(
            'assets/logo.png',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => Icon(Icons.bubble_chart, color: Theme.of(context).colorScheme.surface, size: 24),
          ),
        ),
      ],
    );

    if (isWebLandscape) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        floatingActionButton: aiFloatingButton,
        body: Row(
          children: [
            // Left sidebar pane
            Container(
              width: 380,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), width: 1.5)),
              ),
              child: LuxuryScaffold(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: sidebar,
              ),
            ),
            // Right chat details pane
            Expanded(
              child: _selectedChatId != null
                  ? ClipRect(
                      child: ChatRoomScreen(
                        key: ValueKey(_selectedChatId),
                        chatId: _selectedChatId!,
                      ),
                    )
                  : _buildWebPlaceholderPane(isBusiness),
            ),
          ],
        ),
      );
    }

    return LuxuryScaffold(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      floatingActionButton: aiFloatingButton,
      child: sidebar,
    );
  }

  Widget _buildWebPlaceholderPane(bool isBusiness) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing A-Chatz Brand Icon
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 76,
                    height: 76,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.security,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Text(
                isBusiness ? 'A-Chatz Business Desktop' : 'A-Chatz Desktop',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: isBusiness ? Colors.redAccent : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Select a conversation to start private messaging.\nAll chat communications are commutatively derived and protected with E2EE.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 48),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  SizedBox(width: 6),
                  Text(
                    'End-to-End Encrypted',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
}

enum ChatFilter { all, unread, favorites, groups }

final chatFilterProvider = StateProvider<ChatFilter>((ref) => ChatFilter.all);

class _ChatFilters extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(chatFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(context, ref, 'All', ChatFilter.all, current == ChatFilter.all),
          _filterChip(context, ref, 'Unread', ChatFilter.unread, current == ChatFilter.unread),
          _filterChip(context, ref, 'Favorites', ChatFilter.favorites, current == ChatFilter.favorites),
          _filterChip(context, ref, 'Groups', ChatFilter.groups, current == ChatFilter.groups),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, WidgetRef ref, String label, ChatFilter filter, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => ref.read(chatFilterProvider.notifier).state = filter,
        backgroundColor: Colors.transparent,
        selectedColor: Theme.of(context).colorScheme.onSurface,
        labelStyle: TextStyle(
          color: selected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Theme.of(context).colorScheme.onSurface)),
        showCheckmark: false,
      ),
    );
  }
}

class _ChatListTile extends StatelessWidget {
  static final Map<String, Map<String, dynamic>> _userCache = {};
  static final Map<String, Map<String, dynamic>> _contactCache = {};

  const _ChatListTile({
    required this.chat,
    required this.currentUid,
    required this.isPinned,
    required this.isFavorite,
    required this.onPin,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onLock,
    required this.onArchive,
    required this.onToggleGhost,
    this.onTap,
  });

  final ChatThread chat;
  final String currentUid;
  final bool isPinned;
  final bool isFavorite;
  final VoidCallback onPin;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onLock;
  final VoidCallback onArchive;
  final VoidCallback onToggleGhost;
  final VoidCallback? onTap;

  Future<void> _showCRMLabelDialog(BuildContext context, String chatId, String currentUid) async {
    final labels = ['VIP', 'New Lead', 'Payment Pending', 'Resolved', 'None'];
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Select CRM Label', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: labels.map((label) {
              return ListTile(
                title: Text(label, style: const TextStyle(color: Colors.white70)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (label == 'None') {
                    await AppDatabase.instance.table('chats').doc(chatId).set({
                      'crmLabels': {currentUid: FieldValue.delete()}
                    }, SetOptions(merge: true));
                  } else {
                    await AppDatabase.instance.table('chats').doc(chatId).set({
                      'crmLabels': {currentUid: label}
                    }, SetOptions(merge: true));
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (chat.isGroup) {
      return _buildTile(context, title: chat.title, photoUrl: chat.photoUrl);
    }

    // Self-chat detection
    final isSelfChat = chat.memberIds.length == 1 && chat.memberIds.first == currentUid;

    if (isSelfChat) {
      return _buildTile(context, title: 'You', photoUrl: null, isSelfChat: true);
    }

    String otherUid = '';
    for (final id in chat.memberIds) {
      if (id != currentUid) {
        otherUid = id;
        break;
      }
    }

    if (otherUid.isEmpty) {
      return _buildTile(context, title: chat.title, photoUrl: chat.photoUrl);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppDatabase.instance.table('users').doc(otherUid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.hasData && userSnap.data?.data() != null) {
          _userCache[otherUid] = userSnap.data!.data()!;
        }
        final userData = userSnap.data?.data() ?? _userCache[otherUid];
        final username = userData?['username'] as String? ?? chat.title;
        final photoUrl = userData?['photoUrl'] as String? ?? chat.photoUrl;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AppDatabase.instance
              .table('users')
              .doc(currentUid)
              .table('contacts')
              .doc(otherUid)
              .snapshots(),
          builder: (context, contactSnap) {
            if (contactSnap.hasData && contactSnap.data?.data() != null) {
              _contactCache[otherUid] = contactSnap.data!.data()!;
            }
            final contactData = contactSnap.data?.data() ?? _contactCache[otherUid];
            final displayName = contactData?['displayName'] as String? ?? username;

            return _buildTile(
              context,
              title: displayName,
              photoUrl: photoUrl,
              isVerified: userData?['isVerified'] == true,
              verificationTier: userData?['verificationTier'] as String?,
              isOfficial: otherUid == 'official_a_chatz',
              otherUid: otherUid,
            );
          },
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, {
    required String title,
    String? photoUrl,
    bool isSelfChat = false,
    bool isVerified = false,
    String? verificationTier,
    bool isOfficial = false,
    String? otherUid,
  }) {
    final firstLetter = title.isNotEmpty ? title[0].toUpperCase() : 'A';
    final myLabel = chat.crmLabels[currentUid];

    Widget? statusIcon;
    final lastSender = chat.lastMessageSenderId;
    if (lastSender == currentUid) {
      bool isRead = false;
      bool isDelivered = false;
      
      if (!chat.isGroup) {
         final otherId = chat.memberIds.firstWhere((id) => id != currentUid, orElse: () => '');
         if (otherId.isNotEmpty) {
           if ((chat.unreadCount[otherId] ?? 0) == 0) {
             isRead = true;
           }
           isDelivered = chat.lastMessageDeliveredTo.containsKey(otherId);
         }
      } else {
         final otherMembers = chat.memberIds.where((id) => id != currentUid).toList();
         if (otherMembers.isNotEmpty) {
           if (otherMembers.every((id) => (chat.unreadCount[id] ?? 0) == 0)) {
             isRead = true;
           }
           isDelivered = otherMembers.every((id) => chat.lastMessageDeliveredTo.containsKey(id));
         }
      }

      if (isRead) {
        statusIcon = const Icon(Icons.done_all, color: Colors.blue, size: 16);
      } else if (isDelivered) {
        statusIcon = const Icon(Icons.done_all, color: Colors.grey, size: 16);
      } else {
        statusIcon = const Icon(Icons.done, color: Colors.grey, size: 16);
      }
    }

    return CombinedMultiFingerDetector(
      onThreeFingerScroll: onDelete,
      child: GestureDetector(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1E1E1E),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(isFavorite ? Icons.star_border : Icons.star, color: Colors.amber),
                        title: Text(isFavorite ? 'Remove from Favorites' : 'Add to Favorites', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(ctx);
                          onToggleFavorite();
                        },
                      ),
                      ListTile(
                        leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Theme.of(context).colorScheme.onSurface),
                        title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(ctx);
                          onPin();
                        },
                      ),
                      ListTile(
                        leading: Icon(chat.lockedBy.contains(currentUid) ? Icons.lock_open : Icons.lock_outline, color: Theme.of(context).colorScheme.onSurface),
                        title: Text(chat.lockedBy.contains(currentUid) ? 'Unlock Chat' : 'Lock Chat', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          onLock();
                        },
                      ),
                      ListTile(
                        leading: Icon(chat.isGhost ? Icons.visibility : Icons.visibility_off, color: Theme.of(context).colorScheme.onSurface),
                        title: Text(chat.isGhost ? 'Reveal Chat (Unhide)' : 'Make Ghost (Hide)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(ctx);
                          onToggleGhost();
                        },
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: AppDatabase.instance.table('users').doc(currentUid).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final data = snapshot.data?.data() as Map<String, dynamic>?;
                          if (data?['accountType'] != 'business') return const SizedBox.shrink();

                          return ListTile(
                            leading: Icon(Icons.label_outline, color: Colors.redAccent),
                            title: const Text('Set CRM Label', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showCRMLabelDialog(context, chat.id, currentUid);
                            },
                          );
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.archive_outlined, color: Theme.of(context).colorScheme.onSurface),
                        title: Text('Archive Chat', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        onTap: () {
                          Navigator.pop(ctx);
                          onArchive();
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Delete Chat', style: TextStyle(color: Colors.red)),
                        onTap: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        child: InkWell(
          onTap: onTap ?? () => context.push('/chat/${chat.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 62,
                  height: 62,
                  child: Center(
                    child: isOfficial
                        ? CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFF1E1E24),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/logo.png',
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.verified_user,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ),
                          )
                        : isSelfChat
                            ? CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.bookmark, color: Theme.of(context).colorScheme.onSurface),
                              )
                            : PremiumAvatar(
                                userId: otherUid,
                                photoUrl: photoUrl,
                                radius: 26,
                              ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (isPinned)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.push_pin, size: 14, color: Colors.grey),
                            ),
                          if (chat.isGroup)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.groups, size: 16),
                            ),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: (chat.unreadCount[currentUid] ?? 0) > 0 ? FontWeight.w900 : FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (isOfficial) ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => showVerificationInfoDialog(context),
                                    child: const Icon(Icons.verified, size: 16, color: Colors.blueAccent),
                                  ),
                                ] else if (isVerified) ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => showVerificationInfoDialog(context),
                                    child: Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: verificationTier == 'tier2'
                                          ? Colors.purpleAccent
                                          : (verificationTier == 'tier3'
                                              ? Colors.amberAccent
                                              : Colors.blueAccent),
                                    ),
                                  ),
                                ],
                                if (chat.lockedBy.contains(currentUid))
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.lock, size: 14, color: Colors.grey),
                                  ),
                                if (chat.isGhost)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.visibility_off, size: 14, color: Colors.purple.withOpacity(0.54)),
                                  ),
                                if (isFavorite)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.star, size: 14, color: Colors.amber),
                                  ),
                              ],
                            ),
                          ),
                          if (myLabel != null)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                              ),
                              child: Text(
                                myLabel,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (ctx) {
                        final typingMap = Map<String, dynamic>.from(chat.typing);
                        final recordingMap = Map<String, dynamic>.from(chat.recording);
                        final otherActive = chat.isGroup
                            ? typingMap.entries.any((e) => e.key != currentUid && e.value == true) ||
                              recordingMap.entries.any((e) => e.key != currentUid && e.value == true)
                            : (otherUid != null &&
                                (typingMap[otherUid] == true || recordingMap[otherUid] == true));

                        if (otherActive) {
                          final someoneRecording = chat.isGroup
                              ? recordingMap.entries.any((e) => e.key != currentUid && e.value == true)
                              : (otherUid != null && recordingMap[otherUid] == true);
                          return Row(
                            children: [
                              if (statusIcon != null) ...[
                                statusIcon!,
                                const SizedBox(width: 4),
                              ],
                              Icon(
                                someoneRecording ? Icons.mic : Icons.edit_note,
                                size: 14,
                                color: const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                someoneRecording ? 'recording...' : 'typing...',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            if (statusIcon != null) ...[
                              statusIcon!,
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                chat.lastMessage?.isNotEmpty == true ? chat.lastMessage! : 'Encrypted-ready conversation',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: (chat.unreadCount[currentUid] ?? 0) > 0
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  fontWeight: (chat.unreadCount[currentUid] ?? 0) > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final unread = chat.unreadCount[currentUid] ?? 0;

                    if (unread == 0) {
                      if (chat.lastMessageAt != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            _formatTime(chat.lastMessageAt!),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (chat.lastMessageAt != null)
                          Text(
                            _formatTime(chat.lastMessageAt!),
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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

class CombinedMultiFingerDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTwoFingerScroll;
  final VoidCallback? onThreeFingerScroll;
  final double threshold;

  const CombinedMultiFingerDetector({
    super.key,
    required this.child,
    this.onTwoFingerScroll,
    this.onThreeFingerScroll,
    this.threshold = 40.0,
  });

  @override
  State<CombinedMultiFingerDetector> createState() => _CombinedMultiFingerDetectorState();
}

class _CombinedMultiFingerDetectorState extends State<CombinedMultiFingerDetector> {
  final Map<int, Offset> _pointerPositions = {};
  final Map<int, Offset> _pointerStarts = {};
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _pointerPositions[event.pointer] = event.position;
        _pointerStarts[event.pointer] = event.position;
      },
      onPointerMove: (event) {
        _pointerPositions[event.pointer] = event.position;

        if (!_triggered) {
          final count = _pointerPositions.length;
          if (count == 2 || count == 3) {
            double totalDisplacement = 0.0;
            for (final id in _pointerPositions.keys) {
              final start = _pointerStarts[id];
              final current = _pointerPositions[id];
              if (start != null && current != null) {
                totalDisplacement += (current - start).distance;
              }
            }
            final averageDisplacement = totalDisplacement / count;
            if (averageDisplacement > widget.threshold) {
              _triggered = true;
              if (count == 2 && widget.onTwoFingerScroll != null) {
                widget.onTwoFingerScroll!();
              } else if (count == 3 && widget.onThreeFingerScroll != null) {
                widget.onThreeFingerScroll!();
              }
            }
          }
        }
      },
      onPointerUp: (event) {
        _pointerPositions.remove(event.pointer);
        _pointerStarts.remove(event.pointer);
        if (_pointerPositions.isEmpty) {
          _triggered = false;
        }
      },
      onPointerCancel: (event) {
        _pointerPositions.remove(event.pointer);
        _pointerStarts.remove(event.pointer);
        if (_pointerPositions.isEmpty) {
          _triggered = false;
        }
      },
      child: widget.child,
    );
  }
}
