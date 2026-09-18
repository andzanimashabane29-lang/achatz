import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleCallSheet extends StatefulWidget {
  const ScheduleCallSheet({super.key, required this.chatId});
  final String chatId;

  @override
  State<ScheduleCallSheet> createState() => _ScheduleCallSheetState();
}

class _ScheduleCallSheetState extends State<ScheduleCallSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  String _callType = 'video'; // 'video' or 'voice'
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.greenAccent,
            onPrimary: Colors.black,
            surface: Color(0xFF1C1C1E),
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.greenAccent,
            onPrimary: Colors.black,
            surface: Color(0xFF1C1C1E),
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _scheduleMeeting() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting title'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final uid = AppAuth.instance.currentUser!.uid;
      final userDoc = await AppDatabase.instance.table('users').doc(uid).get();
      final organizerName = userDoc.data()?['username'] ?? 'Host';

      // Store the scheduled meeting in Firestore
      final meetingRef = await AppDatabase.instance.table('scheduled_calls').add({
        'chatId': widget.chatId,
        'organizerId': uid,
        'organizerName': organizerName,
        'title': title,
        'description': _descCtrl.text.trim(),
        'callType': _callType,
        'scheduledAt': Timestamp.fromDate(_selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'scheduled',
      });

      // Post the schedule card message in the chat
      final formattedDate = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
      final formattedTime = DateFormat('h:mm a').format(_selectedDate);
      final typeIcon = _callType == 'video' ? '📹' : '📞';
      final receiptText =
          '📅 SCHEDULED_CALL | MeetingId: ${meetingRef.id} | Title: $title | Type: $_callType | TypeIcon: $typeIcon | Date: $formattedDate | Time: $formattedTime | Organizer: $organizerName';

      await AppDatabase.instance
          .table('chats')
          .doc(widget.chatId)
          .table('messages')
          .add({
        'senderId': uid,
        'type': 'text',
        'cipherText': receiptText,
        'mediaUrl': null,
        'fileName': null,
        'durationMs': null,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'deletedFor': [],
        'deletedForEveryone': false,
        'reactions': {},
        'starredBy': [],
        'deliveredTo': {},
        'readBy': {},
        'isEncrypted': false,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
    final formattedTime = DateFormat('h:mm a').format(_selectedDate);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: const Color(0xEE101012),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.event_outlined, color: Colors.greenAccent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule a Call',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Plan your next meeting in advance',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Title
                _buildLabel('Meeting Title'),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('e.g. Weekly Sync, Project Review...'),
                ),
                const SizedBox(height: 18),

                // Description
                _buildLabel('Description (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: _inputDecoration('Add a short description or agenda...'),
                ),
                const SizedBox(height: 18),

                // Date & Time picker
                _buildLabel('Date & Time'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Colors.greenAccent, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formattedDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(formattedTime, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white30),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Call type selector
                _buildLabel('Call Type'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _TypeChip(
                      label: 'Video Call',
                      icon: Icons.videocam_outlined,
                      selected: _callType == 'video',
                      onTap: () => setState(() => _callType = 'video'),
                    ),
                    const SizedBox(width: 12),
                    _TypeChip(
                      label: 'Voice Call',
                      icon: Icons.call_outlined,
                      selected: _callType == 'voice',
                      onTap: () => setState(() => _callType = 'voice'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Schedule button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saving ? null : _scheduleMeeting,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      _saving ? 'Scheduling...' : 'Schedule Meeting',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.greenAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.greenAccent : Colors.white12,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.greenAccent : Colors.white38, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.greenAccent : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
