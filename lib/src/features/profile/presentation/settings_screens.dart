import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/ambient_background.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:a_chatz/src/shared/widgets/app_tutorial_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/features/profile/presentation/storage_manager_screen.dart';
import 'package:a_chatz/src/shared/widgets/passcode_lock_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/legal_documents.dart';
import 'package:a_chatz/src/features/profile/presentation/help_center_screens.dart';
import 'package:a_chatz/src/shared/widgets/theme_picker_sheet.dart';
import 'package:a_chatz/src/core/theme/theme_provider.dart';
import 'package:a_chatz/src/core/theme/app_theme_preset.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';

class SettingsChatsScreen extends ConsumerStatefulWidget {
  const SettingsChatsScreen({super.key});

  @override
  ConsumerState<SettingsChatsScreen> createState() => _SettingsChatsScreenState();
}

class _SettingsChatsScreenState extends ConsumerState<SettingsChatsScreen> {
  String? _wallpaperPath;
  bool _enterIsSend = false;
  bool _mediaVisibility = true;
  ChatThemePreset _defaultChatTheme = ChatThemePreset.none;

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wallpaperPath = prefs.getString('chat_wallpaper_path');
      _enterIsSend = prefs.getBool('enter_is_send') ?? false;
      _mediaVisibility = prefs.getBool('media_visibility') ?? true;
      _defaultChatTheme = ChatThemePreset.values[prefs.getInt('ambient_theme_preset_default') ?? 0];
    });
  }

  Future<void> _saveDefaultChatTheme(ChatThemePreset theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ambient_theme_preset_default', theme.index);
    if (mounted) {
      setState(() {
        _defaultChatTheme = theme;
      });
    }
  }

  String _chatThemeLabel(ChatThemePreset preset) {
    switch (preset) {
      case ChatThemePreset.neonEclipse:
        return 'Neon Eclipse';
      case ChatThemePreset.auroraBorealis:
        return 'Aurora';
      case ChatThemePreset.cyberpunkAmber:
        return 'Cyberpunk';
      case ChatThemePreset.obsidianOled:
        return 'Obsidian OLED';
      case ChatThemePreset.cyberpunkNeon:
        return 'Cyberpunk Neon';
      case ChatThemePreset.none:
      default:
        return 'Default Dark';
    }
  }

  Future<void> _showChatThemeSelector() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101012),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF303030),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Chat theme',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a theme that applies only inside chat rooms.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildThemeTile(ChatThemePreset.none, 'Default Dark', [const Color(0xFF101012), const Color(0xFF1C1C1E)]),
                      _buildThemeTile(ChatThemePreset.neonEclipse, 'Neon Eclipse', [const Color(0xFF8A2387), const Color(0xFFE94057)]),
                      _buildThemeTile(ChatThemePreset.auroraBorealis, 'Aurora', [const Color(0xFF00B4DB), const Color(0xFF00FF87)]),
                      _buildThemeTile(ChatThemePreset.cyberpunkAmber, 'Cyberpunk', [const Color(0xFFFF416C), const Color(0xFFFFB300)]),
                      _buildThemeTile(ChatThemePreset.obsidianOled, 'Obsidian OLED', [const Color(0xFF00FF66), const Color(0xFF001A09)]),
                      _buildThemeTile(ChatThemePreset.cyberpunkNeon, 'Cyberpunk Neon', [const Color(0xFFFF007F), const Color(0xFF7F00FF)]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeTile(ChatThemePreset preset, String name, List<Color> colors) {
    final isSelected = _defaultChatTheme == preset;
    return GestureDetector(
      onTap: () {
        _saveDefaultChatTheme(preset);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.greenAccent : const Color(0xFF2C2C2E),
            width: isSelected ? 2.5 : 1.5,
          ),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 4,
                    )
                  ],
                ),
              ),
            ),
            if (isSelected)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
              ),
          ],
        ),
      ),
    );
  }


  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_wallpaper_path', picked.path);
      setState(() {
        _wallpaperPath = picked.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallpaper updated!')));
      }
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
          title: const Text('Chats'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('App Theme'),
              subtitle: Text(ref.watch(themeProvider).preset.label),
              onTap: () => showThemePickerSheet(context, ref),
            ),
            const Divider(color: Color(0xFF2C2C2C)),
            ListTile(
              leading: const Icon(Icons.wallpaper),
              title: const Text('Wallpaper'),
              subtitle: Row(
                children: [
                  const Text('Custom Image '),
                  if (_wallpaperPath != null)
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _wallpaperPath!.startsWith('assets/')
                          ? Image.asset(_wallpaperPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black))
                          : Image.file(File(_wallpaperPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black)),
                    ),
                ],
              ),
              onTap: _pickImage,
              trailing: _wallpaperPath != null
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('chat_wallpaper_path');
                        setState(() {
                          _wallpaperPath = null;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallpaper removed')));
                        }
                      },
                    )
                  : null,
            ),
            const Divider(color: Color(0xFF2C2C2C)),
            SwitchListTile(
              title: const Text('Enter is send'),
              subtitle: const Text('Enter key will send your message'),
              value: _enterIsSend,
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('enter_is_send', val);
                setState(() {
                  _enterIsSend = val;
                });
              },
              activeColor: Colors.red,
            ),
            SwitchListTile(
              title: const Text('Media visibility'),
              subtitle: const Text('Show newly downloaded media in your device\'s gallery'),
              value: _mediaVisibility,
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('media_visibility', val);
                setState(() => _mediaVisibility = val);
              },
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsNotificationsScreen extends StatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  State<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends State<SettingsNotificationsScreen> {
  bool _appNotifications = true;
  bool _groupNotifications = true;
  bool _dmNotifications = true;
  bool _statusNotifications = true;
  bool _callNotifications = true;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await AppDatabase.instance.table('users').doc(uid).get();
      final data = doc.data() ?? {};
      final settings = data['notificationSettings'] as Map<String, dynamic>? ?? {};
      
      setState(() {
        _appNotifications = settings['app'] ?? true;
        _groupNotifications = settings['group'] ?? true;
        _dmNotifications = settings['dm'] ?? true;
        _statusNotifications = settings['status'] ?? true;
        _callNotifications = settings['calls'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await AppDatabase.instance.table('users').doc(uid).set({
      'notificationSettings': {
        key: value,
      }
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Notifications'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('All App Notifications'),
              subtitle: const Text('Master switch for all push notifications'),
              value: _appNotifications,
              onChanged: (val) {
                setState(() => _appNotifications = val);
                _updateSetting('app', val);
              },
              activeColor: Colors.red,
            ),
            const Divider(color: Color(0xFF2C2C2C)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Messages', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
              title: const Text('Direct Messages'),
              subtitle: const Text('Get notified when someone messages you directly'),
              value: _dmNotifications,
              onChanged: _appNotifications ? (val) {
                setState(() => _dmNotifications = val);
                _updateSetting('dm', val);
              } : null,
              activeColor: Colors.red,
            ),
            SwitchListTile(
              title: const Text('Group Messages'),
              subtitle: const Text('Get notified for new messages in groups'),
              value: _groupNotifications,
              onChanged: _appNotifications ? (val) {
                setState(() => _groupNotifications = val);
                _updateSetting('group', val);
              } : null,
              activeColor: Colors.red,
            ),
            const Divider(color: Color(0xFF2C2C2C)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Status & Activity', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
              title: const Text('Status Updates & Reactions'),
              subtitle: const Text('Get notified when someone reacts to your status'),
              value: _statusNotifications,
              onChanged: _appNotifications ? (val) {
                setState(() => _statusNotifications = val);
                _updateSetting('status', val);
              } : null,
              activeColor: Colors.red,
            ),
            const Divider(color: Color(0xFF2C2C2C)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Calls', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
              title: const Text('Incoming Calls'),
              subtitle: const Text('Ring for incoming voice and video calls'),
              value: _callNotifications,
              onChanged: _appNotifications ? (val) {
                setState(() => _callNotifications = val);
                _updateSetting('calls', val);
              } : null,
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsLanguageScreen extends StatelessWidget {
  const SettingsLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale.languageCode;

    void setLocale(String lang) async {
      await context.setLocale(Locale(lang));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('language_updated'.tr())));
      }
    }

    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('app_language'.tr()),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RadioListTile<String>(
              value: 'en',
              groupValue: currentLocale,
              onChanged: (val) => setLocale(val!),
              title: const Text('English (device\'s language)'),
              activeColor: Colors.red,
            ),
            RadioListTile<String>(
              value: 'es',
              groupValue: currentLocale,
              onChanged: (val) => setLocale(val!),
              title: const Text('Español'),
              activeColor: Colors.red,
            ),
            RadioListTile<String>(
              value: 'zu',
              groupValue: currentLocale,
              onChanged: (val) => setLocale(val!),
              title: const Text('isiZulu'),
              activeColor: Colors.red,
            ),
            RadioListTile<String>(
              value: 'xh',
              groupValue: currentLocale,
              onChanged: (val) => setLocale(val!),
              title: const Text('isiXhosa'),
              activeColor: Colors.red,
            ),
            RadioListTile<String>(
              value: 'af',
              groupValue: currentLocale,
              onChanged: (val) => setLocale(val!),
              title: const Text('Afrikaans'),
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsStorageScreen extends StatefulWidget {
  const SettingsStorageScreen({super.key});

  @override
  State<SettingsStorageScreen> createState() => _SettingsStorageScreenState();
}

class _SettingsStorageScreenState extends State<SettingsStorageScreen> {
  String _mobileDataDownload = 'Photos';
  String _wifiDownload = 'All media';

  final _downloadOptions = ['No media', 'Photos', 'Audio', 'Photos & Audio', 'All media'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mobileDataDownload = prefs.getString('mobile_data_download') ?? 'Photos';
      _wifiDownload = prefs.getString('wifi_download') ?? 'All media';
    });
  }

  void _showDownloadPicker(String title, String current, Function(String) onChanged) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _downloadOptions.map((opt) {
            return RadioListTile<String>(
              title: Text(opt, style: const TextStyle(color: Colors.white)),
              value: opt,
              groupValue: current,
              onChanged: (val) {
                onChanged(val!);
                Navigator.pop(ctx);
              },
              activeColor: Colors.red,
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Storage and Data'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Manage storage'),
              subtitle: const Text('Tap to see storage usage'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsStorageManagerScreen()),
                );
              },
            ),
            const Divider(color: Color(0xFF2C2C2C)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Media auto-download', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              title: const Text('When using mobile data'),
              subtitle: Text(_mobileDataDownload),
              onTap: () => _showDownloadPicker('Mobile Data', _mobileDataDownload, (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('mobile_data_download', val);
                setState(() => _mobileDataDownload = val);
              }),
            ),
            ListTile(
              title: const Text('When connected on Wi-Fi'),
              subtitle: Text(_wifiDownload),
              onTap: () => _showDownloadPicker('Wi-Fi', _wifiDownload, (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('wifi_download', val);
                setState(() => _wifiDownload = val);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsHelpScreen extends StatelessWidget {
  const SettingsHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Help'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.school_outlined, color: Color(0xFF00FFB2)),
              title: const Text('App tutorial'),
              subtitle: const Text('Full guide to every main button'),
              onTap: () async {
                await showAppTutorialDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_center_outlined),
              title: const Text('Help Center'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail_outlined),
              title: const Text('Contact Us'),
              subtitle: const Text('Questions? Need help?'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Legal & About'),
              subtitle: const Text(
                'Privacy, terms, liability, guidelines',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalDocumentsHubScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xEE1E1E1E),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.redAccent,
                            child: Icon(Icons.info_outline, color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'A-Chatz',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Version 1.0.0',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'A premium messaging platform by Drixel Labs Inc.\n\n'
                            '© 2026 Drixel Labs Incorporation. All rights reserved.\n\n'
                            'See Help → Legal & policies for Terms, Privacy, and Liability.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsBlockedContactsScreen extends ConsumerWidget {
  const SettingsBlockedContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = AppAuth.instance.currentUser?.uid;

    if (currentUid == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Blocked Contacts'),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: AppDatabase.instance.table('users').doc(currentUid).table('blocked').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.red));
            
            final blockedDocs = snapshot.data!.docs;
            if (blockedDocs.isEmpty) {
              return const Center(child: Text('No blocked contacts', style: TextStyle(color: Colors.white54)));
            }

            return ListView.builder(
              itemCount: blockedDocs.length,
              itemBuilder: (context, index) {
                final blockedUserId = blockedDocs[index].id;
                
                return FutureBuilder<DocumentSnapshot>(
                  future: AppDatabase.instance.table('users').doc(blockedUserId).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) return const SizedBox.shrink();
                    
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    final username = userData?['username'] ?? 'Unknown User';
                    final photoUrl = userData?['photoUrl'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(username, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(blockedUserId, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () async {
                          await AppDatabase.instance.table('users').doc(currentUid).table('blocked').doc(blockedUserId).delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$username unblocked')));
                          }
                        },
                        child: const Text('Unblock', style: TextStyle(color: Colors.red)),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
class SettingsAccountScreen extends ConsumerStatefulWidget {
  const SettingsAccountScreen({super.key});

  @override
  ConsumerState<SettingsAccountScreen> createState() => _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends ConsumerState<SettingsAccountScreen> {
  final _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    _keyController.text = prefs.getString('gemini_api_key') ?? '';
  }

  Future<void> _saveKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', _keyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API Key saved!')));
    }
  }

  Future<void> _linkDrixelId() async {
    try {
      final launched = await ref
          .read(authRepositoryProvider)
          .linkDrixelId();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'Complete sign-in in the browser to link Drixel ID to this account.'
                : 'Could not open Drixel ID linking.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not link Drixel ID: $e')),
      );
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Change Account Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'New Email Address',
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    final newEmail = emailController.text.trim();
                    final password = passwordController.text.trim();
                    if (newEmail.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in both fields.')),
                      );
                      return;
                    }
                    try {
                      final user = AppAuth.instance.currentUser;
                      if (user == null) return;
                      
                      // Reauthenticate first
                      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
                      await user.reauthenticateWithCredential(cred);
                      
                      // Update email in firebase auth
                      await user.verifyBeforeUpdateEmail(newEmail);
                      
                      // Update email in database
                      await AppDatabase.instance.table('users').doc(user.uid).update({'email': newEmail});
                      
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification link sent to new email! Please verify before next login.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Verify & Update', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Delete Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WARNING: This action is permanent and cannot be undone. All your profile data, chats, and files will be permanently deleted.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter Password to Confirm',
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () async {
                    final password = passwordController.text.trim();
                    if (password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter your password to confirm.')),
                      );
                      return;
                    }
                    try {
                      final user = AppAuth.instance.currentUser;
                      if (user == null) return;

                      // Reauthenticate
                      final cred = EmailAuthProvider.credential(email: user.email!, password: password);
                      await user.reauthenticateWithCredential(cred);

                      // Delete Firestore user document
                      await AppDatabase.instance.table('users').doc(user.uid).delete();

                      // Delete authenticated user
                      await user.delete();

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        context.go('/onboarding');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Your account has been deleted.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Delete Permanently', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Account')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined, color: Colors.blueAccent),
              title: const Text('A-Chatz AI Assistant'),
              subtitle: const Text('Fully Managed & Active'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blueAccent),
                        SizedBox(width: 10),
                        Text('AI Active & Managed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    content: const Text(
                      'You do not need to configure your own API key! A-Chatz comes pre-loaded with an enterprise API co-pilot subscription, fully managed by Drixel Labs. Enjoy premium assistance, note-taking, and translations built-in.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Got it', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Change Email'),
              onTap: _showChangeEmailDialog,
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, color: Colors.blueAccent),
              title: const Text('Link Drixel ID'),
              subtitle: const Text('Connect your Drixel sign-in to this A-Chatz account'),
              onTap: _linkDrixelId,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete my account', style: TextStyle(color: Colors.red)),
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPrivacyScreen extends ConsumerStatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  ConsumerState<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends ConsumerState<SettingsPrivacyScreen> {
  String lastSeen = 'Everyone';
  String profilePhoto = 'Everyone';
  String about = 'Everyone';
  bool appLock = false;
  bool readReceiptsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await AppDatabase.instance.table('users').doc(uid).get();
    final data = doc.data() ?? {};
    final enabled = data['biometricLockEnabled'] ?? false;
    final passcode = data['appPasscode'] as String?;

    final prefs = await SharedPreferences.getInstance();
    if (enabled && passcode != null) {
      await prefs.setBool('app_lock_enabled', true);
      await prefs.setString('app_passcode', passcode);
    } else {
      await prefs.setBool('app_lock_enabled', false);
      await prefs.remove('app_passcode');
    }

    setState(() {
      lastSeen = data['lastSeenVisibility'] ?? 'Everyone';
      profilePhoto = data['profilePhotoVisibility'] ?? 'Everyone';
      about = data['aboutVisibility'] ?? 'Everyone';
      appLock = enabled;
      readReceiptsEnabled = data['readReceiptsEnabled'] ?? true;
    });
  }

  Future<void> _toggleAppLock(bool enabled) async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();

    if (enabled) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PasscodeLockScreen(
            isSetupMode: true,
            onPasscodeSet: (passcode) async {
              await AppDatabase.instance.table('users').doc(uid).update({
                'biometricLockEnabled': true,
                'appPasscode': passcode,
              });
              await prefs.setBool('app_lock_enabled', true);
              await prefs.setString('app_passcode', passcode);

              setState(() {
                appLock = true;
              });

              if (mounted) {
                Navigator.pop(context); // close passcode setup screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App Lock passcode enabled!')),
                );
              }
            },
          ),
        ),
      );
    } else {
      await AppDatabase.instance.table('users').doc(uid).update({
        'biometricLockEnabled': false,
        'appPasscode': FieldValue.delete(),
      });
      await prefs.setBool('app_lock_enabled', false);
      await prefs.remove('app_passcode');

      setState(() {
        appLock = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App Lock disabled.')),
        );
      }
    }
  }

  Future<void> _updatePrivacy(String field, String value) async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await AppDatabase.instance.table('users').doc(uid).update({field: value});
    _loadPrivacySettings();
  }

  void _showVisibilityPicker(String title, String current, String field) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ['Everyone', 'My contacts', 'Nobody'].map((val) {
          return RadioListTile<String>(
            title: Text(val, style: const TextStyle(color: Colors.white)),
            value: val,
            groupValue: current,
            onChanged: (newVal) {
              _updatePrivacy(field, newVal!);
              Navigator.pop(ctx);
            },
            activeColor: Colors.greenAccent,
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Privacy')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: const Text('Last seen and online'),
              subtitle: Text(lastSeen),
              onTap: () => _showVisibilityPicker('Last seen and online', lastSeen, 'lastSeenVisibility'),
            ),
            ListTile(
              title: const Text('Profile photo'),
              subtitle: Text(profilePhoto),
              onTap: () => _showVisibilityPicker('Profile photo', profilePhoto, 'profilePhotoVisibility'),
            ),
            ListTile(
              title: const Text('About'),
              subtitle: Text(about),
              onTap: () => _showVisibilityPicker('About', about, 'aboutVisibility'),
            ),
            SwitchListTile(
              title: const Text('Read receipts'),
              subtitle: const Text('If turned off, you won\'t send or receive Read receipts. Read receipts are always sent for group chats.'),
              value: readReceiptsEnabled,
              onChanged: (val) async {
                final uid = AppAuth.instance.currentUser?.uid;
                if (uid == null) return;
                await AppDatabase.instance.table('users').doc(uid).update({
                  'readReceiptsEnabled': val,
                });
                _loadPrivacySettings();
              },
              activeColor: Colors.greenAccent,
            ),
            const Divider(color: Color(0xFF2C2C2C)),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Blocked contacts'),
              onTap: () => context.push('/settings-blocked'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: const Text('App passcode lock'),
              subtitle: const Text('Lock the app with a secure 4-digit code'),
              value: appLock,
              onChanged: _toggleAppLock,
              activeColor: Colors.greenAccent,
            ),
            if (appLock)
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Colors.greenAccent),
                title: const Text('Change passcode'),
                subtitle: const Text('Choose a new 4-digit security code'),
                onTap: () => _toggleAppLock(true),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsAccessibilityScreen extends ConsumerWidget {
  const SettingsAccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);

    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Accessibility')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('High Contrast'),
              subtitle: const Text('Increase contrast for better readability'),
              value: settings.highContrast,
              onChanged: (val) {
                ref.read(accessibilityProvider.notifier).setHighContrast(val);
              },
              activeColor: Colors.greenAccent,
            ),
            SwitchListTile(
              title: const Text('Reduce Animations'),
              subtitle: const Text('Minimize motion effects across the app'),
              value: settings.reduceAnimations,
              onChanged: (val) {
                ref.read(accessibilityProvider.notifier).setReduceAnimations(val);
              },
              activeColor: Colors.greenAccent,
            ),
          ],
        ),
      ),
    );
  }
}

class AvatarSelectionScreen extends StatelessWidget {
  const AvatarSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Choose Avatar')),
        body: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            return CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.face, size: 40, color: Colors.accents[index % Colors.accents.length]),
            );
          },
        ),
      ),
    );
  }
}
