DateTime _parseDate(dynamic value, [DateTime? fallback]) {
  if (value == null) return fallback ?? DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? (fallback ?? DateTime.now());
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  try {
    return (value as dynamic).toDate() ?? (fallback ?? DateTime.now());
  } catch (_) {
    return fallback ?? DateTime.now();
  }
}

class Channel {
  const Channel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.followersCount,
    required this.createdAt,
    this.photoUrl,
    this.isVerified = false,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String? photoUrl;
  final int followersCount;
  final bool isVerified;
  final DateTime createdAt;

  factory Channel.fromMap(String id, Map<String, dynamic> map) {
    return Channel(
      id: id,
      ownerId: (map['owner_id'] ?? map['ownerId'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      photoUrl: map['photo_url'] ?? map['photoUrl'],
      followersCount: (map['followers_count'] ?? map['followersCount'] as num?)?.toInt() ?? 0,
      isVerified: (map['is_verified'] ?? map['isVerified']) ?? false,
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'ownerId': ownerId,
      'name': name,
      'description': description,
      'photo_url': photoUrl,
      'photoUrl': photoUrl,
      'followers_count': followersCount,
      'followersCount': followersCount,
      'is_verified': isVerified,
      'isVerified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
