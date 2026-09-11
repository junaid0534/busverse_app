import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/sub_admin/screens/counter_search_bus_screen.dart';
import 'package:bus_ticket_system/sub_admin/screens/counter_book_seat_screen.dart';
import 'package:bus_ticket_system/sub_admin/screens/shift_report_screen.dart';
import 'package:intl/intl.dart';

class SubAdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const SubAdminDashboardScreen({super.key, this.userProfile});

  @override
  State<SubAdminDashboardScreen> createState() => _SubAdminDashboardScreenState();
}

class _SubAdminDashboardScreenState extends State<SubAdminDashboardScreen> {
  bool isLoading = true;
  Map<String, dynamic> terminalStats = {};
  List<Map<String, dynamic>> todayBuses = [];
  List<Map<String, dynamic>> recentBookings = [];
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

  int _currentNavIndex = 0;
  Timer? _autoRefreshTimer;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    // 1. Clock timer (every 1 sec)
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    // 2. Real-time periodic data fetch (every 10 secs silent update)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        loadDashboardData(silent: true);
      }
    });

    loadDashboardData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  String get terminalCity {
    return widget.userProfile?['terminalCity'] ?? 'Lahore';
  }

  String get terminalName {
    return widget.userProfile?['terminalName'] ?? 'Main Terminal Counter';
  }

  String get agentName {
    final fname = widget.userProfile?['firstName'] ?? 'Terminal';
    final lname = widget.userProfile?['lastName'] ?? 'Agent';
    return "$fname $lname";
  }

  String get agentEmail {
    return widget.userProfile?['email'] ?? 'agent@busverse.com';
  }

  Future<void> loadDashboardData({bool silent = false}) async {
    if (!silent) {
      setState(() => isLoading = true);
    }
    try {
      final stats = await DBHelper.instance.getSubAdminStats(terminalCity);
      final buses = (stats['todayBusesList'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final bookings = (stats['recentBookings'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      if (mounted) {
        setState(() {
          terminalStats = stats;
          todayBuses = buses;
          recentBookings = bookings;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading sub-admin dashboard: $e");
      if (mounted && !silent) setState(() => isLoading = false);
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Logout", style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text("Are you sure you want to end your terminal counter shift and log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int todayBusesCount = terminalStats['todayBuses'] ?? 0;
    final int todayBookingsCount = terminalStats['todayBookings'] ?? 0;
    final double revenue = (terminalStats['totalRevenue'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: bgSurface,

      // ─── WHITE APPBAR (BUS IN BLUE, VERSE IN BLACK) ───
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: "Bus",
                style: TextStyle(
                  color: primaryBlue,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              TextSpan(
                text: "Verse",
                style: TextStyle(
                  color: darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
              ),
              onPressed: _handleLogout,
              tooltip: "Logout",
            ),
          ),
        ],
      ),

      // ─── BOTTOM NAVIGATION BAR (4 COUNTER OPERATIONS) ───
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: borderColor, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) async {
            setState(() => _currentNavIndex = index);
            if (index == 1) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CounterSearchBusScreen(
                    userProfile: widget.userProfile,
                  ),
                ),
              );
              loadDashboardData();
              setState(() => _currentNavIndex = 0);
            } else if (index == 2) {
              await Navigator.pushNamed(context, '/view_all_booking');
              loadDashboardData();
              setState(() => _currentNavIndex = 0);
            } else if (index == 3) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShiftReportScreen(
                    userProfile: widget.userProfile,
                  ),
                ),
              );
              loadDashboardData();
              setState(() => _currentNavIndex = 0);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryBlue,
          unselectedItemColor: subText,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_rounded, color: primaryBlue),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_rounded),
              activeIcon: Icon(Icons.point_of_sale_rounded, color: primaryBlue),
              label: 'Book Ticket',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              activeIcon: Icon(Icons.receipt_long_rounded, color: primaryBlue),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              activeIcon: Icon(Icons.account_balance_wallet_rounded, color: primaryBlue),
              label: 'Shift Report',
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : RefreshIndicator(
                onRefresh: loadDashboardData,
                color: primaryBlue,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── 1. HERO CARD (SINGLE CONTAINER) ───
                      _buildTerminalHeroCard(),

                      const SizedBox(height: 14),

                      // ─── 2. TODAY'S OVERVIEW (3 CARDS IN 1 ROW) ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today's Overview",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildOverviewKpiCard(
                                  value: "$todayBusesCount",
                                  icon: Icons.directions_bus_rounded,
                                  color: primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                _buildOverviewKpiCard(
                                  value: "$todayBookingsCount",
                                  icon: Icons.confirmation_number_rounded,
                                  color: const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 8),
                                _buildOverviewKpiCard(
                                  value: "Rs. ${revenue >= 100000 ? '${(revenue / 1000).toStringAsFixed(1)}k' : revenue.toStringAsFixed(0)}",
                                  icon: Icons.payments_rounded,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ─── 3. COUNTER OPERATIONS (4 CARDS IN 1 ROW) ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Counter Operations",
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildCounterOperationCard(
                                  title: "Book Ticket",
                                  icon: Icons.point_of_sale_rounded,
                                  color: primaryBlue,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CounterSearchBusScreen(
                                          userProfile: widget.userProfile,
                                        ),
                                      ),
                                    );
                                    loadDashboardData();
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildCounterOperationCard(
                                  title: "Buses",
                                  icon: Icons.departure_board_rounded,
                                  color: const Color(0xFF0EA5E9),
                                  onTap: () {
                                    Navigator.pushNamed(context, '/manage_buses');
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildCounterOperationCard(
                                  title: "Bookings",
                                  icon: Icons.receipt_long_rounded,
                                  color: const Color(0xFF10B981),
                                  onTap: () {
                                    Navigator.pushNamed(context, '/view_all_booking');
                                  },
                                ),
                                const SizedBox(width: 8),
                                _buildCounterOperationCard(
                                  title: "Shift Report",
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: const Color(0xFFF59E0B),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ShiftReportScreen(
                                          userProfile: widget.userProfile,
                                        ),
                                      ),
                                    );
                                    loadDashboardData();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── 4. TODAY'S DEPARTURES ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Departures from $terminalCity (${todayBuses.length})",
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/manage_buses');
                              },
                              child: const Text(
                                "View All →",
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // List of today's buses
                      if (todayBuses.isEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.bus_alert_rounded, size: 36, color: subText.withAlpha(150)),
                                const SizedBox(height: 8),
                                Text(
                                  "No scheduled departures for today from $terminalCity",
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: subText),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: todayBuses.length,
                          itemBuilder: (context, index) {
                            final bus = todayBuses[index];
                            return _buildBusCard(bus);
                          },
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── 1. HERO CARD (SINGLE CLEAN MODERN CONTAINER) ───
  Widget _buildTerminalHeroCard() {
    final dateStr = DateFormat('EEE, dd MMMM yyyy').format(_currentTime);
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [royalBlue, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: royalBlue.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal City & Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$terminalCity Terminal",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white70, size: 12),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            terminalName.isNotEmpty ? terminalName : "Main Counter",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 10),

          // Date & Live Time Row (Fixed - Never crops)
          Row(
            children: [
              // Live Current Date
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 13.5),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Live Time Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_filled_rounded, color: Color(0xFFFDE047), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
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

  // ─── 2. 3 KPI CARDS IN 1 ROW (TODAY'S OVERVIEW) ───
  Widget _buildOverviewKpiCard({
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
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

  // ─── 3. 4 ACTION CARDS IN 1 ROW (COUNTER OPERATIONS) ───
  Widget _buildCounterOperationCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusCard(Map<String, dynamic> bus) {
    final to = bus['toCity'] ?? 'Destination';
    final time = bus['time'] ?? 'N/A';
    final busClass = bus['busClass'] ?? 'Executive';
    final fare = bus['fare'] != null ? "Rs. ${(bus['fare'] as num).toStringAsFixed(0)}" : "Rs. 0";
    final busNumber = bus['busNumber'] ?? 'BV-Fleet';
    final driver = bus['driverName'] ?? 'Assigned Captain';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      busClass.toString().toUpperCase(),
                      style: const TextStyle(
                        color: primaryBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    busNumber,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subText),
                  ),
                ],
              ),
              Text(
                fare,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    terminalCity,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: subText),
                  ),
                  Text(
                    to,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: darkText),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 13, color: subText),
                  const SizedBox(width: 4),
                  Text(
                    "Captain: $driver",
                    style: const TextStyle(fontSize: 11, color: subText),
                  ),
                ],
              ),
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CounterBookSeatScreen(
                        bus: BusModel.fromMap(bus),
                        selectedDate: DateTime.now(),
                        userProfile: widget.userProfile,
                      ),
                    ),
                  );
                  loadDashboardData();
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.point_of_sale_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "Book POS",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
