import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:flutter/material.dart';

class QuickRepliesScreen extends StatefulWidget {
  const QuickRepliesScreen({super.key});

  @override
  State<QuickRepliesScreen> createState() => _QuickRepliesScreenState();
}

class _QuickRepliesScreenState extends State<QuickRepliesScreen> {
  final uid = AppAuth.instance.currentUser!.uid;

  Future<void> _addReply() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1C),
        title: const Text('Add Quick Reply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Type your message...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await AppDatabase.instance
                    .table('users')
                    .doc(uid)
                    .table('quick_replies')
                    .add({
                  'text': controller.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Quick Replies',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 32),
                onPressed: _addReply,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Save messages you send often to reply instantly',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: AppDatabase.instance
                  .table('users')
                  .doc(uid)
                  .table('quick_replies')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No quick replies yet. Add your first one!', 
                      style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      color: const Color(0xFF242427),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.flash_on, color: Colors.greenAccent),
                        title: Text(data['text'] ?? '', style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => docs[index].reference.delete(),
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
    );
  }
}
