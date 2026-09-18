import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:a_chatz/src/features/profile/presentation/catalog_screen.dart';

class ContactInfoScreen extends ConsumerStatefulWidget {
  const ContactInfoScreen({
    super.key,
    required this.chatId,
    required this.contactUid,
  });

  final String chatId;
  final String contactUid;

  @override
  ConsumerState<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends ConsumerState<ContactInfoScreen> {
  Map<String, dynamic>? contactData;
  bool loading = true;
  bool isMuted = false;
  bool isArchived = false;

  bool get isGroup => widget.contactUid == 'group';

  // Group fields
  Map<String, dynamic>? groupData;
  List<Map<String, dynamic>> groupMembers = [];
  String currentUserName = 'User';
  bool isContactOfTarget = false;

  @override
  void initState() {
    super.initState();
    loadContactData();

    // Increment profileClicks metric for the other user
    if (widget.contactUid.isNotEmpty && widget.contactUid != 'group') {
      final currentUid = AppAuth.instance.currentUser?.uid;
      if (widget.contactUid != currentUid) {
        AppDatabase.instance.table('business_analytics').doc(widget.contactUid).set({
          'profileClicks': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> loadContactData() async {
    try {
      final currentUid = ref.read(chatRepositoryProvider).uid;

      // Load current user profile first (needed for both personal & group)
      final currentUserDoc = await AppDatabase.instance
          .table('users')
          .doc(currentUid)
          .get();
      if (currentUserDoc.exists) {
        currentUserName = currentUserDoc.data()?['username'] ?? 'User';
      }

      final chatDoc = await AppDatabase.instance
          .table('chats')
          .doc(widget.chatId)
          .get();

      final chatData = chatDoc.data() ?? {};
      final mutedBy = List<String>.from(chatData['mutedBy'] ?? []);
      final archivedBy = List<String>.from(chatData['archivedBy'] ?? []);

      if (isGroup) {
        // Load group members profiles
        final memberIds = List<String>.from(chatData['memberIds'] ?? []);
        final List<Map<String, dynamic>> membersList = [];
        for (final mId in memberIds) {
          final mDoc = await AppDatabase.instance.table('users').doc(mId).get();
          if (mDoc.exists) {
            final mData = mDoc.data() ?? {};
            mData['uid'] = mId;
            membersList.add(mData);
          }
        }

        if (mounted) {
          setState(() {
            groupData = chatData;
            groupMembers = membersList;
            isMuted = mutedBy.contains(currentUid);
            isArchived = archivedBy.contains(currentUid);
            loading = false;
          });
        }
      } else {
        final userDoc = await AppDatabase.instance
            .table('users')
            .doc(widget.contactUid)
            .get();

        bool isContactOfTarget = false;
        try {
          final relDoc = await AppDatabase.instance
              .table('users')
              .doc(widget.contactUid)
              .table('contacts')
              .doc(currentUid)
              .get();
          isContactOfTarget = relDoc.exists;
        } catch (_) {}

        if (mounted) {
          setState(() {
            contactData = userDoc.data();
            this.isContactOfTarget = isContactOfTarget;
            isMuted = mutedBy.contains(currentUid);
            isArchived = archivedBy.contains(currentUid);
            loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Leave Group?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to leave this group chat?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(chatRepositoryProvider).leaveGroupChat(widget.chatId, currentUserName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You left the group')),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> removeMember(String memberUid, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove Member?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove $memberName from the group?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(chatRepositoryProvider).removeMemberFromGroup(
        widget.chatId,
        memberUid,
        memberName,
        currentUserName,
      );
      await loadContactData(); // Reload list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> promoteAdmin(String memberUid, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Promote to Admin?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Make $memberName an Admin of this group?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Make Admin', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(chatRepositoryProvider).promoteToAdmin(
        widget.chatId,
        memberUid,
        memberName,
        currentUserName,
      );
      await loadContactData(); // Reload list
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$memberName is now an Admin')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> demoteAdmin(String memberUid, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove Admin?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove $memberName as an Admin of this group?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Admin', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(chatRepositoryProvider).demoteFromAdmin(
        widget.chatId,
        memberUid,
        memberName,
        currentUserName,
      );
      await loadContactData(); // Reload list
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$memberName is no longer an Admin')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> clearGroupHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear History?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete all messages in this group chat for everyone. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(chatRepositoryProvider).clearGroupChatHistory(widget.chatId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group history cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Group?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Delete this group permanently for everyone? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(chatRepositoryProvider).deleteGroupChat(widget.chatId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully')),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> toggleMute() async {
    try {
      await ref.read(chatRepositoryProvider).toggleMuteChat(widget.chatId, isMuted);
      setState(() => isMuted = !isMuted);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> toggleArchive() async {
    try {
      if (!isArchived) {
        await ref.read(chatRepositoryProvider).archiveChat(widget.chatId);
      } else {
        final currentUid = ref.read(chatRepositoryProvider).uid;
        await AppDatabase.instance.table('chats').doc(widget.chatId).update({
          'archivedBy': FieldValue.arrayRemove([currentUid]),
        });
      }
      setState(() => isArchived = !isArchived);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> unblockUser() async {
    try {
      final currentUid = ref.read(chatRepositoryProvider).uid;
      await AppDatabase.instance
          .table('users')
          .doc(currentUid)
          .table('blocked')
          .doc(widget.contactUid)
          .delete();
      
      await ref.read(chatRepositoryProvider).unblockUser(widget.contactUid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Block User?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Blocked contacts will no longer be able to call you or send you messages.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUid = ref.read(chatRepositoryProvider).uid;
      await AppDatabase.instance
          .table('users')
          .doc(currentUid)
          .table('blocked')
          .doc(widget.contactUid)
          .set({'blockedAt': FieldValue.serverTimestamp()});

      await ref.read(chatRepositoryProvider).blockUser(widget.contactUid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
        );
        context.pop();
        context.pop(); // Go back to chats list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> reportUser() async {
    String selectedCategory = 'Spam';
    final detailsController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161618).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Report Contact',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please select a category and provide additional details to help us investigate.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Category chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Spam', 'Harassment', 'Offensive Content', 'Scam', 'Other'].map((cat) {
                  final isSelected = selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedCategory = cat);
                    },
                    backgroundColor: Colors.white.withOpacity(0.04),
                    selectedColor: Colors.redAccent.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.redAccent : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.redAccent : Colors.white12,
                        width: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: detailsController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter more details (optional)...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        try {
                          final currentUid = ref.read(chatRepositoryProvider).uid;
                          final details = detailsController.text.trim();
                          final reasonString = details.isEmpty 
                              ? selectedCategory 
                              : '$selectedCategory: $details';

                          await AppDatabase.instance.table('reports').add({
                            'reportedBy': currentUid,
                            'reportedUserId': widget.contactUid,
                            'reportedUser': widget.contactUid,
                            'chatId': widget.chatId,
                            'reason': reasonString,
                            'status': 'pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('User reported successfully.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> showDisappearingMessagesSheet() async {
    final chatDoc = await AppDatabase.instance.table('chats').doc(widget.chatId).get();
    final chatData = chatDoc.data() ?? {};
    final currentDuration = chatData['disappearingDuration'] as int? ?? 0;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161618).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
              ),
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.cyanAccent, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Disappearing Messages',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'For more privacy and storage, new messages sent in this chat will disappear for everyone after the selected duration. Existing messages will not be affected.',
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  _buildDurationOption(context, 'Off', 0, currentDuration),
                  _buildDurationOption(context, '24 Hours', 86400, currentDuration),
                  _buildDurationOption(context, '7 Days', 604800, currentDuration),
                  _buildDurationOption(context, '90 Days', 7776000, currentDuration),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDurationOption(BuildContext context, String label, int duration, int currentDuration) {
    final isSelected = currentDuration == duration;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () async {
        try {
          await AppDatabase.instance.table('chats').doc(widget.chatId).update({
            'disappearingDuration': duration == 0 ? null : duration,
          });
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Disappearing messages set to $label'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      },
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.cyanAccent : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.cyanAccent)
          : const Icon(Icons.circle_outlined, color: Colors.white30),
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: const Color(0xFF1E1E1E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    if (isGroup) {
      final title = groupData?['title'] ?? 'Group';
      final photoUrl = groupData?['photoUrl'];
      final description = groupData?['description'] ?? 'No description provided.';
      final currentUid = ref.read(chatRepositoryProvider).uid;
      final adminsList = List<String>.from(groupData?['admins'] ?? []);
      final isCurrentUserAdmin = adminsList.contains(currentUid);

      return LuxuryScaffold(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Text(
                    'Group Info',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 64,
                      backgroundColor: const Color(0xFF1E1E1E),
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null ? const Icon(Icons.groups, size: 64, color: Colors.white54) : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${groupMembers.length} Members',
                      style: const TextStyle(fontSize: 16, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(description, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Group QR Code
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Group Invitation QR Code', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: 'achatz://group/${widget.chatId}',
                          version: QrVersions.auto,
                          size: 160.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Group Mute/Archive
              _buildActionTile(
                isMuted ? 'Unmute Group Notifications' : 'Mute Group Notifications',
                isMuted ? Icons.notifications_off : Icons.notifications_active,
                Colors.white,
                toggleMute,
              ),
              _buildActionTile(
                isArchived ? 'Unarchive Group' : 'Archive Group',
                Icons.archive,
                Colors.white,
                toggleArchive,
              ),
              if (isCurrentUserAdmin)
                _buildActionTile(
                  'Disappearing Messages',
                  Icons.timer,
                  Colors.cyanAccent,
                  showDisappearingMessagesSheet,
                ),
              _buildActionTile(
                'Starred Messages',
                Icons.star,
                Colors.amberAccent,
                () => context.push('/chat/${widget.chatId}/starred'),
              ),
              _buildActionTile(
                'Shared Media, Links & Docs',
                Icons.folder,
                Colors.blueAccent,
                () => context.push('/chat/${widget.chatId}/shared'),
              ),

              const SizedBox(height: 24),

              // Members list title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'MEMBERS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFA7A7A7), letterSpacing: 1.2),
                ),
              ),

              // Members List
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groupMembers.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF2C2C2C), height: 1),
                  itemBuilder: (context, idx) {
                    final member = groupMembers[idx];
                    final memberUid = member['uid'];
                    final mName = member['username'] ?? 'User';
                    final mEmail = member['email'] ?? '';
                    final mPhotoUrl = member['photoUrl'];
                    final isMemberAdmin = adminsList.contains(memberUid);
                    final isSelf = memberUid == currentUid;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF2C2C2C),
                        backgroundImage: mPhotoUrl != null ? NetworkImage(mPhotoUrl) : null,
                        child: mPhotoUrl == null ? const Icon(Icons.person, color: Colors.white54) : null,
                      ),
                      title: Row(
                        children: [
                          Text(mName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          if (isMemberAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                              ),
                              child: const Text("ADMIN",
                                  style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(mEmail, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: isCurrentUserAdmin && !isSelf
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white70),
                              color: const Color(0xFF1E1E1E),
                              onSelected: (val) {
                                if (val == 'remove') {
                                  removeMember(memberUid, mName);
                                } else if (val == 'promote') {
                                  promoteAdmin(memberUid, mName);
                                } else if (val == 'demote') {
                                  demoteAdmin(memberUid, mName);
                                }
                              },
                              itemBuilder: (_) => [
                                if (isMemberAdmin)
                                  const PopupMenuItem(
                                    value: 'demote',
                                    child: Text('Remove Admin', style: TextStyle(color: Colors.white)),
                                  ),
                                if (!isMemberAdmin)
                                  const PopupMenuItem(
                                    value: 'promote',
                                    child: Text('Make Admin', style: TextStyle(color: Colors.white)),
                                  ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove from Group', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Group Moderation (Delete/Clear)
              if (isCurrentUserAdmin) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'GROUP MODERATION',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.redAccent, letterSpacing: 1.2),
                  ),
                ),
                _buildActionTile(
                  'Clear Group Messages',
                  Icons.clear_all,
                  Colors.redAccent,
                  clearGroupHistory,
                ),
                _buildActionTile(
                  'Delete Group',
                  Icons.delete_forever,
                  Colors.redAccent,
                  deleteGroup,
                ),
                const SizedBox(height: 16),
              ],

              // Leave group
              _buildActionTile(
                'Leave Group',
                Icons.exit_to_app,
                Colors.redAccent,
                leaveGroup,
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      );
    }

    final username = contactData?['username'] ?? 'User';
    final rawPhotoUrl = contactData?['photoUrl'] as String?;
    final email = contactData?['email'] ?? 'No email provided';
    final rawBio = contactData?['bio'] ?? 'Hey there! I am using a_chatz.';

    final currentUid = AppAuth.instance.currentUser?.uid;
    final isSelf = widget.contactUid == currentUid;

    final aboutVisibility = contactData?['aboutVisibility'] as String? ?? 'Everyone';
    final photoVisibility = contactData?['profilePhotoVisibility'] as String? ?? 'Everyone';

    String? photoUrl = rawPhotoUrl;
    if (!isSelf && !isGroup) {
      if (photoVisibility == 'Nobody') {
        photoUrl = null;
      } else if (photoVisibility == 'My contacts' && !isContactOfTarget) {
        photoUrl = null;
      }
    }

    String bio = rawBio;
    if (!isSelf && !isGroup) {
      if (aboutVisibility == 'Nobody') {
        bio = 'Hey there! I am using a_chatz.';
      } else if (aboutVisibility == 'My contacts' && !isContactOfTarget) {
        bio = 'Hey there! I am using a_chatz.';
      }
    }

    return LuxuryScaffold(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const Text(
                  'Contact Info',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 64,
              backgroundColor: const Color(0xFF1E1E1E),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, size: 64, color: Colors.white54) : null,
            ),
            const SizedBox(height: 16),
            Text(
              username,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 16, color: Colors.white54),
            ),
            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bio', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(bio, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),

            if (contactData?['accountType'] == 'business') ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.business, color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Text('BUSINESS PROFILE', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      ],
                    ),
                    if ((contactData?['businessCategory'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Category', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(contactData?['businessCategory'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ],
                    if ((contactData?['businessAddress'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Address', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(contactData?['businessAddress'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ],
                    if ((contactData?['businessWebsite'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Website', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final website = contactData?['businessWebsite'] as String;
                          final uri = Uri.parse(website.startsWith('http') ? website : 'https://$website');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text(
                          contactData?['businessWebsite'] ?? '',
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 15, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            _buildActionTile(
              'View Product Catalog',
              Icons.storefront,
              Colors.greenAccent,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CatalogScreen(userId: widget.contactUid),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            _buildActionTile(
              isMuted ? 'Unmute Notifications' : 'Mute Notifications',
              isMuted ? Icons.notifications_off : Icons.notifications_active,
              Colors.white,
              toggleMute,
            ),
            _buildActionTile(
              isArchived ? 'Unarchive Chat' : 'Archive Chat',
              Icons.archive,
              Colors.white,
              toggleArchive,
            ),
            _buildActionTile(
              'Disappearing Messages',
              Icons.timer,
              Colors.cyanAccent,
              showDisappearingMessagesSheet,
            ),
            _buildActionTile(
              'Starred Messages',
              Icons.star,
              Colors.amberAccent,
              () => context.push('/chat/${widget.chatId}/starred'),
            ),
            _buildActionTile(
              'Shared Media, Links & Docs',
              Icons.folder,
              Colors.blueAccent,
              () => context.push('/chat/${widget.chatId}/shared'),
            ),
            _buildActionTile(
              'Report User',
              Icons.thumb_down,
              Colors.orangeAccent,
              reportUser,
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AppDatabase.instance
                  .table('users')
                  .doc(ref.read(chatRepositoryProvider).uid)
                  .table('blocked')
                  .doc(widget.contactUid)
                  .snapshots(),
              builder: (context, snapshot) {
                final isBlocked = snapshot.data?.exists ?? false;

                if (isBlocked) {
                  return _buildActionTile(
                    'Unblock User',
                    Icons.block,
                    Colors.greenAccent,
                    unblockUser,
                  );
                }

                return _buildActionTile(
                  'Block User',
                  Icons.block,
                  Colors.redAccent,
                  blockUser,
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
