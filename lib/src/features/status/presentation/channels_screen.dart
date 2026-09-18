import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/status/domain/channel_models.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:a_chatz/src/features/status/presentation/bbc_news_feed_screen.dart';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/features/profile/presentation/verification_info_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
class ChannelsScreen extends ConsumerStatefulWidget {
  const ChannelsScreen({super.key});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  String _searchQuery = "";

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFFA7A7A7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final followedRoles = ref.watch(followedChannelsRolesProvider).value ?? <String, String>{};
    final followedSet = followedRoles.keys.toSet();
    final myUid = AppAuth.instance.currentUser?.uid;

    return LuxuryScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Text(
              'Channels',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Text(
              'Stay updated on your favorite topics. Find channels to follow below.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search channels...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E1E22),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: channelsAsync.when(
              data: (channels) {
                final filtered = channels.where((c) =>
                  c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  c.description.toLowerCase().contains(_searchQuery.toLowerCase())
                ).toList();

                final yourChannels = filtered.where((c) => c.ownerId == myUid || followedRoles[c.id] == 'admin').toList();
                final followedChannels = filtered.where((c) => followedSet.contains(c.id) && c.ownerId != myUid && followedRoles[c.id] != 'admin').toList();
                final mayFollowChannels = filtered.where((c) => !followedSet.contains(c.id) && c.ownerId != myUid).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    _buildBBCNewsFeaturedTile(context),
                    const SizedBox(height: 8),

                    if (yourChannels.isNotEmpty) ...[
                      _buildSectionHeader('These are your channels'),
                      ...yourChannels.map((channel) => _buildChannelTile(
                            context,
                            ref,
                            channel: channel,
                            isFollowing: true,
                          )),
                      const SizedBox(height: 12),
                    ],

                    if (followedChannels.isNotEmpty) ...[
                      _buildSectionHeader('Channels you follow'),
                      ...followedChannels.map((channel) => _buildChannelTile(
                            context,
                            ref,
                            channel: channel,
                            isFollowing: true,
                          )),
                      const SizedBox(height: 12),
                    ],

                    if (mayFollowChannels.isNotEmpty) ...[
                      _buildSectionHeader('Channels you may follow'),
                      ...mayFollowChannels.map((channel) => _buildChannelTile(
                            context,
                            ref,
                            channel: channel,
                            isFollowing: false,
                          )),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 30),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/create-channel'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Channel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBBCNewsFeaturedTile(BuildContext context) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFB80000), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BBCNewsFeedScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFB80000).withOpacity(0.9), Colors.black87],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    "BBC",
                    style: TextStyle(
                      color: Color(0xFFB80000),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "BBC World News & Weather",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => showVerificationInfoDialog(context),
                          child: const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Breaking world updates, hourly local/global weather monitor, and dynamic broadcasts.",
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTile(
    BuildContext context,
    WidgetRef ref, {
    required Channel channel,
    required bool isFollowing,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        onTap: () {
          final myUid = AppAuth.instance.currentUser?.uid;
          final isAdmin = channel.ownerId == myUid;
          if (isFollowing || isAdmin) {
            context.push('/channel/${channel.id}');
          } else {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF16161A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    Text(channel.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (channel.isVerified) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => showVerificationInfoDialog(context),
                        child: const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                      ),
                    ],
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(channel.description, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Text('${channel.followersCount} followers', style: const TextStyle(color: Colors.white30, fontSize: 12)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                  ),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(channelRepositoryProvider).followChannel(channel.id);
                      if (context.mounted) {
                        context.push('/channel/${channel.id}');
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: const Text('Join Channel'),
                  ),
                ],
              ),
            );
          }
        },
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.2),
            shape: BoxShape.circle,
            image: channel.photoUrl != null
                ? DecorationImage(image: NetworkImage(channel.photoUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: channel.photoUrl == null
              ? const Icon(Icons.campaign, color: Colors.blueAccent, size: 28)
              : null,
        ),
        title: Row(
          children: [
            Text(channel.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (channel.isVerified) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => showVerificationInfoDialog(context),
                child: const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(channel.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text('${channel.followersCount} followers', style: const TextStyle(color: Colors.white30, fontSize: 11)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (AppAuth.instance.currentUser?.uid == 'official_a_chatz')
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF16161A),
                      title: const Text('Delete Channel?', style: TextStyle(color: Colors.white)),
                      content: const Text('This will permanently delete this channel.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await AppDatabase.instance.table('channels').doc(channel.id).delete();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            FilledButton(
              onPressed: () {
                if (isFollowing) {
                  ref.read(channelRepositoryProvider).unfollowChannel(channel.id);
                } else {
                  ref.read(channelRepositoryProvider).followChannel(channel.id);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: isFollowing ? Colors.redAccent.withOpacity(0.15) : Colors.white12,
                foregroundColor: isFollowing ? Colors.redAccent : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(isFollowing ? 'Leave' : 'Follow', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
