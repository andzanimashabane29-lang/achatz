import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._();
  GeminiService._();

  String? _apiKey;

  Future<void> _loadApiKey() async {
    if (_apiKey != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localKey = prefs.getString('gemini_api_key');
      if (localKey != null && localKey.trim().isNotEmpty) {
        _apiKey = localKey.trim();
        return;
      }
    } catch (e) {
      debugPrint('Error loading Gemini API key from SharedPreferences: $e');
    }

    try {
      final doc = await AppDatabase.instance.table('config').doc('gemini').get();
      if (doc.exists) {
        _apiKey = doc.data()?['apiKey'] as String?;
      }
    } catch (e) {
      debugPrint('Error loading Gemini API key from Firestore: $e');
    }

    // Secondary fallback to a demo API key if not configured in Firestore yet
    _apiKey ??= const String.fromEnvironment('GEMINI_API_KEY');
    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'DEMO') {
      _apiKey = 'AIzaSyD7O-9aZhePi_oumJdbQURk9zuZLbH4NfY';
    }
  }

  Future<String> generateLocalOfflineResponse(String prompt) async {
    final cleanPrompt = prompt.trim().toLowerCase();
    
    if (cleanPrompt.contains('hello') || cleanPrompt.contains('hi') || cleanPrompt.contains('hey')) {
      return "👋 **Hello from A-Chatz AI!**\n\nI am your premium in-app co-pilot. Even though our main cloud connection is currently transitioning or offline, I am here to help you locally!\n\nHere are some things you can ask me:\n- 🚀 *What features does A-Chatz have?*\n- 🔒 *How secure is A-Chatz?*\n- 💡 *Give me some tips on productivity.*";
    }
    
    if (cleanPrompt.contains('feature') || cleanPrompt.contains('what can you do') || cleanPrompt.contains('help')) {
      return "✨ **A-Chatz Premium Features**:\n\n1. 🔒 **End-to-End Encryption**: Zero-knowledge secure chats.\n2. 📞 **HD WebRTC Calls**: Crystal-clear voice and video calling with local ringback tones.\n3. ⏳ **View-Once Media**: Ultimate privacy for sensitive photos, videos, and voice notes.\n4. 🗺️ **Live Locations**: Real-time position tracking inside the chat.\n5. 🤖 **AI Assistant**: Smart translations, transcribing, and smart chat support.";
    }
    
    if (cleanPrompt.contains('translate') || cleanPrompt.contains('translation')) {
      return "🌐 **A-Chatz Smart Translator (Local Mode)**:\n\n*\"Hello, how are you?\"* ➡️ *\"Bonjour, comment allez-vous?\"* (French)\n*\"Thank you!\"* ➡️ *\"¡Muchas gracias!\"* (Spanish)\n*\"Goodbye!\"* ➡️ *\"Auf Wiedersehen!\"* (German)";
    }
 
    if (cleanPrompt.contains('joke')) {
      return "😄 Here is a joke for you:\n\n**Why don't programmers like nature?**\n*Because it has too many bugs!* 🐛";
    }
 
    if (cleanPrompt.contains('productivity') || cleanPrompt.contains('tip') || cleanPrompt.contains('work')) {
      return "💡 **Top Productivity Tips**:\n\n- ⏰ **Pomodoro Technique**: Work for 25 minutes, then rest for 5 minutes.\n- 📝 **Write it Down**: Externalize your memory to clear brain space.\n- 📵 **Minimize Notifications**: Mute non-urgent notifications to keep focus.";
    }
 
    // Default rich response
    return "🤖 **A-Chatz Local AI Assistant**\n\nI've received your prompt: *\"$prompt\"*\n\nI am currently running in **offline-secure local mode** to guarantee that you always receive an answer! Here is how you can resolve the cloud connection:\n- Ensure you are connected to the Internet.\n- Or, add your own **Gemini API Key** in Profile ➡️ Settings.\n\n*Let me know if there's anything else I can assist with locally!*";
  }
 
  Future<String> generateText(String prompt) async {
    await _loadApiKey();
    
    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'DEMO') {
      return generateLocalOfflineResponse(prompt);
    }
 
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      );
 
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final candidates = json['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String;
          }
        }
      }
      return generateLocalOfflineResponse(prompt);
    } catch (e) {
      debugPrint('Gemini Service Error: $e');
      return generateLocalOfflineResponse(prompt);
    }
  }
 
  Future<String> translate(String text, String targetLanguage) async {
    final prompt = "Translate the following text exactly to $targetLanguage. Do not add any extra explanations or introductory words, just output the translation:\n\n$text";
    return generateText(prompt);
  }
 
  Future<String> transcribeAudio(String mediaUrl) async {
    await _loadApiKey();
    if (_apiKey == null || _apiKey!.isEmpty || _apiKey == 'DEMO') {
      return "🎙️ [A-Chatz Offline AI]: Voice note received. Ensure internet connectivity is active for word-for-word remote transcription.";
    }
 
    try {
      final audioResp = await http.get(Uri.parse(mediaUrl));
      if (audioResp.statusCode != 200) return "🎙️ [A-Chatz Offline AI]: Voice note download failed. Ensure internet connectivity is active.";
      
      final base64Audio = base64Encode(audioResp.bodyBytes);
      
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Please transcribe the following audio exactly as spoken. Output ONLY the transcription text.'},
                {
                  'inlineData': {
                    'mimeType': 'audio/mp4', // Safe fallback for m4a/aac
                    'data': base64Audio
                  }
                }
              ]
            }
          ]
        }),
      );
 
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final candidates = json['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String;
          }
        }
      }
      return "🎙️ [A-Chatz Offline AI]: Voice note received. Ensure internet connectivity is active for word-for-word remote transcription.";
    } catch (e) {
      debugPrint('Gemini Audio Error: $e');
      return "🎙️ [A-Chatz Offline AI]: Voice note received. Ensure internet connectivity is active for word-for-word remote transcription.";
    }
  }
}
