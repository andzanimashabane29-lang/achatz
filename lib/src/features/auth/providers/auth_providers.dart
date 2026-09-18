import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseAuthProvider = Provider((_) => AppAuth.instance);
final supabaseDbProvider = Provider((_) => AppDatabase.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseAuthProvider), ref.watch(supabaseDbProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authState();
});

final currentUserUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

final currentUserProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value(null);
  
  return ref.watch(supabaseDbProvider)
      .table('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data());
});

final userProfileProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  return ref.watch(supabaseDbProvider)
      .table('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data());
});
