import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bus_ticket_system/services/route_coordinates_service.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class LiveBusTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> ticketData;

  const LiveBusTrackingScreen({super.key, required this.ticketData});

  @override
  State<LiveBusTrackingScreen> createState() => _LiveBusTrackingScreenState();
}

class _LiveBusTrackingScreenState extends State<LiveBusTrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Route & Waypoint Data
  List<LatLng> _routeWaypoints = [];
  String _fromCity = "Lahore";
  String _toCity = "Islamabad";
  String _busNumber = "BV-101";
  String _busClass = "Executive";
  String _busName = "BusVerse Express";
  int _busId = 1;

  // Realtime Simulated / Live GPS state
  int _currentWaypointIndex = 0;
  double _segmentProgress = 0.0; // 0.0 to 1.0 between waypoints
  LatLng _currentLocation = const LatLng(31.5204, 74.3587);
  double _currentSpeed = 82.0; // km/h
  double _currentHeading = 0.0; // degrees
  String _nextStop = "Sukheki Rest Area";
  int _etaMinutes = 45;
  double _distanceRemainingKm = 280.0;
  double _totalTripDistanceKm = 380.0;

  // Simulator controls
  bool _isSimulating = true;
  double _simulationSpeedMultiplier = 1.0;
  Timer? _simulationTimer;
  Timer? _syncToCloudTimer;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color cardBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _extractTicketData();
    _initRoute();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startSimulation();

    // Periodic cloud sync every 5 seconds
    _syncToCloudTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncLocationToSupabase();
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _syncToCloudTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _extractTicketData() {
    final t = widget.ticketData;
    _fromCity = (t['fromCity'] ?? t['from_city'] ?? 'Lahore').toString();
    _toCity = (t['toCity'] ?? t['to_city'] ?? 'Islamabad').toString();

    final bus = t['bus'] is Map ? t['bus'] as Map : {};
    _busNumber = (t['busNumber'] ?? bus['busNumber'] ?? t['bus_number'] ?? 'BV-Fleet').toString();
    _busClass = (t['busClass'] ?? bus['busClass'] ?? t['bus_class'] ?? 'Executive').toString();
    _busName = (t['busName'] ?? bus['busName'] ?? t['bus_name'] ?? 'BusVerse Express').toString();

    final bId = t['busId'] ?? bus['id'] ?? t['bus_id'];
    _busId = int.tryParse(bId?.toString() ?? '1') ?? 1;
  }

  void _initRoute() {
    _routeWaypoints = RouteCoordinatesService.instance.getRouteWaypoints(_fromCity, _toCity);
    if (_routeWaypoints.isNotEmpty) {
      _currentLocation = _routeWaypoints.first;
      _totalTripDistanceKm = RouteCoordinatesService.instance.calculateTotalRouteDistance(_routeWaypoints);
      _distanceRemainingKm = _totalTripDistanceKm;
      if (_routeWaypoints.length > 1) {
        _currentHeading = RouteCoordinatesService.instance.calculateBearing(_routeWaypoints[0], _routeWaypoints[1]);
      }
    }
  }

  void _startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!_isSimulating || _routeWaypoints.length < 2) return;

      setState(() {
        final step = 0.04 * _simulationSpeedMultiplier;
        _segmentProgress += step;

        if (_segmentProgress >= 1.0) {
          _segmentProgress = 0.0;
          _currentWaypointIndex++;
          if (_currentWaypointIndex >= _routeWaypoints.length - 1) {
            _currentWaypointIndex = 0; // Loop or reach destination
          }
        }

        final p1 = _routeWaypoints[_currentWaypointIndex];
        final p2 = _routeWaypoints[_currentWaypointIndex + 1];

        // Smooth Linear Interpolation between waypoints
        final lat = p1.latitude + (p2.latitude - p1.latitude) * _segmentProgress;
        final lng = p1.longitude + (p2.longitude - p1.longitude) * _segmentProgress;
        _currentLocation = LatLng(lat, lng);

        _currentHeading = RouteCoordinatesService.instance.calculateBearing(p1, p2);

        // Realistic Highway Speed Fluctuation
        final randomSpeedOffset = (math.sin(DateTime.now().millisecondsSinceEpoch / 2000.0) * 8.0);
        _currentSpeed = (84.0 + randomSpeedOffset).clamp(65.0, 105.0);

        // Calculate Remaining Trip Stats
        final totalPoints = _routeWaypoints.length.toDouble();
        final overallProgress = (_currentWaypointIndex + _segmentProgress) / totalPoints;
        _distanceRemainingKm = (_totalTripDistanceKm * (1.0 - overallProgress)).clamp(0.0, _totalTripDistanceKm);
        _etaMinutes = ((_distanceRemainingKm / (_currentSpeed > 0 ? _currentSpeed : 75.0)) * 60.0).round();

        _nextStop = RouteCoordinatesService.instance.getNextStopName(overallProgress, _fromCity, _toCity);
      });
    });
  }

  Future<void> _syncLocationToSupabase() async {
    try {
      await DBHelper.instance.updateBusLocation(
        busId: _busId,
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        speed: _currentSpeed,
        heading: _currentHeading,
        nextStop: _nextStop,
        etaMinutes: _etaMinutes,
        status: 'in_transit',
      );
    } catch (_) {}
  }

  void _recenterMap() {
    _mapController.move(_currentLocation, 12.5);
  }

  void _fitFullRoute() {
    if (_routeWaypoints.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(_routeWaypoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(top: 80, bottom: 260, left: 40, right: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ─── 1. INTERACTIVE OPENSTREETMAP VIEW ───
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 11.5,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.busverse.app',
                maxZoom: 19,
              ),

              // Route Polyline Glow Shadow
              if (_routeWaypoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeWaypoints,
                      strokeWidth: 9.0,
                      color: primaryBlue.withOpacity(0.25),
                    ),
                    Polyline(
                      points: _routeWaypoints,
                      strokeWidth: 4.5,
                      color: primaryBlue,
                    ),
                  ],
                ),

              // Markers Layer (Start, Destination, Bus)
              MarkerLayer(
                markers: [
                  // Origin Marker
                  if (_routeWaypoints.isNotEmpty)
                    Marker(
                      point: _routeWaypoints.first,
                      width: 44,
                      height: 44,
                      child: _buildTerminalMarker(_fromCity, isStart: true),
                    ),

                  // Destination Marker
                  if (_routeWaypoints.isNotEmpty)
                    Marker(
                      point: _routeWaypoints.last,
                      width: 44,
                      height: 44,
                      child: _buildTerminalMarker(_toCity, isStart: false),
                    ),

                  // Moving Bus Marker with Pulse & Rotation
                  Marker(
                    point: _currentLocation,
                    width: 60,
                    height: 60,
                    child: _buildLiveBusMarker(),
                  ),
                ],
              ),
            ],
          ),

          // ─── 2. TOP HEADER APP BAR ───
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Back Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: darkText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Route & Bus Info Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "$_fromCity → $_toCity",
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: darkText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "$_busName • $_busNumber",
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: subText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: emeraldGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: emeraldGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  "LIVE",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: emeraldGreen,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── 3. FLOATING MAP CONTROLS (RIGHT) ───
          Positioned(
            right: 16,
            top: 110,
            child: Column(
              children: [
                _buildMapFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: "Center on Bus",
                  onTap: _recenterMap,
                ),
                const SizedBox(height: 8),
                _buildMapFloatingButton(
                  icon: Icons.alt_route_rounded,
                  tooltip: "Fit Entire Route",
                  onTap: _fitFullRoute,
                ),
                const SizedBox(height: 8),
                _buildMapFloatingButton(
                  icon: Icons.add_rounded,
                  tooltip: "Zoom In",
                  onTap: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1.0);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingButton(
                  icon: Icons.remove_rounded,
                  tooltip: "Zoom Out",
                  onTap: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1.0);
                  },
                ),
              ],
            ),
          ),

          // ─── 4. BOTTOM TELEMETRY & SIMULATOR PANEL ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomTelemetrySheet(),
          ),
        ],
      ),
    );
  }

  // ─── WIDGET: LIVE BUS MARKER WITH HEADING & PULSE ───
  Widget _buildLiveBusMarker() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Glowing Outer Radar Pulse Ring
            Container(
              width: 52 * _pulseAnimation.value,
              height: 52 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(0.22),
              ),
            ),
            // Inner Circle with Rotation Heading
            Transform.rotate(
              angle: _currentHeading * (math.pi / 180.0),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryBlue, royalBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── WIDGET: TERMINAL PIN MARKER ───
  Widget _buildTerminalMarker(String cityName, {required bool isStart}) {
    final color = isStart ? emeraldGreen : amberWarning;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isStart ? Icons.play_arrow_rounded : Icons.flag_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: darkText),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  // ─── WIDGET: BOTTOM TELEMETRY SHEET ───
  Widget _buildBottomTelemetrySheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // 1. Next Stop & ETA Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.near_me_rounded, color: primaryBlue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "NEXT STOP",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: subText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nextStop,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "~$_etaMinutes mins",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: emeraldGreen,
                    ),
                  ),
                  const Text(
                    "Estimated Arrival",
                    style: TextStyle(fontSize: 10, color: subText),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // 2. Metrics Grid (Speed, Distance, On-Time)
          Row(
            children: [
              _buildMetricCard(
                icon: Icons.speed_rounded,
                label: "CURRENT SPEED",
                value: "${_currentSpeed.toStringAsFixed(0)} km/h",
                color: primaryBlue,
              ),
              const SizedBox(width: 10),
              _buildMetricCard(
                icon: Icons.social_distance_rounded,
                label: "REMAINING",
                value: "${_distanceRemainingKm.toStringAsFixed(0)} km",
                color: royalBlue,
              ),
              const SizedBox(width: 10),
              _buildMetricCard(
                icon: Icons.check_circle_outline_rounded,
                label: "TRIP STATUS",
                value: "On Time",
                color: emeraldGreen,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Smart Simulator Bar (For Real-time Demonstration & Testing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, size: 18, color: subText),
                const SizedBox(width: 8),
                const Text(
                  "Simulator:",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
                ),
                const Spacer(),

                // Play / Pause Simulation
                InkWell(
                  onTap: () {
                    setState(() => _isSimulating = !_isSimulating);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isSimulating ? emeraldGreen.withOpacity(0.12) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isSimulating ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 14,
                          color: _isSimulating ? emeraldGreen : subText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isSimulating ? "Running" : "Paused",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isSimulating ? emeraldGreen : subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Speed Multipliers (1x, 2x, 5x)
                _buildSpeedMultiplierChip(1.0, "1x"),
                const SizedBox(width: 4),
                _buildSpeedMultiplierChip(3.0, "3x"),
                const SizedBox(width: 4),
                _buildSpeedMultiplierChip(6.0, "6x"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: subText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: darkText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedMultiplierChip(double multiplier, String label) {
    final isSelected = _simulationSpeedMultiplier == multiplier;
    return InkWell(
      onTap: () {
        setState(() => _simulationSpeedMultiplier = multiplier);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? primaryBlue : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : subText,
          ),
        ),
      ),
    );
  }
}
