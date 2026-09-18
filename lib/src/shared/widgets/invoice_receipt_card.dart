import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
class InvoiceReceiptCard extends StatelessWidget {
  const InvoiceReceiptCard({
    super.key,
    required this.text,
    required this.mine,
  });

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    // Parse receipt string:
    // 🧾 RECEIPT | Product: {name} | Price: {price} | Qty: {qty} | Total: {total} | Method: {paymentMethod} | SellerId: {sellerId}
    final parts = text.split('|');
    String product = 'Product';
    String price = 'R 0.00';
    String qty = '1';
    String total = 'R 0.00';
    String method = 'Secure Wallet';
    String? sellerId;

    for (final part in parts) {
      final kv = part.split(':');
      if (kv.length >= 2) {
        final key = kv[0].trim().toLowerCase();
        final val = kv.sublist(1).join(':').trim();

        if (key.contains('product')) {
          product = val;
        } else if (key.contains('price')) {
          price = val;
        } else if (key.contains('qty')) {
          qty = val;
        } else if (key.contains('total')) {
          total = val;
        } else if (key.contains('method')) {
          method = val;
        } else if (key.contains('sellerid')) {
          sellerId = val;
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (sellerId == null || sellerId.trim().isEmpty) {
      return _buildReceiptContent(context, product, price, qty, total, method, null, isDark);
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: AppDatabase.instance.table('users').doc(sellerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildReceiptContent(context, product, price, qty, total, method, null, isDark);
        }
        final sellerData = snapshot.data?.data();
        return _buildReceiptContent(context, product, price, qty, total, method, sellerData, isDark);
      },
    );
  }

  Widget _buildReceiptContent(
    BuildContext context,
    String product,
    String price,
    String qty,
    String total,
    String method,
    Map<String, dynamic>? sellerData,
    bool isDark,
  ) {
    final isBusiness = sellerData != null && sellerData['accountType'] == 'business';
    final businessName = sellerData?['username'] ?? sellerData?['email'] ?? 'Premium Business';
    final businessLogo = sellerData?['photoUrl'] as String?;
    final businessAddress = sellerData?['businessAddress'] as String?;
    final businessWebsite = sellerData?['businessWebsite'] as String?;
    final businessCategory = sellerData?['businessCategory'] as String?;

    return Container(
      width: 270,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: mine 
            ? (isDark ? const Color(0xFF1E2A1E) : const Color(0xFFE2F3E2))
            : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: mine 
              ? Colors.greenAccent.withOpacity(0.35) 
              : Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // BUSINESS SENDER SPECIAL HEADER
          if (isBusiness) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                  backgroundImage: businessLogo != null && businessLogo.isNotEmpty
                      ? NetworkImage(businessLogo)
                      : null,
                  child: businessLogo == null || businessLogo.isEmpty
                      ? const Icon(Icons.storefront, color: Colors.redAccent, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.greenAccent, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            businessCategory ?? 'Verified Partner',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (businessAddress != null && businessAddress.trim().isNotEmpty)
              _buildBusinessMetaRow(Icons.location_on_outlined, businessAddress, isDark),
            if (businessWebsite != null && businessWebsite.trim().isNotEmpty)
              _buildBusinessMetaRow(Icons.language_outlined, businessWebsite, isDark),
            const SizedBox(height: 10),
          ] else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.greenAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine ? 'Invoice Sent' : 'Invoice Received',
                        style: TextStyle(
                          color: mine ? Colors.greenAccent : (isDark ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Text(
                        'Payment Complete',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Dashed divider separator line
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLinePainter(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildItemRow('Price:', price, isDark),
          _buildItemRow('Quantity:', qty, isDark),
          _buildItemRow('Method:', method, isDark),
          const SizedBox(height: 12),
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DashedLinePainter(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL PAID',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessMetaRow(IconData icon, String val, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 12),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              val,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
