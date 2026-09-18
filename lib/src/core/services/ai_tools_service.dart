import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:a_chatz/src/core/services/gemini_service.dart';

class AIToolsService {
  static final AIToolsService instance = AIToolsService._();
  AIToolsService._();

  final _gemini = GeminiService.instance;

  /// Summarizes a chat conversation.
  Future<String> summarizeChat(String chatContext) async {
    final prompt = '''
Summarize the following chat conversation into a brief, easy-to-read bulleted list. 
Highlight the main topics, key decisions, and any action items.

Chat Context:
$chatContext
''';
    return await _gemini.generateText(prompt);
  }

  /// Rewrites a message in a specific tone.
  Future<String> rewriteMessage(String text, String tone) async {
    final prompt = '''
Rewrite the following message to sound $tone. 
Keep the original meaning but adjust the vocabulary and phrasing to match the requested tone.
Output ONLY the rewritten message.

Original message:
$text
''';
    return await _gemini.generateText(prompt);
  }

  /// Detects if a message is a scam.
  Future<String> detectScam(String text) async {
    final prompt = '''
Analyze the following message for potential scams, fraud, or phishing attempts.
Provide a risk rating (Low, Medium, High, or Critical) and a brief explanation of why.
Output in a clear, formatted way.

Message to analyze:
$text
''';
    return await _gemini.generateText(prompt);
  }

  /// Detects toxicity in a message.
  Future<String> detectToxicity(String text) async {
    final prompt = '''
Analyze the following message for toxicity, hate speech, harassment, or offensive content.
Provide a toxicity score out of 100%, and a brief explanation of any concerning elements found.

Message to analyze:
$text
''';
    return await _gemini.generateText(prompt);
  }

  /// Explains a confusing message.
  Future<String> explainMessage(String text) async {
    final prompt = '''
Explain the meaning of the following message in plain, simple language. 
If there is slang, idioms, or coded language, break it down clearly.

Message to explain:
$text
''';
    return await _gemini.generateText(prompt);
  }

  /// Suggests replies based on the last message.
  Future<List<String>> suggestReplies(String context) async {
    final prompt = '''
Based on the following message, suggest exactly 3 short, natural, and context-appropriate replies.
Output ONLY the 3 replies, separated by a pipe character (|). No numbers, no bullet points, no extra text.

Message:
$context
''';
    final result = await _gemini.generateText(prompt);
    // Parse the pipe-separated string into a list
    return result.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Translates text.
  Future<String> translateText(String text, String targetLang) async {
    return await _gemini.translate(text, targetLang);
  }

  /// Generates an image using OpenAI's DALL-E 3 API.
  Future<String?> generateImage(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('openai_api_key') ?? '';
    
    if (apiKey.isEmpty) {
      // Use pollinations.ai for real free AI image generation if no OpenAI key is provided
      final encodedPrompt = Uri.encodeComponent(prompt);
      // Adding a random seed prevents caching issues if the exact same prompt is sent
      final seed = DateTime.now().millisecondsSinceEpoch.toString();
      return 'https://image.pollinations.ai/prompt/$encodedPrompt?width=1024&height=1024&nologo=true&seed=$seed';
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'dall-e-3',
          'prompt': prompt,
          'n': 1,
          'size': '1024x1024',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'][0]['url'];
      } else {
        print('DALL-E Error: \${response.body}');
        return null;
      }
    } catch (e) {
      print('DALL-E Exception: \$e');
      return null;
    }
  }

  /// Generates a sticker using OpenAI's DALL-E 3 API (optimized prompt).
  Future<String?> generateSticker(String prompt) async {
    final stickerPrompt = "A flat vector illustration sticker of \$prompt. Clean white background, thick white borders around the subject, cute and expressive style, highly detailed, sticker art.";
    return await generateImage(stickerPrompt);
  }
}
