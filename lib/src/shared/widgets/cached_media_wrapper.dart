import 'dart:io';
import 'package:flutter/material.dart';
import '../services/local_media_cache.dart';

class CachedMediaWrapper extends StatefulWidget {
  final String url;
  final String? encryptedMediaKey;
  final String? senderPublicKey;
  final Widget Function(BuildContext context, File file) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const CachedMediaWrapper({
    Key? key,
    required this.url,
    this.encryptedMediaKey,
    this.senderPublicKey,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  }) : super(key: key);

  @override
  State<CachedMediaWrapper> createState() => _CachedMediaWrapperState();
}

class _CachedMediaWrapperState extends State<CachedMediaWrapper> {
  File? _cachedFile;
  bool _isLoading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _checkCacheAndDownload();
  }

  @override
  void didUpdateWidget(CachedMediaWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _checkCacheAndDownload();
    }
  }

  Future<void> _checkCacheAndDownload() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Check if already cached
      final file = await LocalMediaCache.instance.getCachedFile(widget.url);
      if (file != null) {
        if (mounted) {
          setState(() {
            _cachedFile = file;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. If not, download and cache
      final downloadedFile = await LocalMediaCache.instance.downloadAndCache(
        widget.url,
        encryptedMediaKey: widget.encryptedMediaKey,
        senderPublicKey: widget.senderPublicKey,
      );
      if (mounted) {
        setState(() {
          _cachedFile = downloadedFile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedFile != null) {
      return widget.builder(context, _cachedFile!);
    }

    if (_isLoading) {
      return widget.loadingBuilder?.call(context) ??
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
              ),
            ),
          );
    }

    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          const Center(
            child: Icon(Icons.error_outline, color: Colors.redAccent),
          );
    }

    return const SizedBox.shrink();
  }
}
