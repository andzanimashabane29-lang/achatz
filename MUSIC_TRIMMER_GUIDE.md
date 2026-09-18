# Music Trimming Feature Guide

## How Users Can Select Music Portions

When users upload a status (text, voice, or image), they can now:

### Step 1: Search for Music
- Tap the **Music** button in the toolbar
- Search for songs, artists, or albums
- Browse trending music
- Preview 30-second clips before selecting

### Step 2: Trim the Music
After selecting a track, a **music trimmer** appears allowing users to:

- **Set Start Time**: Drag slider or tap to choose where the music begins (0:00 by default)
- **Set End Time**: Drag slider or choose how long the music plays
- **Play Preview**: Listen to the selected portion before confirming
- **Time Display**: See the exact time range (e.g., "0:15 - 0:45")

### Step 3: Confirm Selection
- Tap **"Use This Portion"** to attach to status
- Music badge shows the track name and selected time range
- Music can be removed by tapping the **X** on the badge

## Features

✨ **Precise Trimming**
- Accurate to the second
- Minimum 1 second selection
- Maximum is the full track duration

🎵 **Smart Preview**
- Play/pause to hear your selection
- Preview updates with slider changes
- Supports preview URLs from Deezer, Spotify, iTunes

📊 **Time Display**
- Shows M:SS format
- Duration of selected portion displayed
- Real-time updates as user adjusts

## How It Works Backend

When a user selects a music portion:
- **musicStartTimeMs**: Stored in milliseconds (e.g., 15000 for 15 seconds)
- **musicEndTimeMs**: Stored in milliseconds (e.g., 45000 for 45 seconds)
- Full track info still stored for display

## Viewing Status with Trimmed Music

When viewing a status with music:
1. Status player shows the full album cover
2. Music plays from start time to end time
3. UI indicates if music is attached and for how long
4. Clicking music shows full track info

## Future Enhancements

Potential features:
- Fade in/out effects at trim points
- Equalizer adjustments
- Multiple music tracks per status
- Music loop/repeat options
- Lyric sync display

## Technical Details

The music trimmer:
- Uses `just_audio` package for playback
- Stores duration as `Duration` objects
- Converts to milliseconds for Firestore storage
- Handles pause/resume during trimming
- Prevents invalid time ranges (start < end)
