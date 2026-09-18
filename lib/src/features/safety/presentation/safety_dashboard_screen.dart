import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:a_chatz/src/core/services/emergency_safety_service.dart';
import 'package:a_chatz/src/features/chat/providers/contacts_provider.dart';

class SafetyDashboardScreen extends ConsumerStatefulWidget {
  const SafetyDashboardScreen({super.key});

  @override
  ConsumerState<SafetyDashboardScreen> createState() => _SafetyDashboardScreenState();
}

class _SafetyDashboardScreenState extends ConsumerState<SafetyDashboardScreen> {
  bool _shakeEnabled = false;
  bool _sosActive = false;
  List<String> _selectedContactUids = [];

  final TextEditingController _destinationNameController = TextEditingController(text: "Sandton City");
  final TextEditingController _latController = TextEditingController(text: "-26.1076");
  final TextEditingController _lngController = TextEditingController(text: "28.0567");

  String _selectedPreset = 'Sandton City';
  final List<Map<String, dynamic>> _presets = [
    {'name': 'Sandton City', 'lat': -26.1076, 'lng': 28.0567},
    {'name': 'UCT Campus', 'lat': -33.9573, 'lng': 18.4612},
    {'name': 'Durban Beachfront', 'lat': -29.8587, 'lng': 31.0418},
    {'name': 'Custom Destination', 'lat': 0.0, 'lng': 0.0},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _locateUser();
  }

  Future<void> _locateUser() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _latController.text = position.latitude.toStringAsFixed(6);
            _lngController.text = position.longitude.toStringAsFixed(6);
            _selectedPreset = 'Custom Destination';
            _destinationNameController.text = "My Location Destination";
          });
        }
      }
    } catch (e) {
      debugPrint('Error locating user on start: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shakeEnabled = prefs.getBool('safety_shake_enabled') ?? false;
      _selectedContactUids = prefs.getStringList('emergency_contact_uids') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency & Safety', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS Button
            Center(
              child: GestureDetector(
                onLongPress: () async {
                  setState(() => _sosActive = true);
                  await EmergencySafetyService.instance.triggerSOS();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SOS Triggered! Location sent to contacts.'), backgroundColor: Colors.redAccent),
                  );
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) setState(() => _sosActive = false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _sosActive ? 180 : 160,
                  height: _sosActive ? 180 : 160,
                  decoration: BoxDecoration(
                    color: _sosActive ? Colors.red : Colors.redAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.5),
                        blurRadius: _sosActive ? 30 : 15,
                        spreadRadius: _sosActive ? 10 : 5,
                      )
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'HOLD TO SOS',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Shake to alert
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                title: const Text('Shake to Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Shake phone 3 times rapidly to trigger SOS', style: TextStyle(color: Colors.grey, fontSize: 12)),
                activeColor: Colors.redAccent,
                value: _shakeEnabled,
                onChanged: (val) {
                  setState(() => _shakeEnabled = val);
                  EmergencySafetyService.instance.toggleShakeToAlert(val);
                },
              ),
            ),
            const SizedBox(height: 16),

            ListenableBuilder(
              listenable: EmergencySafetyService.instance,
              builder: (context, _) {
                final service = EmergencySafetyService.instance;
                final isActive = service.isProtocolActive;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Text('Arrived Safely Protocol', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Automatically send an "I arrived safely" message with your location to your emergency contacts when you arrive at your destination.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      if (isActive) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TRIP IN PROGRESS',
                                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Destination: ${service.destinationName}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'Coordinates: ${service.destinationLatitude}, ${service.destinationLongitude}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                                  foregroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('Cancel Trip'),
                                onPressed: () {
                                  service.cancelLocationBasedSafetyProtocol();
                                },
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Location Autocomplete Search
                        Autocomplete<Map<String, dynamic>>(
                          optionsBuilder: (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<Map<String, dynamic>>.empty();
                            }
                            try {
                              final query = Uri.encodeComponent(textEditingValue.text);
                              final response = await http.get(
                                Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5'),
                                headers: {'User-Agent': 'com.achatz.app'},
                              );
                              if (response.statusCode == 200) {
                                final List<dynamic> data = jsonDecode(response.body);
                                return data.map((e) => e as Map<String, dynamic>);
                              }
                            } catch (_) {}
                            return const Iterable<Map<String, dynamic>>.empty();
                          },
                          displayStringForOption: (option) => option['display_name'] ?? '',
                          onSelected: (option) {
                            setState(() {
                              _destinationNameController.text = option['name'] ?? option['display_name']?.split(',').first ?? 'Selected Location';
                              _latController.text = option['lat'];
                              _lngController.text = option['lon'];
                              _selectedPreset = 'Custom Destination';
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                            // Sync controller
                            if (controller.text.isEmpty && _destinationNameController.text.isNotEmpty) {
                              controller.text = _destinationNameController.text;
                            }
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Search Destination...',
                                labelStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: const Color(0xFF2A2A2E),
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                color: const Color(0xFF1E1E22),
                                elevation: 4.0,
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width - 64, // approximate padding
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(option['display_name'] ?? '', style: const TextStyle(color: Colors.white)),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const Text('Tap map to select destination:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(
                                  double.tryParse(_latController.text) ?? -26.1076,
                                  double.tryParse(_lngController.text) ?? 28.0567,
                                ),
                                initialZoom: 13,
                                onTap: (tapPosition, point) {
                                  setState(() {
                                    _latController.text = point.latitude.toStringAsFixed(6);
                                    _lngController.text = point.longitude.toStringAsFixed(6);
                                    _selectedPreset = 'Custom Destination';
                                    _destinationNameController.text = "Map Pin Destination";
                                  });
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.achatz.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(
                                        double.tryParse(_latController.text) ?? -26.1076,
                                        double.tryParse(_lngController.text) ?? 28.0567,
                                      ),
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_on,
                                        size: 40,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.withOpacity(0.2),
                              foregroundColor: Colors.greenAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              final name = _destinationNameController.text.trim();
                              final lat = double.tryParse(_latController.text) ?? 0.0;
                              final lng = double.tryParse(_lngController.text) ?? 0.0;
                              if (name.isEmpty || lat == 0.0 || lng == 0.0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter valid destination details.'), backgroundColor: Colors.redAccent),
                                );
                                return;
                              }
                              service.startLocationBasedSafetyProtocol(lat: lat, lng: lng, name: name);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Location tracking protocol started for $name.'), backgroundColor: Colors.green),
                              );
                            },
                            child: const Text('Start Location Trip', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Manage Emergency Contacts
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.people_alt_outlined, color: Colors.white),
                title: const Text('Manage Emergency Contacts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Select who receives your SOS alerts', style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1E1E22),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) {
                      return Consumer(
                        builder: (context, ref, _) {
                          final contactsAsync = ref.watch(myContactsProvider);
                          return contactsAsync.when(
                            data: (contacts) {
                              if (contacts.isEmpty) {
                                return const SafeArea(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Text('No contacts found. Please add contacts in chats tab first.', style: TextStyle(color: Colors.white70)),
                                  ),
                                );
                              }
                              return SafeArea(
                                child: StatefulBuilder(
                                  builder: (ctx, setLocalState) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 16),
                                        const Text('Select Emergency Contacts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        Flexible(
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: contacts.length,
                                            itemBuilder: (context, idx) {
                                              final contact = contacts[idx];
                                              final isSelected = _selectedContactUids.contains(contact.uid);
                                              return CheckboxListTile(
                                                title: Text(contact.displayName, style: const TextStyle(color: Colors.white)),
                                                subtitle: Text(contact.phoneNumber ?? contact.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                value: isSelected,
                                                activeColor: Colors.redAccent,
                                                onChanged: (val) async {
                                                  setLocalState(() {
                                                    if (val == true) {
                                                      _selectedContactUids.add(contact.uid);
                                                    } else {
                                                      _selectedContactUids.remove(contact.uid);
                                                    }
                                                  });
                                                  final prefs = await SharedPreferences.getInstance();
                                                  await prefs.setStringList('emergency_contact_uids', _selectedContactUids);
                                                  setState(() {});
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, _) => Center(child: Text('Error loading contacts: $err', style: const TextStyle(color: Colors.redAccent))),
                          );
                        },
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
