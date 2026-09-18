import 'dart:async';
import 'dart:io';
import 'package:a_chatz/src/features/status/data/spotify_service.dart';
import 'package:a_chatz/src/features/status/presentation/spotify_music_picker.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/draggable_sticker_canvas.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/music_sticker_widget.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/status_privacy_sheets.dart';
import 'package:a_chatz/src/features/status/domain/status_models.dart';
import 'package:a_chatz/src/features/status/presentation/music_trimmer.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class CreateVoiceStatusScreen extends ConsumerStatefulWidget {
  final SelectedMusicTrack? initialMusic;

  const CreateVoiceStatusScreen({super.key, this.initialMusic});

  @override
  ConsumerState<CreateVoiceStatusScreen> createState() => _CreateVoiceStatusScreenState();
}

class _CreateVoiceStatusScreenState extends ConsumerState<CreateVoiceStatusScreen>
    with SingleTickerProviderStateMixin {
  final _captionController = TextEditingController();
  final _podcastTitleController = TextEditingController();
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  // Background wallpapers
  final List<int> _bgColors = [
    0xFF8E24AA, // Purple
    0xFF1E88E5, // Blue
    0xFFE53935, // Red
    0xFF43A047, // Green
    0xFFFF8F00, // Amber
    0xFF00ACC1, // Cyan
    0xFF1A1A1A, // Sleek Black
    0xFF3949AB, // Indigo
  ];
  int _currentColorIndex = 0;

  // Recording State
  bool _isRecording = false;
  String? _recordedPath;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Preview Playback State
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Music integration
  SelectedMusicTrack? _selectedMusic;
  SongLyrics? _lyrics;
  MusicStickerStyle _stickerStyle = MusicStickerStyle.simpleText;
  Offset _stickerPosition = const Offset(100, 200);
  double _stickerScale = 1.0;
  bool _uploading = false;

  PrivacyOption _privacyOption = PrivacyOption.contacts;
  List<String> _mentions = [];
  List<String> _excludedIds = [];
  List<String> _allowedIds = [];

  Future<void> _selectAudience() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudiencePickerSheet(
        initialExcludedIds: _excludedIds,
        initialAllowedIds: _allowedIds,
        initialOption: _privacyOption,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _privacyOption = result['option'] as PrivacyOption? ?? PrivacyOption.contacts;
        _excludedIds = List<String>.from(result['excludedIds'] ?? []);
        _allowedIds = List<String>.from(result['allowedIds'] ?? []);
      });
    }
  }

  Future<void> _selectMentions() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MentionsPickerSheet(
        initialMentions: _mentions,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _mentions = result;
      });
    }
  }

  // Mic Pulse animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (widget.initialMusic != null) {
      _selectedMusic = widget.initialMusic;
      _stickerStyle = MusicStickerStyle.simpleText;
      _fetchInitialLyrics();
    }

    // Set up audioplayer listeners for previewing the voice status
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _podcastTitleController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _changeColor() {
    HapticFeedback.lightImpact();
    setState(() => _currentColorIndex = (_currentColorIndex + 1) % _bgColors.length);
  }

  Future<void> _pickMusic() async {
    final track = await showSpotifyMusicPicker(context);
    if (track != null && mounted) {
      final selectedMusic = await showMusicTrimmer(context, track);
      if (selectedMusic != null) {
        setState(() {
          _selectedMusic = selectedMusic;
          _lyrics = null;
        });

        final fetchedLyrics = await MusicService.fetchLyrics(track.artist, track.title);
        if (mounted) {
          setState(() {
            _lyrics = fetchedLyrics;
          });
        }
      }
    }
  }

  Future<void> _fetchInitialLyrics() async {
    final track = widget.initialMusic!.track;
    final fetchedLyrics = await MusicService.fetchLyrics(track.artist, track.title);
    if (mounted) {
      setState(() {
        _lyrics = fetchedLyrics;
      });
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    // Stop current preview if playing
    await _audioPlayer.stop();

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/voice_status_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    HapticFeedback.mediumImpact();
    _pulseController.repeat(reverse: true);

    setState(() {
      _isRecording = true;
      _recordedPath = null;
      _recordSeconds = 0;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordSeconds++;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _pulseController.stop();
    final path = await _recorder.stop();

    HapticFeedback.mediumImpact();

    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });

    if (path != null) {
      // Pre-load audio to get its duration
      await _audioPlayer.setSourceDeviceFile(path);
    }
  }

  Future<void> _togglePreview() async {
    if (_recordedPath == null) return;
    HapticFeedback.lightImpact();

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordedPath!));
    }
  }

  Future<void> _deleteRecording() async {
    HapticFeedback.mediumImpact();
    await _audioPlayer.stop();
    setState(() {
      _recordedPath = null;
      _isPlaying = false;
      _duration = Duration.zero;
      _position = Duration.zero;
    });
  }

  Future<void> _postVoiceStatus() async {
    if (_recordedPath == null) return;

    setState(() => _uploading = true);
    try {
      final file = File(_recordedPath!);
      await ref.read(statusRepositoryProvider).uploadStatus(
            file: file,
            type: StatusType.audio,
            caption: _captionController.text.trim(),
            musicTitle: _selectedMusic?.track.title,
            musicArtist: _selectedMusic?.track.artist,
            musicPreviewUrl: _selectedMusic?.track.previewUrl,
            musicStartTime: _selectedMusic?.startTime,
            musicEndTime: _selectedMusic?.endTime,
            musicStickerStyle: _stickerStyle.index,
            musicStickerX: _stickerPosition.dx / MediaQuery.of(context).size.width,
            musicStickerY: _stickerPosition.dy / MediaQuery.of(context).size.height,
            musicStickerScale: _stickerScale,
            musicLyrics: _lyrics?.syncedLyrics ?? _lyrics?.plainLyrics,
            musicLyricsOffsetMs: _selectedMusic?.lyricsOffsetMs,
            textBgColor: _bgColors[_currentColorIndex],
            podcastTitle: _podcastTitleController.text.trim().isEmpty ? null : _podcastTitleController.text.trim(),
            mentions: _mentions,
            excludedIds: _excludedIds,
            allowedIds: _allowedIds,
            privacyOption: _privacyOption.name,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _uploading = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(_bgColors[_currentColorIndex]);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Concentric Glowing Orbs for visuals
            Positioned(
              top: -100,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.06),
                ),
              ),
            ),

            Column(
              children: [
                // ── Top Bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => context.pop(),
                      ),
                      Row(
                        children: [
                          // Music Picker
                          _TopBarButton(
                            icon: Icons.music_note,
                            label: 'Music',
                            active: _selectedMusic != null,
                            onTap: _pickMusic,
                          ),
                          const SizedBox(width: 8),
                          // Privacy Picker
                          _TopBarButton(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Privacy',
                            active: _privacyOption != PrivacyOption.contacts,
                            onTap: _selectAudience,
                          ),
                          const SizedBox(width: 8),
                          // Mentions Picker
                          _TopBarButton(
                            icon: Icons.alternate_email,
                            label: 'Mentions',
                            active: _mentions.isNotEmpty,
                            onTap: _selectMentions,
                          ),
                          const SizedBox(width: 8),
                          // Color Selector
                          _TopBarButton(
                            icon: Icons.palette_outlined,
                            label: 'Wallpaper',
                            onTap: _changeColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Selected Music Sticker Canvas ──────────────────────────────
                if (_selectedMusic != null)
                  Expanded(
                    child: DraggableStickerCanvas(
                      onTap: () {
                        setState(() {
                          final nextIndex = (_stickerStyle.index + 1) % MusicStickerStyle.values.length;
                          _stickerStyle = MusicStickerStyle.values[nextIndex];
                        });
                      },
                      onTransformChanged: (pos, scale) {
                        _stickerPosition = pos;
                        _stickerScale = scale;
                      },
                      child: MusicStickerWidget(
                        track: _selectedMusic!.track,
                        lyrics: _lyrics,
                        style: _stickerStyle,
                        currentPlaybackPosition: _position,
                      ),
                    ),
                  ),

                // ── Core Visuals & Waveform Section ───────────────────
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_isRecording && _recordedPath == null) ...[
                            // Initial State: Mic prompt
                            const Icon(
                              Icons.mic_none_rounded,
                              size: 100,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Tap the microphone to record\nyour voice status update',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ] else if (_isRecording) ...[
                            // Recording State
                            Text(
                              _formatDuration(Duration(seconds: _recordSeconds)),
                              style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(8, (index) {
                                return AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final height = 15.0 + 35.0 * (index % 2 == 0 ? _pulseController.value : (1.0 - _pulseController.value));
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: 4,
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    );
                                  },
                                );
                              }),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Recording audio status...',
                              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ] else ...[
                            // Preview state (Recorded file ready)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Player Controller
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: _togglePreview,
                                        child: CircleAvatar(
                                          radius: 28,
                                          backgroundColor: Colors.white,
                                          child: Icon(
                                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                            color: bgColor,
                                            size: 32,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Voice note status',
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                                ),
                                                Text(
                                                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            SliderTheme(
                                              data: SliderThemeData(
                                                trackHeight: 3.5,
                                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                                activeTrackColor: Colors.white,
                                                inactiveTrackColor: Colors.white24,
                                                thumbColor: Colors.white,
                                                activeTickMarkColor: Colors.transparent,
                                                inactiveTickMarkColor: Colors.transparent,
                                              ),
                                              child: Slider(
                                                value: _position.inMilliseconds.toDouble(),
                                                max: _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                                                onChanged: (val) {
                                                  _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  // Podcast Title Input
                                  TextField(
                                    controller: _podcastTitleController,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      hintText: 'Podcast Title (optional)...',
                                      hintStyle: const TextStyle(color: Colors.white60),
                                      prefixIcon: const Icon(Icons.podcasts, color: Colors.purpleAccent),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.08),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Caption Text Input (Modern floating-card text field)
                                  TextField(
                                    controller: _captionController,
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: 'Add a caption...',
                                      hintStyle: const TextStyle(color: Colors.white60),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.08),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Delete button
                            TextButton.icon(
                              onPressed: _deleteRecording,
                              style: TextButton.styleFrom(foregroundColor: Colors.white70),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Discard recording', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom Action Pad ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Space placeholder or extra options
                      const SizedBox(width: 56),

                      // Central Recording Mic / Stop Button
                      GestureDetector(
                        onTap: () {
                          if (_recordedPath != null) return;
                          if (_isRecording) {
                            _stopRecording();
                          } else {
                            _startRecording();
                          }
                        },
                        child: ScaleTransition(
                          scale: Tween(begin: 1.0, end: 1.15).animate(
                            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                          ),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording ? Colors.redAccent : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                                if (_isRecording)
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                              ],
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                              color: _isRecording ? Colors.white : bgColor,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      // Post / Send status button (visible if recorded)
                      _recordedPath != null
                          ? FloatingActionButton(
                              onPressed: _postVoiceStatus,
                              backgroundColor: Colors.white,
                              foregroundColor: bgColor,
                              child: const Icon(Icons.send_rounded),
                            )
                          : const SizedBox(width: 56),
                    ],
                  ),
                ),
              ],
            ),

            // Loading overlay during upload
            if (_uploading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Private top bar helper ───────────────────────────────────────────
class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? Colors.black : Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
