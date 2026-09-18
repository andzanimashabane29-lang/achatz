import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _residenceController = TextEditingController();
  final _businessInfoController = TextEditingController();
  final _handlesController = TextEditingController();
  final _businessTypeController = TextEditingController();
  
  List<XFile> _selectedDocuments = [];
  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _isPending = false;
  bool _isVerified = false;

  User? get user => AppAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    if (user == null) return;
    
    try {
      final userDoc = await AppDatabase.instance.table('users').doc(user!.uid).get();
      if (userDoc.exists && userDoc.data()?['isVerified'] == true) {
        setState(() {
          _isVerified = true;
          _isLoading = false;
        });
        return;
      }

      final requests = await AppDatabase.instance
          .table('verification_requests')
          .where('userId', isEqualTo: user!.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (requests.docs.isNotEmpty) {
        setState(() {
          _isPending = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking verification status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedDocuments = pickedFiles;
      });
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocuments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload pictures of your business'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      List<String> docUrls = [];
      for (var file in _selectedDocuments) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final storageRef = AppStorage.instance.ref().child('verification_docs/${user!.uid}/$fileName');
        final UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          uploadTask = storageRef.putData(bytes);
        } else {
          uploadTask = storageRef.putFile(File(file.path));
        }
        final snapshot = await uploadTask;
        final docUrl = await snapshot.ref.getDownloadURL();
        docUrls.add(docUrl);
      }

      await AppDatabase.instance.table('verification_requests').add({
        'userId': user!.uid,
        'legalName': _legalNameController.text.trim(),
        'businessType': _businessTypeController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'residence': _residenceController.text.trim(),
        'businessInfo': _businessInfoController.text.trim(),
        'handles': _handlesController.text.trim(),
        'documentUrls': docUrls,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isPending = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification request submitted successfully!'),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _businessTypeController.dispose();
    _idNumberController.dispose();
    _residenceController.dispose();
    _businessInfoController.dispose();
    _handlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verification Center',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _isVerified
              ? _buildVerifiedState()
              : _isPending
                  ? _buildPendingState()
                  : _buildSubmissionForm(),
    );
  }

  Widget _buildVerifiedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, color: Colors.blueAccent, size: 80),
          const SizedBox(height: 24),
          const Text(
            'You are Verified!',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Your account has the official blue tick badge.',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty_rounded, color: Colors.blueAccent.withOpacity(0.8), size: 80),
          const SizedBox(height: 24),
          const Text(
            'Verification Pending',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your legal documents have been submitted. An admin will review them shortly. You will receive your blue tick once approved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.verified_outlined, color: Colors.blueAccent, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Request Official Blue Tick',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              'Provide your legal details and a valid document (ID/Passport/Business Registration) to verify your identity.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _legalNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Full Legal Name',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _idNumberController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ID Number / Registration Number',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _residenceController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Residential / Physical Address',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _businessInfoController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Detailed Business Information (What do you do?)',
                alignLabelWithHint: true,
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _handlesController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Social Media Handles (e.g. @achatz)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _businessTypeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Business Category (Optional)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _selectedDocuments.isNotEmpty ? Icons.collections_rounded : Icons.add_photo_alternate_rounded,
                    color: _selectedDocuments.isNotEmpty ? Colors.greenAccent : Colors.white54,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedDocuments.isNotEmpty ? '${_selectedDocuments.length} Images Selected' : 'Select images of your business',
                    style: TextStyle(color: _selectedDocuments.isNotEmpty ? Colors.white : Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickDocument,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Select Multiple Images'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            _isSubmitting
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : FilledButton(
                    onPressed: _submitVerification,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
          ],
        ),
      ),
    );
  }
}

