import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:a_chatz/src/features/calls/providers/call_providers.dart';

class ScheduledCallCard extends ConsumerWidget {
  const ScheduledCallCard({super.key, required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parse: 📅 SCHEDULED_CALL | MeetingId: X | Title: X | Type: X | TypeIcon: X | Date: X | Time: X | Organizer: X
    final parts = text.split('|');
    String meetingId = '';
    String title = 'Meeting';
    String callType = 'video';
    String typeIcon = '📹';
    String date = '';
    String time = '';
    String organizer = 'Host';

    for (final part in parts) {
      final kv = part.split(':');
      if (kv.length >= 2) {
        final key = kv[0].trim().toLowerCase();
        final val = kv.sublist(1).join(':').trim();
        if (key.contains('meetingid')) {
          meetingId = val;
        } else if (key.contains('title')) {
          title = val;
        } else if (key == 'type') {
          callType = val;
        } else if (key.contains('typeicon')) {
          typeIcon = val;
        } else if (key.contains('date')) {
          date = val;
        } else if (key.contains('time')) {
          time = val;
        } else if (key.contains('organizer')) {
          organizer = val;
        }
      }
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      stream: meetingId.isNotEmpty
          ? AppDatabase.instance.table('scheduled_calls').doc(meetingId).snapshots()
          : const Stream<DocumentSnapshot<Map<String, dynamic>>?>.empty(),
      builder: (context, snap) {
        final status = snap.data?.data()?['status'] as String? ?? 'scheduled';
        return _buildCard(context, ref, title, callType, typeIcon, date, time, organizer, meetingId, status);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    String title,
    String callType,
    String typeIcon,
    String date,
    String time,
    String organizer,
    String meetingId,
    String status,
  ) {
    final isCancelled = status == 'cancelled';
    final isCompleted = status == 'completed';
    final accentColor = isCancelled
        ? Colors.redAccent
        : isCompleted
            ? Colors.white38
            : Colors.greenAccent;

    return Container(
      width: 270,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF1E2A1E) : const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(typeIcon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scheduled ${callType == 'video' ? 'Video' : 'Voice'} Call',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Cancelled', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Ended', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Upcoming', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Date & Time
          _buildInfoRow(Icons.calendar_today_outlined, date, accentColor),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.access_time_outlined, time, accentColor),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.person_outline, 'By $organizer', accentColor),

          if (!isCancelled && !isCompleted) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connecting to meeting...'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  final repo = ref.read(callRepositoryProvider);
                  final result = await repo.joinScheduledCall(meetingId);
                  if (result != null && context.mounted) {
                    context.push(
                      '/call-room/${result['callId']}?caller=${result['caller']}&video=${result['video']}&name=${result['name']}',
                    );
                  }
                },
                icon: Icon(
                  callType == 'video' ? Icons.videocam_outlined : Icons.call_outlined,
                  size: 18,
                ),
                label: const Text('Join Meeting', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color accent) {
    return Row(
      children: [
        Icon(icon, color: accent.withOpacity(0.7), size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
