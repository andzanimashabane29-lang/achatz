import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';

class QuickReplySheet extends StatelessWidget {
  const QuickReplySheet({super.key, required this.onSelect});

  final Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final uid = AppAuth.instance.currentUser!.uid;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF101012),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Replies',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            StreamBuilder<QuerySnapshot>(
              stream: AppDatabase.instance
                  .table('users')
                  .doc(uid)
                  .table('quick_replies')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                
                final defaultReplies = [
                  'Hello! How can I help you today?',
                  'Thank you for your inquiry. We will get back to you shortly.',
                  'Yes, that is available. Would you like to proceed?',
                  'Sorry, we are currently closed. We will reply once we open.',
                ];

                final allReplies = [
                  ...docs.map((d) => d['text'] as String),
                  if (docs.isEmpty) ...defaultReplies,
                ];

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: allReplies.length,
                  itemBuilder: (context, index) {
                    final reply = allReplies[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.flash_on, color: Colors.greenAccent),
                      title: Text(reply, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        onSelect(reply);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
