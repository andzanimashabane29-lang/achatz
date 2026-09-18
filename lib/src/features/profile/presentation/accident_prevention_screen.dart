import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

class AccidentPreventionScreen extends StatefulWidget {
  const AccidentPreventionScreen({super.key});

  @override
  State<AccidentPreventionScreen> createState() => _AccidentPreventionScreenState();
}

class _AccidentPreventionScreenState extends State<AccidentPreventionScreen> {
  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Accident Prevention HUD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 64),
            SizedBox(height: 24),
            Text(
              'Coming Soon',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 12),
            Text(
              'A-Chatz Smart Driving Radar is currently in development.\nStay tuned for updates!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
