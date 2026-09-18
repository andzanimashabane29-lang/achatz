import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:a_chatz/src/features/moderation/data/moderation_repository.dart';
import 'package:a_chatz/src/features/chat/providers/chat_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:a_chatz/src/shared/widgets/ambient_background.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(AppDatabase.instance);
});

final reportedUsersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(moderationRepositoryProvider).reportedUsers();
});

final verificationRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(moderationRepositoryProvider).verificationRequests();
});

class ModerationDashboardScreen extends ConsumerWidget {
  const ModerationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AmbientBackground(
      theme: ChatThemePreset.neonEclipse,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Admin Dashboard',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
                Text('By Founders: Anelisa Thelejane & Andzani Mashabane',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.greenAccent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            bottom: const TabBar(
              indicatorColor: Colors.blueAccent,
              tabs: [
                Tab(text: 'Reports'),
                Tab(text: 'Verification'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.campaign_outlined, color: Colors.blueAccent),
                tooltip: 'Broadcast Message',
                onPressed: () => _showBroadcastDialog(context, ref),
              ),
            ],
          ),
          body: const TabBarView(
            children: [
              _ReportsTab(),
              _VerificationTab(),
            ],
          ),
        ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String selectedType = 'text';
    XFile? pickedImageOrVideo;
    PlatformFile? pickedAudio;
    bool isUploading = false;
    double uploadProgress = 0.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final picker = ImagePicker();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Official Broadcast Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E1E22),
                    value: selectedType,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Broadcast Type',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'text', child: Text('Text Message')),
                      DropdownMenuItem(value: 'image', child: Text('Image Broadcast')),
                      DropdownMenuItem(value: 'video', child: Text('Video Broadcast')),
                      DropdownMenuItem(value: 'audio', child: Text('Voice Note / Audio')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                          pickedImageOrVideo = null;
                          pickedAudio = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedType != 'text') ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pickedAudio != null
                                ? 'Selected Audio: ${pickedAudio!.name}'
                                : pickedImageOrVideo != null
                                    ? 'Selected file: ${pickedImageOrVideo!.name}'
                                    : 'No media selected',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            if (selectedType == 'image') {
                              final file = await picker.pickImage(source: ImageSource.gallery);
                              if (file != null) {
                                setDialogState(() {
                                  pickedImageOrVideo = file;
                                });
                              }
                            } else if (selectedType == 'video') {
                              final file = await picker.pickVideo(source: ImageSource.gallery);
                              if (file != null) {
                                setDialogState(() {
                                  pickedImageOrVideo = file;
                                });
                              }
                            } else if (selectedType == 'audio') {
                              final result = await FilePicker.platform.pickFiles(type: FileType.audio);
                              if (result != null && result.files.isNotEmpty) {
                                setDialogState(() {
                                  pickedAudio = result.files.first;
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.attach_file, color: Colors.blueAccent, size: 18),
                          label: const Text('Choose', style: TextStyle(color: Colors.blueAccent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: selectedType == 'text'
                          ? 'Type your official announcement...'
                          : 'Add caption (optional)...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF2A2A2E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: uploadProgress,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uploading media: ${(uploadProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: isUploading
                    ? null
                    : () async {
                        final text = controller.text.trim();
                        if (selectedType == 'text' && text.isEmpty) return;
                        if (selectedType != 'text' && pickedImageOrVideo == null && pickedAudio == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a media file to broadcast.')),
                          );
                          return;
                        }

                        setDialogState(() {
                          isUploading = true;
                          uploadProgress = 0.0;
                        });

                        try {
                          String? mediaUrl;
                          String? fileName;

                          if (selectedType != 'text') {
                            final time = DateTime.now().millisecondsSinceEpoch;
                            final extension = pickedAudio != null
                                ? pickedAudio!.extension ?? 'mp3'
                                : pickedImageOrVideo!.path.split('.').last;
                            fileName = 'broadcast_${time}.${extension}';
                            final storageRef = AppStorage.instance.ref().child('official_broadcasts/$fileName');

                            UploadTask uploadTask;
                            if (kIsWeb) {
                              final bytes = pickedAudio != null
                                  ? pickedAudio!.bytes!
                                  : await pickedImageOrVideo!.readAsBytes();
                              uploadTask = storageRef.putData(bytes);
                            } else {
                              final path = pickedAudio != null ? pickedAudio!.path! : pickedImageOrVideo!.path;
                              uploadTask = storageRef.putFile(File(path));
                            }

                            uploadTask.snapshotEvents.listen((event) {
                              final progress = event.bytesTransferred / event.totalBytes;
                              setDialogState(() {
                                uploadProgress = progress.isNaN ? 0.0 : progress;
                              });
                            });

                            final snap = await uploadTask;
                            mediaUrl = await snap.ref.getDownloadURL();
                          }

                          await ref.read(chatRepositoryProvider).broadcastOfficialMessage(
                            text.isEmpty && selectedType != 'text' ? 'Broadcast Media' : text,
                            type: selectedType,
                            mediaUrl: mediaUrl,
                            fileName: fileName,
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Broadcast sent successfully!'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isUploading = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to broadcast: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                child: const Text('Send to Everyone', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportedUsersProvider);
    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(
            child: Text('No pending reports', style: TextStyle(color: Colors.white54)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            return _ReportCard(report: reports[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _VerificationTab extends ConsumerStatefulWidget {
  const _VerificationTab();

  @override
  ConsumerState<_VerificationTab> createState() => _VerificationTabState();
}

class _VerificationTabState extends ConsumerState<_VerificationTab> {
  final _uidController = TextEditingController();
  bool _isRevoking = false;

  Future<void> _revokeVerification() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) return;

    setState(() => _isRevoking = true);
    try {
      await ref.read(moderationRepositoryProvider).removeVerification(uid);
      _uidController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification status revoked successfully!'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke verification: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verificationAsync = ref.watch(verificationRequestsProvider);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REVOKE USER VERIFICATION',
                style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _uidController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Enter User UID',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _isRevoking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.redAccent),
                        )
                      : TextButton(
                          onPressed: _revokeVerification,
                          child: const Text('REVOKE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: verificationAsync.when(
            data: (requests) {
              if (requests.isEmpty) {
                return const Center(
                  child: Text('No pending verification requests', style: TextStyle(color: Colors.white54)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  return _VerificationCard(request: requests[index]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(moderationRepositoryProvider);
    final reportedUid = report['reportedUserId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.report_problem, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reported User: ${reportedUid.toString().substring(0, 8)}...',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      'Reason: ${report['reason'] ?? 'No reason provided'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => repo.dismissReport(report['id']),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => repo.resolveReport(report['id'], reportedUid),
                  child: const Text('Ban User'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends ConsumerWidget {
  const _VerificationCard({required this.request});
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(moderationRepositoryProvider);
    final uid = request['userId'] ?? 'Unknown User';
    final requestedTier = request['businessType'] ?? 'Unknown Business Type';
    final legalName = request['legalName'] ?? 'No Legal Name';
    final idNumber = request['idNumber'] ?? '';
    final residence = request['residence'] ?? '';
    final businessInfo = request['businessInfo'] ?? '';
    final handles = request['handles'] ?? '';
    final documentUrls = (request['documentUrls'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.verified, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Request',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      'UID: ${uid.toString().substring(0, 8)}... | Tier: $requestedTier',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text('Legal Name: $legalName', style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          if (idNumber.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text('ID Number: $idNumber', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          if (residence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text('Residence: $residence', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          if (businessInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text('Business Info: $businessInfo', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          if (handles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text('Social Handles: $handles', style: const TextStyle(color: Colors.blue, fontSize: 13)),
            ),
          if (documentUrls.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Uploaded Documents:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            ...documentUrls.map((url) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: SelectableText(url.toString(), style: const TextStyle(color: Colors.blue, fontSize: 12)),
            )).toList(),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => repo.rejectVerification(request['id']),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => repo.approveVerification(request['id'], uid, requestedTier),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
