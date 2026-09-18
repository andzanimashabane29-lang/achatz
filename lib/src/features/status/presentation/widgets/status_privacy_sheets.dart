import 'package:a_chatz/src/features/chat/providers/contacts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MentionsPickerSheet extends ConsumerStatefulWidget {
  final List<String> initialMentions;

  const MentionsPickerSheet({
    super.key,
    required this.initialMentions,
  });

  @override
  ConsumerState<MentionsPickerSheet> createState() => _MentionsPickerSheetState();
}

class _MentionsPickerSheetState extends ConsumerState<MentionsPickerSheet> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialMentions);
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(myContactsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF101012),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3D),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            const SizedBox(height: 18),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mention Friends',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedIds.toList()),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Color(0xFFFC6D4A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Contacts list
            Expanded(
              child: contactsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFC6D4A)),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Error loading contacts: $err',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                data: (contacts) {
                  final filtered = contacts.where((contact) {
                    final name = contact.displayName.toLowerCase();
                    final email = contact.email.toLowerCase();
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No contacts found',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withOpacity(0.04),
                    ),
                    itemBuilder: (context, index) {
                      final contact = filtered[index];
                      final isSelected = _selectedIds.contains(contact.uid);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(contact.uid);
                            } else {
                              _selectedIds.add(contact.uid);
                            }
                          });
                        },
                        leading: CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: Text(
                            contact.displayName.isNotEmpty
                                ? contact.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          contact.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          contact.email,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                        trailing: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFC6D4A) : Colors.white30,
                              width: 2,
                            ),
                            color: isSelected ? const Color(0xFFFC6D4A) : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PrivacyOption { contacts, contactsExcept, onlyShareWith }

class AudiencePickerSheet extends ConsumerStatefulWidget {
  final List<String> initialExcludedIds;
  final List<String> initialAllowedIds;
  final PrivacyOption? initialOption;

  const AudiencePickerSheet({
    super.key,
    required this.initialExcludedIds,
    required this.initialAllowedIds,
    this.initialOption,
  });

  @override
  ConsumerState<AudiencePickerSheet> createState() => _AudiencePickerSheetState();
}

class _AudiencePickerSheetState extends ConsumerState<AudiencePickerSheet> {
  PrivacyOption _selectedOption = PrivacyOption.contacts;
  final Set<String> _tempExcludedIds = {};
  final Set<String> _tempAllowedIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempExcludedIds.addAll(widget.initialExcludedIds);
    _tempAllowedIds.addAll(widget.initialAllowedIds);

    if (widget.initialOption != null) {
      _selectedOption = widget.initialOption!;
    } else if (widget.initialAllowedIds.isNotEmpty) {
      _selectedOption = PrivacyOption.onlyShareWith;
    } else if (widget.initialExcludedIds.isNotEmpty) {
      _selectedOption = PrivacyOption.contactsExcept;
    } else {
      _selectedOption = PrivacyOption.contacts;
    }
  }

  void _onDone() {
    List<String> excluded = [];
    List<String> allowed = [];

    if (_selectedOption == PrivacyOption.contactsExcept) {
      excluded = _tempExcludedIds.toList();
    } else if (_selectedOption == PrivacyOption.onlyShareWith) {
      allowed = _tempAllowedIds.toList();
    }

    Navigator.pop(context, <String, dynamic>{
      'option': _selectedOption,
      'excludedIds': excluded,
      'allowedIds': allowed,
    });
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(myContactsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF101012),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3D),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            const SizedBox(height: 18),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Status Privacy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextButton(
                    onPressed: _onDone,
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Color(0xFFFC6D4A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Privacy Options Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildOptionTile(
                    title: 'My contacts',
                    subtitle: 'Share with all your contacts',
                    option: PrivacyOption.contacts,
                    icon: Icons.people_outline,
                  ),
                  _buildOptionTile(
                    title: 'My contacts except...',
                    subtitle: 'Exclude specific contacts',
                    option: PrivacyOption.contactsExcept,
                    icon: Icons.person_remove_alt_1_outlined,
                  ),
                  _buildOptionTile(
                    title: 'Only share with...',
                    subtitle: 'Share only with chosen friends',
                    option: PrivacyOption.onlyShareWith,
                    icon: Icons.favorite_border_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Search and selection list if not "My contacts"
            if (_selectedOption != PrivacyOption.contacts) ...[
              const Divider(color: Colors.white12, height: 24),
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Contacts selection list
              Expanded(
                child: contactsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFC6D4A)),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Error loading contacts: $err',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  data: (contacts) {
                    final filtered = contacts.where((contact) {
                      final name = contact.displayName.toLowerCase();
                      final email = contact.email.toLowerCase();
                      return name.contains(_searchQuery) || email.contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'No contacts found',
                          style: TextStyle(color: Colors.white38, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withOpacity(0.04),
                      ),
                      itemBuilder: (context, index) {
                        final contact = filtered[index];
                        final isExcludedSelected = _tempExcludedIds.contains(contact.uid);
                        final isAllowedSelected = _tempAllowedIds.contains(contact.uid);
                        final isSelected = _selectedOption == PrivacyOption.contactsExcept
                            ? isExcludedSelected
                            : isAllowedSelected;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            setState(() {
                              if (_selectedOption == PrivacyOption.contactsExcept) {
                                if (isSelected) {
                                  _tempExcludedIds.remove(contact.uid);
                                } else {
                                  _tempExcludedIds.add(contact.uid);
                                }
                              } else if (_selectedOption == PrivacyOption.onlyShareWith) {
                                if (isSelected) {
                                  _tempAllowedIds.remove(contact.uid);
                                } else {
                                  _tempAllowedIds.add(contact.uid);
                                }
                              }
                            });
                          },
                          leading: CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Text(
                              contact.displayName.isNotEmpty
                                  ? contact.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            contact.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            contact.email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                            ),
                          ),
                          trailing: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFC6D4A) : Colors.white30,
                                width: 2,
                              ),
                              color: isSelected ? const Color(0xFFFC6D4A) : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required PrivacyOption option,
    required IconData icon,
  }) {
    final isSelected = _selectedOption == option;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOption = option;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFFFC6D4A).withOpacity(0.4) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFFFC6D4A) : Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFFC6D4A) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<PrivacyOption>(
                value: option,
                groupValue: _selectedOption,
                activeColor: const Color(0xFFFC6D4A),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedOption = val;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
