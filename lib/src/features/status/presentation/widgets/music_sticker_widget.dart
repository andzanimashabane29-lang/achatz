import 'package:flutter/material.dart';
import 'package:a_chatz/src/features/status/data/spotify_service.dart';
import 'dart:math' as math;

enum MusicStickerStyle {
  simpleText,
  albumWidget,
  lyricsKaraoke,
  lyricsNeon,
  lyricsTypewriter,
  lyricsHighlight,
}

class SyncedLyricLine {
  final Duration time;
  final String text;

  const SyncedLyricLine({required this.time, required this.text});
}

class MusicStickerWidget extends StatelessWidget {
  final SpotifyTrack track;
  final SongLyrics? lyrics;
  final MusicStickerStyle style;
  final Duration currentPlaybackPosition;
  final int lyricsOffsetMs;

  const MusicStickerWidget({
    Key? key,
    required this.track,
    this.lyrics,
    required this.style,
    this.currentPlaybackPosition = Duration.zero,
    this.lyricsOffsetMs = 0,
  }) : super(key: key);

  List<SyncedLyricLine> _parseSyncedLyrics() {
    if (lyrics?.syncedLyrics == null) return [];
    
    final lines = lyrics!.syncedLyrics!.split('\n');
    final parsed = <SyncedLyricLine>[];
    
    // Improved robust regex to match variations like [01:23.4], [01:23.456], [01:23]
    final regex = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)');
    
    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = double.tryParse(match.group(2) ?? '0.0') ?? 0.0;
        final text = match.group(3) ?? '';
        
        final duration = Duration(
          minutes: minutes,
          milliseconds: (seconds * 1000).toInt(),
        );
        
        parsed.add(SyncedLyricLine(time: duration, text: text.trim()));
      }
    }
    
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final isLyricsStyle = style == MusicStickerStyle.lyricsKaraoke || 
                          style == MusicStickerStyle.lyricsNeon ||
                          style == MusicStickerStyle.lyricsTypewriter ||
                          style == MusicStickerStyle.lyricsHighlight;

    if (isLyricsStyle && lyrics?.hasSyncedLyrics == true) {
      return _buildKaraokeLyrics();
    } else if (style == MusicStickerStyle.simpleText) {
      return _buildSimpleText();
    }
    return _buildAlbumWidget();
  }

  Widget _buildAlbumWidget() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 15,
            offset: Offset(0, 8),
          )
        ],
        image: track.albumCoverUrl != null
            ? DecorationImage(
                image: NetworkImage(track.albumCoverUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: track.albumCoverUrl == null
          ? const Center(child: Icon(Icons.music_note, color: Colors.white54, size: 48))
          : Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 10),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            track.artist,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSimpleText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(30), // Pill shape
        border: Border.all(color: Colors.white24, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MiniAudioVisualizer(isPlaying: true),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${track.title} - ${track.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.w700, 
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaraokeLyrics() {
    final parsedLyrics = _parseSyncedLyrics();
    if (parsedLyrics.isEmpty) return _buildAlbumWidget();

    final effectivePositionMs = currentPlaybackPosition.inMilliseconds + lyricsOffsetMs;
    final effectivePosition = Duration(milliseconds: effectivePositionMs);

    int activeIndex = -1;
    for (int i = 0; i < parsedLyrics.length; i++) {
      if (effectivePosition >= parsedLyrics[i].time) {
        activeIndex = i;
      } else {
        break;
      }
    }

    final currentText = activeIndex >= 0 ? parsedLyrics[activeIndex].text : "🎵";
    final textToShow = currentText.isEmpty ? "🎵" : currentText;

    if (style == MusicStickerStyle.lyricsNeon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          textToShow,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.pinkAccent, blurRadius: 10, offset: Offset(0, 0)),
              Shadow(color: Colors.pinkAccent, blurRadius: 20, offset: Offset(0, 0)),
              Shadow(color: Colors.purple, blurRadius: 30, offset: Offset(0, 0)),
            ],
          ),
        ),
      );
    } else if (style == MusicStickerStyle.lyricsTypewriter) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          textToShow,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
      );
    } else if (style == MusicStickerStyle.lyricsHighlight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          textToShow,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    } else {
      // Default karaoke style
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          textToShow,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2))
            ],
          ),
        ),
      );
    }
  }

  Widget _placeholderCover() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.music_note, color: Color(0xFF1DB954), size: 24),
    );
  }
}

class _MiniAudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  const _MiniAudioVisualizer({Key? key, required this.isPlaying}) : super(key: key);

  @override
  State<_MiniAudioVisualizer> createState() => _MiniAudioVisualizerState();
}

class _MiniAudioVisualizerState extends State<_MiniAudioVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_MiniAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(4, (i) {
            final time = _controller.value * 20;
            final offset = i * 1.5;
            final waveHeight = widget.isPlaying ? 4.0 + 8.0 * (0.5 * (1 + math.sin(time + offset))) : 4.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              width: 3.0,
              height: waveHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        );
      },
    );
  }
}

