import 'package:a_chatz/src/features/status/data/spotify_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

/// Track selection with start/end time trimming
class SelectedMusicTrack {
  final SpotifyTrack track;
  final Duration startTime;
  final Duration endTime;
  final int lyricsOffsetMs;

  SelectedMusicTrack({
    required this.track,
    this.startTime = Duration.zero,
    Duration? endTime,
    this.lyricsOffsetMs = 0,
  }) : endTime = endTime ?? const Duration(seconds: 30);

  Duration get duration => endTime - startTime;

  String get timeRange {
    final start = _formatDuration(startTime);
    final end = _formatDuration(endTime);
    return '$start - $end';
  }

  static String _formatDuration(Duration d) {
    final minutes = d.inSeconds ~/ 60;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Music trimmer sheet for selecting portion of track
Future<SelectedMusicTrack?> showMusicTrimmer(
  BuildContext context,
  SpotifyTrack track,
) {
  return showModalBottomSheet<SelectedMusicTrack>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MusicTrimmer(track: track),
  );
}

class _MusicTrimmer extends StatefulWidget {
  final SpotifyTrack track;

  const _MusicTrimmer({required this.track});

  @override
  State<_MusicTrimmer> createState() => _MusicTrimmerState();
}

class _MusicTrimmerState extends State<_MusicTrimmer> {
  late final AudioPlayer _player;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerCompleteSubscription;

  late Duration _totalDuration;
  late Duration _startTime;
  late Duration _endTime;

  bool _isPlaying = false;
  bool _isDownloading = false;
  String? _localPath;
  double _lyricsOffsetSeconds = 0;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    // Capping total duration at 30 seconds because Spotify preview audio clips are always 30 seconds or less
    _totalDuration = const Duration(seconds: 30);
    _startTime = Duration.zero;
    _endTime = _totalDuration;

    bool isSeeking = false;
    _positionSubscription = _player.onPositionChanged.listen((pos) async {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
        if (_isPlaying && !isSeeking) {
          if (pos < _startTime) {
            isSeeking = true;
            await _player.seek(_startTime);
            isSeeking = false;
          } else if (pos >= _endTime) {
            isSeeking = true;
            await _player.seek(_startTime);
            isSeeking = false;
          }
        }
      }
    });

    _playerStateSubscription = _player.onPlayerStateChanged.listen((playerState) {
      final isPlaying = playerState == PlayerState.playing;
      if (mounted) setState(() => _isPlaying = isPlaying);
    });

    _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureLocalFile() async {
    if (_localPath != null) return;
    if (widget.track.previewUrl == null) return;
    
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temp_preview_${widget.track.id}.mp3');
    if (file.existsSync()) {
      _localPath = file.path;
      return;
    }

    if (mounted) setState(() => _isDownloading = true);
    try {
      final secureUrl = widget.track.previewUrl!.replaceAll('http://', 'https://');
      final response = await http.get(Uri.parse(secureUrl));
      await file.writeAsBytes(response.bodyBytes);
      _localPath = file.path;
    } catch (_) {}
    if (mounted) setState(() => _isDownloading = false);
  }

  Future<void> _playPreview() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _ensureLocalFile();
      if (_localPath != null) {
        await _player.play(DeviceFileSource(_localPath!));
        await _player.seek(_startTime);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxSeconds = _totalDuration.inSeconds;
    final startSeconds = _startTime.inSeconds;
    final endSeconds = _endTime.inSeconds;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F12),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3D),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Header
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.track.albumCoverUrl != null
                            ? Image.network(
                                widget.track.albumCoverUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trim Music',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.track.title,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.track.artist,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Duration display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Duration',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_startTime.inSeconds ~/ 60}:${(_startTime.inSeconds % 60).toString().padLeft(2, '0')} - '
                          '${_endTime.inSeconds ~/ 60}:${(_endTime.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Duration: ${(_endTime.inSeconds - _startTime.inSeconds)}s',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Start time slider
                  _TimeSlider(
                    label: 'Start Time',
                    value: startSeconds.toDouble(),
                    max: (endSeconds - 1).toDouble(),
                    onChanged: (val) async {
                      final newStart = Duration(seconds: val.toInt());
                      setState(() {
                        _startTime = newStart;
                      });
                      if (_isPlaying) {
                        await _player.seek(newStart);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // End time slider
                  _TimeSlider(
                    label: 'End Time',
                    value: endSeconds.toDouble(),
                    min: (startSeconds + 1).toDouble(),
                    max: maxSeconds.toDouble(),
                    onChanged: (val) async {
                      final newEnd = Duration(seconds: val.toInt());
                      setState(() {
                        _endTime = newEnd;
                      });
                      if (_isPlaying && _currentPosition >= newEnd) {
                        await _player.seek(_startTime);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Lyrics Offset slider
                  _TimeSlider(
                    label: 'Lyrics Sync Offset (seconds)',
                    value: _lyricsOffsetSeconds,
                    min: -30,
                    max: 30,
                    onChanged: (val) {
                      setState(() => _lyricsOffsetSeconds = val);
                    },
                    isOffset: true,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Slide forward/backward to manually match lyrics with the audio if they are out of sync.',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 24),

                  // Play button
                  _isDownloading
                      ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                      : ElevatedButton.icon(
                    onPressed: _playPreview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(
                      _isPlaying ? 'Pause Preview' : 'Play Selected',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm button
                  FilledButton(
                    onPressed: () {
                      _player.stop();
                      Navigator.pop(
                        context,
                        SelectedMusicTrack(
                          track: widget.track,
                          startTime: _startTime,
                          endTime: _endTime,
                          lyricsOffsetMs: (_lyricsOffsetSeconds * 1000).toInt(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Use This Portion',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.music_note, color: Colors.greenAccent, size: 28),
    );
  }
}

class _TimeSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool isOffset;

  const _TimeSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.min = 0,
    this.isOffset = false,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = value.abs().toInt() ~/ 60;
    final seconds = value.abs().toInt() % 60;
    final sign = value < 0 ? '-' : (isOffset && value > 0 ? '+' : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  activeTrackColor: Colors.greenAccent,
                  inactiveTrackColor: const Color(0xFF3A3A3D),
                  thumbColor: Colors.greenAccent,
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$sign$minutes:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
