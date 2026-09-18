import 'dart:async';
import 'package:a_chatz/src/features/status/data/spotify_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// A premium, native-looking glassmorphic music search bottom sheet.
/// Returns a [SpotifyTrack] when the user taps a song, or null if dismissed.
///
/// Usage:
/// ```dart
/// final track = await showSpotifyMusicPicker(context);
/// if (track != null) { ... }
/// ```
Future<SpotifyTrack?> showSpotifyMusicPicker(BuildContext context) {
  return showModalBottomSheet<SpotifyTrack>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SpotifyMusicPicker(),
  );
}

/// Backwards-compatible alias
Future<SpotifyTrack?> showDeezerMusicPicker(BuildContext context) =>
    showSpotifyMusicPicker(context);

class _SpotifyMusicPicker extends StatefulWidget {
  const _SpotifyMusicPicker();

  @override
  State<_SpotifyMusicPicker> createState() => _SpotifyMusicPickerState();
}

class Mood {
  final String label;
  final String emoji;
  final String query;
  const Mood(this.label, this.emoji, this.query);
}

class _SpotifyMusicPickerState extends State<_SpotifyMusicPicker> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  final _player = AudioPlayer();

  List<SpotifyTrack> _tracks = [];
  bool _loading = false;
  String? _error;
  int? _playingId;
  bool _isPlaying = false;

  Mood? _selectedMood;

  final List<Mood> _moods = const [
    Mood('Chill', '🎧', 'chill vibes'),
    Mood('Sad', '😢', 'sad songs'),
    Mood('Happy', '😄', 'happy pop hits'),
    Mood('Energetic', '🔥', 'workout motivation energetic'),
    Mood('Romantic', '💖', 'romantic love songs'),
    Mood('Focus', '🧠', 'focus lo-fi beats'),
  ];

  @override
  void initState() {
    super.initState();
    _loadChart();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingId = null;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadChart() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await MusicService.chartTracks();
      if (mounted) {
        setState(() {
          _tracks = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load music. Check connection.';
          _loading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() {
      _selectedMood = null;
    });
    if (query.trim().isEmpty) {
      _loadChart();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await MusicService.searchTracks(query);
      if (mounted) {
        setState(() {
          _tracks = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search failed. Check connection.';
          _loading = false;
        });
      }
    }
  }

  void _onMoodSelected(Mood mood) {
    if (_selectedMood == mood) {
      // Deselect
      setState(() {
        _selectedMood = null;
      });
      _loadChart();
    } else {
      setState(() {
        _selectedMood = mood;
        _searchCtrl.clear();
      });
      _search(mood.query);
    }
  }

  Future<void> _togglePreview(SpotifyTrack track) async {
    if (track.previewUrl == null) return;

    if (_playingId == track.id && _isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_playingId != track.id) {
        await _player.setUrl(track.previewUrl!);
      }
      await _player.play();
      setState(() {
        _playingId = track.id;
        _isPlaying = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101012).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3D),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFC6D4A), Color(0xFFFD9070)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.music_note, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Music',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Premium Audio Engine',
                        style: TextStyle(color: Color(0xFFFC6D4A), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38),
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadChart();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Mood Search chips list
            SizedBox(
              height: 40,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _moods.length,
                itemBuilder: (context, index) {
                  final mood = _moods[index];
                  final isSelected = _selectedMood == mood;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${mood.emoji} ${mood.label}'),
                      selected: isSelected,
                      onSelected: (_) => _onMoodSelected(mood),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      selectedColor: const Color(0xFFFC6D4A),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFFC6D4A) : Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Section label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedMood != null
                      ? 'Mood: ${_selectedMood!.label}'
                      : _searchCtrl.text.isEmpty
                          ? '🔥 Trending Now'
                          : 'Results',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Results
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFC6D4A)))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi_off, color: Colors.white38, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _loadChart,
                                icon: const Icon(Icons.refresh, color: Color(0xFFFC6D4A)),
                                label: const Text('Retry', style: TextStyle(color: Color(0xFFFC6D4A))),
                              ),
                            ],
                          ),
                        )
                      : _tracks.isEmpty
                          ? const Center(
                              child: Text(
                                'No results found',
                                style: TextStyle(color: Colors.white38),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              itemCount: _tracks.length,
                              itemBuilder: (_, i) => _TrackTile(
                                track: _tracks[i],
                                isPlaying: _playingId == _tracks[i].id && _isPlaying,
                                onPreview: () => _togglePreview(_tracks[i]),
                                onSelect: () {
                                  _player.stop();
                                  Navigator.pop(context, _tracks[i]);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.isPlaying,
    required this.onPreview,
    required this.onSelect,
  });

  final SpotifyTrack track;
  final bool isPlaying;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.albumCoverUrl != null
                ? Image.network(
                    track.albumCoverUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderCover(),
                  )
                : _placeholderCover(),
          ),
          if (isPlaying)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.equalizer, color: Color(0xFFFC6D4A), size: 22),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              track.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track.artist,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (track.durationFormatted.isNotEmpty)
            Text(track.durationFormatted, style: const TextStyle(color: Colors.white30, fontSize: 11)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview button
          if (track.previewUrl != null)
            GestureDetector(
              onTap: onPreview,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPlaying ? const Color(0xFFFC6D4A) : Colors.white.withOpacity(0.12),
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 18,
                  color: isPlaying ? const Color(0xFFFC6D4A) : Colors.white70,
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Select button
          GestureDetector(
            onTap: onSelect,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFC6D4A), Color(0xFFFD9070)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.music_note, color: Color(0xFFFC6D4A), size: 24),
    );
  }
}
