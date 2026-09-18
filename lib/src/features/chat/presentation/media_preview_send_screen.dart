import 'dart:io';
import 'dart:async';
import 'package:a_chatz/src/features/status/data/spotify_service.dart';
import 'package:a_chatz/src/features/status/presentation/spotify_music_picker.dart';
import 'package:a_chatz/src/features/status/presentation/music_trimmer.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/draggable_sticker_canvas.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/music_sticker_widget.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/status_privacy_sheets.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;

class MediaPreviewSendScreen extends StatefulWidget {
  const MediaPreviewSendScreen({
    super.key,
    this.file,
    this.xFile,
    required this.isVideo,
    this.isForStatus = false,
  });

  final File? file;
  final XFile? xFile;
  final bool isVideo;
  final bool isForStatus;

  @override
  State<MediaPreviewSendScreen> createState() => _MediaPreviewSendScreenState();
}

class _MediaPreviewSendScreenState extends State<MediaPreviewSendScreen> {
  final captionController = TextEditingController();
  VideoPlayerController? _videoController;
  SelectedMusicTrack? _selectedMusic;
  SongLyrics? _lyrics;
  MusicStickerStyle _stickerStyle = MusicStickerStyle.simpleText;
  Duration _currentAudioPosition = Duration.zero;
  Offset _stickerPosition = const Offset(100, 200);
  double _stickerScale = 1.0;
  late XFile _currentFile;

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

  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.xFile ?? XFile(widget.file!.path);
    if (widget.isVideo) {
      if (kIsWeb) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(_currentFile.path))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _videoController?.play();
              _videoController?.setLooping(true);
            }
          });
      } else {
        _videoController = VideoPlayerController.file(File(_currentFile.path))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _videoController?.play();
              _videoController?.setLooping(true);
            }
          });
      }
    }
  }

  @override
  void dispose() {
    captionController.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    super.dispose();
  }

  void _playMusicSegment() async {
    await _audioPlayer.stop();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _playerCompleteSubscription?.cancel();
    _playerCompleteSubscription = null;

    if (_selectedMusic == null || _selectedMusic!.track.previewUrl == null) {
      return;
    }

    try {
      final secureUrl = _selectedMusic!.track.previewUrl!.replaceAll('http://', 'https://');
      await _audioPlayer.setSource(UrlSource(secureUrl));
      final startMs = _selectedMusic!.startTime.inMilliseconds;
      final endMs = _selectedMusic!.endTime.inMilliseconds;

      await _audioPlayer.seek(Duration(milliseconds: startMs));
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      bool isSeeking = false;
      _positionSubscription = _audioPlayer.onPositionChanged.listen((pos) async {
        if (mounted) setState(() => _currentAudioPosition = pos);
        if (isSeeking) return;

        if (pos.inMilliseconds < startMs || pos.inMilliseconds >= endMs) {
          isSeeking = true;
          await _audioPlayer.seek(Duration(milliseconds: startMs));
          isSeeking = false;
        }
      });

      _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) async {
        await _audioPlayer.seek(Duration(milliseconds: startMs));
        if (mounted) setState(() => _currentAudioPosition = Duration(milliseconds: startMs));
        await _audioPlayer.resume();
      });

      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('MediaPreviewSendScreen audio playback error: $e');
    }
  }

  bool _isViewOnce = false;
  bool _isHD = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Preview
          Positioned.fill(
            child: Center(
              child: widget.isVideo
                  ? (_videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator(color: Colors.white))
                  : (kIsWeb 
                      ? Image.network(_currentFile.path, fit: BoxFit.contain)
                      : Image.file(File(_currentFile.path), fit: BoxFit.contain)),
            ),
          ),

          // Top Tools
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 10, right: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isHD ? Icons.hd : Icons.hd_outlined,
                      color: _isHD ? Colors.blue : Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        _isHD = !_isHD;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isHD ? 'HD Quality Selected' : 'Standard Quality Selected'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.music_note, color: Colors.white, size: 28),
                    onPressed: () => _showMusicSelector(),
                  ),
                  if (widget.isForStatus) ...[
                    IconButton(
                      icon: Icon(
                        Icons.privacy_tip_outlined,
                        color: (_privacyOption != PrivacyOption.contacts)
                            ? const Color(0xFFFC6D4A)
                            : Colors.white,
                        size: 28,
                      ),
                      tooltip: 'Privacy',
                      onPressed: _selectAudience,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.alternate_email,
                        color: _mentions.isNotEmpty ? const Color(0xFFFC6D4A) : Colors.white,
                        size: 28,
                      ),
                      tooltip: 'Mentions',
                      onPressed: _selectMentions,
                    ),
                  ],
                  if (_lyrics != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_stickerStyle == MusicStickerStyle.lyricsKaraoke) {
                            _stickerStyle = MusicStickerStyle.lyricsNeon;
                          } else if (_stickerStyle == MusicStickerStyle.lyricsNeon) {
                            _stickerStyle = MusicStickerStyle.lyricsTypewriter;
                          } else {
                            _stickerStyle = MusicStickerStyle.lyricsKaraoke;
                          }
                        });
                      },
                      icon: const Icon(Icons.text_format, color: Colors.white),
                      label: Text(
                        _stickerStyle == MusicStickerStyle.lyricsNeon 
                            ? 'NEON' 
                            : _stickerStyle == MusicStickerStyle.lyricsTypewriter 
                                ? 'TYPEWRITER' 
                                : 'KARAOKE',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (!widget.isVideo)
                    IconButton(
                      icon: const Icon(Icons.design_services, color: Colors.white, size: 28),
                      tooltip: 'Design & Edit',
                      onPressed: () async {
                        final originalBytes = await _currentFile.readAsBytes();
                        final editedXFile = await Navigator.push<XFile?>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProImageEditor.memory(
                              originalBytes,
                              callbacks: ProImageEditorCallbacks(
                                onImageEditingComplete: (Uint8List bytes) async {
                                  if (kIsWeb) {
                                    final xfile = XFile.fromData(bytes, mimeType: 'image/jpeg');
                                    if (context.mounted) Navigator.pop(context, xfile);
                                  } else {
                                    final tempDir = await getTemporaryDirectory();
                                    final file = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
                                    await file.writeAsBytes(bytes);
                                    if (context.mounted) Navigator.pop(context, XFile(file.path));
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                        if (editedXFile != null && mounted) {
                          setState(() {
                            _currentFile = editedXFile;
                          });
                        }
                      },
                    ),
                ],
              ),
            ),
          ),

          // Draggable Interactive Music Sticker
          if (_selectedMusic != null)
            DraggableStickerCanvas(
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
                currentPlaybackPosition: _currentAudioPosition,
              ),
            ),

          // Bottom Bar (Caption + Send)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: captionController,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              decoration: const InputDecoration(
                                hintText: 'Add a caption...',
                                hintStyle: TextStyle(color: Colors.white54),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (!widget.isForStatus)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isViewOnce = !_isViewOnce;
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _isViewOnce ? const Color(0xFF00A884) : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _isViewOnce ? Colors.transparent : Colors.white54,
                                    width: 1.8,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: _isViewOnce ? Colors.white : Colors.white,
                                      fontSize: 13,
                                      height: 1.1,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context, {
                        'caption': captionController.text.trim(),
                        'music': _selectedMusic != null
                            ? '${_selectedMusic!.track.title} - ${_selectedMusic!.track.artist}'
                            : null,
                        'musicTitle': _selectedMusic?.track.title,
                        'musicArtist': _selectedMusic?.track.artist,
                        'musicPreviewUrl': _selectedMusic?.track.previewUrl,
                        'musicStartTimeMs': _selectedMusic?.startTime.inMilliseconds,
                        'musicEndTimeMs': _selectedMusic?.endTime.inMilliseconds,
                        'musicStickerStyle': _stickerStyle.index,
                        'musicStickerX': _stickerPosition.dx / MediaQuery.of(context).size.width, 
                        'musicStickerY': _stickerPosition.dy / MediaQuery.of(context).size.height,
                        'musicStickerScale': _stickerScale,
                        'musicLyrics': _lyrics?.syncedLyrics ?? _lyrics?.plainLyrics,
                        'musicLyricsOffsetMs': _selectedMusic?.lyricsOffsetMs,
                        'isViewOnce': _isViewOnce,
                        'isHD': _isHD,
                        'editedFile': _currentFile.path,
                        'mentions': _mentions,
                        'excludedIds': _excludedIds,
                        'allowedIds': _allowedIds,
                        'privacyOption': _privacyOption.name,
                      });
                    },
                    child: Container(
                      height: 56,
                      width: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.black, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMusicSelector() async {
    final track = await showSpotifyMusicPicker(context);
    if (track != null && mounted) {
      final selectedMusic = await showMusicTrimmer(context, track);
      if (selectedMusic != null) {
        setState(() {
          _selectedMusic = selectedMusic;
          _lyrics = null; // Clear old lyrics while fetching
        });
        _playMusicSegment();
        
        // Fetch lyrics silently in background
        final fetchedLyrics = await MusicService.fetchLyrics(track.artist, track.title);
        if (mounted) {
          setState(() {
            _lyrics = fetchedLyrics;
          });
        }
      }
    }
  }
}
