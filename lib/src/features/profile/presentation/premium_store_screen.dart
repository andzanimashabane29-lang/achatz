import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:a_chatz/src/shared/widgets/premium_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PremiumStoreScreen extends StatefulWidget {
  const PremiumStoreScreen({super.key});

  @override
  State<PremiumStoreScreen> createState() => _PremiumStoreScreenState();
}

class _PremiumStoreScreenState extends State<PremiumStoreScreen> {
  final User? user = AppAuth.instance.currentUser;
  String _activeBorder = 'none';
  bool _loading = true;

  final List<Map<String, dynamic>> _borders = [
    {
      'id': 'none',
      'name': 'Default Classic',
      'price': 'Free',
      'description': 'Simple, elegant layout with no animated boundary.',
      'color': Colors.grey,
    },
    {
      'id': 'neon_rainbow',
      'name': 'Neon Rainbow',
      'price': '\$2.99',
      'description': 'A vibrant, rotating spectrum of neon colors representing diverse creativity.',
      'color': Colors.redAccent,
    },
    {
      'id': 'pulsing_gold',
      'name': 'Pulsing Gold',
      'price': '\$4.99',
      'description': 'Rich gold halo that breathes and expands, showcasing luxury presence.',
      'color': Colors.amber,
    },
    {
      'id': 'cyberpunk',
      'name': 'Cyberpunk Glitch',
      'price': '\$3.99',
      'description': 'Flickering high-contrast cyan and magenta rotating layout for power users.',
      'color': Colors.cyanAccent,
    },
    {
      'id': 'electric_blue',
      'name': 'Electric Blue',
      'price': '\$3.49',
      'description': 'Shimmering lightning-charged metallic blue rotating border.',
      'color': Colors.blueAccent,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadActiveBorder();
  }

  Future<void> _loadActiveBorder() async {
    if (user == null) return;
    try {
      final doc = await AppDatabase.instance.table('users').doc(user!.uid).get();
      if (mounted) {
        setState(() {
          _activeBorder = doc.data()?['profileBorder'] as String? ?? 'none';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _purchaseBorder(String borderId, String name, String price) async {
    if (borderId == 'none') {
      // Free option, update immediately
      await _updateBorderInDb('none');
      return;
    }

    // Open premium mock checkout sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MockCheckoutSheet(
        borderId: borderId,
        borderName: name,
        price: price,
        onSuccess: () async {
          await _updateBorderInDb(borderId);
        },
      ),
    );
  }

  Future<void> _updateBorderInDb(String borderId) async {
    if (user == null) return;
    try {
      await AppDatabase.instance.table('users').doc(user!.uid).update({
        'profileBorder': borderId,
      });
      setState(() {
        _activeBorder = borderId;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activated "$borderId" border profile successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update border: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Digital Store',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Premium Hero Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withOpacity(0.15),
                          Colors.blue.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.25)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'PREMIUM ANIMATED BORDERS',
                          style: TextStyle(
                            color: Colors.purpleAccent,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Real-time Preview Avatar wrapper
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: AppDatabase.instance.table('users').doc(user?.uid).snapshots(),
                          builder: (context, snapshot) {
                            final photoUrl = snapshot.data?.data()?['photoUrl'];
                            Widget avatarChild = CircleAvatar(
                              radius: 50,
                              backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 50, color: Colors.white38)
                                  : null,
                            );

                            if (_activeBorder == 'none') {
                              return avatarChild;
                            }

                            return AnimatedBorderWrapper(
                              borderType: _activeBorder,
                              radius: 50,
                              child: avatarChild,
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Stand out in group threads & status lists with custom-synced live border wrappers.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  const Text(
                    'AVAILABLE PRODUCTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white38,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _borders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _borders[index];
                      final isCurrent = _activeBorder == item['id'];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCurrent ? item['color'] : const Color(0xFF2C2C2C),
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Show small demo border avatar
                            AnimatedBorderWrapper(
                              borderType: item['id'],
                              radius: 20,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey[900],
                                child: Icon(Icons.person, color: Colors.white24, size: 20),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['description'],
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item['price'],
                                  style: TextStyle(
                                    color: item['color'],
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: isCurrent
                                      ? null
                                      : () => _purchaseBorder(item['id'], item['name'], item['price']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCurrent ? Colors.white10 : item['color'],
                                    foregroundColor: isCurrent ? Colors.white38 : Colors.black,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    isCurrent ? 'Active' : 'Get',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

class _MockCheckoutSheet extends StatefulWidget {
  final String borderId;
  final String borderName;
  final String price;
  final VoidCallback onSuccess;

  const _MockCheckoutSheet({
    required this.borderId,
    required this.borderName,
    required this.price,
    required this.onSuccess,
  });

  @override
  State<_MockCheckoutSheet> createState() => _MockCheckoutSheetState();
}

class _MockCheckoutSheetState extends State<_MockCheckoutSheet> {
  int _paymentMethod = 0; // 0 = Card, 1 = Apple Pay, 2 = Google Pay
  bool _processing = false;
  bool _success = false;

  final _cardNoController = TextEditingController(text: '4111 2222 3333 4444');
  final _expiryController = TextEditingController(text: '12/28');
  final _cvvController = TextEditingController(text: '345');

  @override
  void dispose() {
    _cardNoController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _triggerPayment() {
    setState(() {
      _processing = true;
    });

    // Simulate network delay for premium validation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _processing = false;
          _success = true;
        });

        HapticFeedback.vibrate();

        // Delay closing sheet so user sees the premium success screen
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
            widget.onSuccess();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: _success
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.greenAccent,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Successful!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your animated profile border has been unlocked.',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Premium Checkout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock ${widget.borderName} profile border layer',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Cart item receipt details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.borderName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.price,
                        style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'PAYMENT METHOD',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _paymentChoiceCard(0, Icons.credit_card, 'Card'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _paymentChoiceCard(1, Icons.apple, 'Apple Pay'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _paymentChoiceCard(2, Icons.payment, 'Google Pay'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (_paymentMethod == 0) ...[
                  // Card input form
                  _buildFormTextfield(
                    controller: _cardNoController,
                    label: 'Card Number',
                    icon: Icons.credit_card,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormTextfield(
                          controller: _expiryController,
                          label: 'Expiry Date',
                          icon: Icons.calendar_today,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormTextfield(
                          controller: _cvvController,
                          label: 'CVV',
                          icon: Icons.lock_outline,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Center(
                      child: Text(
                        _paymentMethod == 1 ? ' Pay authorization will open on press' : 'Google Pay authorization will open on press',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _processing ? null : _triggerPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _processing
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text(
                            'Authorize & Pay ${widget.price}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _paymentChoiceCard(int methodIndex, IconData icon, String title) {
    final active = _paymentMethod == methodIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _paymentMethod = methodIndex;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.purpleAccent.withOpacity(0.12) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? Colors.purpleAccent : const Color(0xFF2C2C2C),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? Colors.purpleAccent : Colors.white54, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.purpleAccent : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTextfield({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white30, size: 18),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white30, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
