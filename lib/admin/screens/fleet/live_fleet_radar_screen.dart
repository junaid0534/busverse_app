import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bus_ticket_system/services/route_coordinates_service.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class LiveFleetRadarScreen extends StatefulWidget {
  const LiveFleetRadarScreen({super.key});

  @override
  State<LiveFleetRadarScreen> createState() => _LiveFleetRadarScreenState();
}

class _LiveFleetRadarScreenState extends State<LiveFleetRadarScreen> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _activeFleet = [];
  Map<String, dynamic>? _selectedBus;
  bool _isLoading = true;
  String _selectedFilter = "all";
  Timer? _liveRefreshTimer;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color roseDanger = Color(0xFFEF4444);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadFleetData();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadFleetData(silent: true);
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFleetData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final buses = await DBHelper.instance.getAllBuses();
      final List<Map<String, dynamic>> fleet = [];

      final now = DateTime.now();
      for (int i = 0; i < buses.length; i++) {
        final b = buses[i];
        final from = (b['fromCity'] ?? b['from_city'] ?? 'Lahore').toString();
        final to = (b['toCity'] ?? b['to_city'] ?? 'Islamabad').toString();
        final busNum = (b['busNumber'] ?? b['bus_number'] ?? 'BV-${100 + i}').toString();
        final bName = (b['busName'] ?? b['bus_name'] ?? 'BusVerse Express').toString();

        final waypoints = RouteCoordinatesService.instance.getRouteWaypoints(from, to);
        if (waypoints.isNotEmpty) {
          // Calculate realistic active position along route based on bus index
          final offsetRatio = ((i * 0.23 + (now.minute / 60.0) * 0.4) % 0.85) + 0.05;
          final pointIdx = ((waypoints.length - 1) * offsetRatio).floor();
          final currentPos = waypoints[pointIdx];
          final nextPos = (pointIdx + 1 < waypoints.length) ? waypoints[pointIdx + 1] : waypoints.last;
          final heading = RouteCoordinatesService.instance.calculateBearing(currentPos, nextPos);

          final speed = (78.0 + (i * 3.5) % 18.0).clamp(65.0, 98.0);
          final status = (i % 5 == 0) ? 'delayed' : 'in_transit';

          fleet.add({
            'busId': b['id'] ?? (i + 1),
            'busNumber': busNum,
            'busName': bName,
            'fromCity': from,
            'toCity': to,
            'busClass': b['busClass'] ?? b['bus_class'] ?? 'Executive',
            'latitude': currentPos.latitude,
            'longitude': currentPos.longitude,
            'heading': heading,
            'speed': speed,
            'status': status,
            'passengersOnboard': 24 + (i * 3) % 18,
            'driverName': ['Muhammad Aslam', 'Rashid Khan', 'Tariq Mehmood', 'Imran Ali', 'Naveed Akhtar'][i % 5],
            'driverPhone': '0300-765432$i',
            'waypoints': waypoints,
          });
        }
      }

      if (mounted) {
        setState(() {
          _activeFleet = fleet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredFleet {
    if (_selectedFilter == "in_transit") {
      return _activeFleet.where((b) => b['status'] == 'in_transit').toList();
    } else if (_selectedFilter == "delayed") {
      return _activeFleet.where((b) => b['status'] == 'delayed').toList();
    }
    return _activeFleet;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFleet;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Live Fleet Master Radar",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: darkText),
            ),
            Text(
              "Real-time GPS Tracking across Pakistan",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subText),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryBlue),
            tooltip: "Refresh Radar",
            onPressed: () => _loadFleetData(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : Stack(
              children: [
                // ─── 1. MASTER RADAR MAP ───
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(30.8500, 72.8000), // Central Pakistan View
                    initialZoom: 6.8,
                    minZoom: 4.5,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.busverse.app',
                    ),

                    // Active Polylines for Selected Bus
                    if (_selectedBus != null && _selectedBus!['waypoints'] != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _selectedBus!['waypoints'] as List<LatLng>,
                            strokeWidth: 4.5,
                            color: primaryBlue,
                          ),
                        ],
                      ),

                    // Fleet Markers
                    MarkerLayer(
                      markers: filtered.map((bus) {
                        final isSelected = _selectedBus?['busId'] == bus['busId'];
                        final isDelayed = bus['status'] == 'delayed';
                        final markerColor = isDelayed ? roseDanger : (isSelected ? royalBlue : primaryBlue);

                        return Marker(
                          point: LatLng(bus['latitude'], bus['longitude']),
                          width: isSelected ? 50 : 40,
                          height: isSelected ? 50 : 40,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedBus = bus);
                              _mapController.move(LatLng(bus['latitude'], bus['longitude']), 11.0);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: markerColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: markerColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_bus_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // ─── 2. TOP FILTER PILLS ───
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("all", "All Active (${_activeFleet.length})", Icons.radar_rounded),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          "in_transit",
                          "In-Transit (${_activeFleet.where((b) => b['status'] == 'in_transit').length})",
                          Icons.navigation_rounded,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          "delayed",
                          "Delayed (${_activeFleet.where((b) => b['status'] == 'delayed').length})",
                          Icons.warning_amber_rounded,
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── 3. SELECTED BUS INSPECTOR CARD ───
                if (_selectedBus != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: _buildBusDetailCard(_selectedBus!),
                  ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : primaryBlue),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusDetailCard(Map<String, dynamic> b) {
    final isDelayed = b['status'] == 'delayed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${b['fromCity']} ➔ ${b['toCity']}",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: darkText),
                    ),
                    Text(
                      "${b['busName']} • ${b['busNumber']} (${b['busClass']})",
                      style: const TextStyle(fontSize: 11.5, color: subText),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: subText),
                onPressed: () => setState(() => _selectedBus = null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem("SPEED", "${(b['speed'] as double).toStringAsFixed(0)} km/h", Icons.speed_rounded),
              _buildMetricItem("PASSENGERS", "${b['passengersOnboard']} Seats", Icons.people_alt_rounded),
              _buildMetricItem(
                "STATUS",
                isDelayed ? "Delayed (+15m)" : "On Schedule",
                isDelayed ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                color: isDelayed ? roseDanger : emeraldGreen,
              ),
            ],
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("DRIVER ON DUTY", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: subText)),
                    Text(
                      "${b['driverName']} (${b['driverPhone']})",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, {Color color = primaryBlue}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: subText)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ],
    );
  }
}
