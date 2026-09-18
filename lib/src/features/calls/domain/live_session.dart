import 'package:a_chatz/src/core/supabase/supabase.dart';
class LiveSession {
  const LiveSession({
    required this.id,
    required this.hostId,
    required this.hostName,
    this.hostPhotoUrl,
    required this.title,
    required this.viewerCount,
    required this.status,
    required this.createdAt,
    this.coHostId,
    this.coHostName,
    this.coHostPhotoUrl,
    this.coHostStatus,
  });

  final String id;
  final String hostId;
  final String hostName;
  final String? hostPhotoUrl;
  final String title;
  final int viewerCount;
  final String status; // 'active' or 'ended'
  final DateTime createdAt;
  final String? coHostId;
  final String? coHostName;
  final String? coHostPhotoUrl;
  final String? coHostStatus;

  factory LiveSession.fromMap(String id, Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];
    return LiveSession(
      id: id,
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? 'User',
      hostPhotoUrl: map['hostPhotoUrl'],
      title: map['title'] ?? '',
      viewerCount: map['viewerCount'] ?? 0,
      status: map['status'] ?? 'ended',
      createdAt: createdAtRaw == null
          ? DateTime.now()
          : (createdAtRaw as Timestamp).toDate(),
      coHostId: map['coHostId'],
      coHostName: map['coHostName'],
      coHostPhotoUrl: map['coHostPhotoUrl'],
      coHostStatus: map['coHostStatus'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'hostName': hostName,
      'hostPhotoUrl': hostPhotoUrl,
      'title': title,
      'viewerCount': viewerCount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'coHostId': coHostId,
      'coHostName': coHostName,
      'coHostPhotoUrl': coHostPhotoUrl,
      'coHostStatus': coHostStatus,
    };
  }
}

class LiveComment {
  const LiveComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final DateTime createdAt;

  factory LiveComment.fromMap(String id, Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];
    return LiveComment(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'User',
      userPhotoUrl: map['userPhotoUrl'],
      text: map['text'] ?? '',
      createdAt: createdAtRaw == null
          ? DateTime.now()
          : (createdAtRaw as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
