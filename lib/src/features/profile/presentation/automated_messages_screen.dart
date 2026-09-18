import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

class AutomatedMessagesScreen extends StatefulWidget {
  const AutomatedMessagesScreen({super.key});

  @override
  State<AutomatedMessagesScreen> createState() => _AutomatedMessagesScreenState();
}

class _AutomatedMessagesScreenState extends State<AutomatedMessagesScreen> {
  final _greetingController = TextEditingController();
  final _awayController = TextEditingController();
  
  bool _greetingEnabled = false;
  bool _awayEnabled = false;
  bool _loading = true;
  bool _saving = false;

  User? get user => AppAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (user == null) return;
    try {
      final doc = await AppDatabase.instance.table('users').doc(user!.uid).get();
      final data = doc.data() ?? {};
      
      setState(() {
        _greetingController.text = data['greetingMessage'] ?? 'Hello! Thank you for contacting us. How can we help you today?';
        _awayController.text = data['awayMessage'] ?? 'Thank you for your message. We are currently closed/away, but will respond as soon as we return.';
        _greetingEnabled = data['greetingEnabled'] ?? false;
        _awayEnabled = data['awayEnabled'] ?? false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (user == null || _saving) return;
    setState(() => _saving = true);
    
    try {
      await AppDatabase.instance.table('users').doc(user!.uid).set({
        'greetingMessage': _greetingController.text.trim(),
        'awayMessage': _awayController.text.trim(),
        'greetingEnabled': _greetingEnabled,
        'awayEnabled': _awayEnabled,
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Automated messages saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving messages: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Automated Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Greet Customers & Auto-Reply',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Greeting message section
              _buildSectionHeader('Greeting Message'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _greetingEnabled,
                      activeColor: Colors.red,
                      title: const Text('Send greeting message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                        'Greet customers when they message you the first time or after 24 hours of inactivity.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      onChanged: (val) {
                        setState(() => _greetingEnabled = val);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_greetingEnabled) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _greetingController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type greeting message...',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF121212),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Away message section
              _buildSectionHeader('Away Message'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _awayEnabled,
                      activeColor: Colors.red,
                      title: const Text('Send away message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: const Text(
                        'Automatically reply to messages when you are closed or away.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      onChanged: (val) {
                        setState(() => _awayEnabled = val);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_awayEnabled) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _awayController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type away message...',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF121212),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _saveSettings,
                child: _saving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFFA7A7A7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
