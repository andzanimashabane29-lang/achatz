import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:a_chatz/src/features/profile/presentation/catalog_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/verification_info_screen.dart';
import 'package:a_chatz/src/shared/widgets/profile_picture_viewer_screen.dart';
import 'package:a_chatz/src/shared/utils/business_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

void showQrCode(BuildContext context, String title, String data) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF111115),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white12, width: 1.5),
      ),
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.verified, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 6),
              Text(
                'A-CHATZ SECURE PRODUCT',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 200.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.white,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Colors.cyanAccent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Scan to join securely via A-Chatz PWA/App',
            style: TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.otherUid, this.chatId});

  final String otherUid;
  final String? chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (otherUid == 'group' && chatId != null) {
      return _GroupDetailScreen(chatId: chatId!);
    }

    // Increment profileClicks metric for the other user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUid = AppAuth.instance.currentUser?.uid;
      if (otherUid.isNotEmpty && otherUid != 'group' && otherUid != currentUid) {
        AppDatabase.instance.table('business_analytics').doc(otherUid).set({
          'profileClicks': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    });

    return LuxuryScaffold(
      child: StreamBuilder<DocumentSnapshot>(
        stream: AppDatabase.instance.table('users').doc(otherUid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = data['username'] ?? 'User';
          final photoUrl = data['photoUrl'];
          final status = data['status'] ?? 'Hey there! I am using A-Chatz.';
          final isBusiness = data['accountType'] == 'business';

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePictureViewerScreen(
                          photoUrl: otherUid == 'official_a_chatz' ? 'assets/logo.png' : photoUrl,
                          username: name,
                          heroTag: 'profile_$otherUid',
                          isAsset: otherUid == 'official_a_chatz',
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'profile_$otherUid',
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: otherUid == 'official_a_chatz' ? const Color(0xFF1E1E24) : Colors.white,
                      backgroundImage: (photoUrl != null && otherUid != 'official_a_chatz') ? NetworkImage(photoUrl) : null,
                      child: (photoUrl == null || otherUid == 'official_a_chatz')
                          ? (otherUid == 'official_a_chatz'
                              ? ClipOval(
                                  child: Image.asset(
                                    'assets/logo.png',
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.verified_user,
                                      color: Colors.greenAccent,
                                      size: 70,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.person, size: 70, color: Colors.black))
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (otherUid == 'official_a_chatz') ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => showVerificationInfoDialog(context),
                        child: const Icon(Icons.verified, size: 24, color: Colors.blueAccent),
                      ),
                    ] else if (data['isVerified'] == true) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => showVerificationInfoDialog(context),
                        child: Icon(
                          Icons.verified,
                          size: 24,
                          color: data['verificationTier'] == 'tier2'
                              ? Colors.purpleAccent
                              : (data['verificationTier'] == 'tier3'
                                  ? Colors.amberAccent
                                  : Colors.blueAccent),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  data['email'] ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
                if (data['phoneNumber'] != null && data['phoneNumber'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    data['phoneNumber'].toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
                const SizedBox(height: 24),
                
                // Catalog showcase - always shown if user has products
                StreamBuilder<QuerySnapshot>(
                  stream: AppDatabase.instance
                      .table('users')
                      .doc(otherUid)
                      .table('catalog')
                      .snapshots(),
                  builder: (context, catalogSnap) {
                    final products = catalogSnap.data?.docs ?? [];
                    final hasCatalog = products.isNotEmpty;
                    if (!hasCatalog) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('PRODUCT SHOWCASE', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (hasCatalog)
                          SizedBox(
                            height: 160,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: products.length,
                              itemBuilder: (context, idx) {
                                final pData = products[idx].data() as Map<String, dynamic>;
                                final pImage = pData['imageUrl'] as String?;
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CatalogScreen(userId: otherUid),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 130,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                            child: pImage != null
                                                ? Image.network(pImage, fit: BoxFit.cover)
                                                : Container(color: Colors.white12, child: const Icon(Icons.image, color: Colors.white38)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                pData['name'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                              Text(
                                                pData['price'] ?? '',
                                                style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'No products listed yet',
                                style: TextStyle(color: Colors.white30, fontSize: 13),
                              ),
                            ),
                          ),
                        _InfoTile(
                          icon: Icons.storefront,
                          title: 'Business Catalog',
                          subtitle: 'Browse all products & pricing',
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CatalogScreen(userId: otherUid),
                              ),
                            );
                          },
                        ),
                        const Divider(color: Colors.white10),
                      ],
                    );
                  },
                ),

                ListTile(
                  title: const Text('Status', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  subtitle: Text(status, style: const TextStyle(color: Colors.white, fontSize: 18)),
                ),
                const Divider(color: Colors.white10),
                
                // Common groups and channels
                StreamBuilder<QuerySnapshot>(
                  stream: AppDatabase.instance
                      .table('chats')
                      .where('memberIds', arrayContains: otherUid)
                      .snapshots(),
                  builder: (context, chatsSnap) {
                    final chats = chatsSnap.data?.docs ?? [];
                    final currentUid = AppAuth.instance.currentUser?.uid;
                    
                    // Filter to only show groups where current user is also a member
                    final commonChats = chats.where((chat) {
                      final data = chat.data() as Map<String, dynamic>;
                      final members = List<String>.from(data['memberIds'] ?? []);
                      return members.contains(currentUid) && (data['type'] == 'group');
                    }).toList();
                    
                    if (commonChats.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('GROUPS IN COMMON', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...commonChats.map((chat) {
                          final chatData = chat.data() as Map<String, dynamic>;
                          final chatName = chatData['name'] as String? ?? 'Group';
                          final chatId = chat.id;
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.group, color: Colors.white54),
                            ),
                            title: Text(chatName, style: const TextStyle(color: Colors.white)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/chat/$chatId');
                            },
                          );
                        }),
                        const Divider(color: Colors.white10),
                      ],
                    );
                  },
                ),
                
                StreamBuilder<QuerySnapshot>(
                  stream: AppDatabase.instance
                      .table('channels')
                      .where('memberIds', arrayContains: otherUid)
                      .snapshots(),
                  builder: (context, channelsSnap) {
                    final channels = channelsSnap.data?.docs ?? [];
                    final currentUid = AppAuth.instance.currentUser?.uid;
                    
                    // Filter to only show channels where current user is also a member
                    final commonChannels = channels.where((channel) {
                      final data = channel.data() as Map<String, dynamic>;
                      final members = List<String>.from(data['memberIds'] ?? []);
                      return members.contains(currentUid);
                    }).toList();
                    
                    if (commonChannels.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('CHANNELS IN COMMON', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...commonChannels.map((channel) {
                          final channelData = channel.data() as Map<String, dynamic>;
                          final channelName = channelData['name'] as String? ?? 'Channel';
                          final channelId = channel.id;
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.white10,
                              child: Icon(Icons.campaign, color: Colors.white54),
                            ),
                            title: Text(channelName, style: const TextStyle(color: Colors.white)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/channel/$channelId');
                            },
                          );
                        }),
                        const Divider(color: Colors.white10),
                      ],
                    );
                  },
                ),
                
                _InfoTile(
                  icon: Icons.notifications_none,
                  title: 'Mute Notifications',
                  trailing: Switch(value: false, onChanged: (v) {}),
                ),
                _InfoTile(
                  icon: Icons.photo_outlined,
                  title: 'Media, Links, and Docs',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _InfoTile(
                  icon: Icons.star_border,
                  title: 'Starred Messages',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('BUSINESS DETAILS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (isBusiness) ...[
                  _InfoTile(icon: Icons.category_outlined, title: data['businessCategory'] ?? 'N/A'),
                  _InfoTile(icon: Icons.location_on_outlined, title: data['businessAddress'] ?? 'N/A'),
                  _InfoTile(icon: Icons.link_outlined, title: data['businessWebsite'] ?? 'N/A'),
                  Builder(
                    builder: (context) {
                      final hours = data['businessHours'] as Map<String, dynamic>?;
                      final hoursEnabled = data['businessHoursEnabled'] as bool? ?? false;
                      final isOpen = isBusinessOpen(hours, hoursEnabled);
                      final hoursText = getBusinessHoursString(hours, hoursEnabled);
                      return _InfoTile(
                        icon: Icons.schedule_outlined,
                        title: isOpen ? 'Open Now' : 'Closed',
                        subtitle: hoursText,
                        trailing: Icon(
                          Icons.circle,
                          color: isOpen ? Colors.greenAccent : Colors.redAccent,
                          size: 12,
                        ),
                      );
                    },
                  ),
                ] else ...[
                  const ListTile(title: Text('Standard personal account', style: TextStyle(color: Colors.white70))),
                ],

                const SizedBox(height: 30),
                _ActionTile(
                  icon: Icons.block,
                  title: 'Block $name',
                  color: Colors.redAccent,
                  onTap: () => ref.read(chatRepositoryProvider).blockUser(otherUid),
                ),
                _ActionTile(
                  icon: Icons.thumb_down_outlined,
                  title: 'Report $name',
                  color: Colors.redAccent,
                  onTap: () {},
                ),

                StreamBuilder<User?>(
                  stream: AppAuth.instance.authStateChanges(),
                  builder: (context, authSnap) {
                    final currentUser = authSnap.data;
                    if (currentUser?.uid == 'official_a_chatz') {
                      final isBanned = data['isBanned'] == true;
                      return Column(
                        children: [
                          const Divider(color: Colors.white10, height: 40),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('ADMIN ACTIONS', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          _ActionTile(
                            icon: isBanned ? Icons.health_and_safety : Icons.gavel,
                            title: isBanned ? 'Unban User' : 'Ban User',
                            color: Colors.amberAccent,
                            onTap: () async {
                              await AppDatabase.instance.table('users').doc(otherUid).update({
                                'isBanned': !isBanned,
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isBanned ? 'User unbanned' : 'User banned')),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: Colors.white54)) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }
}

class _GroupDetailScreen extends StatelessWidget {
  final String chatId;
  const _GroupDetailScreen({required this.chatId});

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: StreamBuilder<DocumentSnapshot>(
        stream: AppDatabase.instance.table('chats').doc(chatId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = data['title'] ?? 'Group';
          final photoUrl = data['photoUrl'];
          final members = List<String>.from(data['memberIds'] ?? []);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.white,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.groups, size: 70, color: Colors.black) : null,
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                Text('${members.length} members', style: const TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 24),
                
                _InfoTile(
                  icon: Icons.qr_code,
                  title: 'Show Group QR Code',
                  subtitle: 'Let others scan to join',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showQrCode(context, name, 'achatz://group/$chatId');
                  },
                ),
                const Divider(color: Colors.white10),
                
                _InfoTile(
                  icon: Icons.notifications_none,
                  title: 'Mute Notifications',
                  trailing: Switch(value: false, onChanged: (v) {}),
                ),
                _InfoTile(
                  icon: Icons.photo_outlined,
                  title: 'Media, Links, and Docs',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(color: Colors.white10),
                
                _ActionTile(
                  icon: Icons.exit_to_app,
                  title: 'Leave Group',
                  color: Colors.redAccent,
                  onTap: () {},
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }
}
