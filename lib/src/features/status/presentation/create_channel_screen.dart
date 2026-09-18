import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:a_chatz/src/features/status/providers/status_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateChannelScreen extends ConsumerStatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  ConsumerState<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends ConsumerState<CreateChannelScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  File? _profileImage;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _profileImage = File(result.files.single.path!);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(channelRepositoryProvider).createChannel(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            photoFile: _profileImage,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create channel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('New Channel', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? const Icon(Icons.add_a_photo, color: Colors.white54, size: 40)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Channel Name', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter channel name',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Description', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe what your channel is about',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Create Channel', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
