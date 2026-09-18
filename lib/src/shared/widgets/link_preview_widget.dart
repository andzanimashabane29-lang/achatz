import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LinkMetadata {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  LinkMetadata({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });
}

class LinkPreviewHelper {
  static final Map<String, LinkMetadata> _metadataCache = {};

  static String? extractUrl(String text) {
    final regExp = RegExp(
      r'((https?:\/\/[^\s]+)|((www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,6}(\/[^\s]*)?))',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(text);
    if (match == null) return null;

    String matched = match.group(0)!;
    if (!matched.startsWith(RegExp(r'https?:\/\/', caseSensitive: false))) {
      matched = 'https://$matched';
    }
    return matched;
  }

  static String? extractYoutubeVideoId(String url) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  static Future<LinkMetadata> fetchMetadata(String url) async {
    if (_metadataCache.containsKey(url)) {
      return _metadataCache[url]!;
    }

    final ytid = extractYoutubeVideoId(url);
    if (ytid != null) {
      // YouTube shortcut: Avoid redundant network load if title can be fetched or set simple default
      final title = await _fetchTitleOnly(url) ?? 'YouTube Video';
      final meta = LinkMetadata(
        url: url,
        title: title,
        description: 'Watch this video on YouTube.',
        imageUrl: 'https://img.youtube.com/vi/$ytid/0.jpg',
        siteName: 'YouTube',
      );
      _metadataCache[url] = meta;
      return meta;
    }

    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = response.body;

        String? title = _extractMetaTag(body, 'og:title') ?? _extractTitleTag(body);
        String? description = _extractMetaTag(body, 'og:description') ?? _extractMetaTag(body, 'description');
        String? imageUrl = _extractMetaTag(body, 'og:image');
        String? siteName = _extractMetaTag(body, 'og:site_name') ?? uri.host;

        title = _cleanHtmlEntities(title);
        description = _cleanHtmlEntities(description);

        final meta = LinkMetadata(
          url: url,
          title: title,
          description: description,
          imageUrl: imageUrl,
          siteName: siteName,
        );
        _metadataCache[url] = meta;
        return meta;
      }
    } catch (_) {}
    final fallback = LinkMetadata(url: url);
    _metadataCache[url] = fallback;
    return fallback;
  }

  static String? _extractMetaTag(String body, String propertyOrName) {
    // Escape property or name pattern safely without using regex meta chars
    final escaped = RegExp.escape(propertyOrName);

    // double quotes
    final doublePattern1 = RegExp('content="([^"]+)"[^>]*property="$escaped"', caseSensitive: false);
    final doublePattern2 = RegExp('property="$escaped"[^>]*content="([^"]+)"', caseSensitive: false);
    final doublePattern3 = RegExp('content="([^"]+)"[^>]*name="$escaped"', caseSensitive: false);
    final doublePattern4 = RegExp('name="$escaped"[^>]*content="([^"]+)"', caseSensitive: false);

    // single quotes
    final singlePattern1 = RegExp("content='([^']+)'[^>]*property='$escaped'", caseSensitive: false);
    final singlePattern2 = RegExp("property='$escaped'[^>]*content='([^']+)'", caseSensitive: false);
    final singlePattern3 = RegExp("content='([^']+)'[^>]*name='$escaped'", caseSensitive: false);
    final singlePattern4 = RegExp("name='$escaped'[^>]*content='([^']+)'", caseSensitive: false);

    final match = doublePattern1.firstMatch(body) ??
        doublePattern2.firstMatch(body) ??
        doublePattern3.firstMatch(body) ??
        doublePattern4.firstMatch(body) ??
        singlePattern1.firstMatch(body) ??
        singlePattern2.firstMatch(body) ??
        singlePattern3.firstMatch(body) ??
        singlePattern4.firstMatch(body);

    return match?.group(1);
  }

  static String? _extractTitleTag(String body) {
    final titleMatch = RegExp(r'<title>(.*?)<\/title>', caseSensitive: false).firstMatch(body);
    return titleMatch?.group(1);
  }

  static Future<String?> _fetchTitleOnly(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final title = _extractTitleTag(res.body);
        if (title != null) {
          return _cleanHtmlEntities(title
              .replaceAll(' - YouTube', '')
              .replaceAll('&#39;', "'")
              .replaceAll('&quot;', '"'));
        }
      }
    } catch (_) {}
    return null;
  }

  static String? _cleanHtmlEntities(String? text) {
    if (text == null) return null;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}

class LinkPreviewWidget extends StatefulWidget {
  const LinkPreviewWidget({super.key, required this.url, this.compact = false});

  final String url;
  final bool compact;

  @override
  State<LinkPreviewWidget> createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends State<LinkPreviewWidget> {
  late Future<LinkMetadata> _metadataFuture;

  @override
  void initState() {
    super.initState();
    _metadataFuture = LinkPreviewHelper.fetchMetadata(widget.url);
  }

  @override
  void didUpdateWidget(covariant LinkPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _metadataFuture = LinkPreviewHelper.fetchMetadata(widget.url);
      });
    }
  }

  Widget _buildPreview(
    LinkMetadata? meta,
    Color cardBgColor,
    Color textThemeColor,
    Color subtextColor,
  ) {
    if (meta == null || (meta.title == null && meta.imageUrl == null)) {
      return GestureDetector(
        onTap: () async {
          final uri = Uri.parse(widget.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 8.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.url,
                  style: const TextStyle(
                    color: Colors.blueAccent, 
                    decoration: TextDecoration.underline, 
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final siteDisplay = meta.siteName?.toUpperCase() ?? Uri.parse(widget.url).host.toUpperCase();
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(widget.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8.0),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (meta.imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: Image.network(
                    meta.imageUrl!,
                    width: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => const SizedBox.shrink(),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        siteDisplay,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta.title ?? 'Link Preview',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textThemeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                      if (meta.description != null && meta.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ytid = LinkPreviewHelper.extractYoutubeVideoId(widget.url);
    if (ytid != null) {
      return YouTubePreviewWidget(url: widget.url, videoId: ytid);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark 
        ? const Color(0xFF1F2C34) 
        : const Color(0xFFE9EBED);
    final textThemeColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;

    final cached = LinkPreviewHelper._metadataCache[widget.url];
    if (cached != null) {
      return _buildPreview(cached, cardBgColor, textThemeColor, subtextColor);
    }

    return FutureBuilder<LinkMetadata>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          LinkPreviewHelper._metadataCache[widget.url] = snapshot.data!;
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(top: 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Loading link preview...',
                    style: TextStyle(color: subtextColor, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }

        final meta = snapshot.data;
        return _buildPreview(meta, cardBgColor, textThemeColor, subtextColor);
      },
    );
  }
}

class YouTubePreviewWidget extends StatefulWidget {
  const YouTubePreviewWidget({super.key, required this.url, required this.videoId});
  final String url;
  final String videoId;

  @override
  State<YouTubePreviewWidget> createState() => _YouTubePreviewWidgetState();
}

class _YouTubePreviewWidgetState extends State<YouTubePreviewWidget> {
  static final Map<String, String> _youtubeTitleCache = {};
  String? _title;

  @override
  void initState() {
    super.initState();
    _title = _youtubeTitleCache[widget.url];
    _fetchTitle();
  }

  void _fetchTitle() async {
    if (_title != null) return;
    try {
      final res = await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = res.body;
        final match = RegExp(r'<title>(.*?)<\/title>', caseSensitive: false).firstMatch(body);
        if (match != null && match.group(1) != null) {
          final cleanTitle = match.group(1)!
              .replaceAll('&amp;', '&')
              .replaceAll(' - YouTube', '')
              .replaceAll('&#39;', "'")
              .replaceAll('&quot;', '"');
          _youtubeTitleCache[widget.url] = cleanTitle;
          if (mounted) {
            setState(() {
              _title = cleanTitle;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = 'https://img.youtube.com/vi/${widget.videoId}/0.jpg';
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(widget.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2C34),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    thumbnailUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => Container(
                      height: 180,
                      color: Colors.white12,
                      child: const Icon(Icons.video_library, color: Colors.white54, size: 48),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUTUBE',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _title ?? 'Watch video on YouTube',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 12, decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
