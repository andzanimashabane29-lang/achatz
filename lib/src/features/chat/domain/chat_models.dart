enum ChatType { private, group }

enum MessageType {
  text,
  image,
  imageGroup,
  video,
  voice,
  document,
  location,
  system,
  sticker,
  poll,
}

enum MessageStatus { sent, delivered, read }

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  try {
    // In case an object with toDate() exists
    return (value as dynamic).toDate();
  } catch (_) {
    return null;
  }
}

class ChatThread {
  const ChatThread({
    required this.id,
    required this.type,
    required this.title,
    required this.memberIds,
    this.photoUrl,
    this.description,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.pinnedMessageIds = const [],
    this.mutedBy = const [],
    this.archivedBy = const [],
    this.admins = const [],
    this.lockedBy = const [],
    this.createdBy,
    this.unreadCount = const {},
    this.disappearingDuration,
    this.typing = const {},
    this.recording = const {},
    this.deletedAt = const {},
    this.isGhost = false,
    this.crmLabels = const {},
    this.lastMessageDeliveredTo = const {},
  });

  final String id;
  final ChatType type;
  final String title;
  final String? photoUrl;
  final String? description;
  final List<String> memberIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final List<String> pinnedMessageIds;
  final List<String> mutedBy;
  final List<String> archivedBy;
  final List<String> admins;
  final List<String> lockedBy;
  final String? createdBy;
  final Map<String, int> unreadCount;
  final int? disappearingDuration;
  final Map<String, bool> typing;
  final Map<String, bool> recording;
  final Map<String, DateTime> deletedAt;
  final bool isGhost;
  final Map<String, String> crmLabels;
  final Map<String, dynamic> lastMessageDeliveredTo;

  bool get isGroup => type == ChatType.group;

  bool isAdmin(String uid) {
    return admins.contains(uid);
  }

  factory ChatThread.fromMap(String id, Map<String, dynamic> map) {
    final lastMessageAtRaw = map['last_message_at'] ?? map['lastMessageAt'];
    final rawType = (map['type'] ?? 'private').toString().trim().toLowerCase();

    return ChatThread(
      id: id,
      type: rawType == 'group' ? ChatType.group : ChatType.private,
      title: (map['title'] ?? 'Chat').toString(),
      photoUrl: map['photo_url'] ?? map['photoUrl'],
      description: map['description'],
      memberIds: List<String>.from(map['member_ids'] ?? map['memberIds'] ?? []),
      lastMessage: map['last_message'] ?? map['lastMessage'],
      lastMessageAt: _parseDate(lastMessageAtRaw),
      lastMessageSenderId: map['last_message_sender_id'] ?? map['lastMessageSenderId'],
      pinnedMessageIds: List<String>.from(map['pinned_message_ids'] ?? map['pinnedMessageIds'] ?? []),
      mutedBy: List<String>.from(map['muted_by'] ?? map['mutedBy'] ?? []),
      archivedBy: List<String>.from(map['archived_by'] ?? map['archivedBy'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      lockedBy: List<String>.from(map['locked_by'] ?? map['lockedBy'] ?? []),
      createdBy: map['created_by'] ?? map['createdBy'],
      unreadCount: Map<String, int>.from(
        (map['unread_count'] ?? map['unreadCount'] ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
        ),
      ),
      disappearingDuration: (map['disappearing_duration'] ?? map['disappearingDuration']) as int?,
      typing: Map<String, bool>.from(
        (map['typing'] ?? {}).map(
          (k, v) => MapEntry(k.toString(), v == true),
        ),
      ),
      recording: Map<String, bool>.from(
        (map['recording'] ?? {}).map(
          (k, v) => MapEntry(k.toString(), v == true),
        ),
      ),
      deletedAt: (map['deleted_at'] ?? map['deletedAt'] as Map<String, dynamic>? ?? {}).map(
        (key, value) {
          final dt = _parseDate(value);
          return MapEntry(key.toString(), dt ?? DateTime.now());
        },
      ),
      isGhost: (map['is_ghost'] ?? map['isGhost']) as bool? ?? false,
      crmLabels: Map<String, String>.from(
        (map['crm_labels'] ?? map['crmLabels'] ?? {}).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      ),
      lastMessageDeliveredTo: Map<String, dynamic>.from(map['last_message_delivered_to'] ?? map['lastMessageDeliveredTo'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'photo_url': photoUrl,
    'photoUrl': photoUrl,
    'description': description,
    'member_ids': memberIds,
    'memberIds': memberIds,
    'last_message': lastMessage,
    'lastMessage': lastMessage,
    'last_message_at': lastMessageAt?.toIso8601String(),
    'lastMessageAt': lastMessageAt?.toIso8601String(),
    'last_message_sender_id': lastMessageSenderId,
    'lastMessageSenderId': lastMessageSenderId,
    'pinned_message_ids': pinnedMessageIds,
    'pinnedMessageIds': pinnedMessageIds,
    'muted_by': mutedBy,
    'mutedBy': mutedBy,
    'archived_by': archivedBy,
    'archivedBy': archivedBy,
    'admins': admins,
    'locked_by': lockedBy,
    'lockedBy': lockedBy,
    'created_by': createdBy,
    'createdBy': createdBy,
    'unread_count': unreadCount,
    'unreadCount': unreadCount,
    'disappearing_duration': disappearingDuration,
    'disappearingDuration': disappearingDuration,
    'typing': typing,
    'recording': recording,
    'deleted_at': deletedAt.map((k, v) => MapEntry(k, v.toIso8601String())),
    'deletedAt': deletedAt.map((k, v) => MapEntry(k, v.toIso8601String())),
    'is_ghost': isGhost,
    'isGhost': isGhost,
    'crm_labels': crmLabels,
    'crmLabels': crmLabels,
    'last_message_delivered_to': lastMessageDeliveredTo,
    'lastMessageDeliveredTo': lastMessageDeliveredTo,
    'updated_at': DateTime.now().toIso8601String(),
  };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.cipherText,
    required this.createdAt,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaUrls = const [],
    this.localFilePaths = const [],
    this.fileName,
    this.durationMs,
    this.replyToMessageId,
    this.editedAt,
    this.latitude,
    this.longitude,
    this.isLive = false,
    this.liveUntil,
    this.deletedFor = const [],
    this.deletedForEveryone = false,
    this.deletedByAdmin = false,
    this.reactions = const {},
    this.readBy = const {},
    this.deliveredTo = const {},
    this.starredBy = const [],
    this.isEncrypted = false,
    this.senderPublicKey,
    this.recipientPublicKey,
    this.isViewOnce = false,
    this.openedBy = const [],
    this.selfDestructDuration,
    this.isSOS = false,
    this.isForwarded = false,
    this.isHD = false,
    this.isUploading = false,
    this.localFilePath,
    this.encryptedMediaKey,
    this.hasPendingWrites = false,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes,
    this.imageReactions = const {},
  });

  final String id;
  final String senderId;
  final MessageType type;
  final String cipherText;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final List<String> mediaUrls;
  final List<String> localFilePaths;
  final String? fileName;
  final int? durationMs;
  final DateTime createdAt;
  final String? replyToMessageId;
  final DateTime? editedAt;
  final double? latitude;
  final double? longitude;
  final bool isLive;
  final DateTime? liveUntil;
  final List<String> deletedFor;
  final bool deletedForEveryone;
  final bool deletedByAdmin;
  final Map<String, String> reactions;
  final Map<String, DateTime> readBy;
  final Map<String, DateTime> deliveredTo;
  final List<String> starredBy;
  final bool isEncrypted;
  final String? senderPublicKey;
  final String? recipientPublicKey;
  final bool isViewOnce;
  final List<String> openedBy;
  final int? selfDestructDuration;
  final bool isSOS;
  final bool isForwarded;
  final bool isHD;
  final bool isUploading;
  final String? localFilePath;
  final String? encryptedMediaKey;
  final bool hasPendingWrites;
  final String? pollQuestion;
  final List<String>? pollOptions;
  final Map<String, dynamic>? pollVotes;
  final Map<String, Map<String, String>> imageReactions;

  bool get isMultiImage =>
      type == MessageType.imageGroup ||
      mediaUrls.length > 1 ||
      localFilePaths.length > 1;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map, {bool hasPendingWrites = false}) {
    final createdAtRaw = map['created_at'] ?? map['createdAt'];
    final editedAtRaw = map['edited_at'] ?? map['editedAt'];
    final liveUntilRaw = map['live_until'] ?? map['liveUntil'];

    final rawMediaUrls = map['media_urls'] ?? map['mediaUrls'];
    final rawMediaUrl = map['media_url'] ?? map['mediaUrl'];
    List<String> parsedMediaUrls = const [];
    if (rawMediaUrls != null) {
      parsedMediaUrls = List<String>.from(rawMediaUrls);
    } else if (rawMediaUrl != null) {
      parsedMediaUrls = [rawMediaUrl.toString()];
    }

    return ChatMessage(
      id: id,
      senderId: (map['sender_id'] ?? map['senderId'] ?? '').toString(),
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      cipherText: (map['cipher_text'] ?? map['cipherText'] ?? '').toString(),
      mediaUrl: map['media_url'] ?? map['mediaUrl'],
      thumbnailUrl: map['thumbnail_url'] ?? map['thumbnailUrl'],
      mediaUrls: parsedMediaUrls,
      localFilePaths: List<String>.from(map['local_file_paths'] ?? map['localFilePaths'] ?? []),
      fileName: map['file_name'] ?? map['fileName'],
      durationMs: (map['duration_ms'] ?? map['durationMs']) as int?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isLive: (map['is_live'] ?? map['isLive']) ?? false,
      liveUntil: _parseDate(liveUntilRaw),
      createdAt: _parseDate(createdAtRaw) ?? DateTime.now(),
      replyToMessageId: map['reply_to_message_id'] ?? map['replyToMessageId'],
      editedAt: _parseDate(editedAtRaw),
      deletedFor: List<String>.from(map['deleted_for'] ?? map['deletedFor'] ?? []),
      deletedForEveryone: (map['deleted_for_everyone'] ?? map['deletedForEveryone']) ?? false,
      deletedByAdmin: (map['deleted_by_admin'] ?? map['deletedByAdmin']) ?? false,
      reactions: Map<String, String>.from(
        (map['reactions'] ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      ),
      readBy: (map['read_by'] ?? map['readBy'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key.toString(), _parseDate(value) ?? DateTime.now()),
      ),
      deliveredTo: (map['delivered_to'] ?? map['deliveredTo'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key.toString(), _parseDate(value) ?? DateTime.now()),
      ),
      starredBy: List<String>.from(map['starred_by'] ?? map['starredBy'] ?? []),
      isEncrypted: (map['is_encrypted'] ?? map['isEncrypted']) ?? false,
      senderPublicKey: map['sender_public_key'] ?? map['senderPublicKey'],
      recipientPublicKey: map['recipient_public_key'] ?? map['recipientPublicKey'],
      isViewOnce: (map['is_view_once'] ?? map['isViewOnce']) ?? false,
      openedBy: List<String>.from(map['opened_by'] ?? map['openedBy'] ?? []),
      selfDestructDuration: (map['self_destruct_duration'] ?? map['selfDestructDuration']) as int?,
      isSOS: (map['is_sos'] ?? map['isSOS']) ?? false,
      isForwarded: (map['is_forwarded'] ?? map['isForwarded']) ?? false,
      isHD: (map['is_hd'] ?? map['isHD']) ?? false,
      isUploading: (map['is_uploading'] ?? map['isUploading']) ?? false,
      localFilePath: (map['local_file_path'] ?? map['localFilePath']) as String?,
      encryptedMediaKey: (map['encrypted_media_key'] ?? map['encryptedMediaKey']) as String?,
      hasPendingWrites: hasPendingWrites,
      pollQuestion: (map['poll_question'] ?? map['pollQuestion']) as String?,
      pollOptions: (map['poll_options'] ?? map['pollOptions']) != null
          ? List<String>.from(map['poll_options'] ?? map['pollOptions'])
          : null,
      pollVotes: (map['poll_votes'] ?? map['pollVotes']) != null
          ? Map<String, dynamic>.from(map['poll_votes'] ?? map['pollVotes'])
          : null,
      imageReactions: (map['image_reactions'] ?? map['imageReactions'] as Map<String, dynamic>? ?? {}).map(
        (key, val) => MapEntry(
          key.toString(),
          (val as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'sender_id': senderId,
    'senderId': senderId,
    'type': type.name,
    'cipher_text': cipherText,
    'cipherText': cipherText,
    'media_url': mediaUrl,
    'mediaUrl': mediaUrl,
    'thumbnail_url': thumbnailUrl,
    'thumbnailUrl': thumbnailUrl,
    'media_urls': mediaUrls,
    'mediaUrls': mediaUrls,
    'local_file_paths': localFilePaths,
    'localFilePaths': localFilePaths,
    'file_name': fileName,
    'fileName': fileName,
    'duration_ms': durationMs,
    'durationMs': durationMs,
    'latitude': latitude,
    'longitude': longitude,
    'is_live': isLive,
    'isLive': isLive,
    'live_until': liveUntil?.toIso8601String(),
    'liveUntil': liveUntil?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'reply_to_message_id': replyToMessageId,
    'replyToMessageId': replyToMessageId,
    'edited_at': editedAt?.toIso8601String(),
    'editedAt': editedAt?.toIso8601String(),
    'deleted_for': deletedFor,
    'deletedFor': deletedFor,
    'deleted_for_everyone': deletedForEveryone,
    'deletedForEveryone': deletedForEveryone,
    'deleted_by_admin': deletedByAdmin,
    'deletedByAdmin': deletedByAdmin,
    'reactions': reactions,
    'read_by': readBy.map((k, v) => MapEntry(k, v.toIso8601String())),
    'readBy': readBy.map((k, v) => MapEntry(k, v.toIso8601String())),
    'delivered_to': deliveredTo.map((k, v) => MapEntry(k, v.toIso8601String())),
    'deliveredTo': deliveredTo.map((k, v) => MapEntry(k, v.toIso8601String())),
    'starred_by': starredBy,
    'starredBy': starredBy,
    'is_encrypted': isEncrypted,
    'isEncrypted': isEncrypted,
    'sender_public_key': senderPublicKey,
    'senderPublicKey': senderPublicKey,
    'recipient_public_key': recipientPublicKey,
    'recipientPublicKey': recipientPublicKey,
    'is_view_once': isViewOnce,
    'isViewOnce': isViewOnce,
    'opened_by': openedBy,
    'openedBy': openedBy,
    'self_destruct_duration': selfDestructDuration,
    'selfDestructDuration': selfDestructDuration,
    'is_sos': isSOS,
    'isSOS': isSOS,
    'is_forwarded': isForwarded,
    'isForwarded': isForwarded,
    'is_hd': isHD,
    'isHD': isHD,
    'poll_question': pollQuestion,
    'pollQuestion': pollQuestion,
    'poll_options': pollOptions,
    'pollOptions': pollOptions,
    'poll_votes': pollVotes,
    'pollVotes': pollVotes,
    'image_reactions': imageReactions,
    'imageReactions': imageReactions,
  };
}