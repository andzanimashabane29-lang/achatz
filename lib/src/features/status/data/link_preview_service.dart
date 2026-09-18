import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? image;

  LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.image,
  });

  factory LinkPreviewData.fromJson(Map<String, dynamic> json) {
    return LinkPreviewData(
      url: json['url'] ?? '',
      title: json['title'],
      description: json['description'],
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'description': description,
      'image': image,
    };
  }
}

class LinkPreviewService {
  static final LinkPreviewService instance = LinkPreviewService._();
  LinkPreviewService._();

  // Regex pattern to detect URLs in text
  static final RegExp _urlPattern = RegExp(
    r'https?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  );

  /// Extract URLs from text
  List<String> extractUrls(String text) {
    final matches = _urlPattern.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

  /// Check if text contains a URL
  bool containsUrl(String text) {
    return _urlPattern.hasMatch(text);
  }

  /// Fetch link preview metadata from URL
  Future<LinkPreviewData?> fetchLinkPreview(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Failed to fetch link preview: ${response.statusCode}');
        return null;
      }

      final html = response.body;
      
      // Extract Open Graph tags
      final title = _extractMetaContent(html, 'og:title') ?? 
                   _extractTitle(html);
      final description = _extractMetaContent(html, 'og:description') ?? 
                         _extractMetaContent(html, 'description');
      final image = _extractMetaContent(html, 'og:image');

      return LinkPreviewData(
        url: url,
        title: title,
        description: description,
        image: image,
      );
    } catch (e) {
      debugPrint('Error fetching link preview: $e');
      return null;
    }
  }

  String? _extractMetaContent(String html, String property) {
    final pattern = RegExp(
      '<meta[^>]*property=["\']' + property + '["\'][^>]*content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html);
    return match?.group(1);
  }

  String? _extractTitle(String html) {
    final pattern = RegExp(r'<title>([^<]*)</title>', caseSensitive: false);
    final match = pattern.firstMatch(html);
    return match?.group(1);
  }

  /// Fetch link preview for the first URL found in text
  Future<LinkPreviewData?> fetchFirstLinkPreview(String text) async {
    final urls = extractUrls(text);
    if (urls.isEmpty) return null;
    
    return await fetchLinkPreview(urls.first);
  }
}
