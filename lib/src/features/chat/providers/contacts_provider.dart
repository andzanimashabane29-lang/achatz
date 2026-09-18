import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/features/chat/domain/contact_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final myContactsProvider = StreamProvider<List<AppContact>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);

  return AppDatabase.instance
      .table('users')
      .doc(uid)
      .table('contacts')
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => AppContact.fromMap(doc.id, doc.data() ?? {}))
          .toList());
});
