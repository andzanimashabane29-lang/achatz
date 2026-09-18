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

enum StatusType { image, video, text, audio }

class StatusComment {
  const StatusComment({
    required this.userId,
    required this.text,
    required this.createdAt,
    this.userName,
  });

  final String userId;
  final String? userName;
  final String text;
  final DateTime createdAt;

  factory StatusComment.fromMap(Map<String, dynamic> map) {
    return StatusComment(
      userId: (map['user_id'] ?? map['userId'] ?? '').toString(),
      userName: map['user_name'] ?? map['userName'],
      text: (map['text'] ?? '').toString(),
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'userId': userId,
      'user_name': userName,
      'userName': userName,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class StatusStory {
  const StatusStory({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.type,
    required this.mediaUrl,
    required this.createdAt,
    required this.expiresAt,
    this.caption,
    this.ownerPhotoUrl,
    this.seenBy = const {},
    this.reactions = const {},
    this.comments = const [],
    this.resharedFromStatusId,
    this.resharedFromOwnerName,
    this.musicTitle,
    this.musicArtist,
    this.musicPreviewUrl,
    this.musicStartTimeMs,
    this.musicEndTimeMs,
    this.textBgColor,
    this.isOwnerVerified = false,
    this.isPromoted = false,
    this.podcastTitle,
    this.musicStickerStyle,
    this.musicStickerX,
    this.musicStickerY,
    this.musicStickerScale,
    this.musicLyrics,
    this.musicLyricsOffsetMs,
    this.mentions = const [],
    this.excludedIds = const [],
    this.allowedIds = const [],
    this.fontFamily,
    this.linkPreviewUrl,
    this.linkPreviewTitle,
    this.linkPreviewDescription,
    this.linkPreviewImage,
    this.privacyOption,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String? ownerPhotoUrl;
  final bool isOwnerVerified;
  final bool isPromoted;
  final StatusType type;
  final String mediaUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, DateTime> seenBy;
  final Map<String, String> reactions;
  final List<StatusComment> comments;
  final String? resharedFromStatusId;
  final String? resharedFromOwnerName;
  final String? musicTitle;
  final String? musicArtist;
  final String? musicPreviewUrl;
  final int? musicStartTimeMs;
  final int? musicEndTimeMs;
  final int? textBgColor;
  final String? podcastTitle;
  final int? musicStickerStyle;
  final double? musicStickerX;
  final double? musicStickerY;
  final double? musicStickerScale;
  final String? musicLyrics;
  final int? musicLyricsOffsetMs;
  final List<String> mentions;
  final List<String> excludedIds;
  final List<String> allowedIds;
  final String? fontFamily;
  final String? linkPreviewUrl;
  final String? linkPreviewTitle;
  final String? linkPreviewDescription;
  final String? linkPreviewImage;
  final String? privacyOption;

  factory StatusStory.fromMap(String id, Map<String, dynamic> map) {
    return StatusStory(
      id: id,
      ownerId: (map['owner_id'] ?? map['ownerId'] ?? '').toString(),
      ownerName: (map['owner_name'] ?? map['ownerName'] ?? 'A-Chatz User').toString(),
      ownerPhotoUrl: map['owner_photo_url'] ?? map['ownerPhotoUrl'],
      type: StatusType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'image'),
        orElse: () => StatusType.image,
      ),
      mediaUrl: (map['media_url'] ?? map['mediaUrl'] ?? '').toString(),
      caption: map['caption'],
      createdAt: _parseDate(map['created_at'] ?? map['createdAt']),
      expiresAt: _parseDate(
        map['expires_at'] ?? map['expiresAt'],
        DateTime.now().add(const Duration(hours: 24)),
      ),
      seenBy: (map['seen_by'] ?? map['seenBy'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key.toString(), _parseDate(value)),
      ),
      reactions: Map<String, String>.from(
        (map['reactions'] ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      ),
      comments: (map['comments'] as List<dynamic>? ?? [])
          .map((e) => StatusComment.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      resharedFromStatusId: map['reshared_from_status_id'] ?? map['resharedFromStatusId'],
      resharedFromOwnerName: map['reshared_from_owner_name'] ?? map['resharedFromOwnerName'],
      musicTitle: map['music_title'] ?? map['musicTitle'],
      musicArtist: map['music_artist'] ?? map['musicArtist'],
      musicPreviewUrl: map['music_preview_url'] ?? map['musicPreviewUrl'],
      musicStartTimeMs: (map['music_start_time_ms'] ?? map['musicStartTimeMs']) as int?,
      musicEndTimeMs: (map['music_end_time_ms'] ?? map['musicEndTimeMs']) as int?,
      textBgColor: (map['text_bg_color'] ?? map['textBgColor']) as int?,
      isOwnerVerified: (map['is_owner_verified'] ?? map['isOwnerVerified']) ?? false,
      isPromoted: (map['is_promoted'] ?? map['isPromoted']) ?? false,
      podcastTitle: map['podcast_title'] ?? map['podcastTitle'],
      musicStickerStyle: (map['music_sticker_style'] ?? map['musicStickerStyle']) as int?,
      musicStickerX: ((map['music_sticker_x'] ?? map['musicStickerX']) as num?)?.toDouble(),
      musicStickerY: ((map['music_sticker_y'] ?? map['musicStickerY']) as num?)?.toDouble(),
      musicStickerScale: ((map['music_sticker_scale'] ?? map['musicStickerScale']) as num?)?.toDouble(),
      musicLyrics: map['music_lyrics'] ?? map['musicLyrics'],
      musicLyricsOffsetMs: (map['music_lyrics_offset_ms'] ?? map['musicLyricsOffsetMs']) as int?,
      mentions: List<String>.from(map['mentions'] ?? []),
      excludedIds: List<String>.from(map['excluded_ids'] ?? map['excludedIds'] ?? []),
      allowedIds: List<String>.from(map['allowed_ids'] ?? map['allowedIds'] ?? []),
      fontFamily: map['font_family'] ?? map['fontFamily'] ?? map['textFont'],
      linkPreviewUrl: map['link_preview_url'] ?? map['linkPreviewUrl'],
      linkPreviewTitle: map['link_preview_title'] ?? map['linkPreviewTitle'],
      linkPreviewDescription: map['link_preview_description'] ?? map['linkPreviewDescription'],
      linkPreviewImage: map['link_preview_image'] ?? map['linkPreviewImage'],
      privacyOption: map['privacy_option'] ?? map['privacyOption'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'ownerId': ownerId,
    'owner_name': ownerName,
    'ownerName': ownerName,
    'owner_photo_url': ownerPhotoUrl,
    'ownerPhotoUrl': ownerPhotoUrl,
    'is_owner_verified': isOwnerVerified,
    'isOwnerVerified': isOwnerVerified,
    'is_promoted': isPromoted,
    'isPromoted': isPromoted,
    'type': type.name,
    'media_url': mediaUrl,
    'mediaUrl': mediaUrl,
    'caption': caption,
    'created_at': createdAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'seen_by': seenBy.map((k, v) => MapEntry(k, v.toIso8601String())),
    'seenBy': seenBy.map((k, v) => MapEntry(k, v.toIso8601String())),
    'reactions': reactions,
    'comments': comments.map((c) => c.toMap()).toList(),
    'reshared_from_status_id': resharedFromStatusId,
    'resharedFromStatusId': resharedFromStatusId,
    'reshared_from_owner_name': resharedFromOwnerName,
    'resharedFromOwnerName': resharedFromOwnerName,
    'music_title': musicTitle,
    'musicTitle': musicTitle,
    'music_artist': musicArtist,
    'musicArtist': musicArtist,
    'music_preview_url': musicPreviewUrl,
    'musicPreviewUrl': musicPreviewUrl,
    'music_start_time_ms': musicStartTimeMs,
    'musicStartTimeMs': musicStartTimeMs,
    'music_end_time_ms': musicEndTimeMs,
    'musicEndTimeMs': musicEndTimeMs,
    'text_bg_color': textBgColor,
    'textBgColor': textBgColor,
    'podcast_title': podcastTitle,
    'podcastTitle': podcastTitle,
    'music_sticker_style': musicStickerStyle,
    'musicStickerStyle': musicStickerStyle,
    'music_sticker_x': musicStickerX,
    'musicStickerX': musicStickerX,
    'music_sticker_y': musicStickerY,
    'musicStickerY': musicStickerY,
    'music_sticker_scale': musicStickerScale,
    'musicStickerScale': musicStickerScale,
    'music_lyrics': musicLyrics,
    'musicLyrics': musicLyrics,
    'music_lyrics_offset_ms': musicLyricsOffsetMs,
    'musicLyricsOffsetMs': musicLyricsOffsetMs,
    'mentions': mentions,
    'excluded_ids': excludedIds,
    'excludedIds': excludedIds,
    'allowed_ids': allowedIds,
    'allowedIds': allowedIds,
    'font_family': fontFamily,
    'fontFamily': fontFamily,
    'link_preview_url': linkPreviewUrl,
    'linkPreviewUrl': linkPreviewUrl,
    'link_preview_title': linkPreviewTitle,
    'linkPreviewTitle': linkPreviewTitle,
    'link_preview_description': linkPreviewDescription,
    'linkPreviewDescription': linkPreviewDescription,
    'link_preview_image': linkPreviewImage,
    'linkPreviewImage': linkPreviewImage,
    'privacy_option': privacyOption,
    'privacyOption': privacyOption,
  };

  StatusStory copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? ownerPhotoUrl,
    bool? isOwnerVerified,
    bool? isPromoted,
    StatusType? type,
    String? mediaUrl,
    String? caption,
    DateTime? createdAt,
    DateTime? expiresAt,
    Map<String, DateTime>? seenBy,
    Map<String, String>? reactions,
    List<StatusComment>? comments,
    String? resharedFromStatusId,
    String? resharedFromOwnerName,
    String? musicTitle,
    String? musicArtist,
    String? musicPreviewUrl,
    int? musicStartTimeMs,
    int? musicEndTimeMs,
    int? textBgColor,
    String? podcastTitle,
    int? musicStickerStyle,
    double? musicStickerX,
    double? musicStickerY,
    double? musicStickerScale,
    String? musicLyrics,
    int? musicLyricsOffsetMs,
    List<String>? mentions,
    List<String>? excludedIds,
    List<String>? allowedIds,
    String? fontFamily,
    String? linkPreviewUrl,
    String? linkPreviewTitle,
    String? linkPreviewDescription,
    String? linkPreviewImage,
    String? privacyOption,
  }) {
    return StatusStory(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerPhotoUrl: ownerPhotoUrl ?? this.ownerPhotoUrl,
      isOwnerVerified: isOwnerVerified ?? this.isOwnerVerified,
      isPromoted: isPromoted ?? this.isPromoted,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      seenBy: seenBy ?? this.seenBy,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
      resharedFromStatusId: resharedFromStatusId ?? this.resharedFromStatusId,
      resharedFromOwnerName: resharedFromOwnerName ?? this.resharedFromOwnerName,
      musicTitle: musicTitle ?? this.musicTitle,
      musicArtist: musicArtist ?? this.musicArtist,
      musicPreviewUrl: musicPreviewUrl ?? this.musicPreviewUrl,
      musicStartTimeMs: musicStartTimeMs ?? this.musicStartTimeMs,
      musicEndTimeMs: musicEndTimeMs ?? this.musicEndTimeMs,
      textBgColor: textBgColor ?? this.textBgColor,
      podcastTitle: podcastTitle ?? this.podcastTitle,
      musicStickerStyle: musicStickerStyle ?? this.musicStickerStyle,
      musicStickerX: musicStickerX ?? this.musicStickerX,
      musicStickerY: musicStickerY ?? this.musicStickerY,
      musicStickerScale: musicStickerScale ?? this.musicStickerScale,
      musicLyrics: musicLyrics ?? this.musicLyrics,
      musicLyricsOffsetMs: musicLyricsOffsetMs ?? this.musicLyricsOffsetMs,
      mentions: mentions ?? this.mentions,
      excludedIds: excludedIds ?? this.excludedIds,
      allowedIds: allowedIds ?? this.allowedIds,
      fontFamily: fontFamily ?? this.fontFamily,
      linkPreviewUrl: linkPreviewUrl ?? this.linkPreviewUrl,
      linkPreviewTitle: linkPreviewTitle ?? this.linkPreviewTitle,
      linkPreviewDescription: linkPreviewDescription ?? this.linkPreviewDescription,
      linkPreviewImage: linkPreviewImage ?? this.linkPreviewImage,
      privacyOption: privacyOption ?? this.privacyOption,
    );
  }
}