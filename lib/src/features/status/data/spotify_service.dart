import 'dart:convert';
import 'package:http/http.dart' as http;

class SongLyrics {
  final String? plainLyrics;
  final String? syncedLyrics;
  
  const SongLyrics({this.plainLyrics, this.syncedLyrics});
  
  bool get hasSyncedLyrics => syncedLyrics != null && syncedLyrics!.isNotEmpty;
  bool get hasAnyLyrics => hasSyncedLyrics || (plainLyrics != null && plainLyrics!.isNotEmpty);
}

class SpotifyTrack {
  final int id;
  final String title;
  final String artist;
  final String? albumTitle;
  final String? albumCoverUrl; // 250x250 image
  final String? previewUrl;   // 30-second MP3 preview
  final int? durationSeconds;
  final String source; // 'deezer', 'spotify', or 'itunes'

  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.albumTitle,
    this.albumCoverUrl,
    this.previewUrl,
    this.durationSeconds,
    this.source = 'deezer',
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final album = json['album'] as Map<String, dynamic>?;
    final artistMap = json['artist'] as Map<String, dynamic>?;
    return SpotifyTrack(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      artist: artistMap?['name'] as String? ?? '',
      albumTitle: album?['title'] as String?,
      albumCoverUrl: album?['cover_medium'] as String?,
      previewUrl: json['preview'] as String?,
      durationSeconds: json['duration'] as int?,
      source: 'deezer',
    );
  }

  factory SpotifyTrack.fromSpotify(Map<String, dynamic> json) {
    final artists = json['artists'] as List<dynamic>? ?? [];
    final artistName = artists.isNotEmpty ? artists[0]['name'] as String? ?? '' : '';
    final album = json['album'] as Map<String, dynamic>?;
    final images = album?['images'] as List<dynamic>? ?? [];
    final image = images.isNotEmpty ? images[0]['url'] as String? : null;

    return SpotifyTrack(
      id: json['id']?.hashCode ?? 0,
      title: json['name'] as String? ?? '',
      artist: artistName,
      albumTitle: album?['name'] as String?,
      albumCoverUrl: image,
      previewUrl: json['preview_url'] as String?,
      durationSeconds: json['duration_ms'] is int ? (json['duration_ms'] as int) ~/ 1000 : null,
      source: 'spotify',
    );
  }

  factory SpotifyTrack.fromITunes(Map<String, dynamic> json) {
    int durationMillis = json['trackTimeMillis'] as int? ?? 0;
    return SpotifyTrack(
      id: json['trackId'] as int? ?? 0,
      title: json['trackName'] as String? ?? '',
      artist: json['artistName'] as String? ?? '',
      albumTitle: json['collectionName'] as String?,
      albumCoverUrl: json['artworkUrl100'] as String?,
      previewUrl: json['previewUrl'] as String?,
      durationSeconds: durationMillis > 0 ? durationMillis ~/ 1000 : null,
      source: 'itunes',
    );
  }

  String get durationFormatted {
    if (durationSeconds == null) return '';
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class MusicService {
  static const _deezerBaseUrl = 'https://api.deezer.com';
  static const _spotifyBaseUrl = 'https://api.spotify.com/v1';
  static const _spotifyAuthUrl = 'https://accounts.spotify.com/api/token';

  static String? _spotifyAccessToken;
  static DateTime? _spotifyTokenExpiry;

  /// Get Spotify access token using Client Credentials flow
  static Future<String?> _getSpotifyToken() async {
    try {
      // Check if token is still valid
      if (_spotifyAccessToken != null && _spotifyTokenExpiry != null) {
        if (DateTime.now().isBefore(_spotifyTokenExpiry!)) {
          return _spotifyAccessToken;
        }
      }

      // Spotify credentials
      const clientId = 'a041ff8958414dfbb48a6780c93f4308';
      const clientSecret = '9f4df7ce7bbe4642a78cc362d5fde71f';

      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final response = await http.post(
        Uri.parse(_spotifyAuthUrl),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _spotifyAccessToken = data['access_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        _spotifyTokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        return _spotifyAccessToken;
      }
    } catch (_) {}
    return null;
  }

  /// Search Spotify tracks
  static Future<List<SpotifyTrack>> _searchSpotify(String query) async {
    try {
      final token = await _getSpotifyToken();
      if (token == null) return [];

      final uri = Uri.parse('$_spotifyBaseUrl/search').replace(
        queryParameters: {
          'q': query,
          'type': 'track',
          'limit': '15',
        },
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final tracks = body['tracks'] as Map<String, dynamic>?;
        final items = tracks?['items'] as List<dynamic>? ?? [];

        return items
            .map((e) => SpotifyTrack.fromSpotify(e as Map<String, dynamic>))
            .where((t) => t.previewUrl != null && t.previewUrl!.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Search Deezer tracks
  static Future<List<SpotifyTrack>> _searchDeezer(String query) async {
    try {
      final uri = Uri.parse('$_deezerBaseUrl/search').replace(
        queryParameters: {'q': query, 'limit': '20'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => SpotifyTrack.fromJson(e as Map<String, dynamic>))
            .where((t) => t.previewUrl != null && t.previewUrl!.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Search iTunes tracks
  static Future<List<SpotifyTrack>> _searchITunes(String query) async {
    try {
      final itunesUri = Uri.parse('https://itunes.apple.com/search').replace(
        queryParameters: {
          'term': query,
          'limit': '20',
          'media': 'music',
          'entity': 'song',
        },
      );
      final response = await http.get(itunesUri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = body['results'] as List<dynamic>? ?? [];
        return results
            .map((e) => SpotifyTrack.fromITunes(e as Map<String, dynamic>))
            .where((t) => t.previewUrl != null && t.previewUrl!.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Search tracks — Spotify primary, Deezer fallback, iTunes last resort
  static Future<List<SpotifyTrack>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    // 1️⃣ Spotify (primary — richest metadata + previews)
    final spotifyResults = await _searchSpotify(query);
    if (spotifyResults.isNotEmpty) return spotifyResults;

    // 2️⃣ Deezer (fallback)
    final deezerResults = await _searchDeezer(query);
    if (deezerResults.isNotEmpty) return deezerResults;

    // 3️⃣ iTunes (last resort)
    return _searchITunes(query);
  }

  /// Fetch trending/popular chart tracks — Spotify Global Top 50 primary
  static Future<List<SpotifyTrack>> chartTracks() async {
    // Try Spotify global chart via search for "top hits"
    try {
      final token = await _getSpotifyToken();
      if (token != null) {
        final uri = Uri.parse('$_spotifyBaseUrl/search').replace(
          queryParameters: {
            'q': 'year:${DateTime.now().year} tag:new',
            'type': 'track',
            'limit': '20',
            'market': 'US',
          },
        );
        final response = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final items = (body['tracks']?['items'] as List<dynamic>?) ?? [];
          final tracks = items
              .map((e) => SpotifyTrack.fromSpotify(e as Map<String, dynamic>))
              .where((t) => t.previewUrl != null && t.previewUrl!.isNotEmpty)
              .toList();
          if (tracks.isNotEmpty) return tracks;
        }
      }
    } catch (_) {}

    // Fallback: Deezer chart
    try {
      final uri = Uri.parse('$_deezerBaseUrl/chart/0/tracks')
          .replace(queryParameters: {'limit': '20'});
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = (body['data'] as List<dynamic>?) ?? [];
        final tracks = data
            .map((e) => SpotifyTrack.fromJson(e as Map<String, dynamic>))
            .where((t) => t.previewUrl != null && t.previewUrl!.isNotEmpty)
            .toList();
        if (tracks.isNotEmpty) return tracks;
      }
    } catch (_) {}

    // Last resort: search-based chart
    return searchTracks('top hits ${DateTime.now().year}');
  }

  static Future<SongLyrics?> fetchLyrics(String artist, String title) async {
    try {
      final uri = Uri.parse('https://lrclib.net/api/search').replace(
        queryParameters: {
          'artist_name': artist,
          'track_name': title,
        },
      );
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          // Find the first result that has synced lyrics, or fallback to the very first result
          final bestMatch = results.firstWhere(
            (r) => r['syncedLyrics'] != null && (r['syncedLyrics'] as String).isNotEmpty,
            orElse: () => results.first,
          );
          
          return SongLyrics(
            plainLyrics: bestMatch['plainLyrics'] as String?,
            syncedLyrics: bestMatch['syncedLyrics'] as String?,
          );
        }
      }
    } catch (_) {}
    return null;
  }
}

// Backwards compatibility removed
