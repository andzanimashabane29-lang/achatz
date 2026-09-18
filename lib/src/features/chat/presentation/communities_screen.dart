import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  final _db = AppDatabase.instance;

  Future<void> _createNewCommunity() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _CreateCommunityDialog(),
    );

    if (result != null && mounted) {
      final currentUid = AppAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      try {
        await _db.table('communities').add({
          'name': result['name'],
          'description': result['description'],
          'ownerId': currentUid,
          'groupIds': [],
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Community created successfully!'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create community: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AppAuth.instance.currentUser?.uid;
    if (currentUid == null) return const Center(child: Text('Please log in'));

    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Communities',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createNewCommunity,
          backgroundColor: const Color(0xFF00FFB2),
          foregroundColor: Colors.black,
          icon: const Icon(Icons.group_add),
          label: const Text('New Community', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.table('communities').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFB2)));
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 72, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text(
                      'No Communities Yet',
                      style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a community to organize your groups.',
                      style: TextStyle(color: Colors.white30, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = data['name'] ?? 'Community';
                final description = data['description'] ?? '';
                final groupIds = List<String>.from(data['groupIds'] ?? []);
                final ownerId = data['ownerId'];
                final isMyCommunity = ownerId == currentUid;

                return Card(
                  color: const Color(0xFF1E1E22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white10, width: 1),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityDetailScreen(
                            communityId: doc.id,
                            name: name,
                            description: description,
                            ownerId: ownerId,
                            groupIds: groupIds,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FFB2).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.hub_outlined, color: Color(0xFF00FFB2), size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${groupIds.length} ${groupIds.length == 1 ? "group" : "groups"}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (isMyCommunity)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'OWNER',
                                    style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _CreateCommunityDialog extends StatefulWidget {
  const _CreateCommunityDialog();

  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('New Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Community Name',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFB2))),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFB2))),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context, {
                'name': name,
                'description': _descController.text.trim(),
              });
            }
          },
          child: const Text('Create', style: TextStyle(color: Color(0xFF00FFB2), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.groupIds,
  });

  final String communityId;
  final String name;
  final String description;
  final String ownerId;
  final List<String> groupIds;

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  final _db = AppDatabase.instance;

  Future<void> _addExistingGroup() async {
    final selectedGroupId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddExistingGroupsSheet(),
    );

    if (selectedGroupId != null && mounted) {
      try {
        await _db.table('communities').doc(widget.communityId).update({
          'groupIds': FieldValue.arrayUnion([selectedGroupId]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group added to community!'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add group: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Future<void> _createNewGroup() async {
    final groupName = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Group Name',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFB2))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Create', style: TextStyle(color: Color(0xFF00FFB2), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (groupName != null && groupName.isNotEmpty && mounted) {
      final currentUid = AppAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      try {
        final newChatRef = _db.table('chats').doc();
        await newChatRef.set({
          'type': 'group',
          'name': groupName,
          'memberIds': [currentUid],
          'unreadCount': {currentUid: 0},
          'createdBy': currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _db.table('communities').doc(widget.communityId).update({
          'groupIds': FieldValue.arrayUnion([newChatRef.id]),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New group created under community!'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create group: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  Future<void> _removeGroupFromCommunity(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        title: const Text('Remove Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove this group from this community?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _db.table('communities').doc(widget.communityId).update({
          'groupIds': FieldValue.arrayRemove([groupId]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group removed from community!'), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove group: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AppAuth.instance.currentUser?.uid;
    final isMyCommunity = widget.ownerId == currentUid;

    return LuxuryScaffold(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.table('communities').doc(widget.communityId).snapshots(),
        builder: (context, communitySnap) {
          final data = communitySnap.data?.data() ?? {};
          final currentGroupIds = List<String>.from(data['groupIds'] ?? widget.groupIds);

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            body: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About Community',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.description.isNotEmpty ? widget.description : 'No description provided.',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (isMyCommunity) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _addExistingGroup,
                                icon: const Icon(Icons.link, size: 18),
                                label: const Text('Add Existing'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF00FFB2),
                                  side: const BorderSide(color: Color(0xFF00FFB2)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _createNewGroup,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Create New'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00FFB2),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'GROUPS UNDER COMMUNITY',
                      style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: currentGroupIds.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined, size: 48, color: Colors.white.withOpacity(0.15)),
                              const SizedBox(height: 12),
                              const Text('No Groups Associated', style: TextStyle(color: Colors.white30, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: currentGroupIds.length,
                          itemBuilder: (context, idx) {
                            final groupId = currentGroupIds[idx];
                            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: _db.table('chats').doc(groupId).snapshots(),
                              builder: (context, chatSnap) {
                                if (!chatSnap.hasData) return const SizedBox.shrink();
                                final chatData = chatSnap.data?.data() ?? {};
                                final groupName = chatData['name'] ?? 'Group Chat';

                                return Card(
                                  color: const Color(0xFF16161A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF00FFB2).withOpacity(0.1),
                                      child: const Icon(Icons.forum, color: Color(0xFF00FFB2)),
                                    ),
                                    title: Text(groupName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    trailing: isMyCommunity
                                        ? IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                            onPressed: () => _removeGroupFromCommunity(groupId),
                                          )
                                        : const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
                                    onTap: () {
                                      context.push('/chat/$groupId');
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddExistingGroupsSheet extends ConsumerWidget {
  const _AddExistingGroupsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = AppAuth.instance.currentUser?.uid;
    if (currentUid == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E22),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Group to Link',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppDatabase.instance
                  .table('chats')
                  .where('type', isEqualTo: 'group')
                  .where('memberIds', arrayContains: currentUid)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFB2)));

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No group chats found to link.', style: TextStyle(color: Colors.white30)),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final chatData = doc.data();
                    final groupName = chatData['name'] ?? 'Group Chat';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF00FFB2).withOpacity(0.1),
                        child: const Icon(Icons.forum, color: Color(0xFF00FFB2)),
                      ),
                      title: Text(groupName, style: const TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.add, color: Color(0xFF00FFB2)),
                      onTap: () {
                        Navigator.pop(context, doc.id);
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
