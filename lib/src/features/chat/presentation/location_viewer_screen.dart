import 'package:a_chatz/src/core/supabase/supabase.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

class LocationViewerScreen extends StatefulWidget {
  const LocationViewerScreen({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.senderId,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.isLive,
  });

  final String chatId;
  final String messageId;
  final String senderId;
  final double initialLatitude;
  final double initialLongitude;
  final bool isLive;

  @override
  State<LocationViewerScreen> createState() => _LocationViewerScreenState();
}

class _LocationViewerScreenState extends State<LocationViewerScreen> {
  final MapController _mapController = MapController();
  
  // Geolocation states
  LatLng? _currentLatLng;
  late LatLng _destinationLatLng;
  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<DocumentSnapshot>? _liveLocationSub;

  // Sender details
  String? _senderName;
  String? _senderPhotoUrl;

  // Map settings
  bool _showSatellite = false;
  
  // Routing states
  String _transportMode = 'driving'; // driving, foot, bicycle
  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  double _durationMin = 0.0;
  List<Map<String, dynamic>> _navigationSteps = [];
  bool _isRoutingLoading = false;
  String? _routingError;

  @override
  void initState() {
    super.initState();
    _destinationLatLng = LatLng(widget.initialLatitude, widget.initialLongitude);
    _initLocationTracking();
    _loadSenderProfile();
    if (widget.isLive) {
      _listenToLiveLocation();
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _liveLocationSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadSenderProfile() async {
    try {
      final snap = await AppDatabase.instance.table('users').doc(widget.senderId).get();
      if (snap.exists && mounted) {
        final data = snap.data();
        if (data != null) {
          setState(() {
            _senderName = data['displayName'] as String? ?? data['name'] as String? ?? 'User';
            _senderPhotoUrl = data['photoUrl'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading sender profile: $e');
    }
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _fetchRoute(); // Fetch route with whatever we have
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _fetchRoute();
        return;
      }
    } else if (permission == LocationPermission.deniedForever) {
      _fetchRoute();
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLatLng = LatLng(pos.latitude, pos.longitude);
        });
        _fetchRoute();
      }

      // Track live movement of current user
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position p) {
        if (mounted) {
          setState(() {
            _currentLatLng = LatLng(p.latitude, p.longitude);
          });
          _fetchRoute(); // Recalculate routing on the go
        }
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      _fetchRoute();
    }
  }

  void _listenToLiveLocation() {
    _liveLocationSub = AppDatabase.instance
        .table('chats')
        .doc(widget.chatId)
        .table('messages')
        .doc(widget.messageId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data();
      if (data == null) return;
      final lat = data['latitude'] as double?;
      final lng = data['longitude'] as double?;
      if (lat != null && lng != null) {
        setState(() {
          _destinationLatLng = LatLng(lat, lng);
        });
        _fetchRoute(); // Recalculate route as the sender moves
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_currentLatLng == null) return;

    if (mounted) {
      setState(() {
        _isRoutingLoading = true;
        _routingError = null;
      });
    }

    try {
      // Map modes to OSRM profiles
      String profile = 'driving';
      if (_transportMode == 'foot') profile = 'foot';
      if (_transportMode == 'bicycle') profile = 'bicycle';

      final url = 'https://router.project-osrm.org/route/v1/$profile/'
          '${_currentLatLng!.longitude},${_currentLatLng!.latitude};'
          '${_destinationLatLng.longitude},${_destinationLatLng.latitude}'
          '?steps=true&geometries=geojson';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first;
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coordinates = geometry['coordinates'] as List;
          final List<LatLng> points = coordinates.map((c) {
            return LatLng(c[1] as double, c[0] as double);
          }).toList();

          final distance = (route['distance'] as num).toDouble() / 1000.0; // convert to km
          final duration = (route['duration'] as num).toDouble() / 60.0; // convert to minutes

          final legs = route['legs'] as List;
          final List<Map<String, dynamic>> steps = [];
          if (legs.isNotEmpty) {
            final legSteps = legs.first['steps'] as List;
            for (final step in legSteps) {
              final maneuver = step['maneuver'] as Map<String, dynamic>;
              steps.add({
                'instruction': maneuver['instruction'] ?? 'Continue straight',
                'distance': (step['distance'] as num).toDouble(),
                'modifier': maneuver['modifier'],
                'type': maneuver['type'],
              });
            }
          }

          if (mounted) {
            setState(() {
              _routePoints = points;
              _distanceKm = distance;
              _durationMin = duration;
              _navigationSteps = steps;
              _isRoutingLoading = false;
            });
          }
        } else {
          throw Exception('No routes found');
        }
      } else {
        throw Exception('Routing API server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting route: $e');
      if (mounted) {
        setState(() {
          _routingError = 'Could not calculate directions';
          _isRoutingLoading = false;
        });
      }
    }
  }

  IconData _getManeuverIcon(String? type, String? modifier) {
    if (type == 'arrive') return Icons.flag;
    if (modifier == null) return Icons.navigation;
    if (modifier.contains('left')) return Icons.turn_left;
    if (modifier.contains('right')) return Icons.turn_right;
    if (modifier.contains('slight left')) return Icons.turn_slight_left;
    if (modifier.contains('slight right')) return Icons.turn_slight_right;
    return Icons.navigation;
  }

  @override
  Widget build(BuildContext context) {
    final osmLayer = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.achatz.messenger',
    );

    final satelliteLayer = TileLayer(
      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.achatz.messenger',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        title: Text(
          widget.isLive ? 'Live Navigation' : 'Location Viewer',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _showSatellite ? Icons.map_outlined : Icons.satellite_alt_outlined,
              color: Colors.white,
            ),
            tooltip: _showSatellite ? 'Standard Map' : 'Satellite Map',
            onPressed: () {
              setState(() {
                _showSatellite = !_showSatellite;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.greenAccent),
            tooltip: 'Recenter to Destination',
            onPressed: () {
              _mapController.move(_destinationLatLng, 15);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _destinationLatLng,
                    initialZoom: 14.0,
                  ),
                  children: [
                    _showSatellite ? satelliteLayer : osmLayer,
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: Colors.greenAccent.withOpacity(0.8),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // User's current location marker
                        if (_currentLatLng != null)
                          Marker(
                            point: _currentLatLng!,
                            width: 50.0,
                            height: 50.0,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Shared destination location marker
                        Marker(
                          point: _destinationLatLng,
                          width: 60.0,
                          height: 60.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.greenAccent, width: 2),
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF1E1E22),
                                  backgroundImage: _senderPhotoUrl != null && _senderPhotoUrl!.isNotEmpty
                                      ? NetworkImage(_senderPhotoUrl!)
                                      : null,
                                  child: _senderPhotoUrl == null || _senderPhotoUrl!.isEmpty
                                      ? const Icon(Icons.person, color: Colors.white, size: 18)
                                      : null,
                                ),
                              ),
                              const Icon(Icons.location_on, color: Colors.greenAccent, size: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isRoutingLoading)
                  const Positioned(
                    top: 16,
                    left: 16,
                    child: Card(
                      color: Color(0xFF1A1A1E),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.greenAccent,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Calculating Route...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Directions and bottom navigation info drawer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF16161A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _senderName != null ? "${_senderName}'s Location" : 'Location Directions',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_currentLatLng != null && _routingError == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                '${_distanceKm.toStringAsFixed(1)} km • ${_durationMin.round()} min away',
                                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (_currentLatLng == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 2.0),
                              child: Text(
                                'Enable GPS to start turn-by-turn navigation',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ),
                          if (_routingError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                _routingError!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      
                      // Recenter button
                      CircleAvatar(
                        backgroundColor: const Color(0xFF2E2E35),
                        child: IconButton(
                          icon: const Icon(Icons.navigation_outlined, color: Colors.white),
                          onPressed: () {
                            if (_currentLatLng != null) {
                              _mapController.move(_currentLatLng!, 15);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Transport Mode selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTransportButton('driving', Icons.directions_car_outlined, 'Car'),
                      _buildTransportButton('bicycle', Icons.directions_bike_outlined, 'Bicycle'),
                      _buildTransportButton('foot', Icons.directions_walk_outlined, 'Walking'),
                    ],
                  ),
                  
                  if (_currentLatLng != null && _navigationSteps.isNotEmpty) ...[
                    const Divider(color: Colors.white10, height: 24),
                    const Text(
                      'Turn-by-Turn Directions',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    // Show top turn directions
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        itemCount: _navigationSteps.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 12),
                        itemBuilder: (ctx, idx) {
                          final step = _navigationSteps[idx];
                          final distance = step['distance'] as double;
                          final distText = distance >= 1000
                              ? '${(distance / 1000).toStringAsFixed(1)} km'
                              : '${distance.round()} m';

                          return Row(
                            children: [
                              Icon(
                                _getManeuverIcon(step['type'], step['modifier']),
                                color: Colors.greenAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step['instruction'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      distText,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportButton(String mode, IconData icon, String label) {
    final isSelected = _transportMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _transportMode = mode;
        });
        _fetchRoute();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.greenAccent : const Color(0xFF2E2E35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
