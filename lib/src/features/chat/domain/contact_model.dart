DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  try {
    return (value as dynamic).toDate();
  } catch (_) {
    return DateTime.now();
  }
}

class AppContact {
  const AppContact({
    required this.uid,
    required this.displayName,
    required this.email,
    this.phoneNumber,
    required this.addedAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final DateTime addedAt;

  factory AppContact.fromMap(String uid, Map<String, dynamic> map) {
    final addedAtRaw = map['added_at'] ?? map['addedAt'];
    return AppContact(
      uid: uid,
      displayName: map['display_name'] ?? map['displayName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phone_number'] ?? map['phoneNumber'],
      addedAt: _parseDate(addedAtRaw),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': uid,
      'display_name': displayName,
      'displayName': displayName,
      'email': email,
      'phone_number': phoneNumber,
      'phoneNumber': phoneNumber,
      'added_at': addedAt.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
    };
  }
}
