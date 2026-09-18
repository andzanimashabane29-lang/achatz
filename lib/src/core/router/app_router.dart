import 'package:a_chatz/src/features/auth/presentation/login_screen.dart';
import 'package:a_chatz/src/features/auth/presentation/onboarding_screen.dart';
import 'package:a_chatz/src/features/ai_agent/presentation/ai_agent_screen.dart';
import 'package:a_chatz/src/features/calls/presentation/call_screen.dart';
import 'package:a_chatz/src/features/calls/presentation/incoming_call_screen.dart';
import 'package:a_chatz/src/features/calls/presentation/go_live_setup_screen.dart';
import 'package:a_chatz/src/features/calls/presentation/host_live_screen.dart';
import 'package:a_chatz/src/features/calls/presentation/viewer_live_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/contact_info_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/starred_messages_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/media_links_docs_screen.dart';
import 'package:a_chatz/src/features/status/presentation/create_channel_screen.dart';
import 'package:a_chatz/src/features/status/presentation/create_text_status_screen.dart';
import 'package:a_chatz/src/features/status/presentation/create_voice_status_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/settings_screens.dart';
import 'package:a_chatz/src/features/status/presentation/channel_feed_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/chat_room_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/create_group_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/user_search_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/locked_chats_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/archived_chats_screen.dart';
import 'package:a_chatz/src/features/home/presentation/shell_screen.dart';
import 'package:a_chatz/src/features/notifications/presentation/notifications_screen.dart';
import 'package:a_chatz/src/features/chat/presentation/qr_scanner_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/profile_screen.dart';
import 'package:a_chatz/src/features/business/presentation/business_dashboard_screen.dart';
import 'dart:async';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  refreshListenable: GoRouterRefreshStream(AppAuth.instance.authStateChanges()),
  redirect: (context, state) async {
    final user = AppAuth.instance.currentUser;
    final isAuthenticated = user != null;
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/onboarding';

    if (!isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_route_location');
      await prefs.remove('last_home_tab_index');

      if (!isLoggingIn) {
        return '/onboarding';
      }
    } else if (isLoggingIn) {
      // Restore last location when logging in
      final prefs = await SharedPreferences.getInstance();
      final lastLocation = prefs.getString('last_route_location');
      if (lastLocation != null && lastLocation.isNotEmpty) {
        return lastLocation;
      }
      return '/home';
    }

    // Save last location if authenticated (not on call screens)
    if (isAuthenticated && !isLoggingIn) {
      final loc = state.uri.toString();
      if (!loc.contains('/call-room') && !loc.contains('/incoming-call') && loc != '/') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_route_location', loc);
      }
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),

    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),

    GoRoute(
      path: '/home',
      builder: (_, __) => const ShellScreen(),
    ),

    GoRoute(
      path: '/profile',
      builder: (_, __) => const ProfileScreen(),
    ),

    GoRoute(
      path: '/business-dashboard',
      builder: (_, __) => const BusinessDashboardScreen(),
    ),

    GoRoute(
      path: '/ai-agent',
      builder: (_, __) => const AIAgentScreen(),
    ),

    GoRoute(
      path: '/locked-chats',
      builder: (_, __) => const LockedChatsScreen(),
    ),

    GoRoute(
      path: '/archived-chats',
      builder: (_, __) => const ArchivedChatsScreen(),
    ),

    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),

    GoRoute(
      path: '/create-text-status',
      builder: (_, __) => const CreateTextStatusScreen(),
    ),
    GoRoute(
      path: '/create-voice-status',
      builder: (_, __) => const CreateVoiceStatusScreen(),
    ),
    GoRoute(
      path: '/create-channel',
      builder: (_, __) => const CreateChannelScreen(),
    ),

    GoRoute(
      path: '/search-users',
      builder: (_, __) => const UserSearchScreen(),
    ),

    GoRoute(
      path: '/qr-scanner',
      builder: (_, __) => const QrScannerScreen(),
    ),

    GoRoute(
      path: '/settings-chats',
      builder: (_, __) => const SettingsChatsScreen(),
    ),
    GoRoute(
      path: '/settings-notifications',
      builder: (_, __) => const SettingsNotificationsScreen(),
    ),
    GoRoute(
      path: '/settings-language',
      builder: (_, __) => const SettingsLanguageScreen(),
    ),
    GoRoute(
      path: '/settings-storage',
      builder: (_, __) => const SettingsStorageScreen(),
    ),
    GoRoute(
      path: '/settings-help',
      builder: (_, __) => const SettingsHelpScreen(),
    ),
    GoRoute(
      path: '/settings-blocked',
      builder: (_, __) => const SettingsBlockedContactsScreen(),
    ),

    GoRoute(
      path: '/create-group',
      builder: (_, __) => const CreateGroupScreen(),
    ),

    GoRoute(
      path: '/chat/:chatId',
      builder: (_, state) {
        return ChatRoomScreen(
          chatId: state.pathParameters['chatId']!,
        );
      },
    ),
    GoRoute(
      path: '/channel/:channelId',
      builder: (_, state) {
        return ChannelFeedScreen(
          channelId: state.pathParameters['channelId']!,
        );
      },
    ),

    GoRoute(
      path: '/contact-info/:chatId/:contactUid',
      builder: (_, state) {
        return ContactInfoScreen(
          chatId: state.pathParameters['chatId']!,
          contactUid: state.pathParameters['contactUid']!,
        );
      },
    ),
    GoRoute(
      path: '/chat/:chatId/starred',
      builder: (_, state) {
        return StarredMessagesScreen(
          chatId: state.pathParameters['chatId']!,
        );
      },
    ),
    GoRoute(
      path: '/chat/:chatId/shared',
      builder: (_, state) {
        return MediaLinksDocsScreen(
          chatId: state.pathParameters['chatId']!,
        );
      },
    ),

    GoRoute(
      path: '/call-room/:callId',
      builder: (_, state) {
        final callId = state.pathParameters['callId']!;
        final isCaller =
            state.uri.queryParameters['caller'] == 'true';

        final isVideo =
            state.uri.queryParameters['video'] == 'true';

        final name = state.uri.queryParameters['name'];
        final photoUrl = state.uri.queryParameters['photoUrl'];

        return CallScreen(
          callId: callId,
          isCaller: isCaller,
          isVideo: isVideo,
          initialRemoteUserName: name,
          initialRemotePhotoUrl: (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : null,
        );
      },
    ),

    GoRoute(
      path: '/incoming-call/:callId',
      builder: (_, state) {
        final callId = state.pathParameters['callId']!;

        final isVideo =
            state.uri.queryParameters['video'] == 'true';

        final callerName =
            state.uri.queryParameters['name'] ??
                'A-Chatz User';

        return IncomingCallScreen(
          callId: callId,
          isVideo: isVideo,
          callerName: callerName,
        );
      },
    ),
    GoRoute(
      path: '/go-live',
      builder: (_, __) => const GoLiveSetupScreen(),
    ),
    GoRoute(
      path: '/live/host/:sessionId',
      builder: (_, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return HostLiveScreen(sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/live/viewer/:sessionId',
      builder: (_, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return ViewerLiveScreen(sessionId: sessionId);
      },
    ),
  ],
);