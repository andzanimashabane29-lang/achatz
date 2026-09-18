import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:a_chatz/src/core/router/app_router.dart';
import 'package:a_chatz/src/features/calls/presentation/active_call_manager.dart';

@pragma('vm:entry-point')
Future<void> appMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] == 'call') {
    await _showCallKit(message.data);
  }
}

Future<void> _showCallKit(Map<String, dynamic> data) async {
  final params = CallKitParams(
    id: data['chatId'] ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
    nameCaller: data['callerName'] ?? 'A-Chatz User',
    appName: 'A-Chatz',
    avatar: data['callerPhotoUrl'] ?? '',
    handle: 'Incoming Call',
    type: 0,
    textAccept: 'Accept',
    textDecline: 'Decline',
    duration: 30000,
    extra: <String, dynamic>{
      'chatId': data['chatId'] ?? data['callId'] ?? '',
      'callId': data['callId'] ?? data['chatId'] ?? '',
      'isVideo': (data['isVideo'] ?? 'false').toString(),
    },
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      backgroundColor: '#000000',
      actionColor: '#4CAF50',
      isShowFullLockedScreen: true,
    ),
    ios: const IOSParams(
      iconName: 'CallKitLogo',
      handleType: 'generic',
      supportsVideo: true,
      maximumCallGroups: 2,
      maximumCallsPerCallGroup: 1,
      audioSessionMode: 'default',
      audioSessionActive: true,
      audioSessionPreferredSampleRate: 44100.0,
      audioSessionPreferredIOBufferDuration: 0.005,
      supportsDTMF: true,
      supportsHolding: true,
      supportsGrouping: false,
      supportsUngrouping: false,
    ),
  );
  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

class FcmService {
  FcmService._();
  static final instance = FcmService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> bootstrap() async {
    AppMessaging.onBackgroundMessage(appMessagingBackgroundHandler);

    await _setupLocalNotifications();

    final messaging = AppMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    if (!kIsWeb) {
      await AppMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final token = await messaging.getToken();
    await _saveToken(token);
    messaging.onTokenRefresh.listen(_saveToken);

    AppMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null && !kIsWeb) {
        final isCall = message.data['type'] == 'call';
        if (isCall) {
          _showCallKit(message.data);
          return;
        }
      }
    });

    if (!kIsWeb) {
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
        if (event == null) return;
        final extra = event.body['extra'] as Map<dynamic, dynamic>? ?? {};
        final chatId = extra['chatId'];

        switch (event.event) {
          case Event.actionCallAccept:
            if (chatId != null) {
              ActiveCallManager.instance.activeCallId = chatId;
              int attempts = 0;
              while (rootNavigatorKey.currentContext == null && attempts < 50) {
                await Future.delayed(const Duration(milliseconds: 100));
                attempts++;
              }
              appRouter.go('/call-room/$chatId?caller=false&video=false');
            }
            break;
          case Event.actionCallDecline:
            if (chatId != null) {
              try {
                await AppDatabase.instance
                    .table('calls')
                    .doc(chatId)
                    .update({'status': 'ended'});
              } catch (_) {}
            }
            break;
          default:
            break;
        }
      });
    }
  }

  Future<void> _setupLocalNotifications() async {
    if (kIsWeb) return;

    const channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const callsChannel = AndroidNotificationChannel(
      'a_chatz_calls_v2', // id
      'Incoming Calls', // title
      description: 'This channel is used for incoming call notifications.',
      importance: Importance.max,
      playSound: true,
      sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(callsChannel);

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(initializationSettings);
  }

  Future<void> _saveToken(String? token) async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (token == null || uid == null) return;
    await AppDatabase.instance
        .table('users')
        .doc(uid)
        .table('tokens')
        .doc(token)
        .set({
      'token': token,
      'platform': 'flutter',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
