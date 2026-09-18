import 'dart:async';
import 'package:a_chatz/src/features/status/data/channel_repository.dart';
import 'package:a_chatz/src/features/status/data/status_repository.dart';
import 'package:a_chatz/src/features/status/domain/channel_models.dart';
import 'package:a_chatz/src/features/status/domain/status_models.dart';
import 'package:a_chatz/src/features/auth/providers/auth_providers.dart';
import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:a_chatz/src/features/chat/providers/contacts_provider.dart';

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  return StatusRepository(
    AppDatabase.instance,
    AppAuth.instance,
  );
});

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepository(
    AppDatabase.instance,
    AppAuth.instance,
  );
});

final blockedUsersProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value({});
  return ref.watch(supabaseDbProvider)
      .table('users')
      .doc(uid)
      .table('blocked')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.id).toSet());
});

final statusesProvider = StreamProvider<List<StatusStory>>((ref) {
  final myUid = ref.watch(currentUserUidProvider);
  if (myUid == null) return Stream.value([]);
  return ref.watch(statusRepositoryProvider).statuses();
});

final filteredStatusesProvider = StreamProvider<List<StatusStory>>((ref) {
  final statusesAsync = ref.watch(statusesProvider).value ?? [];
  final myUid = ref.watch(currentUserUidProvider);
  if (myUid == null) return Stream.value([]);

  final blockedSet = ref.watch(blockedUsersProvider).value ?? {};
  final contacts = ref.watch(myContactsProvider).value ?? [];
  
  final allowedUids = <String>{};
  const officialUid = 'official_a_chatz';
  allowedUids.add(officialUid);
  allowedUids.add(myUid);
  
  for (final contact in contacts) {
    allowedUids.add(contact.uid);
  }

  final controller = StreamController<List<StatusStory>>();
  
  Future<void> runFilter() async {
    final result = <StatusStory>[];
    for (final s in statusesAsync) {
      if (s.isPromoted) {
        result.add(s);
        continue;
      }
      if (s.ownerId == myUid || s.ownerId == officialUid) {
        result.add(s);
        continue;
      }
      if (allowedUids.contains(s.ownerId) && !blockedSet.contains(s.ownerId)) {
        try {
          final doc = await AppDatabase.instance
              .table('users')
              .doc(s.ownerId)
              .table('contacts')
              .doc(myUid)
              .get();
          if (doc.exists) {
            result.add(s);
          }
        } catch (_) {
          // Default to hidden if permissions block it
        }
      }
    }
    if (!controller.isClosed) {
      controller.add(result);
    }
  }

  runFilter();
  
  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});

final myStatusesProvider = StreamProvider<List<StatusStory>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(statusRepositoryProvider).myStatuses();
});

final channelsProvider = StreamProvider<List<Channel>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value([]);
  return ref.read(channelRepositoryProvider).allChannels();
});

final followedChannelsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value(<String>{});
  return ref.watch(supabaseDbProvider)
      .table('users')
      .doc(uid)
      .table('followedChannels')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.id).toSet());
});

final followedChannelsRolesProvider = StreamProvider<Map<String, String>>((ref) {
  final uid = ref.watch(currentUserUidProvider);
  if (uid == null) return Stream.value(<String, String>{});
  return ref.watch(supabaseDbProvider)
      .table('users')
      .doc(uid)
      .table('followedChannels')
      .snapshots()
      .map((snap) {
        final Map<String, String> roles = {};
        for (final doc in snap.docs) {
          roles[doc.id] = doc.data()['role'] ?? 'member';
        }
        return roles;
      });
});