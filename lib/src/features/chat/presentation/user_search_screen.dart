import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/features/chat/providers/contacts_provider.dart';
import 'package:a_chatz/src/features/chat/domain/contact_model.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _filterQuery = '';
  bool _isStartingChat = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> startChat(String otherUserId) async {
    if (_isStartingChat) return;

    setState(() => _isStartingChat = true);

    try {
      final chatId = await ref
          .read(chatRepositoryProvider)
          .createPrivateChat(otherUserId);

      if (mounted) {
        context.push('/chat/$chatId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start chat: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingChat = false);
      }
    }
  }

  void _showAddContactSheet() {
    final nameCtrl = TextEditingController();
    final searchInputCtrl = TextEditingController();
    bool isSearching = false;
    String? errorText;

    // Capture the database provider reference before opening the sheet so
    // it is accessible inside the StatefulBuilder without ref.read per build.
    final db = ref.read(supabaseDbProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Contact',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Nickname / Display Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchInputCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Email or Phone Number',
                      prefixIcon: Icon(Icons.contact_mail_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isSearching
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final contactSearch =
                                  searchInputCtrl.text.trim();

                              if (name.isEmpty || contactSearch.isEmpty) {
                                setSheetState(() {
                                  errorText = 'Please enter both fields.';
                                });
                                return;
                              }

                              setSheetState(() {
                                isSearching = true;
                                errorText = null;
                              });

                              try {
                                // Use the provider-sourced Firestore instance
                                // rather than AppDatabase.instance directly.
                                QuerySnapshot<Map<String, dynamic>> querySnap;
                                if (contactSearch.contains('@')) {
                                  querySnap = await db
                                      .table('users')
                                      .where('email',
                                          isEqualTo: contactSearch)
                                      .limit(1)
                                      .get();
                                } else {
                                  querySnap = await db
                                      .table('users')
                                      .where('phoneNumber',
                                          isEqualTo: contactSearch)
                                      .limit(1)
                                      .get();
                                }

                                if (querySnap.docs.isEmpty) {
                                  setSheetState(() {
                                    isSearching = false;
                                    errorText =
                                        'This person is not an A-Chatz user yet.';
                                  });
                                  return;
                                }

                                final targetDoc = querySnap.docs.first;
                                final targetUid = targetDoc.id;
                                final targetData = targetDoc.data();
                                final myUid =
                                    ref.read(currentUserUidProvider);

                                if (targetUid == myUid) {
                                  setSheetState(() {
                                    isSearching = false;
                                    errorText =
                                        'You cannot add yourself as a contact.';
                                  });
                                  return;
                                }

                                await db
                                    .table('users')
                                    .doc(myUid)
                                    .table('contacts')
                                    .doc(targetUid)
                                    .set({
                                  'displayName': name,
                                  'email': targetData['email'] ?? '',
                                  'phoneNumber':
                                      targetData['phoneNumber'] ?? '',
                                  'addedAt': FieldValue.serverTimestamp(),
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Added $name successfully! Starting chat...'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  startChat(targetUid);
                                }
                              } catch (e) {
                                setSheetState(() {
                                  isSearching = false;
                                  errorText = 'An error occurred: $e';
                                });
                              }
                            },
                      child: isSearching
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Add Contact & Chat',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRenameDialog(AppContact contact) {
    final nameCtrl = TextEditingController(text: contact.displayName);
    final db = ref.read(supabaseDbProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          title: const Text('Rename Contact',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'New Nickname',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isNotEmpty) {
                  final myUid = ref.read(currentUserUidProvider);
                  await db
                      .table('users')
                      .doc(myUid)
                      .table('contacts')
                      .doc(contact.uid)
                      .update({'displayName': newName});
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(AppContact contact) {
    final db = ref.read(supabaseDbProvider);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161618),
          title: const Text('Remove Contact',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to remove ${contact.displayName} from your contacts?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final myUid = ref.read(currentUserUidProvider);
                await db
                    .table('users')
                    .doc(myUid)
                    .table('contacts')
                    .doc(contact.uid)
                    .delete();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Shimmer skeleton shown while contacts are loading
  // ---------------------------------------------------------------------------
  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.white10,
      highlightColor: Colors.white24,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Row(
          children: [
            // Avatar placeholder
            const CircleAvatar(radius: 26, backgroundColor: Colors.white),
            const SizedBox(width: 14),
            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 14,
                      width: 140,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 8),
                  Container(
                      height: 11,
                      width: 200,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(myContactsProvider);
    final db = ref.read(supabaseDbProvider);

    return LuxuryScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Text(
                    'Contacts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _showAddContactSheet,
                icon: const Icon(Icons.person_add_alt_1_outlined,
                    color: Colors.greenAccent, size: 28),
                tooltip: 'Add Contact',
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _filterQuery = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: contactsAsync.when(
              // Advanced: shimmer skeleton instead of a plain spinner
              loading: _buildShimmerList,
              error: (err, stack) => Center(
                child: Text(
                  'Error loading contacts: $err',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              data: (contacts) {
                final filtered = contacts.where((c) {
                  final name = c.displayName.toLowerCase();
                  final email = c.email.toLowerCase();
                  final phone = (c.phoneNumber ?? '').toLowerCase();
                  return name.contains(_filterQuery) ||
                      email.contains(_filterQuery) ||
                      phone.contains(_filterQuery);
                }).toList()
                  ..sort((a, b) => a.displayName
                      .toLowerCase()
                      .compareTo(b.displayName.toLowerCase()));

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline,
                            size: 64, color: Colors.white30),
                        const SizedBox(height: 16),
                        Text(
                          contacts.isEmpty
                              ? 'No contacts added yet.\nTap the + icon to add a contact.'
                              : 'No contacts match your search.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFFA7A7A7), fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    final hasPhone = contact.phoneNumber != null &&
                        contact.phoneNumber!.isNotEmpty;

                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: db
                          .table('users')
                          .doc(contact.uid)
                          .snapshots(),
                      builder: (context, userSnap) {
                        final userData = userSnap.data?.data() ?? {};
                        final photoUrl = userData['photoUrl'] as String?;
                        final isOfficial =
                            contact.uid == 'official_a_chatz';

                        return InkWell(
                          onTap: () => startChat(contact.uid),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 66,
                                  alignment: Alignment.centerLeft,
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: isOfficial
                                            ? const Color(0xFF1E1E24)
                                            : Colors.white,
                                        // Advanced: CachedNetworkImage replaces
                                        // plain NetworkImage — handles caching,
                                        // placeholders and errors automatically.
                                        backgroundImage: (photoUrl != null &&
                                                photoUrl.isNotEmpty &&
                                                !isOfficial)
                                            ? CachedNetworkImageProvider(
                                                photoUrl)
                                            : null,
                                        child: (photoUrl == null ||
                                                photoUrl.isEmpty ||
                                                isOfficial)
                                            ? (isOfficial
                                                ? ClipOval(
                                                    child: Image.asset(
                                                      'assets/logo.png',
                                                      width: 52,
                                                      height: 52,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __,
                                                              ___) =>
                                                          const Icon(
                                                        Icons.verified_user,
                                                        color:
                                                            Colors.greenAccent,
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    contact.displayName
                                                            .isNotEmpty
                                                        ? contact.displayName[0]
                                                            .toUpperCase()
                                                        : 'U',
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ))
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        hasPhone
                                            ? '${contact.email} • ${contact.phoneNumber}'
                                            : contact.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.white54),
                                  onSelected: (val) {
                                    if (val == 'rename') {
                                      _showRenameDialog(contact);
                                    } else if (val == 'delete') {
                                      _confirmDelete(contact);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('Rename'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 18),
                                          SizedBox(width: 8),
                                          Text('Remove',
                                              style: TextStyle(
                                                  color: Colors.redAccent)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}