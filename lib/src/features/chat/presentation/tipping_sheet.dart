import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TippingSheet extends StatefulWidget {
  final String chatPartnerName;
  final Function(double amount) onTipSuccess;

  const TippingSheet({
    super.key,
    required this.chatPartnerName,
    required this.onTipSuccess,
  });

  @override
  State<TippingSheet> createState() => _TippingSheetState();
}

class _TippingSheetState extends State<TippingSheet> {
  double _amount = 10.0;
  bool _processing = false;
  bool _success = false;

  final _cardNoController = TextEditingController(text: '4111 5555 6666 7777');
  final _expiryController = TextEditingController(text: '09/29');
  final _cvvController = TextEditingController(text: '999');

  @override
  void dispose() {
    _cardNoController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _processTip() {
    setState(() {
      _processing = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _processing = false;
          _success = true;
        });

        HapticFeedback.vibrate();

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
            widget.onTipSuccess(_amount);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 80),
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
                    'Tip Sent!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You sent a \$${_amount.toStringAsFixed(2)} tip to ${widget.chatPartnerName}.',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.greenAccent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Support ${widget.chatPartnerName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Show your appreciation by sending a direct tip.',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Big dynamic amount display
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'TIP AMOUNT',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick presets
                  Row(
                    children: [5.0, 10.0, 20.0, 50.0].map((val) {
                      final selected = _amount == val;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _amount = val;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? Colors.greenAccent.withOpacity(0.15) : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? Colors.greenAccent : const Color(0xFF2C2C2C),
                              ),
                            ),
                            child: Text(
                              '\$$val',
                              style: TextStyle(
                                color: selected ? Colors.greenAccent : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Custom slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.greenAccent,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: Colors.greenAccent,
                      overlayColor: Colors.greenAccent.withOpacity(0.12),
                      valueIndicatorColor: Colors.greenAccent,
                      valueIndicatorTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    child: Slider(
                      value: _amount,
                      min: 1.0,
                      max: 100.0,
                      divisions: 99,
                      label: '\$${_amount.round()}',
                      onChanged: (val) {
                        setState(() {
                          _amount = val.roundToDouble();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'PAYMENT INFO',
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
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
                          label: 'Expiry',
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
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _processing ? null : _processTip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _processing
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text(
                              'Authorize & Send \$${_amount.toStringAsFixed(2)} Tip',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
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
