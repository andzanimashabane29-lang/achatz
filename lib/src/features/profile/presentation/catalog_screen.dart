import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'dart:math' as math;
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:a_chatz/src/shared/widgets/payment_checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CartItem model
// ─────────────────────────────────────────────────────────────────────────────

class CartItem {
  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.quantity,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Supported currencies
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, String>> _kCurrencies = [
  {'code': 'ZAR', 'symbol': 'R',  'label': 'South African Rand (R)'},
  {'code': 'USD', 'symbol': '\$',  'label': 'US Dollar (\$)'},
  {'code': 'EUR', 'symbol': '€',  'label': 'Euro (€)'},
  {'code': 'GBP', 'symbol': '£',  'label': 'British Pound (£)'},
  {'code': 'NGN', 'symbol': '₦',  'label': 'Nigerian Naira (₦)'},
  {'code': 'KES', 'symbol': 'KSh','label': 'Kenyan Shilling (KSh)'},
  {'code': 'GHS', 'symbol': 'GH₵','label': 'Ghanaian Cedi (GH₵)'},
  {'code': 'EGP', 'symbol': 'E£', 'label': 'Egyptian Pound (E£)'},
  {'code': 'AED', 'symbol': 'د.إ','label': 'UAE Dirham (د.إ)'},
  {'code': 'INR', 'symbol': '₹',  'label': 'Indian Rupee (₹)'},
  {'code': 'AUD', 'symbol': 'A\$', 'label': 'Australian Dollar (A\$)'},
  {'code': 'CAD', 'symbol': 'C\$', 'label': 'Canadian Dollar (C\$)'},
];

String _symbolForCode(String code) =>
    _kCurrencies.firstWhere((c) => c['code'] == code, orElse: () => {'symbol': '\$'})['symbol']!;

// ─────────────────────────────────────────────────────────────────────────────
// CatalogScreen
// ─────────────────────────────────────────────────────────────────────────────

class CatalogScreen extends ConsumerStatefulWidget {
  final String? userId;
  const CatalogScreen({super.key, this.userId});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  late final String _uid;
  late final bool _isReadOnly;
  Map<String, dynamic>? _paymentIntegration;

  // Currency state
  String _currencyCode = 'ZAR';

  // Cart state (only used in read-only / buyer mode)
  final Map<String, CartItem> _cart = {};

  int get _cartCount => _cart.values.fold(0, (s, i) => s + i.quantity);
  double get _cartSubtotal => _cart.values.fold(0.0, (s, i) => s + i.price * i.quantity);

  @override
  void initState() {
    super.initState();
    final current = AppAuth.instance.currentUser?.uid ?? '';
    _uid = widget.userId ?? current;
    _isReadOnly = widget.userId != null && widget.userId != current;
    _loadPaymentIntegrationAndCurrency();

    if (_isReadOnly && _uid.isNotEmpty) {
      AppDatabase.instance.table('business_analytics').doc(_uid).set({
        'catalogViews': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _loadPaymentIntegrationAndCurrency() async {
    try {
      final doc = await AppDatabase.instance.table('users').doc(_uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            if (data.containsKey('paymentIntegration')) {
              _paymentIntegration = data['paymentIntegration'] as Map<String, dynamic>;
            }
            final savedCode = data['catalogCurrency'] as String?;
            if (savedCode != null && _kCurrencies.any((c) => c['code'] == savedCode)) {
              _currencyCode = savedCode;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading catalog data: $e');
    }
  }

  Future<void> _saveCurrency(String code) async {
    setState(() => _currencyCode = code);
    await AppDatabase.instance.table('users').doc(_uid).update({
      'catalogCurrency': code,
    });
  }

  /// Parse a price string like "R 299", "$29.99", "299" → double
  double _parsePrice(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Format a price double using the active currency symbol
  String _formatPrice(double amount, {String? overrideCode}) {
    final sym = _symbolForCode(overrideCode ?? _currencyCode);
    return '$sym ${amount.toStringAsFixed(2)}';
  }

  // ───────────────────────────────────────── Cart helpers ─────────────────

  void _addToCart(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;
    final price = _parsePrice(data['price'] ?? '0');
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!.quantity++;
      } else {
        _cart[id] = CartItem(
          id: id,
          name: data['name'] ?? '',
          price: price,
          imageUrl: data['imageUrl'] as String?,
          quantity: 1,
        );
      }
    });
  }

  void _removeFromCart(String id) {
    setState(() => _cart.remove(id));
  }

  void _adjustQty(String id, int delta) {
    setState(() {
      if (!_cart.containsKey(id)) return;
      _cart[id]!.quantity += delta;
      if (_cart[id]!.quantity <= 0) _cart.remove(id);
    });
  }

  // ───────────────────────────────────── Product dialog ────────────────────

  Future<void> _showProductDialog({DocumentSnapshot? existing}) async {
    if (!_isReadOnly &&
        (_paymentIntegration == null || _paymentIntegration!['isVerified'] != true)) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Payment Integration Required', style: TextStyle(color: Colors.white)),
          content: const Text(
            'You must link and verify a payment integration before you can manage products in your catalog.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.greenAccent)),
            ),
          ],
        ),
      );
      return;
    }

    final data = existing?.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: data?['price'] != null
          ? _parsePrice(data!['price']).toStringAsFixed(2)
          : '',
    );
    final descCtrl = TextEditingController(text: data?['description'] ?? '');
    XFile? pickedImage;
    String? existingImageUrl = data?['imageUrl'];
    bool uploading = false;

    // ── Read-only product detail sheet ──────────────────────────────────────
    if (_isReadOnly) {
      if (existing == null) return;
      final cartItem = _cart[existing.id];

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF101012),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) {
            final inCart = _cart.containsKey(existing.id);
            final qty = _cart[existing.id]?.quantity ?? 0;
            final itemPrice = _parsePrice(data?['price'] ?? '0');

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24, 24, 24,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 44, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (existingImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          existingImageUrl!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            nameCtrl.text,
                            style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatPrice(itemPrice),
                          style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF00FFB2),
                          ),
                        ),
                      ],
                    ),
                    if (descCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        descCtrl.text,
                        style: const TextStyle(fontSize: 14, color: Colors.white60, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // ── Add to cart / qty controls ──────────────────────
                    if (!inCart)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white54,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FFB2),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.add_shopping_cart, size: 20),
                              label: const Text('Add to Cart',
                                  style: TextStyle(fontWeight: FontWeight.w900)),
                              onPressed: () {
                                _addToCart(existing);
                                setSheet(() {});
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      )
                    else ...[
                      // Qty editor
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF00FFB2).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.white60, size: 26),
                              onPressed: () {
                                _adjustQty(existing.id, -1);
                                setSheet(() {});
                                if (!_cart.containsKey(existing.id)) Navigator.pop(ctx);
                              },
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$qty',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Color(0xFF00FFB2), size: 26),
                              onPressed: () {
                                _adjustQty(existing.id, 1);
                                setSheet(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                _removeFromCart(existing.id);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Remove from Cart'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FFB2),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                              },
                              child: const Text('Done',
                                  style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
      return;
    }

    // ── Owner product editor ─────────────────────────────────────────────────
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121214),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24, 24, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  existing == null ? 'Add Product' : 'Edit Product',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 20),

                // Image picker
                GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker()
                        .pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (picked != null) setModal(() => pickedImage = picked);
                  },
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                      image: pickedImage != null
                          ? (kIsWeb
                              ? DecorationImage(
                                  image: NetworkImage(pickedImage!.path),
                                  fit: BoxFit.cover)
                              : DecorationImage(
                                  image: FileImage(File(pickedImage!.path)),
                                  fit: BoxFit.cover))
                          : (existingImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(existingImageUrl!),
                                  fit: BoxFit.cover)
                              : null),
                    ),
                    child: (pickedImage == null && existingImageUrl == null)
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: Colors.white38, size: 48),
                              SizedBox(height: 8),
                              Text('Tap to add photo',
                                  style: TextStyle(color: Colors.white38, fontSize: 13)),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                _Field(controller: nameCtrl, label: 'Product Name', icon: Icons.label_outline),
                const SizedBox(height: 12),

                // Price field with currency symbol prefix
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    labelStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.sell_outlined, color: Colors.white38, size: 20),
                    prefix: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        _symbolForCode(_currencyCode),
                        style: const TextStyle(
                          color: Color(0xFF00FFB2),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                    controller: descCtrl,
                    label: 'Description',
                    icon: Icons.notes,
                    maxLines: 3),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: uploading
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            setModal(() => uploading = true);

                            String? imageUrl = existingImageUrl;
                            if (pickedImage != null) {
                              final storageRef = AppStorage.instance
                                  .ref()
                                  .child(
                                      'catalog/$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
                              final UploadTask uploadTask;
                              if (kIsWeb) {
                                final bytes = await pickedImage!.readAsBytes();
                                uploadTask = storageRef.putData(
                                  bytes,
                                  SettableMetadata(contentType: 'image/jpeg'),
                                );
                              } else {
                                uploadTask = storageRef.putFile(
                                  File(pickedImage!.path),
                                  SettableMetadata(contentType: 'image/jpeg'),
                                );
                              }
                              await uploadTask;
                              imageUrl = await storageRef.getDownloadURL();
                            }

                            // Store price as numeric string with currency code
                            final priceNum = double.tryParse(
                                    priceCtrl.text.replaceAll(RegExp(r'[^\d.]'), '')) ??
                                0.0;
                            final priceFormatted =
                                '${_symbolForCode(_currencyCode)} ${priceNum.toStringAsFixed(2)}';

                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'price': priceFormatted,
                              'description': descCtrl.text.trim(),
                              'imageUrl': imageUrl,
                              'currencyCode': _currencyCode,
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            final col = AppDatabase.instance
                                .table('users')
                                .doc(_uid)
                                .table('catalog');

                            if (existing == null) {
                              payload['createdAt'] = FieldValue.serverTimestamp();
                              await col.add(payload);
                            } else {
                              await existing.reference.update(payload);
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: uploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            existing == null ? 'Add to Catalog' : 'Save Changes',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────── Build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Catalog',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_isReadOnly) ...[
                    // Currency selector
                    _CurrencyDropdown(
                      selectedCode: _currencyCode,
                      onChanged: _saveCurrency,
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _showProductDialog,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Product',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isReadOnly
                    ? 'Browse products and pricing'
                    : 'Showcase your products to customers',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),

              // Currency badge for read-only viewers
              if (_isReadOnly) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    'Prices in ${_kCurrencies.firstWhere((c) => c['code'] == _currencyCode, orElse: () => {'label': _currencyCode})['label']!}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Product Grid ───────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: AppDatabase.instance
                      .table('users')
                      .doc(_uid)
                      .table('catalog')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.storefront_outlined,
                                color: Colors.white24, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              _isReadOnly ? 'Catalog is empty' : 'Your catalog is empty',
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isReadOnly
                                  ? 'This business hasn\'t added any products yet.'
                                  : 'Add products to showcase them to customers',
                              style: const TextStyle(
                                  color: Colors.white24, fontSize: 13),
                            ),
                            if (!_isReadOnly) ...[
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _showProductDialog,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Product',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final imageUrl = data['imageUrl'] as String?;
                        final inCart = _cart.containsKey(doc.id);
                        final cartQty = _cart[doc.id]?.quantity ?? 0;

                        return GestureDetector(
                          onTap: () => _showProductDialog(existing: doc),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1D),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: inCart
                                    ? const Color(0xFF00FFB2).withOpacity(0.4)
                                    : Colors.white.withOpacity(0.06),
                                width: inCart ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product image
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(20)),
                                      child: imageUrl != null
                                          ? Image.network(
                                              imageUrl,
                                              height: 130,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _imagePlaceholder(),
                                            )
                                          : _imagePlaceholder(),
                                    ),
                                    if (inCart)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00FFB2),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '×$cartQty',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                // Info
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          data['price'] ?? '',
                                          style: const TextStyle(
                                            color: Color(0xFF00FFB2),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (!_isReadOnly)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      _showProductDialog(existing: doc),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                    foregroundColor: Colors.white,
                                                    side: const BorderSide(
                                                        color: Colors.white12),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(10)),
                                                  ),
                                                  child: const Text('Edit',
                                                      style: TextStyle(fontSize: 12)),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      backgroundColor:
                                                          const Color(0xFF1E1E1E),
                                                      title: const Text(
                                                          'Delete Product',
                                                          style: TextStyle(
                                                              color: Colors.white)),
                                                      content: const Text(
                                                          'Remove this product from your catalog?',
                                                          style: TextStyle(
                                                              color: Colors.white70)),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(ctx, false),
                                                            child: const Text('Cancel')),
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(ctx, true),
                                                            child: const Text('Delete',
                                                                style: TextStyle(
                                                                    color: Colors.red))),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    await doc.reference.delete();
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.redAccent.withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(Icons.delete_outline,
                                                      color: Colors.redAccent, size: 18),
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          Text(
                                            data['description'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white38, fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // ── Floating Cart Button (read-only / buyer mode only) ──────────
          if (_isReadOnly && _cartCount > 0)
            Positioned(
              bottom: 20,
              right: 0,
              left: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _showCartSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FFB2), Color(0xFF00C896)],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFB2).withOpacity(0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_bag_outlined,
                            color: Colors.black, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          '$_cartCount item${_cartCount == 1 ? '' : 's'} · ${_formatPrice(_cartSubtotal * 1.15)}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.black54, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────── Cart sheet ──────────────────────────

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final subtotal = _cartSubtotal;
          final tax = subtotal * 0.15;
          final total = subtotal + tax;
          final sym = _symbolForCode(_currencyCode);

          String externalGateway = '';
          if (_paymentIntegration != null &&
              _paymentIntegration!['isVerified'] == true) {
            externalGateway = _paymentIntegration!['gateway'] ?? '';
          }

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121214),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withOpacity(0.07), width: 1.5),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                  child: Center(
                    child: Container(
                      width: 44, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          color: Color(0xFF00FFB2), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Your Cart ($_cartCount item${_cartCount == 1 ? '' : 's'})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cart items list
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.3,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shrinkWrap: true,
                    children: _cart.values.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: item.imageUrl != null
                                  ? Image.network(
                                      item.imageUrl!,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _thumbPlaceholder(),
                                    )
                                  : _thumbPlaceholder(),
                            ),
                            const SizedBox(width: 12),
                            // Name + price
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    '$sym ${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Color(0xFF00FFB2), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Qty controls
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    _adjustQty(item.id, -1);
                                    setSheet(() {});
                                    if (_cart.isEmpty) Navigator.pop(ctx);
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.remove,
                                        color: Colors.white60, size: 16),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _adjustQty(item.id, 1);
                                    setSheet(() {});
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00FFB2)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.add,
                                        color: Color(0xFF00FFB2), size: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // Remove
                            GestureDetector(
                              onTap: () {
                                _removeFromCart(item.id);
                                setSheet(() {});
                                if (_cart.isEmpty) Navigator.pop(ctx);
                              },
                              child: const Icon(Icons.close,
                                  color: Colors.white24, size: 18),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(color: Colors.white10, height: 28),

                // Totals
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _totalRow('Subtotal', '$sym ${subtotal.toStringAsFixed(2)}'),
                      const SizedBox(height: 6),
                      _totalRow('VAT (15%)', '$sym ${tax.toStringAsFixed(2)}'),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL DUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$sym ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF00FFB2),
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Checkout button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFB2),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _checkoutCart(
                          subtotal: subtotal,
                          tax: tax,
                          total: total,
                          currencyCode: _currencyCode,
                          externalGateway: externalGateway,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Pay $sym ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────── Checkout ────────────────────────────

  Future<void> _checkoutCart({
    required double subtotal,
    required double tax,
    required double total,
    required String currencyCode,
    required String externalGateway,
  }) async {
    final cartSnapshot = Map<String, CartItem>.from(_cart);

    // Build a comma-separated product summary for the payment gateway
    final itemsSummary = cartSnapshot.values
        .map((i) => '${i.name} ×${i.quantity}')
        .join(', ');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutScreen(
          productId: 'cart_${DateTime.now().millisecondsSinceEpoch}',
          productName: 'Cart: $itemsSummary',
          amount: total,
          currency: currencyCode,
          sellerId: _uid,
          productImage: cartSnapshot.values.first.imageUrl,
        ),
      ),
    );

    if (result == true && mounted) {
      await _completePurchase(
        cartSnapshot: cartSnapshot,
        subtotal: subtotal,
        tax: tax,
        total: total,
        currencyCode: currencyCode,
        paymentMethod: externalGateway.isNotEmpty ? externalGateway : 'A-Chatz Secure Wallet',
      );
    }
  }

  Future<void> _completePurchase({
    required Map<String, CartItem> cartSnapshot,
    required double subtotal,
    required double tax,
    required double total,
    required String currencyCode,
    required String paymentMethod,
  }) async {
    final currentUid = AppAuth.instance.currentUser?.uid ?? '';
    final sym = _symbolForCode(currencyCode);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00FFB2)),
      ),
    );

    try {
      // Fetch buyer & seller profiles
      final buyerDoc =
          await AppDatabase.instance.table('users').doc(currentUid).get();
      final sellerDoc =
          await AppDatabase.instance.table('users').doc(_uid).get();

      final buyerData = buyerDoc.data() ?? {};
      final sellerData = sellerDoc.data() ?? {};

      final buyerName =
          buyerData['displayName'] ?? buyerData['username'] ?? 'Customer';
      final buyerPhone = buyerData['phoneNumber'] ?? 'N/A';
      final sellerBusinessName =
          sellerData['businessName'] ?? sellerData['username'] ?? 'Business';
      final sellerPhone = sellerData['phoneNumber'] ?? 'N/A';

      // Save order to Firestore
      final orderItems = cartSnapshot.values
          .map((i) => {
                'id': i.id,
                'name': i.name,
                'price': i.price,
                'quantity': i.quantity,
                'imageUrl': i.imageUrl,
              })
          .toList();

      final orderId = await AppDatabase.instance.table('orders').add({
        'buyerId': currentUid,
        'sellerId': _uid,
        'items': orderItems,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'currencyCode': currencyCode,
        'paymentMethod': paymentMethod,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      }).then((ref) => ref.id);

      // Find or create private chat
      final chatSnap = await AppDatabase.instance
          .table('chats')
          .where('type', isEqualTo: 'private')
          .where('memberIds', arrayContains: currentUid)
          .get();

      String? chatId;
      for (final doc in chatSnap.docs) {
        final members = List<String>.from(doc.data()['memberIds'] ?? []);
        if (members.contains(_uid)) {
          chatId = doc.id;
          break;
        }
      }

      if (chatId == null) {
        final newChatRef =
            await AppDatabase.instance.table('chats').add({
          'type': 'private',
          'memberIds': [currentUid, _uid],
          'title': '',
          'photoUrl': null,
          'lastMessage': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'admins': [],
          'pinnedMessageIds': [],
        });
        chatId = newChatRef.id;
      }

      // Build a rich receipt message
      final now = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
      final itemLines = cartSnapshot.values
          .map((i) =>
              '  • ${i.name} ×${i.quantity} @ $sym ${i.price.toStringAsFixed(2)} = $sym ${(i.price * i.quantity).toStringAsFixed(2)}')
          .join('\n');

      final receiptMsg = '''🧾 OFFICIAL RECEIPT
━━━━━━━━━━━━━━━━━━━━━━━━
🏪 Business: $sellerBusinessName
📞 Contact: $sellerPhone

👤 Customer: $buyerName
📱 Phone: $buyerPhone

📦 ITEMS PURCHASED:
$itemLines

💰 SUMMARY:
   Subtotal : $sym ${subtotal.toStringAsFixed(2)}
   VAT 15%  : $sym ${tax.toStringAsFixed(2)}
   ──────────────────────
   TOTAL    : $sym ${total.toStringAsFixed(2)}

💳 Payment: $paymentMethod
🗓  Date: $now
🔖 Order ID: $orderId

✅ Payment Successful
Thank you for your purchase! 🎉''';

      await ref.read(chatRepositoryProvider).sendText(chatId, receiptMsg);

      if (mounted) {
        Navigator.pop(context); // dismiss loading
        setState(() => _cart.clear()); // clear cart
        _triggerConfettiSuccess();

        // Show the receipt dialog
        await _showReceiptDialog(
          buyerName: buyerName,
          buyerPhone: buyerPhone,
          sellerName: sellerBusinessName,
          sellerPhone: sellerPhone,
          cartSnapshot: cartSnapshot,
          subtotal: subtotal,
          tax: tax,
          total: total,
          currencyCode: currencyCode,
          paymentMethod: paymentMethod,
          orderId: orderId,
          date: now,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Purchase failed: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ─────────────────────────────────── Receipt Dialog ─────────────────────

  Future<void> _showReceiptDialog({
    required String buyerName,
    required String buyerPhone,
    required String sellerName,
    required String sellerPhone,
    required Map<String, CartItem> cartSnapshot,
    required double subtotal,
    required double tax,
    required double total,
    required String currencyCode,
    required String paymentMethod,
    required String orderId,
    required String date,
  }) async {
    final sym = _symbolForCode(currencyCode);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121214),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FFB2).withOpacity(0.08),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00FFB2), Color(0xFF00C896)],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Order Confirmed!',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business & Buyer info
                      _receiptSection('🏪 Seller', [
                        sellerName,
                        sellerPhone,
                      ]),
                      const SizedBox(height: 14),
                      _receiptSection('👤 Customer', [
                        buyerName,
                        buyerPhone,
                      ]),
                      const SizedBox(height: 20),

                      // Items
                      const Text(
                        'ITEMS',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...cartSnapshot.values.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.imageUrl != null
                                      ? Image.network(
                                          item.imageUrl!,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _thumbPlaceholder(size: 44),
                                        )
                                      : _thumbPlaceholder(size: 44),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '$sym ${item.price.toStringAsFixed(2)} × ${item.quantity}',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$sym ${(item.price * item.quantity).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )),

                      const Divider(color: Colors.white10, height: 24),

                      // Totals
                      _totalRow('Subtotal', '$sym ${subtotal.toStringAsFixed(2)}'),
                      const SizedBox(height: 6),
                      _totalRow('VAT 15%', '$sym ${tax.toStringAsFixed(2)}'),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL PAID',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$sym ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF00FFB2),
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Payment method + order ID
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.credit_card,
                                    color: Colors.white38, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  paymentMethod,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.tag,
                                    color: Colors.white38, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Order #${orderId.substring(0, math.min(12, orderId.length))}',
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFB2),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Done 🎉',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────── Helpers ──────────────────────────────

  Widget _receiptSection(String label, List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        ...lines.map(
          (l) => Text(
            l,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Text(value,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 130,
      color: Colors.white.withOpacity(0.05),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white24, size: 40),
      ),
    );
  }

  Widget _thumbPlaceholder({double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.white30, size: 20),
    );
  }

  void _triggerConfettiSuccess() {
    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ConfettiLayer(
        onFinished: () {
          entry.remove();
        },
      ),
    );

    overlayState.insert(entry);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Currency Dropdown widget (for catalog owners)
// ─────────────────────────────────────────────────────────────────────────────

class _CurrencyDropdown extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onChanged;

  const _CurrencyDropdown({
    required this.selectedCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xFF1A1A1D),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Set Catalog Currency',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _kCurrencies.map((c) {
                    final isSelected = c['code'] == selectedCode;
                    return ListTile(
                      onTap: () => Navigator.pop(ctx, c['code']),
                      leading: Text(
                        c['symbol']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      title: Text(
                        c['label']!,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF00FFB2) : Colors.white,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF00FFB2), size: 20)
                          : null,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _symbolForCode(selectedCode),
              style: const TextStyle(
                color: Color(0xFF00FFB2),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              selectedCode,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti overlay
// ─────────────────────────────────────────────────────────────────────────────

class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer({required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < 90; i++) {
        final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * 1.2;
        final speed = 8.0 + _random.nextDouble() * 12.0;

        _particles.add(ConfettiParticle(
          x: size.width / 2,
          y: size.height * 0.85,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          color: _getRandomColor(),
          size: 6.0 + _random.nextDouble() * 8.0,
          rotation: _random.nextDouble() * math.pi * 2,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.3,
        ));
      }

      _controller.addListener(() {
        for (final p in _particles) {
          p.update();
        }
        setState(() {});
      });

      _controller.forward().then((_) => widget.onFinished());
    });
  }

  Color _getRandomColor() {
    final colors = [
      Colors.pinkAccent,
      Colors.cyanAccent,
      Colors.amberAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.redAccent,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: ConfettiPainter(_particles),
      ),
    );
  }
}

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.2;
    vx *= 0.98;
    rotation += rotationSpeed;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// _Field helper widget
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
