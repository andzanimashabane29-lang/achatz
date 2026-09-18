import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:a_chatz/src/core/services/payment_service.dart';
class PaymentCheckoutScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final double amount;
  final String currency;
  final String sellerId;
  final String? productImage;

  const PaymentCheckoutScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.amount,
    required this.currency,
    required this.sellerId,
    this.productImage,
  });

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isProcessing = false;
  Map<String, dynamic>? _paymentData;

  @override
  void initState() {
    super.initState();
    _loadPaymentIntegration();
  }

  Future<void> _loadPaymentIntegration() async {
    await _paymentService.loadUserPaymentIntegration();
    setState(() {});
  }

  Future<void> _initiatePayment() async {
    setState(() => _isProcessing = true);

    try {
      final user = AppAuth.instance.currentUser;
      final result = await _paymentService.processPayment(
        amount: widget.amount,
        currency: widget.currency,
        description: widget.productName,
        metadata: {
          'productId': widget.productId,
          'productName': widget.productName,
          'sellerId': widget.sellerId,
          'buyerId': user?.uid,
          'customerEmail': user?.email ?? 'buyer@achatz.com',
          'customerPhone': user?.phoneNumber ?? '',
        },
      );

      if (result != null) {
        setState(() => _paymentData = result);
        await _executePayment(result);
      }
    } catch (e) {
      _showError('Payment initiation failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executePayment(Map<String, dynamic> paymentData) async {
    final gateway = paymentData['gateway'] as String;

    switch (gateway) {
      case 'stripe':
        await _executeStripePayment(paymentData);
        break;
      case 'razorpay':
        await _executeRazorpayPayment(paymentData);
        break;
      case 'paystack':
        await _executePaystackPayment(paymentData);
        break;
      case 'flutterwave':
        await _executeFlutterwavePayment(paymentData);
        break;
      default:
        _showError('Payment gateway not supported');
    }
  }

  Future<void> _executeStripePayment(Map<String, dynamic> data) async {
    try {
      // For Stripe, we would typically use PaymentSheet
      // This requires a clientSecret from a Cloud Function
      if (data['clientSecret'] == null) {
        _showError('Stripe client secret not available. Please ensure Cloud Functions are configured.');
        return;
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: data['clientSecret'],
          merchantDisplayName: 'A-Chatz Store',
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: const Color(0xFF00FFB2),
              background: const Color(0xFF1E1E1E),
              componentBackground: const Color(0xFF2D2D2D),
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      await _saveTransaction('success', data['paymentIntentId']);
      _showSuccess();
    } catch (e) {
      _showError('Stripe payment failed: $e');
      await _saveTransaction('failed', null);
    }
  }

  Future<void> _executeRazorpayPayment(Map<String, dynamic> data) async {
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) {
      _saveTransaction('success', response.paymentId);
      _showSuccess();
      razorpay.clear();
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (response) {
      _showError('Razorpay payment failed: ${response.message}');
      _saveTransaction('failed', null);
      razorpay.clear();
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) {
      // Handle external wallet
    });

    final options = {
      'key': data['key'],
      'amount': data['amount'],
      'name': data['name'],
      'description': data['description'],
      'prefill': data['prefill'],
      'theme': {
        'color': '#00FFB2',
      },
    };

    try {
      razorpay.open(options);
    } catch (e) {
      _showError('Razorpay error: $e');
      razorpay.clear();
    }
  }

  Future<void> _executePaystackPayment(Map<String, dynamic> data) async {
    final publicKey = data['publicKey'] as String?;
    if (publicKey == null || publicKey.isEmpty) {
      _showError('Paystack public key is not configured');
      return;
    }

    final plugin = PaystackPlugin();
    await plugin.initialize(publicKey: publicKey);

    final email = data['email'] as String? ?? 'buyer@achatz.com';
    final amount = data['amount'] as int? ?? (widget.amount * 100).toInt();
    final reference = data['reference'] as String?;

    final charge = Charge()
      ..amount = amount
      ..email = email
      ..reference = reference
      ..currency = data['currency'] ?? widget.currency;

    try {
      final response = await plugin.checkout(
        context,
        method: CheckoutMethod.card,
        charge: charge,
      );

      if (response.status == true) {
        await _saveTransaction('success', response.reference);
        _showSuccess();
      } else {
        _showError('Paystack payment failed: ${response.message}');
        await _saveTransaction('failed', null);
      }
    } catch (e) {
      _showError('Paystack error: $e');
      await _saveTransaction('failed', null);
    }
  }

  Future<void> _executeFlutterwavePayment(Map<String, dynamic> data) async {
    final flutterwave = Flutterwave(
      publicKey: data['publicKey'],
      txRef: data['txRef'],
      amount: data['amount'].toString(),
      currency: data['currency'],
      redirectUrl: 'https://achatz.app/payment-redirect',
      paymentOptions: 'card,mobilemoneyghana,ussd',
      isTestMode: (data['publicKey'] as String? ?? '').toLowerCase().contains('test'),
      customer: Customer(
        name: data['name'] ?? '',
        phoneNumber: data['phoneNumber'] ?? '',
        email: data['email'] ?? '',
      ),
      customization: Customization(
        title: 'A-Chatz Store',
        description: data['description'] ?? '',
      ),
    );

    try {
      final response = await flutterwave.charge(context);
      if (response.success == true) {
        await _saveTransaction('success', response.transactionId);
        _showSuccess();
      } else {
        _showError('Flutterwave payment failed');
        await _saveTransaction('failed', null);
      }
    } catch (e) {
      _showError('Flutterwave error: $e');
      await _saveTransaction('failed', null);
    }
  }

  Future<void> _saveTransaction(String status, String? transactionId) async {
    await _paymentService.saveTransactionRecord(
      productId: widget.productId,
      productName: widget.productName,
      amount: widget.amount,
      currency: widget.currency,
      gateway: _paymentData?['gateway'] ?? 'unknown',
      status: status,
      transactionId: transactionId,
      reference: _paymentData?['reference'],
    );
  }

  void _showSuccess() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Payment Successful', style: TextStyle(color: Colors.greenAccent)),
        content: const Text('Your order has been placed successfully!', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('OK', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Checkout', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  if (widget.productImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.productImage!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.white10,
                          child: const Icon(Icons.image, color: Colors.white38),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.currency.toUpperCase()} ${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method
            const Text(
              'Payment Method',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: Colors.greenAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Integrated Payment Gateway',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const Icon(Icons.verified, color: Colors.greenAccent, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  Text(
                    '${widget.currency.toUpperCase()} ${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFB2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Pay Now',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
