import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Help Center'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            _FaqTile(
              question: 'How do I change my privacy settings?',
              answer: 'Go to Settings -> Privacy to manage who can see your profile photo, about info, and last seen status.',
            ),
            _FaqTile(
              question: 'Why does my status upload fail?',
              answer: 'Ensure you have granted the required storage permissions and that your media is within the allowed file size limits.',
            ),
            _FaqTile(
              question: 'How do I upload to my catalog?',
              answer: 'Go to your Profile -> Catalog, tap the plus icon and select an image from your gallery to add to your business catalog.',
            ),
            _FaqTile(
              question: 'Is A-Chatz secure and encrypted?',
              answer: 'Yes, A-Chatz secures your messages using client-side cryptographic encryption. Your content, media, and voice notes are secure during transmission.',
            ),
            _FaqTile(
              question: 'What happens if I disable Read Receipts?',
              answer: 'If you turn off Read Receipts, you will not send or receive read receipts (blue ticks) for messages. Additionally, you will not see who viewed your status updates, and others won\'t see when you view theirs.',
            ),
            _FaqTile(
              question: 'Why are my photos grouped in a grid?',
              answer: 'A-Chatz groups multiple images (2 or more) sent together in a WhatsApp-style collage. This keeps the conversation feed neat and organized.',
            ),
            _FaqTile(
              question: 'Can I change my email or delete my account?',
              answer: 'Yes, go to Profile -> Settings -> Account. From there you can securely verify and update your account email, or permanently delete your account profile.',
            ),
            _FaqTile(
              question: 'How do I configure high contrast or reduce animations?',
              answer: 'Go to Profile -> Accessibility. Toggle \'High Contrast\' to raise visibility of buttons and icons, or \'Reduce Animations\' to eliminate screen transitions and motion effects.',
            ),
            _FaqTile(
              question: 'I can\'t hear audio on statuses.',
              answer: 'Make sure your device is not on silent or vibrate mode. Adjusting the volume button while playing a status will also help.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      iconColor: Colors.white70,
      collapsedIconColor: Colors.white70,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Text(
            answer,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Contact Us'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.support_agent_outlined, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                'We\'re here to help!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'If you have any questions, require technical support, or need to report an issue, please reach out to our dedicated support team.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Text('Email Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SelectableText('support@a-chatz.com', style: TextStyle(color: Colors.blue[300], fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.email),
                label: const Text('Send us an Email'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email functionality will be available in production.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
