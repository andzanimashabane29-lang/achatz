import 'package:flutter/material.dart';
import 'package:a_chatz/src/core/services/emergency_safety_service.dart';

class ActiveSafetyOverlay extends StatefulWidget {
  final Widget child;

  const ActiveSafetyOverlay({super.key, required this.child});

  @override
  State<ActiveSafetyOverlay> createState() => _ActiveSafetyOverlayState();
}

class _ActiveSafetyOverlayState extends State<ActiveSafetyOverlay> {
  void _onSafetyStateChanged() {
    setState(() {}); // Rebuild when EmergencySafetyService updates
  }

  @override
  void initState() {
    super.initState();
    EmergencySafetyService.instance.addListener(_onSafetyStateChanged);
  }

  @override
  void dispose() {
    EmergencySafetyService.instance.removeListener(_onSafetyStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safetyService = EmergencySafetyService.instance;
    final isSOSActive = safetyService.isSOSActive;
    final isProtocolActive = safetyService.isProtocolActive;

    return Stack(
      children: [
        widget.child,

        // SOS Active Visual Alert Overlay
        if (isSOSActive)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 6),
                ),
              ),
            ),
          ),

        // Arrived Safely Protocol Pill
        if (isProtocolActive)
          Positioned(
            top: MediaQuery.of(context).padding.top + 50,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_moon_outlined, color: Colors.greenAccent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Safety Protocol Active',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Cancel protocol
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E22),
                            title: const Text('Cancel Protocol?', style: TextStyle(color: Colors.white)),
                            content: const Text('Are you sure you want to stop the "Arrived Safely" location tracker?', style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('No', style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () {
                                  EmergencySafetyService.instance.cancelLocationBasedSafetyProtocol();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Yes, Cancel', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
