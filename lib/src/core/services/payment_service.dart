import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:flutter/foundation.dart';

enum PaymentGateway {
  stripe,
  razorpay,
  paystack,
  paypal,
  flutterwave,
  square,
  yoco,
  payfast,
  peachPayments,
  snapscan,
  zapper,
  ozow,
  custom,
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  String? _stripePublishableKey;
  String? _razorpayKey;
  String? _paystackPublicKey;
  String? _flutterwavePublicKey;
  String? _flutterwaveSecretKey;
  String? _customVerifyUrl;
  PaymentGateway _currentGateway = PaymentGateway.stripe;
  bool _isInitialized = false;

  Future<void> initialize({
    required PaymentGateway gateway,
    String? stripeKey,
    String? razorpayKey,
    String? paystackKey,
    String? flutterwavePublicKey,
    String? flutterwaveSecretKey,
    String? customVerifyUrl,
  }) async {
    _currentGateway = gateway;
    _stripePublishableKey = stripeKey;
    _razorpayKey = razorpayKey;
    _paystackPublicKey = paystackKey;
    _flutterwavePublicKey = flutterwavePublicKey;
    _flutterwaveSecretKey = flutterwaveSecretKey;
    _customVerifyUrl = customVerifyUrl;

    try {
      switch (gateway) {
        case PaymentGateway.stripe:
          if (stripeKey != null) {
            Stripe.publishableKey = stripeKey;
            await Stripe.instance.applySettings();
          }
          break;
        case PaymentGateway.razorpay:
          // Razorpay doesn't need initialization, key is passed per transaction
          break;
        case PaymentGateway.paystack:
          // PaystackPlugin.initialize is an instance method; initialization
          // happens per-transaction in _processPaystackPayment
          break;
        case PaymentGateway.flutterwave:
          // Flutterwave initialization happens per transaction
          break;
        default:
          debugPrint('Payment gateway $gateway not yet implemented');
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Payment service initialization error: $e');
      _isInitialized = false;
    }
  }

  Future<Map<String, dynamic>?> processPayment({
    required double amount,
    required String currency,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw Exception('Payment service not initialized');
    }

    try {
      switch (_currentGateway) {
        case PaymentGateway.stripe:
          return await _processStripePayment(amount, currency, description, metadata);
        case PaymentGateway.razorpay:
          return await _processRazorpayPayment(amount, currency, description, metadata);
        case PaymentGateway.paystack:
          return await _processPaystackPayment(amount, currency, description, metadata);
        case PaymentGateway.flutterwave:
          return await _processFlutterwavePayment(amount, currency, description, metadata);
        default:
          throw Exception('Payment gateway $_currentGateway not yet implemented');
      }
    } catch (e) {
      debugPrint('Payment processing error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _processStripePayment(
    double amount,
    String currency,
    String description,
    Map<String, dynamic>? metadata,
  ) async {
    // Create payment intent
    final paymentIntentData = {
      'amount': (amount * 100).toInt(), // Stripe uses cents
      'currency': currency.toLowerCase(),
      'description': description,
      'metadata': metadata ?? {},
    };

    // This would typically call a Cloud Function to create the payment intent
    // For now, we'll return the data for the UI to handle
    return {
      'gateway': 'stripe',
      'clientSecret': null, // Would come from Cloud Function
      'amount': amount,
      'currency': currency,
      'description': description,
    };
  }

  Future<Map<String, dynamic>?> _processRazorpayPayment(
    double amount,
    String currency,
    String description,
    Map<String, dynamic>? metadata,
  ) async {
    return {
      'gateway': 'razorpay',
      'key': _razorpayKey,
      'amount': (amount * 100).toInt(), // Razorpay uses smallest currency unit
      'currency': currency,
      'description': description,
      'name': metadata?['businessName'] ?? 'Business',
      'prefill': {
        'contact': metadata?['customerPhone'],
        'email': metadata?['customerEmail'],
      },
    };
  }

  Future<Map<String, dynamic>?> _processPaystackPayment(
    double amount,
    String currency,
    String description,
    Map<String, dynamic>? metadata,
  ) async {
    // PaystackPlugin.checkout() requires a BuildContext from the UI layer.
    // Return payment params so the UI (PaymentCheckoutScreen) handles the checkout.
    return {
      'gateway': 'paystack',
      'publicKey': _paystackPublicKey,
      'amount': (amount * 100).toInt(),
      'currency': currency,
      'description': description,
      'email': metadata?['customerEmail'] ?? '',
      'reference': _generateReference(),
    };
  }

  Future<Map<String, dynamic>?> _processFlutterwavePayment(
    double amount,
    String currency,
    String description,
    Map<String, dynamic>? metadata,
  ) async {
    return {
      'gateway': 'flutterwave',
      'amount': amount,
      'currency': currency,
      'description': description,
      'publicKey': _flutterwavePublicKey,
      'email': metadata?['customerEmail'] ?? '',
      'phoneNumber': metadata?['customerPhone'] ?? '',
      'txRef': _generateReference(),
    };
  }

  String _generateReference() {
    return 'ACHATZ_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> saveTransactionRecord({
    required String productId,
    required String productName,
    required double amount,
    required String currency,
    required String gateway,
    required String status,
    String? transactionId,
    String? reference,
  }) async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await AppDatabase.instance.table('users').doc(uid).table('transactions').add({
      'productId': productId,
      'productName': productName,
      'amount': amount,
      'currency': currency,
      'gateway': gateway,
      'status': status,
      'transactionId': transactionId,
      'reference': reference,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> loadUserPaymentIntegration() async {
    final uid = AppAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await AppDatabase.instance.table('users').doc(uid).get();
      final data = doc.data();
      if (data != null && data.containsKey('paymentIntegration')) {
        final paymentMap = data['paymentIntegration'] as Map<String, dynamic>;
        final gatewayStr = paymentMap['gateway'] as String? ?? 'stripe';
        
        await initialize(
          gateway: _parseGateway(gatewayStr),
          stripeKey: paymentMap['publicKey'],
          razorpayKey: paymentMap['publicKey'],
          paystackKey: paymentMap['publicKey'],
          flutterwavePublicKey: paymentMap['publicKey'],
          flutterwaveSecretKey: paymentMap['secretKey'],
          customVerifyUrl: paymentMap['customVerifyUrl'],
        );
      }
    } catch (e) {
      debugPrint('Error loading payment integration: $e');
    }
  }

  PaymentGateway _parseGateway(String gateway) {
    switch (gateway.toLowerCase()) {
      case 'stripe':
        return PaymentGateway.stripe;
      case 'razorpay':
        return PaymentGateway.razorpay;
      case 'paystack':
        return PaymentGateway.paystack;
      case 'paypal':
        return PaymentGateway.paypal;
      case 'flutterwave':
        return PaymentGateway.flutterwave;
      case 'square':
        return PaymentGateway.square;
      case 'yoco':
        return PaymentGateway.yoco;
      case 'payfast':
        return PaymentGateway.payfast;
      case 'peach payments':
        return PaymentGateway.peachPayments;
      case 'snapscan':
        return PaymentGateway.snapscan;
      case 'zapper':
        return PaymentGateway.zapper;
      case 'ozow':
        return PaymentGateway.ozow;
      case 'custom':
        return PaymentGateway.custom;
      default:
        return PaymentGateway.stripe;
    }
  }
}
