import 'package:a_chatz/src/features/status/data/spotify_service.dart';
import 'package:a_chatz/src/features/status/data/link_preview_service.dart';
import 'package:a_chatz/src/features/status/presentation/spotify_music_picker.dart';
import 'package:a_chatz/src/features/status/presentation/music_trimmer.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/status_privacy_sheets.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/draggable_sticker_canvas.dart';
import 'package:a_chatz/src/features/status/presentation/widgets/music_sticker_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateTextStatusScreen extends ConsumerStatefulWidget {
  final SelectedMusicTrack? initialMusic;

  const CreateTextStatusScreen({super.key, this.initialMusic});

  @override
  ConsumerState<CreateTextStatusScreen> createState() => _CreateTextStatusScreenState();
}

class _CreateTextStatusScreenState extends ConsumerState<CreateTextStatusScreen> {
  final _textController = TextEditingController();

  final List<int> _bgColors = [
    0xFF1E88E5, 0xFFE53935, 0xFF43A047, 0xFF8E24AA,
    0xFFFF8F00, 0xFF3949AB, 0xFF00ACC1,
  ];
  int _currentColorIndex = 0;

  final List<String> _fonts = ['Default', 'Serif', 'Monospace', 'Handwriting', 'Impact'];
  int _currentFontIndex = 0;

  SelectedMusicTrack? _selectedMusic;
  SongLyrics? _lyrics;
  MusicStickerStyle _stickerStyle = MusicStickerStyle.simpleText;
  Duration _currentAudioPosition = Duration.zero;
  Offset _stickerPosition = const Offset(100, 200);
  double _stickerScale = 1.0;
  bool _uploading = false;

  PrivacyOption _privacyOption = PrivacyOption.contacts;
  List<String> _mentions = [];
  List<String> _excludedIds = [];
  List<String> _allowedIds = [];
  
  LinkPreviewData? _linkPreview;
  bool _fetchingLinkPreview = false;

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
  // ignore: cancel_subscriptions
  var _positionSubscription;
  // ignore: cancel_subscriptions
  var _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialMusic != null) {
      _selectedMusic = widget.initialMusic;
      _stickerStyle = MusicStickerStyle.simpleText;
      _fetchInitialLyrics();
    }
    
    // Listen for text changes to fetch link preview
    _textController.addListener(_fetchLinkPreview);
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

  Future<void> _fetchLinkPreview() async {
    final text = _textController.text.trim();
    if (!LinkPreviewService.instance.containsUrl(text)) {
      setState(() {
        _linkPreview = null;
      });
      return;
    }

    setState(() => _fetchingLinkPreview = true);

    try {
      final preview = await LinkPreviewService.instance.fetchFirstLinkPreview(text);
      if (mounted) {
        setState(() {
          _linkPreview = preview;
          _fetchingLinkPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingLinkPreview = false);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioPlayer.dispose();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    super.dispose();
  }

  void _changeColor() =>
      setState(() => _currentColorIndex = (_currentColorIndex + 1) % _bgColors.length);

  void _changeFont() =>
      setState(() => _currentFontIndex = (_currentFontIndex + 1) % _fonts.length);

  TextStyle _getTextStyle() {
    switch (_fonts[_currentFontIndex]) {
      case 'Serif':
        return const TextStyle(fontFamily: 'Georgia', fontSize: 36, color: Colors.white, height: 1.4);
      case 'Monospace':
        return const TextStyle(fontFamily: 'Courier', fontSize: 30, color: Colors.white, height: 1.4);
      case 'Handwriting':
        return const TextStyle(fontFamily: 'Cursive', fontSize: 36, color: Colors.white, height: 1.4);
      case 'Impact':
        return const TextStyle(fontWeight: FontWeight.w900, fontSize: 42, color: Colors.white, height: 1.3);
      default:
        return const TextStyle(fontWeight: FontWeight.w600, fontSize: 36, color: Colors.white, height: 1.4);
    }
  }

  void _playMusicSegment() async {
    await _audioPlayer.stop();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();

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
      debugPrint('CreateTextStatusScreen audio playback error: $e');
    }
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
        _playMusicSegment();

        final fetchedLyrics = await MusicService.fetchLyrics(track.artist, track.title);
        if (mounted) {
          setState(() {
            _lyrics = fetchedLyrics;
          });
        }
      }
    }
  }

  Future<void> _uploadStatus() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _uploading = true);
    try {
      await ref.read(statusRepositoryProvider).uploadTextStatus(
            text: text,
            bgColor: _bgColors[_currentColorIndex],
            textFont: _fonts[_currentFontIndex],
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
            mentions: _mentions,
            excludedIds: _excludedIds,
            allowedIds: _allowedIds,
            privacyOption: _privacyOption.name,
            linkPreviewUrl: _linkPreview?.url,
            linkPreviewTitle: _linkPreview?.title,
            linkPreviewDescription: _linkPreview?.description,
            linkPreviewImage: _linkPreview?.image,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(_bgColors[_currentColorIndex]);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Top bar ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Music picker button
                              _TopBarButton(
                                icon: Icons.music_note,
                                label: 'Music',
                                active: _selectedMusic != null,
                                onTap: _pickMusic,
                              ),
                              // Font selector
                              _TopBarButton(
                                icon: Icons.text_fields,
                                label: _fonts[_currentFontIndex],
                                onTap: _changeFont,
                              ),
                              // Privacy selector
                              _TopBarButton(
                                icon: Icons.privacy_tip_outlined,
                                label: 'Privacy',
                                active: _privacyOption != PrivacyOption.contacts,
                                onTap: _selectAudience,
                              ),
                              // Mentions selector
                              _TopBarButton(
                                icon: Icons.alternate_email,
                                label: 'Mentions',
                                active: _mentions.isNotEmpty,
                                onTap: _selectMentions,
                              ),
                              // Color selector
                              _TopBarButton(
                                icon: Icons.palette,
                                label: 'Color',
                                onTap: _changeColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Text input ─────────────────────────────────────
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        textAlign: TextAlign.center,
                        maxLines: null,
                        style: _getTextStyle(),
                        decoration: const InputDecoration(
                          hintText: 'Type a status…',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // Link preview card
                if (_linkPreview != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        if (_linkPreview!.image != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _linkPreview!.image!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                color: Colors.white10,
                                child: const Icon(Icons.link, color: Colors.white30),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.link, color: Colors.white30),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_linkPreview!.title != null)
                                Text(
                                  _linkPreview!.title!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (_linkPreview!.description != null)
                                Text(
                                  _linkPreview!.description!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                _linkPreview!.url,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bottom spacer for FAB
                const SizedBox(height: 80),
              ],
            ),

            // Draggable Interactive Music Sticker overlay
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

            // Uploading overlay
            if (_uploading) const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFC6D4A),
        onPressed: _uploading ? null : _uploadStatus,
        child: const Icon(Icons.send, color: Colors.white),
      ),
    );
  }
}

// ── Small helper widget for top-bar icon buttons ─────────────────────────────

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFC6D4A).withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? const Color(0xFFFC6D4A) : Colors.white30,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? const Color(0xFFFC6D4A) : Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFFFC6D4A) : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
