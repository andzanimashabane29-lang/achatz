import 'package:a_chatz/src/core/router/app_router.dart';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/calls/data/call_repository.dart';
import 'package:a_chatz/src/shared/widgets/floating_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter/foundation.dart';
import 'package:a_chatz/src/core/services/ai_tools_service.dart';
import 'package:a_chatz/src/core/services/encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

Future<StyleInformation?> _downloadStyleInformation(
  String url,
  String title,
  String displayBody, {
  String? symmetricKey,
}) async {
  if (url.isEmpty) return null;
  try {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      var bytes = response.bodyBytes;
      if (symmetricKey != null && symmetricKey.isNotEmpty) {
        try {
          final decrypted = await EncryptionService().decryptFileBytes(bytes, symmetricKey);
          bytes = Uint8List.fromList(decrypted);
        } catch (e) {
          debugPrint('Failed to decrypt notification media: $e');
        }
      }
      return BigPictureStyleInformation(
        ByteArrayAndroidBitmap(bytes),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        contentTitle: title,
        htmlFormatContentTitle: true,
        summaryText: displayBody,
        htmlFormatSummaryText: true,
      );
    }
  } catch (e) {
    debugPrint('Failed to download image preview for notification: $e');
  }
  return null;
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'reply') {
    final replyText = notificationResponse.input;
    final chatId = notificationResponse.payload;
    if (replyText != null && replyText.isNotEmpty && chatId != null) {
      try {
// Supabase already initialized
        final prefs = await SharedPreferences.getInstance();
        
        final auth = AppAuth.instance;
        if (auth.currentUser == null) {
          int attempts = 0;
          while (auth.currentUser == null && attempts < 20) {
            await Future.delayed(const Duration(milliseconds: 100));
            attempts++;
          }
        }

        String? senderId = auth.currentUser?.uid;
        senderId ??= prefs.getString('current_user_uid');
        if (senderId == null || senderId.isEmpty) {
          debugPrint('Failed to send background reply: senderId is null');
          return;
        }

        await AppDatabase.instance.table('chats').doc(chatId).table('messages').add({
          'senderId': senderId,
          'type': 'text',
          'cipherText': replyText,
          'mediaUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
          'deletedFor': [],
          'deletedForEveryone': false,
          'reactions': {},
          'readBy': {senderId: FieldValue.serverTimestamp()},
          'deliveredTo': {senderId: FieldValue.serverTimestamp()},
          'isEncrypted': false,
        });

        await AppDatabase.instance.table('chats').doc(chatId).update({
          'lastMessage': replyText,
          'lastMessageSenderId': senderId,
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Failed to send background reply: $e');
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> appMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  // Detect calls via data paylods
  final isCall = data['type'] == 'call' || 
                 data['type'] == 'video' || 
                 data['status'] == 'ringing' || 
                 data['callId'] != null;

  if (isCall) {
    final callId = data['callId'] ?? data['chatId'] ?? '';
    if (callId.isEmpty) return;
    
    // Check if call is still ringing to avoid duplicate notifications
    String callerName = data['callerName'] ?? data['username'] ?? 'Incoming Call';
    String callerPhotoUrl = data['callerPhotoUrl'] ?? '';
    
    try {
// Supabase already initialized
      final callDoc = await AppDatabase.instance.table('calls').doc(callId).get();
      if (!callDoc.exists) return;
      final callData = callDoc.data() ?? {};
      final callStatus = callData['status'] as String? ?? '';
      if (callStatus != 'ringing') return; // Don't show notification if call is no longer ringing
      
      // Fetch caller info from call document if not provided
      if (callerName == 'Incoming Call' || callerName.isEmpty) {
        callerName = callData['callerName'] as String? ?? callerName;
      }
      if (callerPhotoUrl.isEmpty) {
        callerPhotoUrl = callData['callerPhotoUrl'] as String? ?? '';
      }
    } catch (_) {
      // If checking fails, proceed with provided data
    }
    
    final isVideo = data['type'] == 'video' || data['isVideo'] == 'true';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'A-Chatz',
      avatar: callerPhotoUrl,
      handle: isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
      type: isVideo ? 1 : 0, // 0: audio, 1: video
      textAccept: 'Accept',
      textDecline: 'Decline',
      duration: 30000,
      extra: <String, dynamic>{
        'callId': callId,
        'isVideo': isVideo.toString(),
        'callerName': callerName,
        'callerPhotoUrl': callerPhotoUrl,
      },
      android: const AndroidParams(
        isCustomNotification: false,
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
  } else {
    // Premium background message notification with image/sticker preview
    final chatId = data['chatId'] ?? '';
    final senderId = data['senderId'] ?? '';
    
    // Fetch sender name and public key from database
    String title = 'A-Chatz';
    String? senderPublicKey;
    if (senderId.isNotEmpty) {
      try {
// Supabase already initialized
        final senderDoc = await AppDatabase.instance.table('users').doc(senderId).get();
        if (senderDoc.exists) {
          final senderData = senderDoc.data() ?? {};
          title = senderData['username'] as String? ?? 'A-Chatz';
          senderPublicKey = senderData['publicKey'] as String?;
        }
      } catch (_) {}
    }
    if (title == 'A-Chatz') {
      title = message.notification?.title ?? data['senderName'] ?? 'A-Chatz';
    }

    final body = message.notification?.body ?? 
                 data['message'] ?? 
                 data['cipherText'] ?? 
                 data['content'] ?? 
                 'New message';
    final mediaUrl = data['mediaUrl'] ?? '';
    final messageType = data['type'] ?? 'text';
    final isEncrypted = data['isEncrypted'] == 'true' || data['isEncrypted'] == true;
    final cipherText = data['cipherText'] ?? '';
    final encryptedMediaKey = data['encryptedMediaKey'] ?? '';

    String displayBody = body;
    if (isEncrypted && cipherText.isNotEmpty && senderPublicKey != null) {
      try {
        displayBody = await EncryptionService().decrypt(cipherText, senderPublicKey);
      } catch (_) {}
    } else if (displayBody == 'New message') {
      displayBody = cipherText.isNotEmpty ? cipherText : displayBody;
    }

    if (messageType == 'voice') {
      displayBody = '🎙️ Voice message';
    } else if (messageType == 'image') {
      displayBody = '📷 Photo${displayBody.isNotEmpty && displayBody != 'New message' && displayBody != '📷 Photo' ? ': $displayBody' : ''}';
    } else if (messageType == 'video') {
      displayBody = '🎥 Video${displayBody.isNotEmpty && displayBody != 'New message' && displayBody != '🎥 Video' ? ': $displayBody' : ''}';
    } else if (messageType == 'sticker') {
      displayBody = '😀 Sticker';
    }

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    await localNotifications.initialize(
      const InitializationSettings(android: androidInit),
    );

    const messagesChannel = AndroidNotificationChannel(
      'messages_channel_v2',
      'Messages',
      description: 'Message notifications with premium chime',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('premium_chime'),
      enableVibration: true,
    );

    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(messagesChannel);

    List<String> suggestions = ['Yes', 'No', 'Thanks!'];
    if (displayBody.isNotEmpty && displayBody != 'New message') {
      try {
        final parts = await AIToolsService.instance.suggestReplies(displayBody);
        if (parts.length >= 3) {
          suggestions = parts.sublist(0, 3);
        } else if (parts.isNotEmpty) {
          suggestions = parts;
        }
      } catch (_) {}
    }

    String? symmetricKey;
    if (encryptedMediaKey.isNotEmpty && senderPublicKey != null) {
      try {
        symmetricKey = await EncryptionService().decrypt(encryptedMediaKey, senderPublicKey);
      } catch (_) {}
    }

    final styleInfo = mediaUrl.isNotEmpty
        ? await _downloadStyleInformation(mediaUrl, title, displayBody, symmetricKey: symmetricKey)
        : null;

    // Build notification with image/sticker preview
    final androidNotificationDetails = AndroidNotificationDetails(
      messagesChannel.id,
      messagesChannel.name,
      channelDescription: messagesChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('premium_chime'),
      enableVibration: true,
      styleInformation: styleInfo,
      actions: [
        AndroidNotificationAction(
          'reply',
          'Reply',
          icon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          inputs: [
            AndroidNotificationActionInput(
              choices: suggestions,
              allowFreeFormInput: true,
              label: 'Type a reply...',
            ),
          ],
        ),
      ],
    );

    final notificationId = chatId.isNotEmpty ? chatId.hashCode : message.hashCode;
    await localNotifications.show(
      notificationId,
      title,
      displayBody,
      NotificationDetails(android: androidNotificationDetails),
      payload: chatId,
    );
  }
}

class NotificationService {
  static final AppMessaging messaging = AppMessaging.instance;

  static final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      final user = AppAuth.instance.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_uid', user.uid);
      }
    } catch (_) {}

    AppMessaging.onBackgroundMessage(appMessagingBackgroundHandler);

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await localNotifications.initialize(
      initSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;

        if (response.actionId == 'reply') {
          final replyText = response.input;
          if (replyText != null && replyText.isNotEmpty && payload != null) {
            try {
              final auth = AppAuth.instance;
              if (auth.currentUser == null) {
                int attempts = 0;
                while (auth.currentUser == null && attempts < 20) {
                  await Future.delayed(const Duration(milliseconds: 100));
                  attempts++;
                }
              }
              final senderId = auth.currentUser?.uid;
              if (senderId != null) {
                await AppDatabase.instance.table('chats').doc(payload).table('messages').add({
                  'senderId': senderId,
                  'type': 'text',
                  'cipherText': replyText,
                  'mediaUrl': null,
                  'createdAt': FieldValue.serverTimestamp(),
                  'deletedFor': [],
                  'deletedForEveryone': false,
                  'reactions': {},
                  'readBy': {senderId: FieldValue.serverTimestamp()},
                  'deliveredTo': {senderId: FieldValue.serverTimestamp()},
                  'isEncrypted': false,
                });

                await AppDatabase.instance.table('chats').doc(payload).update({
                  'lastMessage': replyText,
                  'lastMessageSenderId': senderId,
                  'lastMessageAt': FieldValue.serverTimestamp(),
                });
              }
            } catch (e) {
              debugPrint('Error sending foreground direct reply: $e');
            }
          }
          return;
        }

        if (payload != null && payload.isNotEmpty) {
          if (payload.startsWith('call:')) {
            final parts = payload.split(':');
            if (parts.length >= 4) {
              final callId = parts[1];
              final isVideo = parts[2] == 'true';
              final callerName = parts[3];
              appRouter.go('/incoming-call/$callId?video=$isVideo&callerName=$callerName');
            }
          } else if (payload.startsWith('scheduled_call:')) {
            final meetingId = payload.substring('scheduled_call:'.length);
            final db = AppDatabase.instance;
            final auth = AppAuth.instance;
            final repo = CallRepository(db, auth);
            final result = await repo.joinScheduledCall(meetingId);
            if (result != null) {
              appRouter.go(
                '/call-room/${result['callId']}?caller=${result['caller']}&video=${result['video']}&name=${result['name']}',
              );
            }
          } else {
            appRouter.go('/chat/$payload');
          }
        }
      },
    );

    const messagesChannel = AndroidNotificationChannel(
      'messages_channel_v2',
      'Messages',
      description: 'Message notifications with premium chime',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('premium_chime'),
      enableVibration: true,
    );

    const callsChannel = AndroidNotificationChannel(
      'a_chatz_calls_v2',
      'Calls',
      description: 'Incoming call notifications',
      importance: Importance.max,
      playSound: true,
      sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
      enableVibration: true,
    );

    final plugin = localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    await plugin?.createNotificationChannel(messagesChannel);
    await plugin?.createNotificationChannel(callsChannel);

    AppMessaging.onMessage.listen((message) async {
      final data = message.data;

      if (data['type'] == 'device_linking') {
        final code = data['code'] ?? '';
        final title = message.notification?.title ?? 'Device Linking Request';
        final body = code.isNotEmpty 
            ? 'A new device is trying to link. Use code: $code' 
            : (message.notification?.body ?? 'A new device is trying to link.');
        
        final androidDetails = const AndroidNotificationDetails(
          'messages_channel_v2',
          'Messages',
          channelDescription: 'Device linking updates',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('premium_chime'),
          enableVibration: true,
        );

        localNotifications.show(
          12345,
          title,
          body,
          NotificationDetails(android: androidDetails),
          payload: 'device_linking',
        );

        final context = appRouter.routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          FloatingNotification.show(
            context,
            title: title,
            body: body,
            photoUrl: null,
            onTap: () {},
          );
        }
        return;
      }

      final isCall = data['type'] == 'call' || 
                     data['type'] == 'video' || 
                     data['status'] == 'ringing' || 
                     data['callId'] != null;
      if (isCall) return;

      final chatId = message.data['chatId'] ?? '';
      final senderId = message.data['senderId'] ?? '';
      
      // Fetch sender name and public key from database
      String title = 'A-Chatz';
      String? senderPublicKey;
      if (senderId.isNotEmpty) {
        try {
          final senderDoc = await AppDatabase.instance.table('users').doc(senderId).get();
          if (senderDoc.exists) {
            final senderData = senderDoc.data() ?? {};
            title = senderData['username'] as String? ?? 'A-Chatz';
            senderPublicKey = senderData['publicKey'] as String?;
          }
        } catch (_) {}
      }
      if (title == 'A-Chatz') {
        title = message.data['senderName'] ?? message.notification?.title ?? 'A-Chatz';
      }

      final body = message.notification?.body ?? 
                   message.data['message'] ?? 
                   message.data['cipherText'] ?? 
                   message.data['content'] ?? 
                   'New message';
      final photoUrl = message.data['senderPhotoUrl'] ?? '';
      final mediaUrl = message.data['mediaUrl'] ?? '';
      final messageType = message.data['type'] ?? 'text';
      final isEncrypted = message.data['isEncrypted'] == 'true' || message.data['isEncrypted'] == true;
      final cipherText = message.data['cipherText'] ?? '';
      final encryptedMediaKey = message.data['encryptedMediaKey'] ?? '';

      // Customize body based on message type
      String displayBody = body;
      if (isEncrypted && cipherText.isNotEmpty && senderPublicKey != null) {
        try {
          displayBody = await EncryptionService().decrypt(cipherText, senderPublicKey);
        } catch (_) {}
      } else if (displayBody == 'New message') {
        displayBody = cipherText.isNotEmpty ? cipherText : displayBody;
      }

      if (messageType == 'voice') {
        displayBody = '🎙️ Voice message';
      } else if (messageType == 'image') {
        displayBody = '📷 Photo${displayBody.isNotEmpty && displayBody != 'New message' && displayBody != '📷 Photo' ? ': $displayBody' : ''}';
      } else if (messageType == 'video') {
        displayBody = '🎥 Video${displayBody.isNotEmpty && displayBody != 'New message' && displayBody != '🎥 Video' ? ': $displayBody' : ''}';
      } else if (messageType == 'sticker') {
        displayBody = '😀 Sticker';
      }

      List<String> suggestions = ['Yes', 'No', 'Thanks!'];
      if (displayBody.isNotEmpty && displayBody != 'New message') {
        try {
          final parts = await AIToolsService.instance.suggestReplies(displayBody);
          if (parts.length >= 3) {
            suggestions = parts.sublist(0, 3);
          } else if (parts.isNotEmpty) {
            suggestions = parts;
          }
        } catch (_) {}
      }

      String? symmetricKey;
      if (encryptedMediaKey.isNotEmpty && senderPublicKey != null) {
        try {
          symmetricKey = await EncryptionService().decrypt(encryptedMediaKey, senderPublicKey);
        } catch (_) {}
      }

      final styleInfo = mediaUrl.isNotEmpty
          ? await _downloadStyleInformation(mediaUrl, title, displayBody, symmetricKey: symmetricKey)
          : null;

      // Always show notification regardless of app state (foreground/background)
      // This ensures notifications work both inside and outside the app
      final androidNotificationDetails = AndroidNotificationDetails(
        'messages_channel_v2',
        'Messages',
        channelDescription: 'Message notifications with premium chime',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('premium_chime'),
        enableVibration: true,
        styleInformation: styleInfo,
        actions: [
          AndroidNotificationAction(
            'reply',
            'Reply',
            icon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
            inputs: [
              AndroidNotificationActionInput(
                choices: suggestions,
                allowFreeFormInput: true,
                label: 'Type a reply...',
              ),
            ],
          ),
        ],
      );

      final notificationId = chatId.isNotEmpty ? chatId.hashCode : message.hashCode;
      localNotifications.show(
        notificationId,
        title,
        displayBody,
        NotificationDetails(android: androidNotificationDetails),
        payload: chatId,
      );

      // Also show floating notification if app is in foreground and not on the active chat
      final context = appRouter.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final currentRoute = appRouter.routerDelegate.currentConfiguration.uri.path;
        if (chatId.isNotEmpty && currentRoute != '/chat/$chatId') {
          FloatingNotification.show(
            context,
            title: title,
            body: displayBody,
            photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
            onTap: () {
              if (chatId.isNotEmpty) {
                appRouter.go('/chat/$chatId');
              }
            },
          );
        }
      }
    });

    AppMessaging.onMessageOpenedApp.listen((message) async {
      final data = message.data;
      final callId = data['callId'];
      final chatId = data['chatId'];

      // If this FCM message is a call notification, answer and route to call room
      if (callId != null && callId.isNotEmpty) {
        final isVideo = data['type'] == 'video' || data['isVideo'] == 'true';
        final callerName = data['callerName'] ?? data['username'] ?? 'Contact';
        final photoUrl = data['callerPhotoUrl'] ?? '';
        try {
          await answerCall(callId);
          // Wait for app/router to be ready
          int attempts = 0;
          while (rootNavigatorKey.currentContext == null && attempts < 40) {
            await Future.delayed(const Duration(milliseconds: 150));
            attempts++;
          }
          final nameParam = Uri.encodeComponent(callerName);
          final photoParam = photoUrl.isNotEmpty ? Uri.encodeComponent(photoUrl) : '';
          appRouter.go('/call-room/$callId?caller=false&video=$isVideo&name=$nameParam&photoUrl=$photoParam');
        } catch (e) {
          debugPrint('Error answering call from notification tap: $e');
        }
      } else if (chatId != null && chatId.isNotEmpty) {
        appRouter.go('/chat/$chatId');
      }
    });

    final initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null) {
      final data = initialMessage.data;
      final callId = data['callId'];
      final chatId = data['chatId'];

      // App was launched by tapping a call notification while terminated
      if (callId != null && callId.isNotEmpty) {
        final isVideo = data['type'] == 'video' || data['isVideo'] == 'true';
        final callerName = data['callerName'] ?? data['username'] ?? 'Contact';
        final photoUrl = data['callerPhotoUrl'] ?? '';
        try {
          await answerCall(callId);
          // Wait for router to be ready after cold start
          int attempts = 0;
          while (rootNavigatorKey.currentContext == null && attempts < 60) {
            await Future.delayed(const Duration(milliseconds: 150));
            attempts++;
          }
          final nameParam = Uri.encodeComponent(callerName);
          final photoParam = photoUrl.isNotEmpty ? Uri.encodeComponent(photoUrl) : '';
          appRouter.go('/call-room/$callId?caller=false&video=$isVideo&name=$nameParam&photoUrl=$photoParam');
        } catch (e) {
          debugPrint('Error answering call from initial message: $e');
        }
      } else if (chatId != null && chatId.isNotEmpty) {
        appRouter.go('/chat/$chatId');
      }
    }

    await saveToken();

    messaging.onTokenRefresh.listen((token) async {
      await saveToken(token: token);
    });

    // Listen to native CallKit accept/decline action buttons
    if (!kIsWeb) {
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
        if (event == null) return;
        final extra = Map<String, dynamic>.from(event.body['extra'] ?? {});
        final callId = extra['callId'] as String?;
        final isVideo = extra['isVideo'] == 'true';
        final name = extra['callerName'] as String? ?? 'Contact';
        final photoUrl = extra['callerPhotoUrl'] as String? ?? '';

        if (callId == null || callId.isEmpty) return;

        switch (event.event) {
          case Event.actionCallAccept:
            try {
              await answerCall(callId);
              final nameParam = Uri.encodeComponent(name);
              final photoParam = photoUrl.isNotEmpty ? Uri.encodeComponent(photoUrl) : '';
              appRouter.go('/call-room/$callId?caller=false&video=$isVideo&name=$nameParam&photoUrl=$photoParam');
            } catch (e) {
              debugPrint('Error answering CallKit call: $e');
            }
            break;
          case Event.actionCallDecline:
            try {
              await declineCall(callId);
            } catch (e) {
              debugPrint('Error declining CallKit call: $e');
            }
            break;
          default:
            break;
        }
      });
    }
  }

  static Future<void> answerCall(String callId) async {
    final db = AppDatabase.instance;
    final snapshot = await db.table('calls').doc(callId).get();
    if (!snapshot.exists) return;
    final data = snapshot.data() ?? {};
    final chatId = data['chatId'] as String?;
    final type = data['type'] as String? ?? 'voice';

    await db.table('calls').doc(callId).update({
      'status': 'answered',
      'answeredAt': FieldValue.serverTimestamp(),
    });

    final query = await db.table('call_history').where('callId', isEqualTo: callId).get();
    for (final doc in query.docs) {
      await doc.reference.update({'status': 'answered'});
    }

    if (chatId != null) {
      final typeStr = type == 'video' ? 'Video Call' : 'Voice Call';
      final senderId = AppAuth.instance.currentUser?.uid ?? 'system';

      await db.table('chats').doc(chatId).table('messages').add({
        'senderId': senderId,
        'type': 'system',
        'cipherText': '📞 Answered $typeStr',
        'mediaUrl': null,
        'fileName': null,
        'durationMs': null,
        'replyToMessageId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'deletedFor': [],
        'seenBy': {},
        'isEncrypted': false,
      });

      await db.table('chats').doc(chatId).update({
        'lastMessage': '📞 Answered $typeStr',
        'lastMessageSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> declineCall(String callId) async {
    final db = AppDatabase.instance;
    final snapshot = await db.table('calls').doc(callId).get();
    if (!snapshot.exists) return;
    final data = snapshot.data() ?? {};
    final chatId = data['chatId'] as String?;
    final type = data['type'] as String? ?? 'voice';

    await db.table('calls').doc(callId).update({
      'status': 'declined',
      'endedAt': FieldValue.serverTimestamp(),
    });

    final query = await db.table('call_history').where('callId', isEqualTo: callId).get();
    for (final doc in query.docs) {
      await doc.reference.update({'status': 'declined'});
    }

    if (chatId != null) {
      final typeStr = type == 'video' ? 'Video Call' : 'Voice Call';
      final senderId = AppAuth.instance.currentUser?.uid ?? 'system';

      await db.table('chats').doc(chatId).table('messages').add({
        'senderId': senderId,
        'type': 'system',
        'cipherText': '📞 Missed $typeStr',
        'mediaUrl': null,
        'fileName': null,
        'durationMs': null,
        'replyToMessageId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'deletedFor': [],
        'seenBy': {},
        'isEncrypted': false,
      });

      await db.table('chats').doc(chatId).update({
        'lastMessage': '📞 Missed $typeStr',
        'lastMessageSenderId': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> saveToken({String? token}) async {
    final user = AppAuth.instance.currentUser;

    if (user == null) return;

    final fcmToken = token ?? await messaging.getToken();

    if (fcmToken == null) return;

    await AppDatabase.instance.table('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([fcmToken]),
      'lastFcmToken': fcmToken,
    }, SetOptions(merge: true));

    // Also save in 'tokens' subcollection for Cloud Functions
    await AppDatabase.instance
        .table('users')
        .doc(user.uid)
        .table('tokens')
        .doc(fcmToken)
        .set({
      'createdAt': FieldValue.serverTimestamp(),
      'platform': 'android',
    });
  }
}