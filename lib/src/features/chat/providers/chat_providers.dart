import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/features/chat/data/chat_repository.dart';
import 'package:a_chatz/src/features/chat/domain/chat_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseDbProvider), ref.watch(supabaseAuthProvider));
});

final myChatsProvider = StreamProvider<List<ChatThread>>((ref) {
  ref.keepAlive();
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(chatRepositoryProvider).myChats();
});

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  ref.keepAlive();
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(chatRepositoryProvider).messages(chatId);
});

final pinnedChatsProvider = StreamProvider<List<String>>((ref) {
  ref.keepAlive();
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(supabaseDbProvider)
      .table('users')
      .doc(uid)
      .snapshots()
      .map((snap) => List<String>.from(snap.data()?['pinnedChats'] ?? []));
});

final favoriteChatsProvider = StreamProvider<List<String>>((ref) {
  ref.keepAlive();
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(supabaseDbProvider)
      .table('users')
      .doc(uid)
      .snapshots()
      .map((snap) => List<String>.from(snap.data()?['favoriteChats'] ?? []));
});

final archivedChatsProvider = StreamProvider<List<ChatThread>>((ref) {
  ref.keepAlive();
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(chatRepositoryProvider).archivedChats();
});

final chatDetailsProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, chatId) {
  return ref.watch(supabaseDbProvider)
      .table('chats')
      .doc(chatId)
      .snapshots()
      .map((doc) => doc.data());
});
