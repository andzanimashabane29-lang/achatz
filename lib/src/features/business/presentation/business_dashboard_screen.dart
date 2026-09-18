import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/features/profile/presentation/catalog_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/payment_integration_screen.dart';
import 'package:a_chatz/src/features/profile/presentation/profile_screen.dart';

class BusinessDashboardScreen extends ConsumerStatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  ConsumerState<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends ConsumerState<BusinessDashboardScreen> {
  int catalogViews = 0;
  int profileClicks = 0;
  int activeChats = 0;
  bool isLoading = true;
  bool autoResponderEnabled = false;
  String autoResponderMessage = "Hi, we are currently away. We will get back to you soon!";

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final uid = ref.read(authRepositoryProvider).uid;
    if (uid == null) return;

    try {
      final doc = await AppDatabase.instance.table('business_analytics').doc(uid).get();
      final userDoc = await AppDatabase.instance.table('users').doc(uid).get();

      if (mounted) {
        setState(() {
          if (doc.exists) {
            final data = doc.data()!;
            catalogViews = data['catalogViews'] ?? 0;
            profileClicks = data['profileClicks'] ?? 0;
            activeChats = data['activeChats'] ?? 0;
          }
          if (userDoc.exists) {
            final uData = userDoc.data()!;
            autoResponderEnabled = uData['autoResponderEnabled'] ?? false;
            autoResponderMessage = uData['autoResponderMessage'] ?? autoResponderMessage;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleAutoResponder(bool value) async {
    final uid = ref.read(authRepositoryProvider).uid;
    if (uid == null) return;

    setState(() => autoResponderEnabled = value);
    await AppDatabase.instance.table('users').doc(uid).set({
      'autoResponderEnabled': value,
    }, SetOptions(merge: true));

    if (value && mounted) {
      _showAutoResponderConfigDialog();
    }
  }

  void _showAutoResponderConfigDialog() {
    final uid = ref.read(authRepositoryProvider).uid;
    final controller = TextEditingController(text: autoResponderMessage);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Away Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter your auto-reply message',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final newMsg = controller.text.trim();
              if (newMsg.isNotEmpty && uid != null) {
                await AppDatabase.instance.table('users').doc(uid).set({
                  'autoResponderMessage': newMsg,
                }, SetOptions(merge: true));
                if (mounted) setState(() => autoResponderMessage = newMsg);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'A-Chatz Business Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analytics Overview',
                    style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('Catalog Views', catalogViews.toString(), Icons.shopping_bag, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen())))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildMetricCard('Profile Clicks', profileClicks.toString(), Icons.touch_app, onTap: () => context.go('/profile'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard('Active Chats', activeChats.toString(), Icons.chat, isFullWidth: true, onTap: () => context.go('/home')),
                  
                  const SizedBox(height: 32),
                  const Text(
                    'Quick Tools',
                    style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: SwitchListTile(
                      value: autoResponderEnabled,
                      onChanged: _toggleAutoResponder,
                      activeColor: Colors.redAccent,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.reply_all, color: Colors.redAccent, size: 20),
                      ),
                      title: const Text('Auto-Responder (Away Message)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Automatically reply when you are away', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ),
                  _buildToolTile(
                    'CRM Labels',
                    'Manage your chat labels and categories',
                    Icons.label,
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Swipe on any chat to add a CRM label!')),
                      );
                    },
                  ),
                  _buildToolTile(
                    'Payment Integration',
                    'Manage Stripe/Paystack API Keys',
                    Icons.payment,
                    () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentIntegrationScreen()));
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, {bool isFullWidth = false, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white54, size: 24),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.redAccent, size: 20),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}
