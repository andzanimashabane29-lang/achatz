import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:a_chatz/src/core/services/ai_tools_service.dart';

class AIAvatarCreatorScreen extends StatefulWidget {
  const AIAvatarCreatorScreen({super.key});

  @override
  State<AIAvatarCreatorScreen> createState() => _AIAvatarCreatorScreenState();
}

class _AIAvatarCreatorScreenState extends State<AIAvatarCreatorScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _loading = false;
  String? _generatedUrl;
  String? _error;

  Future<void> _generateAvatar() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _generatedUrl = null;
    });

    try {
      final url = await AIToolsService.instance.generateImage(prompt);
      if (url != null) {
        setState(() {
          _generatedUrl = url;
        });
      } else {
        setState(() {
          _error = "Failed to generate image. Please check your OpenAI API Key.";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveAsProfilePicture() async {
    if (_generatedUrl == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final uid = AppAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not authenticated");

      // 1. Download image to temporary file
      final response = await http.get(Uri.parse(_generatedUrl!));
      final documentDirectory = await getTemporaryDirectory();
      final file = File('${documentDirectory.path}/avatar_$uid.jpg');
      await file.writeAsBytes(response.bodyBytes);

      // 2. Upload to Supabase Storage
      final storageRef = AppStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // 3. Update Firestore
      await AppDatabase.instance
          .table('users')
          .doc(uid)
          .update({'photoUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile picture: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('AI Avatar Generator', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: _loading 
                      ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                      : _generatedUrl != null
                          ? Image.network(_generatedUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.person, size: 80, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Prompt Input
            TextField(
              controller: _promptController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Describe your avatar...',
                labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                hintText: 'e.g., A futuristic cyberpunk warrior, neon lighting, highly detailed',
                hintStyle: const TextStyle(color: Color(0x3DFFFFFF)),
                filled: true,
                fillColor: const Color(0xFF1E1E22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.purpleAccent.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              const SizedBox(height: 16),
            ],

            // Generate Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _generateAvatar,
              child: const Text('Generate Avatar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 12),

            // Save Profile Pic Button
            if (_generatedUrl != null)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: const BorderSide(color: Colors.greenAccent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _saveAsProfilePicture,
                child: const Text('Set as Profile Picture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}
