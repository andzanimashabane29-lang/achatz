import 'dart:io';

import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:a_chatz/src/features/chat/providers/contacts_provider.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:a_chatz/src/features/chat/presentation/communities_screen.dart';
import 'package:go_router/go_router.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  final selectedMembers = <String>{};

  File? groupPhoto;
  bool creating = false;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickGroupPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    final filePath = result?.files.single.path;

    if (filePath != null) {
      setState(() => groupPhoto = File(filePath));
    }
  }

  Future<void> createGroup() async {
    final title = nameController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name is required')),
      );
      return;
    }

    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member')),
      );
      return;
    }

    setState(() => creating = true);

    try {
      final chatId = await ref.read(chatRepositoryProvider).createGroupChat(
            title: title,
            description: descriptionController.text.trim(),
            memberIds: selectedMembers.toList(),
            photoFile: groupPhoto,
          );

      if (mounted) {
        context.pushReplacement('/chat/$chatId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create group: $e')),
        );
      }
    }

    if (mounted) setState(() => creating = false);
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const Expanded(
                child: Text(
                  'New group',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: pickGroupPhoto,
              child: CircleAvatar(
                radius: 54,
                backgroundColor: Colors.white,
                backgroundImage:
                    groupPhoto != null ? FileImage(groupPhoto!) : null,
                child: groupPhoto == null
                    ? const Icon(Icons.camera_alt, color: Colors.black, size: 34)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Group name',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
              hintText: 'Group description',
              prefixIcon: Icon(Icons.info_outline),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Add members',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final contactsAsync = ref.watch(myContactsProvider);
                return contactsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
                  data: (contacts) {
                    if (contacts.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_outlined, color: Colors.white24, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'No contacts yet.',
                              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Add contacts first to create a group.',
                              style: TextStyle(color: Colors.white24, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: contacts.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF202024)),
                      itemBuilder: (_, i) {
                        final contact = contacts[i];
                        final selected = selectedMembers.contains(contact.uid);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            setState(() {
                              selected
                                  ? selectedMembers.remove(contact.uid)
                                  : selectedMembers.add(contact.uid);
                            });
                          },
                          leading: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Text(
                              contact.displayName.isNotEmpty
                                  ? contact.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            contact.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(contact.email),
                          trailing: Icon(
                            selected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: selected ? Colors.greenAccent : null,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: creating ? null : createGroup,
            icon: creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(creating ? 'Creating...' : 'Create group'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
              );
            },
            icon: const Icon(Icons.people_outline, size: 18),
            label: const Text('Manage Communities', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}