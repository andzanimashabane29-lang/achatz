import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

class PaymentIntegrationScreen extends StatefulWidget {
  const PaymentIntegrationScreen({super.key});

  @override
  State<PaymentIntegrationScreen> createState() => _PaymentIntegrationScreenState();
}

class _PaymentIntegrationScreenState extends State<PaymentIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _selectedGateway = 'Stripe';
  final _publicKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _customVerifyUrlController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isVerified = false;

  final List<String> _gateways = [
    'Stripe',
    'Paystack',
    'PayPal',
    'Razorpay',
    'Flutterwave',
    'Square',
    'Yoco',
    'PayFast',
    'Peach Payments',
    'SnapScan',
    'Zapper',
    'Ozow',
    'Custom'
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingIntegration();
  }

  Future<void> _loadExistingIntegration() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await AppDatabase.instance.table('users').doc(uid).get();
      final data = doc.data();
      if (data != null && data.containsKey('paymentIntegration')) {
        final paymentMap = data['paymentIntegration'] as Map<String, dynamic>;
        setState(() {
          _selectedGateway = paymentMap['gateway'] ?? 'Stripe';
          if (!_gateways.contains(_selectedGateway)) {
             if (!paymentMap['gateway'].toString().isEmpty) {
                 _gateways.add(_selectedGateway);
             }
          }
          _publicKeyController.text = paymentMap['publicKey'] ?? '';
          // We intentionally do not load the secret key for security reasons, 
          // but we indicate it is set by showing a placeholder.
          if (paymentMap['secretKeyPlaceholder'] != null) {
            _secretKeyController.text = paymentMap['secretKeyPlaceholder'];
          }
          _customVerifyUrlController.text = paymentMap['customVerifyUrl'] ?? '';
          _isVerified = paymentMap['isVerified'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading payment integration: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _publicKeyController.addListener(_onKeyChanged);
      _secretKeyController.addListener(_onKeyChanged);
    }
  }

  @override
  void dispose() {
    _publicKeyController.removeListener(_onKeyChanged);
    _secretKeyController.removeListener(_onKeyChanged);
    _publicKeyController.dispose();
    _secretKeyController.dispose();
    _customVerifyUrlController.dispose();
    super.dispose();
  }

  void _onKeyChanged() {
    final pubKey = _publicKeyController.text.trim();
    final secKey = _secretKeyController.text.trim();
    
    String? detected;
    
    // Check Razorpay
    if (pubKey.startsWith('rzp_') || secKey.startsWith('rzp_')) {
      detected = 'Razorpay';
    }
    // Check Flutterwave
    else if (pubKey.startsWith('FLWPUBK') || pubKey.startsWith('FLWSECK') || 
             secKey.startsWith('FLWPUBK') || secKey.startsWith('FLWSECK')) {
      detected = 'Flutterwave';
    }
    // Check Square
    else if (pubKey.startsWith('sandbox-sq0idb-') || pubKey.startsWith('sq0idb-') || pubKey.startsWith('sq0idp-') ||
             secKey.startsWith('EAAA')) {
      detected = 'Square';
    }
    // Check PayPal
    else if ((pubKey.startsWith('A') && pubKey.length >= 70) || 
             (secKey.startsWith('E') && secKey.length >= 70)) {
      detected = 'PayPal';
    }
    // Check Yoco
    else if (pubKey.contains('yoco') || secKey.contains('yoco') || 
             pubKey.startsWith('pk_yoco_') || secKey.startsWith('sk_yoco_')) {
      detected = 'Yoco';
    }
    // Check Peach Payments
    else if (pubKey.toLowerCase().contains('peach') || secKey.toLowerCase().contains('peach')) {
      detected = 'Peach Payments';
    }
    // Check SnapScan
    else if (pubKey.toLowerCase().contains('snapscan') || secKey.toLowerCase().contains('snapscan')) {
      detected = 'SnapScan';
    }
    // Check Zapper
    else if (pubKey.toLowerCase().contains('zapper') || secKey.toLowerCase().contains('zapper')) {
      detected = 'Zapper';
    }
    // Check Ozow
    else if (pubKey.toLowerCase().contains('ozow') || secKey.toLowerCase().contains('ozow') ||
             RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(pubKey)) {
      detected = 'Ozow';
    }
    // Check Stripe vs Paystack
    else if (pubKey.startsWith('pk_') || secKey.startsWith('sk_')) {
      if (pubKey.startsWith('pk_test_51') || pubKey.startsWith('pk_live_51') ||
          secKey.startsWith('sk_test_51') || secKey.startsWith('sk_live_51')) {
        detected = 'Stripe';
      } else {
        detected = 'Paystack';
      }
    }
    // Check PayFast
    else if (RegExp(r'^[0-9]+$').hasMatch(pubKey) && pubKey.length >= 6 && pubKey.length <= 12) {
      detected = 'PayFast';
    }

    if (detected != null && detected != _selectedGateway && _gateways.contains(detected)) {
      setState(() {
        _selectedGateway = detected!;
        _isVerified = false; // Reset verification if key triggers a new gateway change
      });
    }
  }

  Future<void> _verifyAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final callable = AppFunctions.instance.httpsCallable('verifyPaymentAPI');
      final response = await callable.call({
        'gateway': _selectedGateway,
        'publicKey': _publicKeyController.text.trim(),
        'secretKey': _secretKeyController.text.trim(),
        'customVerifyUrl': _customVerifyUrlController.text.trim(),
      });

      if (response.data['success'] == true) {
        setState(() {
          _isVerified = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API Verified & Saved Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(response.data['error'] ?? 'Verification failed');
      }
    } catch (e) {
      debugPrint('Error verifying API: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    const Expanded(
                      child: Text(
                        'Payment Integration',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Link your API to process business transactions directly through your catalog.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 24),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isVerified ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isVerified ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isVerified ? Icons.check_circle : Icons.info_outline,
                                  color: _isVerified ? Colors.greenAccent : Colors.orangeAccent,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _isVerified
                                        ? 'Your $_selectedGateway integration is verified and active.'
                                        : 'Integration is pending. Please verify your API keys.',
                                    style: TextStyle(
                                      color: _isVerified ? Colors.greenAccent : Colors.orangeAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Gateway Selection
                          const Text(
                            'Select Gateway',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedGateway,
                            dropdownColor: const Color(0xFF1E1E1E),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: _gateways.map((g) {
                              return DropdownMenuItem(
                                value: g,
                                child: Text(g),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedGateway = val);
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          if (_selectedGateway == 'Custom') ...[
                            _buildTextField(
                              controller: _customVerifyUrlController,
                              label: 'Custom Verification URL',
                              hint: 'https://api.yourgateway.com/verify',
                              icon: Icons.link,
                              validator: (v) => v!.isEmpty ? 'Required for custom gateway' : null,
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Public Key
                          _buildTextField(
                            controller: _publicKeyController,
                            label: 'Public / Publishable Key',
                            hint: 'e.g. pk_test_...',
                            icon: Icons.vpn_key_outlined,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),

                          // Secret Key
                          _buildTextField(
                            controller: _secretKeyController,
                            label: 'Secret / Private Key',
                            hint: 'e.g. sk_test_...',
                            icon: Icons.lock_outline,
                            isPassword: true,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _isSaving ? null : _verifyAndSave,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Verify & Save API',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: Icon(icon, color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
