import 'package:a_chatz/src/features/calls/data/call_repository.dart';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(
    AppDatabase.instance,
    AppAuth.instance,
  );
});

final incomingCallsProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref.read(callRepositoryProvider).incomingCalls();
});