import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/services.dart';
import 'package:a_chatz/src/core/services/emergency_safety_service.dart';
import 'package:a_chatz/src/features/calls/presentation/calls_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/chats_screen.dart';
import 'package:a_chatz/src/features/status/presentation/updates_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'package:a_chatz/src/features/status/presentation/status_screen.dart';
import 'package:a_chatz/src/features/status/presentation/channels_screen.dart';
import 'package:a_chatz/src/features/business/presentation/business_dashboard_screen.dart' show BusinessDashboardScreen;
import 'package:a_chatz/src/features/ai_agent/presentation/ai_agent_screen.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/features/calls/providers/call_providers.dart';
import 'package:a_chatz/src/features/calls/presentation/incoming_call_screen.dart';
import 'package:a_chatz/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:a_chatz/src/core/services/encryption_service.dart';
import 'package:flutter/foundation.dart';
import 'package:a_chatz/src/features/calls/presentation/incoming_call_overlay.dart';
import 'package:a_chatz/src/features/safety/presentation/widgets/active_safety_overlay.dart';
import 'package:a_chatz/src/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:a_chatz/src/core/services/tutorial_service.dart';
import 'package:a_chatz/src/shared/widgets/app_tutorial_dialog.dart';
import 'package:a_chatz/src/shared/widgets/floating_notification.dart';
import 'package:a_chatz/src/features/calls/data/live_repository.dart';
import 'package:a_chatz/src/features/calls/domain/live_session.dart';
// business_dashboard_screen already imported above
import 'package:a_chatz/src/core/services/device_linking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> with WidgetsBindingObserver {
  int index = 0;
  bool _isOffline = false;
  Timer? _offlineCheckTimer;
  StreamSubscription<QuerySnapshot>? _sosSubscription;
  final Set<String> _notifiedSOSMessageIds = {};
  StreamSubscription<QuerySnapshot>? _scheduledCallsSubscription;
  final Set<String> _notifiedScheduledCallIds = {};
  StreamSubscription<List<LiveSession>>? _liveSessionsSubscription;
  final Set<String> _notifiedLiveSessionIds = {};
  String? _lastOpenedIncomingCallId;

  List<Widget> _buildPages(bool isBusiness) {
    return [
      const ChatsScreen(),
      const UpdatesScreen(),
      const CallsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startConnectivityCheck();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Restore home tab index and last route
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedIndex = prefs.getInt('last_home_tab_index');
        if (savedIndex != null && mounted) {
          setState(() {
            index = savedIndex;
          });
        }
        final lastRoute = prefs.getString('last_route_location');
        if (lastRoute != null && lastRoute != '/home' && lastRoute != '/' && mounted) {
          context.go(lastRoute);
        }
      } catch (_) {}

      final authRepo = ref.read(authRepositoryProvider);
      authRepo.seedOfficialAccount();

      final currentUid = authRepo.uid;
      if (currentUid != null) {
        try {
          await EncryptionService().ensureKeysExistAndSync(currentUid);
        } catch (_) {}
        _startSOSAlertsListener(currentUid);
        _startScheduledCallsListener(currentUid);
        _startLiveSessionsListener(currentUid);
        DeviceLinkingService.instance.startListening(context);
      }
      
      // Initialize safety service (detects shakes if enabled)
      await EmergencySafetyService.instance.init();

      if (!mounted) return;
      if (await TutorialService.shouldShow()) {
        if (!mounted) return;
        await showAppTutorialDialog(context);
        await TutorialService.markCompleted();
      }
    });
  }

  void _startSOSAlertsListener(String currentUid) {
    _sosSubscription = AppDatabase.instance
        .collectionGroup('messages')
        .where('isSOS', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final msgId = doc.id;
          if (_notifiedSOSMessageIds.contains(msgId)) continue;
          _notifiedSOSMessageIds.add(msgId);

          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final senderId = data['senderId'] as String?;
          if (senderId == currentUid) continue;

          final createdAtRaw = data['createdAt'];
          if (createdAtRaw == null) continue;
          final createdAt = (createdAtRaw as Timestamp).toDate();

          // Only notify for fresh messages (sent in the last 2 minutes)
          if (DateTime.now().difference(createdAt).inMinutes > 2) continue;

          final parentChatRef = doc.reference.parent.parent;
          if (parentChatRef != null) {
            final chatDoc = await parentChatRef.get();
            final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
            if (participants.contains(currentUid)) {
              // Fetch sender name
              final senderDoc = await AppDatabase.instance.table('users').doc(senderId).get();
              final senderName = senderDoc.data()?['username'] ?? 'A contact';

              if (mounted) {
                _showInAppSOSAlert(senderName, data['text'] ?? '', parentChatRef.id);
              }
            }
          }
        }
      }
    });
  }

  void _showInAppSOSAlert(String senderName, String messageText, String chatId) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2C0F14).withOpacity(0.95), // Dark red crimson
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.redAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '🚨 EMERGENCY SOS ALERT 🚨',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '$senderName has triggered an SOS alert and needs help immediately!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    messageText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/chat/$chatId');
                        },
                        child: const Text('Open Chat', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }

  void _startScheduledCallsListener(String currentUid) {
    _scheduledCallsSubscription = AppDatabase.instance
        .table('scheduled_calls')
        .where('status', isEqualTo: 'scheduled')
        .snapshots()
        .listen((snapshot) async {
      // Get user chats
      final userChatsSnap = await AppDatabase.instance
          .table('chats')
          .where('memberIds', arrayContains: currentUid)
          .get();
      final userChatIds = userChatsSnap.docs.map((d) => d.id).toSet();

      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final chatId = data['chatId'] as String?;
        if (chatId == null || !userChatIds.contains(chatId)) continue;

        final scheduledAtRaw = data['scheduledAt'];
        if (scheduledAtRaw == null) continue;
        final scheduledAt = (scheduledAtRaw as Timestamp).toDate();

        final meetingId = doc.id;

        // If the scheduled time has arrived/passed (and within 15 mins window)
        if (now.isAfter(scheduledAt) && now.difference(scheduledAt).inMinutes <= 15) {
          if (_notifiedScheduledCallIds.contains(meetingId)) continue;
          _notifiedScheduledCallIds.add(meetingId);

          final title = data['title'] ?? 'Meeting';
          final callType = data['callType'] ?? 'video';

          await _showScheduledCallNotification(meetingId, title, callType);

          if (mounted) {
            _showInAppScheduledCallAlert(meetingId, title, callType, chatId);
          }
        }
      }
    });
  }

  Future<void> _showScheduledCallNotification(String meetingId, String title, String callType) async {
    try {
      final typeStr = callType == 'video' ? 'Video' : 'Voice';
      await NotificationService.localNotifications.show(
        meetingId.hashCode,
        'Meeting Starting Now 📹',
        'Your scheduled $typeStr Call "$title" is starting. Tap to join!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'a_chatz_calls_v2',
            'Calls',
            channelDescription: 'Scheduled call reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        payload: 'scheduled_call:$meetingId',
      );
    } catch (e) {
      debugPrint('Error showing local scheduled call notification: $e');
    }
  }

  void _showInAppScheduledCallAlert(String meetingId, String title, String callType, String chatId) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F2013).withOpacity(0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.greenAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    callType == 'video' ? Icons.videocam : Icons.call,
                    color: Colors.greenAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '📅 MEETING STARTING NOW',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your scheduled meeting "$title" is starting now. Join the call room immediately.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Dismiss'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final repo = ref.read(callRepositoryProvider);
                          final result = await repo.joinScheduledCall(meetingId);
                          if (result != null && mounted) {
                            context.push(
                              '/call-room/${result['callId']}?caller=${result['caller']}&video=${result['video']}&name=${result['name']}',
                            );
                          }
                        },
                        child: const Text('Join Now', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }

  void _startLiveSessionsListener(String currentUid) {
    AppDatabase.instance
        .table('users')
        .doc(currentUid)
        .table('contacts')
        .snapshots()
        .listen((contactsSnap) {
      final contactUids = contactsSnap.docs.map((d) => d.id).toList();
      if (contactUids.isEmpty) return;

      _liveSessionsSubscription?.cancel();

      final liveRepo = ref.read(liveRepositoryProvider);
      _liveSessionsSubscription = liveRepo.watchActiveSessions(contactUids).listen((sessions) {
        for (final session in sessions) {
          if (session.status == 'active') {
            final sessionId = session.id;
            if (_notifiedLiveSessionIds.contains(sessionId)) continue;
            _notifiedLiveSessionIds.add(sessionId);

            // Avoid showing old notifications on app startup
            if (DateTime.now().difference(session.createdAt).inMinutes > 5) continue;

            if (mounted) {
              FloatingNotification.show(
                context,
                title: '🔴 Live Stream Started',
                body: '${session.hostName} is now LIVE: "${session.title}"',
                photoUrl: session.hostPhotoUrl,
                onTap: () {
                  context.push('/live/viewer/$sessionId');
                },
              );
            }
          }
        }
      });
    });
  }

  void _startConnectivityCheck() {
    // Initial verification
    _verifyConnection();

    _offlineCheckTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _verifyConnection();
    });
  }

  Future<void> _verifyConnection() async {
    if (kIsWeb) {
      _updateOfflineState(false);
      return;
    }
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      _updateOfflineState(result.isEmpty || result[0].rawAddress.isEmpty);
    } catch (_) {
      _updateOfflineState(true);
    }
  }

  void _updateOfflineState(bool offline) {
    if (offline != _isOffline) {
      if (mounted) {
        setState(() {
          _isOffline = offline;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyConnection();
    }
  }

  void _setTabIndex(int val) async {
    if (!mounted) return;
    setState(() => index = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_home_tab_index', val);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineCheckTimer?.cancel();
    _sosSubscription?.cancel();
    _scheduledCallsSubscription?.cancel();
    _liveSessionsSubscription?.cancel();
    DeviceLinkingService.instance.stopListening();
    super.dispose();
  }


  
  @override
  Widget build(BuildContext context) {
    ref.listen(incomingCallsProvider, (prev, next) {
      final calls = next.value?.docs;
      if (calls == null || calls.isEmpty) {
        _lastOpenedIncomingCallId = null;
        IncomingCallOverlayManager.instance.remove();
        return;
      }

      final call = calls.first;
      final data = call.data();
      final status = data['status'] as String? ?? 'ringing';

      if (status != 'ended' && status != 'declined') {
        final callerId = data['callerId'] as String;
        final answeredUids = List<String>.from(data['answeredUids'] ?? []);

        final currentUid = ref.read(authRepositoryProvider).uid;
        final meFuture = AppDatabase.instance.table('users').doc(currentUid).get();
        final callerFuture = AppDatabase.instance.table('users').doc(callerId).get();
        final answeredFutures = answeredUids
            .where((uid) => uid != callerId)
            .take(3)
            .map((uid) => AppDatabase.instance.table('users').doc(uid).get());

        Future.wait([meFuture, callerFuture, ...answeredFutures]).then((docs) {
          final meDoc = docs[0];
          final myData = meDoc.data() ?? {};
          final myBlockedUsers = List<String>.from(myData['blockedUsers'] ?? []);
          if (myBlockedUsers.contains(callerId)) {
            // Ignore the call if I blocked them
            return;
          }

          final callerDoc = docs[1];
          final callerUserData = callerDoc.data();
          final callerName = callerUserData?['username'] ?? callerUserData?['email'] ?? 'Someone';

          final otherNames = <String>[];
          for (var i = 2; i < docs.length; i++) {
            final otherDoc = docs[i];
            final otherUserData = otherDoc.data();
            if (otherUserData != null) {
              final name = otherUserData['username'] ?? otherUserData['email'];
              if (name != null) otherNames.add(name);
            }
          }

          String overlayTitle = callerName;
          if (otherNames.isNotEmpty) {
            overlayTitle = "$callerName, ${otherNames.join(', ')}";
          }

          final chatName = data['chatName'] as String?;
          if (chatName != null && chatName.isNotEmpty) {
            overlayTitle = "$overlayTitle calling $chatName";
          } else {
            overlayTitle = "$overlayTitle is calling you";
          }

          if (mounted) {
            final callId = call.id;
            if (_lastOpenedIncomingCallId != callId) {
              _lastOpenedIncomingCallId = callId;
              final nameParam = Uri.encodeComponent(overlayTitle);
              context.push('/incoming-call/$callId?video=${data['type'] == 'video'}&name=$nameParam');
            }
          }
        });
      } else {
        _lastOpenedIncomingCallId = null;
        IncomingCallOverlayManager.instance.remove();
      }
    });

    ref.listen(invitedCoHostSessionsProvider, (prev, next) {
      final sessions = next.value;
      if (sessions == null || sessions.isEmpty) {
        // Only remove if it was a co-host invite that we were showing
        // But IncomingCallOverlayManager is singleton, so if there's no incoming calls either, remove.
        // Actually, we should just let it be handled, or add a check. For now, remove if empty.
        // Wait, if a real call is ringing, removing here will kill the real call UI.
        // Let's only remove if we know it was our invite. 
        // A safer way is to just call remove() if we are actively tracking an invite, but for MVP:
        // IncomingCallOverlayManager.instance.remove(); 
        // We will just let the call end handler do it, or rely on the user tapping decline.
        // But if the host cancels the invite, we need to hide it.
        return;
      }

      final session = sessions.first;
      if (mounted) {
        IncomingCallOverlayManager.instance.show(
          context: context,
          callId: session.id,
          callerName: "Live Co-Host Invite from ${session.hostName}",
          callerPhotoUrl: session.hostPhotoUrl,
          isVideo: true,
          onDecline: () async {
            await AppDatabase.instance
                .table('live_sessions')
                .doc(session.id)
                .update({'coHostStatus': 'declined'});
          },
          onAnswer: () async {
            await AppDatabase.instance
                .table('live_sessions')
                .doc(session.id)
                .update({'coHostStatus': 'accepted'});
            context.go('/live/viewer/${session.id}');
          },
        );
      }
    });

    return ActiveSafetyOverlay(
      child: Stack(
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: AppDatabase.instance.table('users').doc(ref.read(authRepositoryProvider).uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final isBanned = userData?['isBanned'] == true;

        if (isBanned) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await ref.read(authRepositoryProvider).signOut();
            if (context.mounted) {
              context.go('/onboarding');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Your account has been suspended for violating terms of service.'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
          );
        }

        final isBusiness = userData?['accountType'] == 'business';
        final maxIndex = isBusiness ? 5 : 4;
        if (index > maxIndex) {
          index = 0;
        }
        final primaryColor = isBusiness ? Colors.red : Colors.white;

        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktopWeb = screenWidth > 900;

        if (isDesktopWeb) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F0F11),
            body: Row(
              children: [
                // Slim Side Navigation Bar
                Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(right: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15), width: 1.5)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // Glowing App Logo
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.04),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.greenAccent.withOpacity(0.15), width: 1.5),
                        ),
                        child: const Center(
                          child: Icon(Icons.security, color: Colors.greenAccent, size: 22),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Navigation Destinations
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _SidebarDestination(
                                icon: Icons.chat_bubble_outline,
                                selectedIcon: Icons.chat_bubble,
                                label: 'Chats',
                                isSelected: index == 0,
                                onTap: () => _setTabIndex(0),
                                badgeStream: AppDatabase.instance
                                    .table('chats')
                                    .where('memberIds', arrayContains: ref.read(authRepositoryProvider).uid)
                                    .snapshots(),
                                badgeBuilder: (context, snap) {
                                  final currentUid = ref.read(authRepositoryProvider).uid;
                                  int unread = 0;
                                  if (snap.hasData) {
                                    for (final doc in snap.data!.docs) {
                                      final d = doc.data() as Map<String, dynamic>;
                                      final last = d['lastMessageSenderId'] as String?;
                                      final unreadCount = (d['unreadCount'] as Map<String, dynamic>?)?[currentUid] ?? 0;
                                      if (last != null && last != currentUid && unreadCount > 0) unread++;
                                    }
                                  }
                                  return unread > 0 ? '$unread' : null;
                                },
                                badgeColor: Colors.greenAccent,
                              ),
                              const SizedBox(height: 12),
                              _SidebarDestination(
                                icon: Icons.burst_mode_outlined,
                                selectedIcon: Icons.burst_mode,
                                label: 'Updates',
                                isSelected: index == 1,
                                onTap: () => _setTabIndex(1),
                                badgeStream: AppDatabase.instance
                                    .table('statuses')
                                    .where('expiresAt', isGreaterThan: Timestamp.now())
                                    .where('ownerId', isNotEqualTo: ref.read(authRepositoryProvider).uid)
                                    .limit(30)
                                    .snapshots(),
                                badgeBuilder: (context, statusSnap) {
                                  final currentUid = ref.read(authRepositoryProvider).uid;
                                  bool hasUnseen = false;
                                  if (statusSnap.hasData) {
                                    for (var doc in statusSnap.data!.docs) {
                                      final d = doc.data() as Map<String, dynamic>;
                                      final seenBy = d['seenBy'] as Map<String, dynamic>? ?? {};
                                      if (!seenBy.containsKey(currentUid)) {
                                        hasUnseen = true;
                                        break;
                                      }
                                    }
                                  }
                                  return hasUnseen ? '●' : null;
                                },
                                badgeColor: Colors.blueAccent,
                              ),
                              const SizedBox(height: 12),
                              _SidebarDestination(
                                icon: Icons.call_outlined,
                                selectedIcon: Icons.call,
                                label: 'Calls',
                                isSelected: index == 2,
                                onTap: () => _setTabIndex(2),
                                badgeStream: AppDatabase.instance
                                    .table('call_history')
                                    .where('receiverIds', arrayContains: ref.read(authRepositoryProvider).uid)
                                    .snapshots(),
                                badgeBuilder: (context, callSnap) {
                                  final missedCount = callSnap.data?.docs.where((doc) {
                                    final d = doc.data() as Map<String, dynamic>;
                                    final status = d['status'] as String?;
                                    final viewed = d['viewed'] as bool? ?? false;
                                    return (status == 'missed' || status == 'declined') && !viewed;
                                  }).length ?? 0;
                                  return missedCount > 0 ? '$missedCount' : null;
                                },
                                badgeColor: Colors.redAccent,
                              ),
                              const SizedBox(height: 12),
                              _SidebarDestination(
                                icon: Icons.settings_outlined,
                                selectedIcon: Icons.settings,
                                label: 'Settings',
                                isSelected: index == 3,
                                onTap: () => _setTabIndex(3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bottom user quick-info — wired to real profile
                      StreamBuilder<DocumentSnapshot>(
                        stream: AppDatabase.instance
                            .table('users')
                            .doc(ref.read(authRepositoryProvider).uid)
                            .snapshots(),
                        builder: (context, snap) {
                          final data =
                              snap.data?.data() as Map<String, dynamic>?;
                          final photoUrl = data?['photoUrl'] as String?;
                          final isOnline = data?['isOnline'] as bool? ?? false;

                          return Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white10,
                                backgroundImage: (photoUrl != null &&
                                        photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: (photoUrl == null || photoUrl.isEmpty)
                                    ? const Icon(Icons.person,
                                        color: Colors.white60, size: 18)
                                    : null,
                              ),
                              if (isOnline)
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black, width: 1.5),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // Page Content
                Expanded(
                  child: IndexedStack(
                    index: index,
                    children: _buildPages(isBusiness),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: index,
            children: _buildPages(isBusiness),
          ),
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xD3000000) // Frosted pitch black in dark mode
                      : const Color(0xD3FFFFFF), // Frosted pure white in light mode!
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0x1FFFFFFF)
                          : const Color(0x1F000000),
                      width: 0.8,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NavigationBar(
                      backgroundColor: Colors.transparent,
                      indicatorColor: Colors.transparent,
                      selectedIndex: index,
                      onDestinationSelected: _setTabIndex,
                      destinations: [
                        NavigationDestination(
                          icon: StreamBuilder<QuerySnapshot>(
                            stream: AppDatabase.instance
                                .table('chats')
                                .where('memberIds', arrayContains: ref.read(authRepositoryProvider).uid)
                                .snapshots(),
                            builder: (context, snap) {
                              final currentUid = ref.read(authRepositoryProvider).uid;
                              int unread = 0;
                              if (snap.hasData) {
                                for (final doc in snap.data!.docs) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  final last = d['lastMessageSenderId'] as String?;
                                  final unreadCount = (d['unreadCount'] as Map<String, dynamic>?)?[currentUid] ?? 0;
                                  if (last != null && last != currentUid && unreadCount > 0) unread++;
                                }
                              }
                              return Badge(
                                label: unread > 0 ? Text('$unread') : null,
                                isLabelVisible: unread > 0,
                                backgroundColor: Colors.greenAccent,
                                child: const Icon(Icons.chat_bubble_outline),
                              );
                            },
                          ),
                          selectedIcon: const Icon(Icons.chat_bubble),
                          label: 'Chats',
                        ),
                        NavigationDestination(
                          icon: StreamBuilder<QuerySnapshot>(
                            stream: AppDatabase.instance
                                .table('statuses')
                                .where('expiresAt', isGreaterThan: Timestamp.now())
                                .where('ownerId', isNotEqualTo: ref.read(authRepositoryProvider).uid)
                                .limit(30)
                                .snapshots(),
                            builder: (context, statusSnap) {
                              final currentUid = ref.read(authRepositoryProvider).uid;
                              bool hasUnseen = false;
                              if (statusSnap.hasData) {
                                for (var doc in statusSnap.data!.docs) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  final seenBy = d['seenBy'] as Map<String, dynamic>? ?? {};
                                  if (!seenBy.containsKey(currentUid)) {
                                    hasUnseen = true;
                                    break;
                                  }
                                }
                              }
                              return Badge(
                                isLabelVisible: hasUnseen,
                                backgroundColor: Colors.blueAccent,
                                child: const Icon(Icons.burst_mode_outlined),
                              );
                            },
                          ),
                          selectedIcon: const Icon(Icons.burst_mode),
                          label: 'Updates',
                        ),
                        NavigationDestination(
                          icon: StreamBuilder<QuerySnapshot>(
                            stream: AppDatabase.instance
                                .table('call_history')
                                .where('receiverIds', arrayContains: ref.read(authRepositoryProvider).uid)
                                .snapshots(),
                            builder: (context, callSnap) {
                              final missedCount = callSnap.data?.docs.where((doc) {
                                final d = doc.data() as Map<String, dynamic>;
                                final status = d['status'] as String?;
                                final viewed = d['viewed'] as bool? ?? false;
                                return (status == 'missed' || status == 'declined') && !viewed;
                              }).length ?? 0;
                              return Badge(
                                label: missedCount > 0 ? Text('$missedCount') : null,
                                isLabelVisible: missedCount > 0,
                                backgroundColor: Colors.redAccent,
                                child: const Icon(Icons.call_outlined),
                              );
                            },
                          ),
                          selectedIcon: const Icon(Icons.call),
                          label: 'Calls',
                        ),
                        const NavigationDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: 'Settings',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    ),
    _buildOfflineBanner(),
  ],
  ),
);
  }

  Widget _buildOfflineBanner() {
    if (!_isOffline) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 50,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.redAccent.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "You don't have an internet connection. Please connect to continue.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatefulWidget {
  const _SidebarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeStream,
    this.badgeBuilder,
    this.badgeText,
    this.badgeColor = Colors.greenAccent,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? badgeStream;
  final String? Function(BuildContext, AsyncSnapshot<QuerySnapshot>)? badgeBuilder;
  final String? badgeText;
  final Color badgeColor;

  @override
  State<_SidebarDestination> createState() => _SidebarDestinationState();
}

class _SidebarDestinationState extends State<_SidebarDestination> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.label,
          preferBelow: false,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Active background glow card
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? Colors.greenAccent.withOpacity(0.08)
                      : isHovered
                          ? Colors.white.withOpacity(0.03)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    widget.isSelected ? widget.selectedIcon : widget.icon,
                    color: widget.isSelected
                        ? Colors.greenAccent
                        : isHovered
                            ? Colors.white.withOpacity(0.7)
                            : Colors.white.withOpacity(0.38),
                    size: 24,
                  ),
                ),
              ),
              // Left indicator bar
              if (widget.isSelected)
                Positioned(
                  left: 0,
                  child: Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Badge count builder
              if (widget.badgeStream != null && widget.badgeBuilder != null)
                Positioned(
                  right: 4,
                  top: 4,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: widget.badgeStream,
                    builder: (context, snap) {
                      final text = widget.badgeBuilder!(context, snap);
                      if (text == null) return const SizedBox.shrink();

                      final isDotOnly = text == '●';

                      return Container(
                        padding: isDotOnly
                            ? EdgeInsets.zero
                            : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        constraints: BoxConstraints(
                          minWidth: isDotOnly ? 8 : 16,
                          minHeight: isDotOnly ? 8 : 16,
                        ),
                        decoration: BoxDecoration(
                          color: widget.badgeColor,
                          shape: isDotOnly ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: isDotOnly ? null : BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: isDotOnly
                            ? null
                            : Text(
                                text,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      );
                    },
                  ),
                )
              else if (widget.badgeText != null)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
