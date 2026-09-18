import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

void showVerificationInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: const [
          Icon(Icons.verified, color: Colors.blueAccent, size: 28),
          SizedBox(width: 10),
          Text(
            'Verified Account',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Text(
        'This account has been verified by Drixel Labs Inc, the parent company of A-Chatz. This badge confirms that Drixel Labs Inc has verified the authentic identity of this user or business entity.',
        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VerificationInfoScreen()),
            );
          },
          child: const Text('Learn More', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class VerificationInfoScreen extends StatelessWidget {
  const VerificationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Verification Guide', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: const [
                    Icon(Icons.verified, color: Colors.white, size: 64),
                    SizedBox(height: 12),
                    Text(
                      'Drixel Labs Inc Verification',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Authenticity and Trust on A-Chatz',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'What is the Blue Tick?',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'The blue verification tick is a mark of trust indicating that Drixel Labs Inc has reviewed and authenticated the account owner. It protects against impersonation and helps users find legitimate creators, businesses, and channels.',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),

              const Text(
                'Verification Criteria',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildStepItem(
                context,
                Icons.person_pin_outlined,
                'Authenticity',
                'Your account must represent a real registered person, active business, or recognized brand.',
              ),
              _buildStepItem(
                context,
                Icons.trending_up,
                'Activity',
                'Your account must be actively posting, communicating, and have a complete bio and profile picture.',
              ),
              _buildStepItem(
                context,
                Icons.description_outlined,
                'Documentation',
                'For individuals, a government-issued ID is required. For businesses, official registration certificates and office photos must be provided.',
              ),
              const SizedBox(height: 24),

              const Text(
                'How to Apply',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Go to your Profile settings, scroll down to the "Request Verification" option, fill out the form, upload the required documentation, and submit. The Drixel Labs Inc trust and safety team will review your application within 3–5 business days.',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),

              const Text(
                'When is Verification Removed?',
                style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Verification can be revoked immediately if you:\n'
                '• Attempt to impersonate other brands or individuals.\n'
                '• Engage in spam, scamming, or illegal activities.\n'
                '• Change your profile username or legal ownership details without re-applying.\n'
                '• Fail to maintain account security or violate our Terms of Service.',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(BuildContext context, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
