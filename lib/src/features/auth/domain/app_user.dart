import 'package:equatable/equatable.dart';

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.username,
    this.phoneNumber,
    this.avatarUrl,
    this.bio = '',
    this.status = 'Available',
    this.isOnline = false,
    this.lastSeen,
    this.blockedUserIds = const [],
    this.accountType = 'personal',
    this.publicKey,
    this.role = 'user',
    this.isBanned = false,
    this.isVerified = false,
  });

  final String uid;
  final String? email;
  final String username;
  final String? phoneNumber;
  final String? avatarUrl;
  final String bio;
  final String status;
  final bool isOnline;
  final DateTime? lastSeen;
  final List<String> blockedUserIds;
  final String accountType;
  final String? publicKey;
  final String role;
  final bool isBanned;
  final bool isVerified;

  factory AppUser.fromMap(String id, Map<String, dynamic> map) => AppUser(
        uid: id,
        email: map['email'],
        username: map['username'] ?? 'A-Chatz User',
        phoneNumber: map['phone_number'] ?? map['phoneNumber'],
        avatarUrl: map['avatar_url'] ?? map['avatarUrl'] ?? map['photoUrl'],
        bio: map['bio'] ?? '',
        status: map['status'] ?? 'Available',
        isOnline: map['is_online'] ?? map['isOnline'] ?? false,
        lastSeen: _parseDateTime(map['last_seen'] ?? map['lastSeen']),
        blockedUserIds: List<String>.from(map['blocked_user_ids'] ?? map['blockedUserIds'] ?? []),
        accountType: map['account_type'] ?? map['accountType'] ?? 'personal',
        publicKey: map['public_key'] ?? map['publicKey'],
        role: map['role'] ?? 'user',
        isBanned: map['is_banned'] ?? map['isBanned'] ?? false,
        isVerified: map['is_verified'] ?? map['isVerified'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': uid,
        'email': email,
        'username': username,
        'phone_number': phoneNumber,
        'phoneNumber': phoneNumber,
        'avatar_url': avatarUrl,
        'avatarUrl': avatarUrl,
        'photoUrl': avatarUrl,
        'bio': bio,
        'status': status,
        'is_online': isOnline,
        'isOnline': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
        'lastSeen': lastSeen?.toIso8601String(),
        'blocked_user_ids': blockedUserIds,
        'blockedUserIds': blockedUserIds,
        'account_type': accountType,
        'accountType': accountType,
        'public_key': publicKey,
        'publicKey': publicKey,
        'role': role,
        'is_banned': isBanned,
        'isBanned': isBanned,
        'is_verified': isVerified,
        'isVerified': isVerified,
        'updated_at': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [
        uid,
        email,
        username,
        phoneNumber,
        avatarUrl,
        bio,
        status,
        isOnline,
        lastSeen,
        blockedUserIds,
        accountType,
        publicKey,
        role,
        isBanned,
        isVerified,
      ];
}
