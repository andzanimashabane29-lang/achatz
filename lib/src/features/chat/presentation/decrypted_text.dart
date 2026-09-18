import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/core/services/encryption_service.dart';
import 'package:a_chatz/src/shared/widgets/link_preview_widget.dart';
import 'package:a_chatz/src/shared/widgets/invoice_receipt_card.dart';

class DecryptedText extends StatefulWidget {
  const DecryptedText({
    super.key,
    required this.cipherText,
    required this.senderId,
    required this.mine,
    required this.chatId,
    this.senderPublicKey,
    this.recipientPublicKey,
    this.builder,
  });

  final String cipherText;
  final String senderId;
  final bool mine;
  final String chatId;
  final String? senderPublicKey;
  final String? recipientPublicKey;
  final Widget? Function(String text)? builder;

  @override
  State<DecryptedText> createState() => _DecryptedTextState();
}

class _DecryptedTextState extends State<DecryptedText> {
  String? decrypted;

  @override
  void initState() {
    super.initState();
    decrypted = EncryptionService.decryptedCache[widget.cipherText];
    if (decrypted == null) {
      _decrypt();
    }
  }

  @override
  void didUpdateWidget(covariant DecryptedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cipherText != oldWidget.cipherText ||
        widget.senderPublicKey != oldWidget.senderPublicKey ||
        widget.recipientPublicKey != oldWidget.recipientPublicKey ||
        widget.senderId != oldWidget.senderId ||
        widget.mine != oldWidget.mine ||
        widget.chatId != oldWidget.chatId) {
      
      decrypted = EncryptionService.decryptedCache[widget.cipherText];
      if (decrypted == null) {
        _decrypt();
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _decrypt() async {
    try {
      final currentUid = AppAuth.instance.currentUser?.uid;
      if (currentUid == null) throw 'User not logged in';

      String? targetPublicKey = widget.mine ? widget.recipientPublicKey : widget.senderPublicKey;

      if (targetPublicKey == null) {
        String targetKeyUid = widget.senderId;

        if (widget.mine) {
          // Fetch chat to find the other member
          final chatDoc = await AppDatabase.instance.table('chats').doc(widget.chatId).get();
          final members = List<String>.from(chatDoc.data()?['memberIds'] ?? []);
          final otherUid = members.firstWhere((id) => id != currentUid, orElse: () => currentUid);
          targetKeyUid = otherUid;
        }

        final userDoc = await AppDatabase.instance.table('users').doc(targetKeyUid).get();
        targetPublicKey = userDoc.data()?['publicKey'];
      }

      if (targetPublicKey == null) throw 'No public key found';

      final res = await EncryptionService().decrypt(widget.cipherText, targetPublicKey);
      if (mounted) {
        setState(() {
          decrypted = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          decrypted = '[Decryption failed]';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = decrypted ?? '';
    if (decrypted == null) {
      return SizedBox(
        width: 100,
        height: 20,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 80,
            height: 8,
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black)
                  .withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
    }

    if (widget.builder != null) {
      final customWidget = widget.builder!(text);
      if (customWidget != null) return customWidget;
    }

    if (text.startsWith('🧾 RECEIPT')) {
      return InvoiceReceiptCard(text: text, mine: widget.mine);
    }

    final url = LinkPreviewHelper.extractUrl(text);
    if (url != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: widget.mine ? Colors.black : Colors.white,
              fontSize: 15,
              height: 1.25,
            ),
          ),
          LinkPreviewWidget(url: url, compact: true),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        color: widget.mine ? Colors.black : Colors.white,
        fontSize: 15,
        height: 1.25,
      ),
    );
  }
}
