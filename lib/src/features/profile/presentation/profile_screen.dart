import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:a_chatz/src/features/auth/presentation/login_screen.dart' as a_chatz_login;

import 'package:a_chatz/src/features/profile/presentation/help_center_screens.dart';

import 'package:a_chatz/src/features/profile/presentation/settings_screens.dart';
import 'package:a_chatz/src/features/safety/presentation/safety_dashboard_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/ai_avatar_creator_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/quick_replies_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/catalog_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/wallpaper_picker_screen.dart';
import 'package:a_chatz/src/features/moderation/presentation/moderation_dashboard_screen.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:a_chatz/src/core/services/linked_accounts_manager.dart';
import 'package:a_chatz/src/features/profile/presentation/linked_accounts_dialogs.dart';
import 'package:a_chatz/src/features/profile/presentation/verification_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/accident_prevention_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/automated_messages_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/business_hours_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/payment_integration_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:a_chatz/src/features/business/presentation/business_dashboard_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final usernameController = TextEditingController();
  final bioController = TextEditingController();
  final statusController = TextEditingController();
  final businessAddressController = TextEditingController();
  final businessWebsiteController = TextEditingController();
  final businessCategoryController = TextEditingController();

  List<LinkedAccount> _linkedAccounts = [];

  bool loading = true;
  bool saving = false;
  bool readReceipts = true;

  String? photoUrl;
  String accountType = 'personal';
  String role = 'user';

  XFile? selectedImage;

  User? get user => AppAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final doc = await AppDatabase.instance
          .table('users')
          .doc(user!.uid)
          .get();

      final data = doc.data();

      usernameController.text = data?['username'] ?? '';
      bioController.text = data?['bio'] ?? '';
      statusController.text = data?['status'] ?? 'Available';
      readReceipts = data?['readReceiptsEnabled'] ?? true;
      accountType = data?['accountType'] ?? 'personal';
      role = data?['role'] ?? 'user';
      businessAddressController.text = data?['businessAddress'] ?? '';
      businessWebsiteController.text = data?['businessWebsite'] ?? '';
      businessCategoryController.text = data?['businessCategory'] ?? '';

      photoUrl = data?['photoUrl'];

      final accounts = await LinkedAccountsManager.getLinkedAccounts();

      setState(() {
        _linkedAccounts = accounts;
        loading = false;
      });
    } catch (e) {
      final accounts = await LinkedAccountsManager.getLinkedAccounts();
      setState(() {
        _linkedAccounts = accounts;
        loading = false;
      });
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (picked == null) return;

    setState(() {
      selectedImage = picked;
    });
  }

  Future<void> _showQuickRepliesDialog() async {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickRepliesScreen()));
  }

  Future<void> saveProfile() async {
    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      String? uploadedPhotoUrl = photoUrl;

      if (selectedImage != null) {
        final storageRef = AppStorage.instance
            .ref()
            .child('users')
            .child(user!.uid)
            .child('avatars')
            .child('avatar.jpg');

        final UploadTask uploadTask;
        if (kIsWeb) {
          final bytes = await selectedImage!.readAsBytes();
          uploadTask = storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          uploadTask = storageRef.putFile(
            File(selectedImage!.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }
        await uploadTask;

        uploadedPhotoUrl = await storageRef.getDownloadURL();
      }

      await AppDatabase.instance
          .table('users')
          .doc(user!.uid)
          .set({
        'username': usernameController.text.trim(),
        'bio': bioController.text.trim(),
        'status': statusController.text.trim(),
        'readReceiptsEnabled': readReceipts,
        'accountType': accountType,
        'businessAddress': businessAddressController.text.trim(),
        'businessWebsite': businessWebsiteController.text.trim(),
        'businessCategory': businessCategoryController.text.trim(),
        'email': user?.email,
        'photoUrl': uploadedPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        photoUrl = uploadedPhotoUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save profile: $e'),
          ),
        );
      }
    }

    setState(() {
      saving = false;
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    bioController.dispose();
    statusController.dispose();
    businessAddressController.dispose();
    businessWebsiteController.dispose();
    businessCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFFA7A7A7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    return LuxuryScaffold(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (user != null) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text('My QR Code', style: TextStyle(color: Colors.black)),
                              content: SizedBox(
                                width: 250,
                                height: 250,
                                child: QrImageView(
                                  data: 'achatz://user/${user!.uid}',
                                  version: QrVersions.auto,
                                  size: 250.0,
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                              ],
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.qr_code, size: 28),
                    ),
                  ],
                ),
            SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 64,
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                           backgroundImage: selectedImage != null
                              ? (kIsWeb 
                                  ? NetworkImage(selectedImage!.path) as ImageProvider
                                  : FileImage(File(selectedImage!.path)) as ImageProvider)
                              : (photoUrl != null
                                  ? NetworkImage(photoUrl!) as ImageProvider
                                  : null),
                          child: selectedImage == null && photoUrl == null
                              ? Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), size: 64)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                              builder: (ctx) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.onSurface),
                                    title: Text('Choose from Gallery', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                    onTap: () { Navigator.pop(ctx); pickImage(); },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.face, color: Theme.of(context).colorScheme.onSurface),
                                    title: Text('Choose Avatar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                    onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AvatarSelectionScreen())); },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                                    title: Text('Generate AI Avatar (DALL-E)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const AIAvatarCreatorScreen()),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.onSurface, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),

            _buildSectionHeader('Linked Accounts (${_linkedAccounts.length}/6)'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Switch Accounts Instantly",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Tap to switch, long-press to unlink.",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 11),
                  ),
                  SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _linkedAccounts.length,
                    separatorBuilder: (_, __) => Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 16),
                    itemBuilder: (context, idx) {
                      final acc = _linkedAccounts[idx];
                      final isCurrent = acc.uid == user?.uid;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          backgroundImage: acc.photoUrl != null && acc.photoUrl!.isNotEmpty
                              ? NetworkImage(acc.photoUrl!)
                              : null,
                          child: acc.photoUrl == null || acc.photoUrl!.isEmpty
                              ? Text(acc.username.substring(0, 1).toUpperCase(),
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        title: Row(
                          children: [
                            Text(acc.username,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                            if (isCurrent) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                                ),
                                child: Text("ACTIVE",
                                    style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(acc.email, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                        trailing: isCurrent
                            ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : IconButton(
                                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), size: 20),
                                onPressed: () async {
                                  await LinkedAccountsManager.removeAccount(acc.uid);
                                  final accounts = await LinkedAccountsManager.getLinkedAccounts();
                                  setState(() {
                                    _linkedAccounts = accounts;
                                  });
                                },
                              ),
                        onTap: isCurrent
                            ? null
                            : () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => Center(
                                    child: Card(
                                      color: Theme.of(context).colorScheme.surfaceVariant,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(color: Colors.redAccent),
                                            SizedBox(height: 16),
                                            Text("Switching profiles...", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                final success = await LinkedAccountsManager.switchAccount(context, acc);
                                if (mounted) {
                                  Navigator.pop(context); // Pop overlay spinner
                                  if (success) {
                                    setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Switched to account: ${acc.username}"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Failed to switch account.")),
                                    );
                                  }
                                }
                              },
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const ShowPairingQrDialog(),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.qr_code, color: Colors.redAccent, size: 18),
                          label: Text("Show QR", style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => UnifiedQrScannerDialog(
                                onSuccess: () async {
                                  final accounts = await LinkedAccountsManager.getLinkedAccounts();
                                  setState(() {
                                    _linkedAccounts = accounts;
                                  });
                                },
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.qr_code_scanner, color: Theme.of(context).colorScheme.onSurface, size: 18),
                          label: Text("Scan QR", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to login screen to add another account
                        Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                title: const Text('Add Account'),
                                leading: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(context, false),
                                ),
                              ),
                              body: const a_chatz_login.LoginScreen(),
                            ),
                          ),
                        ).then((result) async {
                          if (result == true) {
                            // Refresh accounts when returning
                            final accounts = await LinkedAccountsManager.getLinkedAccounts();
                            if (mounted) {
                              setState(() {
                                _linkedAccounts = accounts;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account successfully linked!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("Add Account", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            _buildSectionHeader('Linked Devices'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Active Sessions",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Devices currently logged into this account.",
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 11),
                  ),
                  SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: AppDatabase.instance
                        .table('users')
                        .doc(user?.uid)
                        .table('devices')
                        .orderBy('lastActive', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                      }
                      final devices = snapshot.data!.docs;
                      if (devices.isEmpty) {
                        return const Text("No active devices detected.", style: TextStyle(color: Colors.white54));
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: devices.length,
                        separatorBuilder: (_, __) => Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 16),
                        itemBuilder: (context, idx) {
                          final device = devices[idx];
                          final data = device.data() as Map<String, dynamic>;
                          final deviceName = data['deviceName'] ?? 'Unknown Device';
                          final isWeb = deviceName.toString().toLowerCase().contains('web');
                          final lastActive = data['lastActive'] as Timestamp?;
                          final dateStr = lastActive != null ? DateFormat('MMM d, h:mm a').format(lastActive.toDate()) : 'Recently';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: Colors.redAccent.withOpacity(0.1),
                              child: Icon(
                                isWeb ? Icons.computer : Icons.smartphone,
                                color: Colors.redAccent,
                              ),
                            ),
                            title: Text(deviceName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('Last active: $dateStr', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                              onPressed: () async {
                                await device.reference.delete();
                                if (isWeb && data['sessionId'] != null) {
                                  // Invalidate web session
                                  await AppDatabase.instance.table('qr_logins').doc(data['sessionId']).delete();
                                }
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Device logged out.")));
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),



            _buildSectionHeader('Account Type'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
              ),
              child: ListTile(
                leading: Icon(
                  accountType == 'business' ? Icons.storefront : Icons.person,
                  color: accountType == 'business' ? Colors.red : Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                ),
                title: Text(
                  accountType == 'business' ? 'Business Account' : 'Personal Account',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Account type is set during login',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12),
                ),
              ),
            ),
            if (accountType == 'business') ...[
              _buildSectionHeader('Business Profile'),
              _buildTextField(
                controller: businessCategoryController,
                label: 'Business Category',
                icon: Icons.category_outlined,
              ),
              _buildTextField(
                controller: businessAddressController,
                label: 'Business Address',
                icon: Icons.location_on_outlined,
              ),
              _buildTextField(
                controller: businessWebsiteController,
                label: 'Website',
                icon: Icons.language_outlined,
              ),
            ],
            
            _buildSectionHeader('Monetization & Tools'),
            Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.flash_on, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                      title: Text('Quick Replies', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                      subtitle: Text('Pre-defined message shortcuts', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                      onTap: _showQuickRepliesDialog,
                    ),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                    ListTile(
                      leading: Icon(Icons.storefront, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                      title: Text('Catalog', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                      subtitle: Text('Manage products and pricing', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen()));
                      },
                    ),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                    ListTile(
                      leading: Icon(Icons.payment, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                      title: Text('Payment Integration', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                      subtitle: Text('Link payment gateway APIs', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentIntegrationScreen()));
                      },
                    ),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                    ListTile(
                      leading: Icon(Icons.schedule, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                      title: Text('Business Hours', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                      subtitle: Text('Set working hours & schedule status', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessHoursScreen()));
                      },
                    ),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                    ListTile(
                      leading: Icon(Icons.message_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                      title: Text('Automated Messages', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                      subtitle: Text('Configure greeting & away replies', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AutomatedMessagesScreen()));
                      },
                    ),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.dashboard, color: Colors.blueAccent),
                      title: Text('Business Dashboard', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                      subtitle: Text('Analytics, stats & insights', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()));
                      },
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),
            
            _buildSectionHeader('account_settings'.tr()),
            _buildTextField(
              controller: usernameController,
              label: 'username'.tr(),
              icon: Icons.person_outline,
            ),
            _buildTextField(
              controller: statusController,
              label: 'Status',
              icon: Icons.emoji_emotions_outlined,
            ),
            _buildTextField(
              controller: bioController,
              label: 'Bio',
              icon: Icons.info_outline,
              maxLines: 3,
            ),
            
            _buildSectionHeader('Premium & VIP'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent),
                    title: Text('Verification Center', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('Subscribe to premium verification badge tiers', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const VerificationScreen()));
                    },
                  ),
                ],
              ),
            ),

            _buildSectionHeader('Account'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
              ),
              child: ListTile(
                leading: Icon(Icons.key, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                title: Text('Account Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                subtitle: Text('Security, email, delete account', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsAccountScreen()));
                },
              ),
            ),

            if (role == 'admin' || role == 'official') ...[
              _buildSectionHeader('Administration'),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                  title: Text('Moderation Dashboard',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                  subtitle: Text('Manage reports and user bans',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ModerationDashboardScreen()));
                  },
                ),
              ),
            ],

            if (role == 'admin' || role == 'official') ...[
              SizedBox(height: 16),
              _buildSectionHeader('Admin Center'),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amberAccent.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.amberAccent),
                  title: Text('Admin Dashboard', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                  subtitle: Text('Global moderation & system broadcast', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ModerationDashboardScreen()));
                  },
                ),
              ),
            ],

            SizedBox(height: 16),
            _buildSectionHeader('Safety'),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: ListTile(
                leading: Icon(Icons.emergency_share, color: Colors.redAccent),
                title: Text('Emergency & Safety Mode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                subtitle: Text('Shake to alert, SOS, Arrived Safely', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyDashboardScreen()));
                },
              ),
            ),

            SizedBox(height: 16),
            _buildSectionHeader('Privacy'),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    title: Text('Privacy Settings', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('Last seen, profile photo, read receipts', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPrivacyScreen()));
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.block, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    title: Text('Blocked Contacts', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('Manage blocked users', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      context.push('/settings-blocked');
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),
            _buildSectionHeader('Preferences'),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.wallpaper, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    title: Text('Chats', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('Theme, wallpapers, chat history', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      context.push('/settings-chats');
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    title: Text('Notifications', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('Message, group & call tones', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      context.push('/settings-notifications');
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.data_usage, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    title: Text('Storage and Data', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('Network usage, auto-download', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      context.push('/settings-storage');
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.language, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    title: Text('App Language', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('English (device\'s language)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      context.push('/settings-language');
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.accessibility_new, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    title: Text('Accessibility', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('High contrast, reduced motion', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsAccessibilityScreen()));
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.shield_outlined, color: Colors.blueAccent),
                    title: Text('Accident Prevention Mode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                    subtitle: Text('Driving safety proximity car radar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccidentPreventionScreen()));
                    },
                  ),
                  Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1, indent: 56),
                  ListTile(
                    leading: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    title: const Text('Legal & About'),
                    subtitle: Text('Tutorial, legal docs, terms', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
                    onTap: () {
                      context.push('/settings-help');
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Theme.of(context).colorScheme.onSurface,
                foregroundColor: Theme.of(context).colorScheme.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: saving ? null : saveProfile,
              child: saving
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Theme.of(context).colorScheme.background, strokeWidth: 2),
                    )
                  : Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
            ),
            SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                foregroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                elevation: 0,
              ),
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: Icon(Icons.logout),
              label: Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
      ),
      ),
    );
  }
}