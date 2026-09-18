import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:io';

import 'package:a_chatz/src/features/status/domain/status_models.dart';
import 'package:a_chatz/src/features/status/presentation/status_viewer_screen.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:a_chatz/src/features/chat/presentation/media_preview_send_screen.dart';
import 'package:a_chatz/src/features/status/presentation/builtin_camera_screen.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/core/platform/platform_layout.dart';
import 'package:a_chatz/src/features/chat/providers/contacts_provider.dart';
import 'package:a_chatz/src/features/calls/data/live_repository.dart';
import 'package:a_chatz/src/shared/widgets/premium_avatar.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  bool uploading = false;

  Future<void> pickStatus(ImageSource source, StatusType type) async {
    final picker = ImagePicker();

    Navigator.pop(context);

    final XFile? pickedXFile;

    if (source == ImageSource.camera) {
      if (!mounted) return;
      final path = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => BuiltInCameraScreen(initialIsVideo: type == StatusType.video),
        ),
      );
      pickedXFile = path != null ? XFile(path) : null;
    } else {
      pickedXFile = type == StatusType.video
          ? await picker.pickVideo(
              source: source,
              maxDuration: const Duration(minutes: 4),
            )
          : await picker.pickImage(
              source: source,
              imageQuality: 60,
              maxWidth: 1080,
              maxHeight: 1920,
            );
    }

    if (pickedXFile == null) return;

    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPreviewSendScreen(
          xFile: pickedXFile,
          isVideo: type == StatusType.video,
          isForStatus: true,
        ),
      ),
    );

    if (result == null) return;

    setState(() => uploading = true);

    try {
      final musicTitle = result['musicTitle'] as String?;
      final musicArtist = result['musicArtist'] as String?;
      final musicPreviewUrl = result['musicPreviewUrl'] as String?;
      final musicStartTimeMs = result['musicStartTimeMs'] as int?;
      final musicEndTimeMs = result['musicEndTimeMs'] as int?;
      final musicStartTime = musicStartTimeMs != null ? Duration(milliseconds: musicStartTimeMs) : null;
      final musicEndTime = musicEndTimeMs != null ? Duration(milliseconds: musicEndTimeMs) : null;

      final mentions = result['mentions'] as List<String>?;
      final excludedIds = result['excludedIds'] as List<String>?;
      final allowedIds = result['allowedIds'] as List<String>?;
      final privacyOption = result['privacyOption'] as String?;

      final editedPath = result['editedFile'] as String?;
      final finalXFile = editedPath != null ? XFile(editedPath) : pickedXFile;

      await ref.read(statusRepositoryProvider).uploadStatus(
            xFile: finalXFile,
            type: type,
            caption: result['caption'],
            musicTitle: musicTitle,
            musicArtist: musicArtist,
            musicPreviewUrl: musicPreviewUrl,
            musicStartTime: musicStartTime,
            musicEndTime: musicEndTime,
            musicStickerStyle: result['musicStickerStyle'] as int?,
            musicStickerX: result['musicStickerX'] as double?,
            musicStickerY: result['musicStickerY'] as double?,
            musicStickerScale: result['musicStickerScale'] as double?,
            musicLyrics: result['musicLyrics'] as String?,
            musicLyricsOffsetMs: result['musicLyricsOffsetMs'] as int?,
            mentions: mentions,
            excludedIds: excludedIds,
            allowedIds: allowedIds,
            privacyOption: privacyOption,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status upload failed: $e')),
        );
      }
    }

    if (mounted) setState(() => uploading = false);
  }

  Future<void> showStatusOptions() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3D),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Add status',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    children: [
                      _StatusOption(
                        icon: Icons.edit_outlined,
                        title: 'Text Status',
                        compact: isWindowsApp,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/create-text-status');
                        },
                      ),
                      _StatusOption(
                        icon: Icons.photo_library_outlined,
                        title: 'Gallery Photo',
                        onTap: () => pickStatus(ImageSource.gallery, StatusType.image),
                      ),
                      _StatusOption(
                        icon: Icons.camera_alt_outlined,
                        title: 'Take Photo',
                        onTap: () => pickStatus(ImageSource.camera, StatusType.image),
                      ),
                      _StatusOption(
                        icon: Icons.video_library_outlined,
                        title: 'Gallery Video',
                        onTap: () => pickStatus(ImageSource.gallery, StatusType.video),
                      ),
                      _StatusOption(
                        icon: Icons.videocam_outlined,
                        title: 'Record Video',
                        onTap: () => pickStatus(ImageSource.camera, StatusType.video),
                      ),
                      _StatusOption(
                        icon: Icons.mic_none_outlined,
                        title: 'Voice Status',
                        compact: isWindowsApp,
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/create-voice-status');
                        },
                      ),
                      _StatusOption(
                        icon: Icons.sensors,
                        title: 'Go Live',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/go-live');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> showMuteConfirmDialog(String ownerId, String ownerName, bool isMuted, String currentUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101012),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isMuted ? 'Unmute $ownerName?' : 'Mute $ownerName?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isMuted
                ? 'New status updates from $ownerName will appear under recent updates.'
                : 'New status updates from $ownerName won\'t appear under recent updates anymore.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(_, true),
              child: Text(
                isMuted ? 'Unmute' : 'Mute',
                style: TextStyle(
                  color: isMuted ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final docRef = AppDatabase.instance.table('users').doc(currentUid);
      if (isMuted) {
        await docRef.update({
          'mutedStatusUsers': FieldValue.arrayRemove([ownerId]),
        });
      } else {
        await docRef.update({
          'mutedStatusUsers': FieldValue.arrayUnion([ownerId]),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ref.watch(filteredStatusesProvider);
    final myStatuses = ref.watch(myStatusesProvider);
    final currentUid = AppAuth.instance.currentUser?.uid;

    return LuxuryScaffold(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppDatabase.instance.table('users').doc(currentUid).snapshots(),
        builder: (context, userSnap) {
          final mutedStatusUsers = List<String>.from(
            userSnap.data?.data()?['mutedStatusUsers'] ?? [],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),

              // Active Live Streams Feed
              (() {
                final contactsAsyncValue = ref.watch(myContactsProvider);
                final contacts = contactsAsyncValue.value ?? [];
                final contactUids = contacts.map((c) => c.uid).toList();
                final liveSessionsAsync = ref.watch(activeLiveSessionsProvider(contactUids));

                return liveSessionsAsync.when(
                  data: (sessions) {
                    if (sessions.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Streams',
                          style: TextStyle(color: Color(0xFF00FFB2), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (ctx, idx) {
                              final session = sessions[idx];
                              return _LiveAvatarRing(
                                photoUrl: session.hostPhotoUrl,
                                label: session.hostName,
                                onTap: () => context.push('/live/viewer/${session.id}'),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFF202024)),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              })(),

              myStatuses.when(
                data: (mine) {
                  final hasMyStatus = mine.isNotEmpty;
                  final totalViews =
                      mine.fold<int>(0, (sum, story) => sum + story.seenBy.length);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: uploading
                        ? null
                        : hasMyStatus
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => StatusViewerScreen(
                                        stories: mine.reversed.toList(),
                                        isMine: true,
                                      ),
                                  ),
                                );
                              }
                            : showStatusOptions,
                    leading: _MyStatusAvatarWithAdd(
                      photoUrl: userSnap.data?.data()?['photoUrl'],
                      statusCount: mine.length,
                      onAddTap: uploading ? null : showStatusOptions,
                    ),
                    title: const Text(
                      'My status',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      uploading
                          ? 'Uploading...'
                          : hasMyStatus
                              ? '$totalViews views • Tap to view • + to add'
                              : 'Tap + to add photo, video, or text',
                    ),
                  );
                },
                loading: () => const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Loading your status...'),
                ),
                error: (e, _) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Could not load your status: $e'),
                ),
              ),

              const Divider(color: Color(0xFF202024)),

              Expanded(
                child: statuses.when(
                  data: (items) {
                    final grouped = <String, List<StatusStory>>{};

                    for (final item in items) {
                      grouped.putIfAbsent(item.ownerId, () => []).add(item);
                    }

                    final entries = grouped.entries
                        .where((entry) => entry.key != currentUid)
                        .toList();

                    final recentUpdates = entries
                        .where((e) => !mutedStatusUsers.contains(e.key))
                        .toList();

                    final mutedUpdates = entries
                        .where((e) => mutedStatusUsers.contains(e.key))
                        .toList();

                    if (recentUpdates.isEmpty && mutedUpdates.isEmpty) {
                      return const Center(
                        child: Text(
                          'No recent updates yet.',
                          style: TextStyle(color: Color(0xFFA7A7A7)),
                        ),
                      );
                    }

                    Widget buildStatusTile(MapEntry<String, List<StatusStory>> entry, bool isMuted) {
                      final stories = entry.value;
                      final first = stories.first;
                      final seen = currentUid != null &&
                          stories.every((s) => s.seenBy.containsKey(currentUid));

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StatusViewerScreen(
                                stories: stories,
                                isMine: false,
                              ),
                            ),
                          );
                        },
                        onLongPress: () {
                          if (currentUid != null) {
                            showMuteConfirmDialog(first.ownerId, first.ownerName, isMuted, currentUid);
                          }
                        },
                        leading: _StatusAvatar(
                          userId: first.ownerId,
                          photoUrl: first.ownerPhotoUrl,
                          statusCount: stories.length,
                          seenCount: stories.where((s) => s.seenBy.containsKey(currentUid)).length,
                          isMuted: isMuted,
                        ),
                        title: Text(
                          first.ownerName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          first.resharedFromOwnerName != null
                              ? 'Reshared from ${first.resharedFromOwnerName} • ${DateFormat.jm().format(first.createdAt)}'
                              : '${stories.length} update${stories.length == 1 ? '' : 's'} • ${DateFormat.jm().format(first.createdAt)}',
                        ),
                      );
                    }

                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (recentUpdates.isNotEmpty) ...[
                          const Text(
                            'Recent updates',
                            style: TextStyle(color: Color(0xFFA7A7A7)),
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentUpdates.length,
                            separatorBuilder: (_, __) => const Divider(color: Color(0xFF202024)),
                            itemBuilder: (_, i) => buildStatusTile(recentUpdates[i], false),
                          ),
                        ],
                        if (mutedUpdates.isNotEmpty) ...[
                          if (recentUpdates.isNotEmpty) const SizedBox(height: 24),
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              iconColor: Colors.grey,
                              collapsedIconColor: Colors.grey,
                              title: Text(
                                'Muted updates (${mutedUpdates.length})',
                                style: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: mutedUpdates.length,
                                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF202024)),
                                  itemBuilder: (_, i) => buildStatusTile(mutedUpdates[i], true),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Status error: $e')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// WhatsApp-style "My status" row: avatar ring + bottom-right add badge.
class _MyStatusAvatarWithAdd extends StatelessWidget {
  const _MyStatusAvatarWithAdd({
    required this.photoUrl,
    required this.statusCount,
    required this.onAddTap,
  });

  static const double _avatarSize = 66;
  static const double _badgeSize = 22;

  final String? photoUrl;
  final int statusCount;
  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _avatarSize,
      height: _avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _StatusAvatar(
            userId: AppAuth.instance.currentUser?.uid,
            photoUrl: photoUrl,
            statusCount: statusCount,
            seenCount: statusCount,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAddTap,
              child: Container(
                width: _badgeSize,
                height: _badgeSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFB2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF101012),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add,
                  size: 14,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool compact;

  List<Color> _getGradientColors(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;
    return [themeColor, themeColor.withOpacity(0.8)];
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getGradientColors(context);
    final radius = compact ? 14.0 : 24.0;
    final iconPad = compact ? 5.0 : 10.0;
    final iconSize = compact ? 16.0 : 26.0;
    final labelSize = compact ? 8.0 : 11.0;
    final gap = compact ? 4.0 : 8.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: compact
                ? null
                : [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(iconPad),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: gap),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusAvatar extends StatelessWidget {
  const _StatusAvatar({
    this.userId,
    required this.photoUrl,
    required this.statusCount,
    required this.seenCount,
    this.isMuted = false,
  });

  final String? userId;
  final String? photoUrl;
  final int statusCount;
  final int seenCount;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final ringColor = isMuted
        ? Colors.grey.shade600
        : const Color(0xFF00FFB2); // Premium emerald neon green
    final seenRingColor = Colors.white24;

    return Container(
      width: 66,
      height: 66,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (statusCount > 0)
            CustomPaint(
              size: const Size(66, 66),
              painter: _StatusRingPainter(
                statusCount: statusCount,
                seenCount: seenCount,
                color: ringColor,
                seenColor: seenRingColor,
              ),
            ),
          PremiumAvatar(
            userId: userId,
            photoUrl: photoUrl,
            radius: 27,
          ),
        ],
      ),
    );
  }
}

class _StatusRingPainter extends CustomPainter {
  _StatusRingPainter({
    required this.statusCount,
    required this.seenCount,
    required this.color,
    required this.seenColor,
  });

  final int statusCount;
  final int seenCount;
  final Color color;
  final Color seenColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (statusCount <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - paint.strokeWidth) / 2;

    if (statusCount == 1) {
      paint.color = seenCount == 1 ? seenColor : color;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // Segmented ring
    final double spacing = 0.08; // gap size in radians
    final double totalSpacing = spacing * statusCount;
    final double arcLength = (2 * 3.141592653589793 - totalSpacing) / statusCount;

    double startAngle = -3.141592653589793 / 2 + spacing / 2;

    for (int i = 0; i < statusCount; i++) {
      // If index is less than (statusCount - seenCount), it is unseen, otherwise seen
      final isSeen = i >= (statusCount - seenCount);
      paint.color = isSeen ? seenColor : color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcLength,
        false,
        paint,
      );

      startAngle += arcLength + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _StatusRingPainter oldDelegate) {
    return oldDelegate.statusCount != statusCount ||
        oldDelegate.seenCount != seenCount ||
        oldDelegate.color != color ||
        oldDelegate.seenColor != seenColor;
  }
}

class _LiveAvatarRing extends StatefulWidget {
  final String? photoUrl;
  final VoidCallback onTap;
  final String label;

  const _LiveAvatarRing({
    required this.photoUrl,
    required this.onTap,
    required this.label,
  });

  @override
  State<_LiveAvatarRing> createState() => _LiveAvatarRingState();
}

class _LiveAvatarRingState extends State<_LiveAvatarRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final glow = 2.0 + (_controller.value * 5.0);
              return SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 60,
                        height: 60,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE8002D),
                            width: 2.0 + (_controller.value * 0.8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE8002D).withOpacity(0.3 + (_controller.value * 0.4)),
                              blurRadius: glow,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFF1E1E22),
                          backgroundImage: widget.photoUrl != null ? NetworkImage(widget.photoUrl!) : null,
                          child: widget.photoUrl == null
                              ? const Icon(Icons.person, color: Colors.white70, size: 24)
                              : null,
                        ),
                      ),
                    ),
                    // LIVE pill badge at bottom
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8002D),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE8002D).withOpacity(0.55),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 70,
            child: Text(
              widget.label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}