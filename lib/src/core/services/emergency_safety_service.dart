import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencySafetyService extends ChangeNotifier {
  static final EmergencySafetyService instance = EmergencySafetyService._();
  EmergencySafetyService._();

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastShakeTime;
  int _shakeCount = 0;

  double? destinationLatitude;
  double? destinationLongitude;
  String? destinationName;
  StreamSubscription<Position>? _positionSubscription;

  final double _shakeThresholdGravity = 2.7; 
  final int _shakeSlopTimeMS = 500;
  final int _shakeCountResetTimeMS = 3000;

  bool _isShakeEnabled = false;
  bool _isSOSActive = false;
  
  bool get isSOSActive => _isSOSActive;
  bool get isProtocolActive => _positionSubscription != null;

  /// Initializes the service and starts listening to shakes if enabled in settings
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isShakeEnabled = prefs.getBool('safety_shake_enabled') ?? false;

    if (_isShakeEnabled) {
      startShakeDetection();
    }
  }

  /// Toggles the shake-to-alert feature
  Future<void> toggleShakeToAlert(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('safety_shake_enabled', enable);
    _isShakeEnabled = enable;

    if (enable) {
      startShakeDetection();
    } else {
      stopShakeDetection();
    }
  }

  /// Begins listening to accelerometer data for the shake gesture
  void startShakeDetection() {
    if (_accelerometerSubscription != null) return;

    _accelerometerSubscription = userAccelerometerEventStream().listen((event) {
      final double x = event.x;
      final double y = event.y;
      final double z = event.z;

      final double gX = x / 9.80665;
      final double gY = y / 9.80665;
      final double gZ = z / 9.80665;

      final double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      if (gForce > _shakeThresholdGravity) {
        final now = DateTime.now();
        if (_lastShakeTime != null && now.difference(_lastShakeTime!).inMilliseconds > _shakeCountResetTimeMS) {
          _shakeCount = 0;
        }

        if (_lastShakeTime == null || now.difference(_lastShakeTime!).inMilliseconds > _shakeSlopTimeMS) {
          _lastShakeTime = now;
          _shakeCount++;

          if (_shakeCount >= 3) {
            _lastShakeTime = null;
            _shakeCount = 0;
            triggerSOS();
          }
        }
      }
    });
  }

  void stopShakeDetection() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  /// Triggers the emergency protocol
  Future<void> triggerSOS() async {
    if (_isSOSActive) return; // Prevent spamming
    _isSOSActive = true;
    notifyListeners();

    try {
      final pos = await _getCurrentLocation();
      final locationLink = pos != null
          ? 'https://maps.google.com/?q=\${pos.latitude},\${pos.longitude}'
          : 'Location unavailable';

      final prefs = await SharedPreferences.getInstance();
      final contactUids = prefs.getStringList('emergency_contact_uids') ?? [];

      if (contactUids.isEmpty) {
        debugPrint('SOS Triggered but no emergency contacts are set!');
        // Fallback: wait a bit and turn off active state
        await Future.delayed(const Duration(seconds: 10));
        _isSOSActive = false;
        return;
      }

      final uid = AppAuth.instance.currentUser?.uid;
      if (uid == null) {
        _isSOSActive = false;
        notifyListeners();
        return;
      }

      final messageText = "🚨 *EMERGENCY SOS* 🚨\\nI need help immediately!\\nMy current location: \$locationLink";

      for (String contactUid in contactUids) {
        // Find or create chat with this contact
        final chatQuery = await AppDatabase.instance
            .table('chats')
            .where('participants', arrayContains: uid)
            .where('type', isEqualTo: 'direct')
            .get();

        String? chatId;
        for (var doc in chatQuery.docs) {
          final participants = List<String>.from(doc['participants']);
          if (participants.contains(contactUid)) {
            chatId = doc.id;
            break;
          }
        }

        if (chatId == null) {
          // Create new chat
          final newChat = await AppDatabase.instance.table('chats').add({
            'type': 'direct',
            'participants': [uid, contactUid],
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': messageText,
            'lastMessageTime': FieldValue.serverTimestamp(),
          });
          chatId = newChat.id;
        }

        // Send the SOS message
        await AppDatabase.instance.table('chats').doc(chatId).table('messages').add({
          'senderId': uid,
          'text': messageText,
          'cipherText': messageText,
          'type': 'text',
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': {uid: true},
          'isSOS': true, // Custom flag to highlight in UI
        });

        // Update chat
        await AppDatabase.instance.table('chats').doc(chatId).update({
          'lastMessage': '🚨 EMERGENCY SOS',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount_\$contactUid': FieldValue.increment(1),
        });
      }

      // Reset SOS active flag after 1 minute to allow triggering again if needed
      Timer(const Duration(minutes: 1), () {
        _isSOSActive = false;
        notifyListeners();
      });

    } catch (e) {
      debugPrint('Error triggering SOS: $e');
      _isSOSActive = false;
      notifyListeners();
    }
  }

  void startLocationBasedSafetyProtocol({
    required double lat,
    required double lng,
    required String name,
  }) {
    cancelLocationBasedSafetyProtocol();
    destinationLatitude = lat;
    destinationLongitude = lng;
    destinationName = name;
    notifyListeners();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );

      if (distance < 150) { // If within 150 meters
        final locationLink = 'https://maps.google.com/?q=${lat},${lng}';
        final messageText = "✅ *Arrived Safely*\nI have safely arrived at my destination ($name).\n$locationLink";
        await _broadcastToEmergencyContacts(messageText);
        cancelLocationBasedSafetyProtocol();
      }
    });
  }

  void cancelLocationBasedSafetyProtocol() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    destinationLatitude = null;
    destinationLongitude = null;
    destinationName = null;
    notifyListeners();
  }

  Future<void> _broadcastToEmergencyContacts(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final contactUids = prefs.getStringList('emergency_contact_uids') ?? [];
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null || contactUids.isEmpty) return;

    for (String contactUid in contactUids) {
      final chatQuery = await AppDatabase.instance
          .table('chats')
          .where('participants', arrayContains: uid)
          .where('type', isEqualTo: 'direct')
          .get();

      String? chatId;
      for (var doc in chatQuery.docs) {
        final participants = List<String>.from(doc['participants']);
        if (participants.contains(contactUid)) {
          chatId = doc.id;
          break;
        }
      }

      if (chatId != null) {
        await AppDatabase.instance.table('chats').doc(chatId).table('messages').add({
          'senderId': uid,
          'text': text,
          'cipherText': text,
          'type': 'text',
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': {uid: true},
        });

        await AppDatabase.instance.table('chats').doc(chatId).update({
          'lastMessage': '✅ Arrived Safely',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount_\$contactUid': FieldValue.increment(1),
        });
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }
}
