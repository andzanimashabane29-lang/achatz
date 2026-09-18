# Music API Integration Guide

Your app now supports music search from **three major platforms**: Deezer, Spotify, and iTunes. Users can search and add music to their status updates with a simple search interface.

## Current Setup

- **Deezer**: ✅ No configuration needed (no API key required)
- **iTunes**: ✅ No configuration needed (no API key required)  
- **Spotify**: ⚠️ Optional - Requires setup for enhanced music catalog

## How It Works

When users upload a status (text, voice, image), they can:
1. Tap the **Music** button
2. Search for any song, artist, or album
3. Preview the track (30-second preview from Deezer/Spotify/iTunes)
4. Select and attach to their status

The app automatically searches these platforms in order:
1. **Deezer** (fastest, no auth needed)
2. **Spotify** (if configured)
3. **iTunes** (fallback)

## Setting Up Spotify (Optional)

To enable Spotify search, follow these steps:

### Step 1: Create Spotify App
1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Log in or create an account
3. Click "Create an App"
4. Accept the terms and create the app
5. You'll get:
   - **Client ID**
   - **Client Secret**

### Step 2: Configure Your App

✅ **Already configured!** Your Spotify credentials have been set in `deezer_service.dart`:

```dart
const clientId = 'a041ff8958414dfbb48a6780c93f4308';
const clientSecret = '••••••••••••••••••••••••••••••••'; // stored in source
```


### Step 3: (Production) Use Environment Variables

For production apps, store credentials securely:

**Option A - Firebase Remote Config:**
```dart
final remoteConfig = FirebaseRemoteConfig.instance;
final clientId = remoteConfig.getString('spotify_client_id');
final clientSecret = remoteConfig.getString('spotify_client_secret');
```

**Option B - Environment Variables:**
```dart
import 'dart:io';

final clientId = Platform.environment['SPOTIFY_CLIENT_ID'];
final clientSecret = Platform.environment['SPOTIFY_CLIENT_SECRET'];
```

## Features

✨ **Multi-Platform Search**
- Search across Deezer, Spotify, and iTunes simultaneously
- Results show the platform source (DEEZER, SPOTIFY, ITUNES)

🎵 **Preview Playback**
- Listen to 30-second previews before adding
- Platform badges indicate track source

📱 **Smart Fallback**
- If Spotify is unavailable, uses Deezer or iTunes
- No interruption to user experience

⚡ **Fast & Lightweight**
- No heavy dependencies
- Works on mobile, web, and desktop

## Status Music Display

When a user views a status with music:
- Album cover displays
- Track title and artist shown
- Music player plays the preview
- Tap to expand full player

## Troubleshooting

**"No results found"**
- Check internet connection
- Try a different search term
- All three APIs might be experiencing downtime

**Spotify search not working**
- Verify Client ID and Secret are correct
- Check your Spotify app is not rate-limited
- Ensure `const clientId` is not 'YOUR_SPOTIFY_CLIENT_ID'

**Preview not playing**
- Some tracks may not have preview URLs available
- iTunes and Deezer previews have different availability
- Try another track

## API Rate Limits

- **Deezer**: 50 requests/second
- **Spotify**: 429 rate limit (handles automatically)
- **iTunes**: No official limit (very generous)

If you hit rate limits, the app automatically falls back to the next API.

## Future Enhancements

Possible improvements:
- Apple Music API integration
- YouTube Music API integration
- SoundCloud API integration
- Custom playlist support
- Offline music caching
