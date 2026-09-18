import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'package:flutter/material.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

class BusinessHoursScreen extends StatefulWidget {
  const BusinessHoursScreen({super.key});

  @override
  State<BusinessHoursScreen> createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  bool _businessHoursEnabled = false;
  bool _loading = true;
  bool _saving = false;

  final Map<String, Map<String, dynamic>> _hours = {
    'monday': {'enabled': true, 'start': '09:00', 'end': '17:00'},
    'tuesday': {'enabled': true, 'start': '09:00', 'end': '17:00'},
    'wednesday': {'enabled': true, 'start': '09:00', 'end': '17:00'},
    'thursday': {'enabled': true, 'start': '09:00', 'end': '17:00'},
    'friday': {'enabled': true, 'start': '09:00', 'end': '17:00'},
    'saturday': {'enabled': false, 'start': '09:00', 'end': '17:00'},
    'sunday': {'enabled': false, 'start': '09:00', 'end': '17:00'},
  };

  User? get user => AppAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (user == null) return;
    try {
      final doc = await AppDatabase.instance.table('users').doc(user!.uid).get();
      final data = doc.data() ?? {};
      
      setState(() {
        _businessHoursEnabled = data['businessHoursEnabled'] ?? false;
        
        final savedHours = data['businessHours'] as Map<String, dynamic>?;
        if (savedHours != null) {
          savedHours.forEach((day, value) {
            if (_hours.containsKey(day) && value is Map) {
              _hours[day] = {
                'enabled': value['enabled'] ?? false,
                'start': value['start'] ?? '09:00',
                'end': value['end'] ?? '17:00',
              };
            }
          });
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (user == null || _saving) return;
    setState(() => _saving = true);
    
    try {
      await AppDatabase.instance.table('users').doc(user!.uid).set({
        'businessHoursEnabled': _businessHoursEnabled,
        'businessHours': _hours,
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business hours saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving hours: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _selectTime(String day, bool isStart) async {
    final currentVal = isStart ? _hours[day]!['start'] : _hours[day]!['end'];
    final parts = currentVal.split(':');
    final initialHour = int.tryParse(parts[0]) ?? 9;
    final initialMin = int.tryParse(parts[1]) ?? 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMin),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.redAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _hours[day]![isStart ? 'start' : 'end'] = '$hourStr:$minStr';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Business Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure your business hours. Customers will see if you are Open or Closed.',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: SwitchListTile(
                  value: _businessHoursEnabled,
                  activeColor: Colors.red,
                  title: const Text('Enable Business Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    'Calculate and display open/closed status dynamically.',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  onChanged: (val) {
                    setState(() => _businessHoursEnabled = val);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 24),

              if (_businessHoursEnabled) ...[
                _buildSectionHeader('Weekly Schedule'),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dayKeys.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final day = dayKeys[index];
                    final dayData = _hours[day]!;
                    final enabled = dayData['enabled'] as bool;
                    final start = dayData['start'] as String;
                    final end = dayData['end'] as String;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2C2C2C)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  day.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  enabled ? 'Open' : 'Closed',
                                  style: TextStyle(
                                    color: enabled ? Colors.greenAccent : Colors.white30,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: enabled,
                            activeColor: Colors.greenAccent,
                            onChanged: (val) {
                              setState(() {
                                _hours[day]!['enabled'] = val;
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          if (enabled) ...[
                            TextButton(
                              onPressed: () => _selectTime(day, true),
                              child: Text(
                                start,
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            const Text('to', style: TextStyle(color: Colors.white54)),
                            TextButton(
                              onPressed: () => _selectTime(day, false),
                              child: Text(
                                end,
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ] else ...[
                            const Expanded(
                              flex: 4,
                              child: Text(
                                'Closed all day',
                                textAlign: TextAlign.right,
                                style: TextStyle(color: Colors.white24, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],

              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _saveSettings,
                child: _saving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFFA7A7A7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
