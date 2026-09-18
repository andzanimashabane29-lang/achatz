import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:a_chatz/src/features/status/domain/status_models.dart';

class CreateAdvertisementScreen extends ConsumerStatefulWidget {
  const CreateAdvertisementScreen({super.key});

  @override
  ConsumerState<CreateAdvertisementScreen> createState() => _CreateAdvertisementScreenState();
}

class _CreateAdvertisementScreenState extends ConsumerState<CreateAdvertisementScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _publishAd() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add an image or text for your ad.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedImage != null) {
        await ref.read(statusRepositoryProvider).uploadStatus(
          file: _selectedImage!,
          type: StatusType.image,
          caption: caption.isEmpty ? null : caption,
          isPromoted: true,
        );
      } else {
        await ref.read(statusRepositoryProvider).uploadTextStatus(
          text: caption,
          bgColor: Colors.redAccent.value,
          isPromoted: true,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Advertisement published successfully!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to publish ad: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Create Advertisement'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.campaign, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Reach all potential customers',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create an ad to be seen by everyone on A-Chatz. Ads appear at the very top of all users\' Status screens.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                  image: _selectedImage != null
                      ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                      : null,
                ),
                child: _selectedImage == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: Colors.white54, size: 40),
                          SizedBox(height: 8),
                          Text('Tap to select an image (Optional)', style: TextStyle(color: Colors.white54)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _captionController,
              maxLines: 4,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a catchy caption or promotion...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black45,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _publishAd,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Publish Ad (Free Trial)',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
