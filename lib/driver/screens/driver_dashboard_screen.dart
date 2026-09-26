import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/route_coordinates_service.dart';
import 'package:latlong2/latlong.dart';

class DriverDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> driverProfile;

  const DriverDashboardScreen({super.key, required this.driverProfile});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isTripActive = false;
  double _currentSpeed = 0.0;
  String _currentNextStop = "Sukheki Rest Stop";
  int _delayMinutes = 0;

  // Passenger Manifest
  List<Map<String, dynamic>> _manifest = [];
  final Set<String> _boardedSeatNumbers = {};
  bool _isLoadingPassengers = true;

  // Realtime Waypoint simulation state
  List<LatLng> _routeWaypoints = [];
  int _waypointIndex = 0;
  Timer? _gpsBroadcastTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color roseDanger = Color(0xFFEF4444);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  String get _driverName => "${widget.driverProfile['firstName'] ?? ''} ${widget.driverProfile['lastName'] ?? ''}".trim();
  String get _busNumber => widget.driverProfile['assignedBusNumber'] ?? widget.driverProfile['assigned_bus_number'] ?? 'BV-101';
  String get _route => widget.driverProfile['assignedRoute'] ?? widget.driverProfile['assigned_route'] ?? 'Lahore - Islamabad';
  int get _busId => int.tryParse(widget.driverProfile['assignedBusId']?.toString() ?? '1') ?? 1;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.2).animate(_pulseController);

    _initRoute();
    _loadPassengerManifest();
  }

  @override
  void dispose() {
    _gpsBroadcastTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _initRoute() {
    final parts = _route.split('-');
    final from = parts.isNotEmpty ? parts[0].trim() : 'Lahore';
    final to = parts.length > 1 ? parts[1].trim() : 'Islamabad';
    _routeWaypoints = RouteCoordinatesService.instance.getRouteWaypoints(from, to);
  }

  Future<void> _loadPassengerManifest() async {
    setState(() => _isLoadingPassengers = true);
    try {
      final list = await DBHelper.instance.getTripPassengers(busId: _busId);
      if (mounted) {
        setState(() {
          _manifest = list;
          _isLoadingPassengers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPassengers = false);
    }
  }

  void _toggleTrip() {
    setState(() {
      _isTripActive = !_isTripActive;
      if (_isTripActive) {
        _currentSpeed = 82.0;
        _startGpsBroadcast();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚀 Trip Started! Live GPS Broadcaster is Online."),
            backgroundColor: emeraldGreen,
          ),
        );
      } else {
        _currentSpeed = 0.0;
        _gpsBroadcastTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Trip Finished. GPS Broadcaster Stopped."),
            backgroundColor: Color(0xFF64748B),
          ),
        );
      }
    });
  }

  void _startGpsBroadcast() {
    _gpsBroadcastTimer?.cancel();
    _gpsBroadcastTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isTripActive || _routeWaypoints.isEmpty) return;

      _waypointIndex = (_waypointIndex + 1) % _routeWaypoints.length;
      final currentPos = _routeWaypoints[_waypointIndex];
      final nextPos = (_waypointIndex + 1 < _routeWaypoints.length) ? _routeWaypoints[_waypointIndex + 1] : _routeWaypoints.last;
      final heading = RouteCoordinatesService.instance.calculateBearing(currentPos, nextPos);

      DBHelper.instance.updateBusLocation(
        busId: _busId,
        latitude: currentPos.latitude,
        longitude: currentPos.longitude,
        speed: _currentSpeed,
        heading: heading,
        nextStop: _currentNextStop,
        etaMinutes: 35,
        status: _delayMinutes > 0 ? 'delayed' : 'in_transit',
      );
    });
  }

  void _reportDelayDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Report Traffic Delay", style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select estimated delay time due to highway traffic, fog, or weather:"),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [10, 20, 30, 45].map((mins) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _delayMinutes == mins ? amberWarning : const Color(0xFFF1F5F9),
                    foregroundColor: _delayMinutes == mins ? Colors.white : darkText,
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() => _delayMinutes = mins);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Broadcasted +$mins mins delay to all passengers."),
                        backgroundColor: amberWarning,
                      ),
                    );
                  },
                  child: Text("+$mins m"),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: primaryBlue,
              child: Icon(Icons.airline_seat_recline_normal_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Captain ${_driverName.isNotEmpty ? _driverName : 'Driver'}",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: darkText),
                ),
                Text(
                  "Fleet Cockpit • $_busNumber",
                  style: const TextStyle(fontSize: 11, color: subText),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: roseDanger),
            tooltip: "Logout",
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. ASSIGNED BUS TRIP CARD ───
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3C72).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("ASSIGNED FLEET BUS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
                          const SizedBox(height: 2),
                          Text(_busNumber, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isTripActive ? emeraldGreen : Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            if (_isTripActive)
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) => Container(
                                  width: 8 * _pulseAnimation.value,
                                  height: 8 * _pulseAnimation.value,
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                ),
                              ),
                            if (_isTripActive) const SizedBox(width: 6),
                            Text(
                              _isTripActive ? "LIVE ON GPS" : "OFFLINE",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _route,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── 2. BIG START/END TRIP CONTROLLER ───
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTripActive ? roseDanger : emeraldGreen,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _toggleTrip,
                icon: Icon(_isTripActive ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, size: 24),
                label: Text(
                  _isTripActive ? "END TRIP & STOP BROADCAST" : "START TRIP & BROADCAST GPS",
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── 3. QUICK ACTION BUTTONS (REPORT DELAY, NEXT STOP) ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: amberWarning, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 18, color: amberWarning),
                    label: Text(
                      _delayMinutes > 0 ? "Delay: +$_delayMinutes m" : "Report Delay",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: amberWarning),
                    ),
                    onPressed: _reportDelayDialog,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: primaryBlue, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.location_on_rounded, size: 18, color: primaryBlue),
                    label: const Text(
                      "Next Stop",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryBlue),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Notified passengers: Approaching Next Stop.")),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ─── 4. PASSENGER BOARDING CHECKLIST / MANIFEST ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Passenger Manifest",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${_boardedSeatNumbers.length}/${_manifest.length} Boarded",
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: primaryBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _isLoadingPassengers
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : _manifest.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            "No booked passengers for this trip yet.",
                            style: TextStyle(fontSize: 13, color: subText),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _manifest.length,
                        itemBuilder: (context, index) {
                          final p = _manifest[index];
                          final user = p['users'] is Map ? p['users'] as Map : {};
                          final seat = (p['seat_number'] ?? p['seatNumber'] ?? 'N/A').toString();
                          final pName = user['first_name'] != null ? "${user['first_name']} ${user['last_name'] ?? ''}".trim() : (p['user_email'] ?? 'Passenger');
                          final phone = user['phone'] ?? p['passengerPhone'] ?? '0300-XXXXXXX';
                          final isBoarded = _boardedSeatNumbers.contains(seat);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isBoarded ? emeraldGreen.withOpacity(0.06) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isBoarded ? emeraldGreen.withOpacity(0.3) : const Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: isBoarded ? emeraldGreen : primaryBlue.withOpacity(0.1),
                                child: Text(
                                  "#$seat",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isBoarded ? Colors.white : primaryBlue),
                                ),
                              ),
                              title: Text(pName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: darkText)),
                              subtitle: Text(phone, style: const TextStyle(fontSize: 11.5, color: subText)),
                              trailing: IconButton(
                                icon: Icon(
                                  isBoarded ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isBoarded ? emeraldGreen : subText,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (isBoarded) {
                                      _boardedSeatNumbers.remove(seat);
                                    } else {
                                      _boardedSeatNumbers.add(seat);
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
