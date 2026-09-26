import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class TerminalDetailScreen extends StatefulWidget {
  final String terminalCity;

  const TerminalDetailScreen({
    super.key,
    required this.terminalCity,
  });

  @override
  State<TerminalDetailScreen> createState() => _TerminalDetailScreenState();
}

class _TerminalDetailScreenState extends State<TerminalDetailScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic> _data = {};

  late TabController _tabController;
  Timer? _clockTimer;
  Timer? _realtimeTimer;
  DateTime _currentTime = DateTime.now();

  String _bookingSearchQuery = "";
  final TextEditingController _bookingSearchCtrl = TextEditingController();

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTerminalDetails();

    // 1-sec clock ticker
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    // 8-sec real-time live refresh
    _realtimeTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadTerminalDetails(silent: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clockTimer?.cancel();
    _realtimeTimer?.cancel();
    _bookingSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTerminalDetails({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final res = await DBHelper.instance.getTerminalLiveDeepDive(widget.terminalCity);
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching terminal deep-dive: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String city = _data['terminalCity'] ?? widget.terminalCity;
    final String terminalName = _data['terminalName'] ?? "$city Main Terminal";
    final bool isShiftActive = _data['isShiftActive'] == true;
    final activeShift = _data['activeShift'] as Map<String, dynamic>?;
    final subAdmin = _data['subAdmin'] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> bookings = (_data['bookings'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final List<Map<String, dynamic>> departingBuses = (_data['departingBuses'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final List<Map<String, dynamic>> agents = (_data['agents'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final List<Map<String, dynamic>> shiftHistory = (_data['shiftHistory'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: darkText),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    "$city Terminal Monitor",
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: darkText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isShiftActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isShiftActive ? const Color(0xFF86EFAC) : borderColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isShiftActive ? "LIVE ON DUTY" : "OFF DUTY",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: isShiftActive ? const Color(0xFF15803D) : subText,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              terminalName,
              style: const TextStyle(fontSize: 10.5, color: subText, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Live Refresh",
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
                  )
                : const Icon(Icons.refresh_rounded, color: primaryBlue, size: 22),
            onPressed: () {
              setState(() => _isRefreshing = true);
              _loadTerminalDetails(silent: true);
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryBlue,
          unselectedLabelColor: subText,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          indicatorColor: primaryBlue,
          indicatorWeight: 2.5,
          tabs: [
            const Tab(text: "Live Shift"),
            Tab(text: "Bookings (${bookings.length})"),
            Tab(text: "Buses (${departingBuses.length})"),
            const Tab(text: "Staff & Logs"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. LIVE SHIFT & CASH DRAWER TAB
                _buildLiveShiftTab(activeShift, isShiftActive, subAdmin),

                // 2. REAL-TIME BOOKINGS TAB
                _buildBookingsTab(bookings),

                // 3. DEPARTING BUSES TAB
                _buildDepartingBusesTab(departingBuses),

                // 4. STAFF & SHIFT AUDIT LOGS TAB
                _buildStaffAndLogsTab(agents, subAdmin, shiftHistory),
              ],
            ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 1. LIVE SHIFT & DRAWER RECONCILIATION TAB
  // ════════════════════════════════════════════════════════════
  Widget _buildLiveShiftTab(Map<String, dynamic>? activeShift, bool isShiftActive, Map<String, dynamic>? subAdmin) {
    final double openingFloat = (_data['openingFloat'] as num?)?.toDouble() ?? 0.0;
    final double shiftCash = (_data['shiftCash'] as num?)?.toDouble() ?? 0.0;
    final double shiftDigital = (_data['shiftDigital'] as num?)?.toDouble() ?? 0.0;
    final double netDrawerCash = (_data['netDrawerCash'] as num?)?.toDouble() ?? 0.0;
    final int shiftBookingsCount = _data['shiftBookingsCount'] ?? 0;

    final double todayRevenue = (_data['todayRevenue'] as num?)?.toDouble() ?? 0.0;
    final double todayCash = (_data['todayCash'] as num?)?.toDouble() ?? 0.0;
    final double todayDigital = (_data['todayDigital'] as num?)?.toDouble() ?? 0.0;
    final int totalBookingsCount = _data['totalBookingsCount'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── HERO DUTY CARD ───
          if (isShiftActive && activeShift != null) ...[
            _buildActiveDutyHero(activeShift),
            const SizedBox(height: 14),

            // ─── CASH DRAWER RECONCILIATION CARD ───
            _buildDrawerCard(
              openingFloat: openingFloat,
              shiftCash: shiftCash,
              shiftDigital: shiftDigital,
              netDrawerCash: netDrawerCash,
              shiftBookingsCount: shiftBookingsCount,
            ),
          ] else ...[
            _buildNoActiveShiftCard(subAdmin),
          ],

          const SizedBox(height: 16),

          // ─── TERMINAL TODAY FINANCIAL KPI SUMMARY ───
          const Text(
            "Terminal Financial Performance (Today)",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFinancialKpiCard(
                  title: "Total Revenue",
                  amount: "PKR ${todayRevenue.toStringAsFixed(0)}",
                  icon: Icons.payments_rounded,
                  subtitle: "$totalBookingsCount total tickets",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinancialKpiCard(
                  title: "Cash Collection",
                  amount: "PKR ${todayCash.toStringAsFixed(0)}",
                  icon: Icons.money_rounded,
                  subtitle: "Physical notes",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFinancialKpiCard(
                  title: "Card / Digital",
                  amount: "PKR ${todayDigital.toStringAsFixed(0)}",
                  icon: Icons.credit_card_rounded,
                  subtitle: "POS online/card",
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─── TERMINAL INCHARGE CARD ───
          _buildTerminalInchargeSummary(subAdmin),
        ],
      ),
    );
  }

  Widget _buildActiveDutyHero(Map<String, dynamic> activeShift) {
    final String agentName = activeShift['agentName'] ?? 'Counter Agent';
    final String agentCode = activeShift['agentCode'] ?? 'AGT';
    final String shiftType = activeShift['shiftType'] ?? 'General';
    final String openingTime = activeShift['openingTime'] ?? '';

    String formattedDate = DateFormat('EEE, dd MMM yyyy').format(_currentTime);
    String formattedLiveTime = DateFormat('hh:mm:ss a').format(_currentTime);
    String formattedInTime = 'N/A';

    if (openingTime.isNotEmpty) {
      final dt = DateTime.tryParse(openingTime);
      if (dt != null) formattedInTime = DateFormat('hh:mm a').format(dt);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: primaryBlue,
                child: Icon(Icons.person_pin_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agentName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
                    ),
                    Text(
                      "On-Duty Counter Agent ($agentCode) • $shiftType Shift",
                      style: const TextStyle(fontSize: 11.5, color: subText, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF86EFAC), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      "LIVE DUTY",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF15803D),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHeroMetaItem("SHIFT DATE", formattedDate, Icons.calendar_today_rounded),
              ),
              Expanded(
                child: _buildHeroMetaItem("LIVE TIME", formattedLiveTime, Icons.access_time_filled_rounded),
              ),
              Expanded(
                child: _buildHeroMetaItem("SHIFT IN TIME", formattedInTime, Icons.login_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetaItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: primaryBlue),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: subText),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: primaryBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerCard({
    required double openingFloat,
    required double shiftCash,
    required double shiftDigital,
    required double netDrawerCash,
    required int shiftBookingsCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: primaryBlue),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Live Shift Drawer Reconciliation",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$shiftBookingsCount tickets",
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _drawerRow("Opening Drawer Float (Change)", "PKR ${openingFloat.toStringAsFixed(0)}", isMuted: true),
          const SizedBox(height: 6),
          _drawerRow("(+) Shift Cash Ticket Sales", "PKR ${shiftCash.toStringAsFixed(0)}", isBlue: true),
          const SizedBox(height: 6),
          _drawerRow("(+) Card / Digital POS Sales", "PKR ${shiftDigital.toStringAsFixed(0)}", isMuted: true),
          const SizedBox(height: 10),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Physical Cash in Drawer",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: darkText),
                  ),
                  Text(
                    "Float + Shift Cash Sales (Verified in Drawer)",
                    style: TextStyle(fontSize: 10, color: subText),
                  ),
                ],
              ),
              Text(
                "PKR ${netDrawerCash.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerRow(String title, String amount, {bool isBlue = false, bool isMuted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            color: isMuted ? subText : darkText,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isBlue ? primaryBlue : (isMuted ? subText : darkText),
          ),
        ),
      ],
    );
  }

  Widget _buildNoActiveShiftCard(Map<String, dynamic>? subAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.pause_circle_filled_rounded, size: 40, color: subText),
          SizedBox(height: 10),
          Text(
            "Shift Currently Closed / Off Duty",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText),
          ),
          SizedBox(height: 4),
          Text(
            "No counter agent is currently clocked in at this terminal. When a counter agent clocks in via PIN, live status and drawer balance will appear here instantly.",
            style: TextStyle(fontSize: 12, color: subText, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialKpiCard({
    required String title,
    required String amount,
    required IconData icon,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: primaryBlue),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subText),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primaryBlue),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 8.5, color: subText),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalInchargeSummary(Map<String, dynamic>? subAdmin) {
    final String managerName = subAdmin != null ? "${subAdmin['firstName']} ${subAdmin['lastName']}".trim() : "Not Assigned";
    final String phone = subAdmin?['phone'] ?? 'N/A';
    final String email = subAdmin?['email'] ?? 'N/A';
    final String status = subAdmin?['status'] ?? 'inactive';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, size: 22, color: primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Terminal Incharge / Manager",
                  style: TextStyle(fontSize: 10, color: subText, fontWeight: FontWeight.w600),
                ),
                Text(
                  managerName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: darkText),
                ),
                Text(
                  "Phone: $phone • Email: $email",
                  style: const TextStyle(fontSize: 10.5, color: subText),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: status.toLowerCase() == 'active' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: status.toLowerCase() == 'active' ? const Color(0xFF15803D) : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 2. REAL-TIME BOOKINGS TAB
  // ════════════════════════════════════════════════════════════
  Widget _buildBookingsTab(List<Map<String, dynamic>> allBookings) {
    List<Map<String, dynamic>> filtered = allBookings;
    if (_bookingSearchQuery.trim().isNotEmpty) {
      final q = _bookingSearchQuery.toLowerCase().trim();
      filtered = allBookings.where((b) {
        final pName = (b['passengerName'] ?? '').toString().toLowerCase();
        final pPhone = (b['passengerPhone'] ?? '').toString().toLowerCase();
        final pCnic = (b['passengerCnic'] ?? '').toString().toLowerCase();
        final bus = (b['busName'] ?? '').toString().toLowerCase();
        final agent = (b['agentName'] ?? '').toString().toLowerCase();
        return pName.contains(q) || pPhone.contains(q) || pCnic.contains(q) || bus.contains(q) || agent.contains(q);
      }).toList();
    }

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _bookingSearchCtrl,
              onChanged: (val) => setState(() => _bookingSearchQuery = val),
              style: const TextStyle(fontSize: 12.5, color: darkText, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: "Search passenger name, CNIC, phone, bus...",
                hintStyle: const TextStyle(fontSize: 11.5, color: subText),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: primaryBlue),
                suffixIcon: _bookingSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: subText),
                        onPressed: () {
                          _bookingSearchCtrl.clear();
                          setState(() => _bookingSearchQuery = "");
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),

        const Divider(height: 1, color: borderColor),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 40, color: subText),
                      const SizedBox(height: 8),
                      Text(
                        _bookingSearchQuery.isNotEmpty ? "No matching bookings found" : "No terminal bookings recorded yet",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subText),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _buildBookingTicketCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildBookingTicketCard(Map<String, dynamic> b) {
    final String pName = b['passengerName'] ?? 'Walk-in Passenger';
    final String pPhone = b['passengerPhone'] ?? 'N/A';
    final String pCnic = b['passengerCnic'] ?? 'N/A';
    final String busName = b['busName'] ?? 'BusVerse Express';
    final String busNumber = b['busNumber'] ?? '';
    final String toCity = b['toCity'] ?? 'Destination';
    final String fromCity = b['fromCity'] ?? widget.terminalCity;
    final int seat = b['seatNumber'] is int ? b['seatNumber'] : int.tryParse(b['seatNumber']?.toString() ?? '1') ?? 1;
    final double fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
    final String method = (b['paymentMethod'] ?? 'Cash').toString();
    final String agent = b['agentName'] ?? 'Counter Agent';
    final String timeStr = (b['createdAt'] ?? b['bookingDate'] ?? '').toString();

    String formattedTime = '';
    if (timeStr.isNotEmpty) {
      final dt = DateTime.tryParse(timeStr);
      if (dt != null) formattedTime = DateFormat('dd MMM, hh:mm a').format(dt);
    }

    final bool isCash = method.toLowerCase().contains('cash') || method.isEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Seat #$seat",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText),
                  ),
                ],
              ),
              Text(
                "PKR ${fare.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.directions_bus_rounded, size: 13, color: subText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  "$busName ${busNumber.isNotEmpty ? '($busNumber)' : ''} • $fromCity ➔ $toCity",
                  style: const TextStyle(fontSize: 11, color: darkText, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CNIC: $pCnic • Phone: $pPhone",
                style: const TextStyle(fontSize: 10, color: subText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isCash ? const Color(0xFFEFF6FF) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isCash ? "CASH" : "DIGITAL/POS",
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isCash ? primaryBlue : const Color(0xFF7E22CE),
                  ),
                ),
              ),
            ],
          ),
          if (formattedTime.isNotEmpty || agent.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Booked by: $agent",
                  style: const TextStyle(fontSize: 9.5, color: subText, fontStyle: FontStyle.italic),
                ),
                Text(
                  formattedTime,
                  style: const TextStyle(fontSize: 9.5, color: subText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 3. DEPARTING BUSES TAB
  // ════════════════════════════════════════════════════════════
  Widget _buildDepartingBusesTab(List<Map<String, dynamic>> buses) {
    if (buses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_rounded, size: 40, color: subText),
            SizedBox(height: 8),
            Text(
              "No buses scheduled from this terminal",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: subText),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: buses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final b = buses[i];
        final String busName = b['busName'] ?? 'BusVerse Fleet';
        final String busNumber = b['busNumber'] ?? 'BV-00';
        final String toCity = b['toCity'] ?? 'Destination';
        final String time = b['time'] ?? '00:00';
        final String date = b['date'] ?? 'Today';
        final String busClass = b['busClass'] ?? 'Executive';
        final double fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
        final int seats = (b['seats'] as num?)?.toInt() ?? 40;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus_filled_rounded, size: 22, color: primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          busName,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: darkText),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: bgSurface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            busNumber,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: subText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "To: $toCity • $busClass • $seats Seats",
                      style: const TextStyle(fontSize: 11, color: subText),
                    ),
                    Text(
                      "Departure: $time • Date: $date",
                      style: const TextStyle(fontSize: 10.5, color: primaryBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "PKR ${fare.toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: primaryBlue),
                  ),
                  const Text("Fare / Seat", style: TextStyle(fontSize: 9, color: subText)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  // 4. STAFF & SHIFT AUDIT LOGS TAB
  // ════════════════════════════════════════════════════════════
  Widget _buildStaffAndLogsTab(
    List<Map<String, dynamic>> agents,
    Map<String, dynamic>? subAdmin,
    List<Map<String, dynamic>> shiftHistory,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Registered Counter Agents
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Registered Counter Staff (${agents.length})",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (agents.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: const Text("No counter agents registered for this terminal yet.", style: TextStyle(fontSize: 12, color: subText)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: agents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final ag = agents[i];
                final String name = ag['name'] ?? 'Agent';
                final String code = ag['agentCode'] ?? 'AGT';
                final String phone = ag['phone'] ?? 'N/A';
                final String status = ag['status'] ?? 'active';

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: primaryBlue,
                        child: Icon(Icons.badge_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: darkText)),
                            Text("Agent Code: $code • Phone: $phone", style: const TextStyle(fontSize: 10.5, color: subText)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Section 2: Shift History Logs
          Text(
            "Shift Audit Logs & Handovers (${shiftHistory.length})",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: darkText),
          ),
          const SizedBox(height: 10),
          if (shiftHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: const Text("No closed shifts recorded for this terminal yet.", style: TextStyle(fontSize: 12, color: subText)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shiftHistory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final s = shiftHistory[i];
                final String agentName = s['agentName'] ?? 'Agent';
                final String shiftType = s['shiftType'] ?? 'General';
                final String status = s['status'] ?? 'closed';
                final double closingCash = (s['closingCash'] as num?)?.toDouble() ?? 0.0;
                final int tickets = (s['ticketsCount'] as num?)?.toInt() ?? 0;
                final String openTime = s['openingTime'] ?? '';
                final String closeTime = s['closingTime'] ?? '';

                String formattedOpen = '';
                if (openTime.isNotEmpty) {
                  final dt = DateTime.tryParse(openTime);
                  if (dt != null) formattedOpen = DateFormat('dd MMM, hh:mm a').format(dt);
                }

                String formattedClose = '';
                if (closeTime.isNotEmpty) {
                  final dt = DateTime.tryParse(closeTime);
                  if (dt != null) formattedClose = DateFormat('hh:mm a').format(dt);
                }

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$agentName • $shiftType Shift",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: darkText),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: status == 'active' ? const Color(0xFFDCFCE7) : bgSurface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: status == 'active' ? const Color(0xFF15803D) : subText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "In: $formattedOpen ${formattedClose.isNotEmpty ? '• Out: $formattedClose' : ''}",
                            style: const TextStyle(fontSize: 10, color: subText),
                          ),
                          Text(
                            "Handover: PKR ${closingCash.toStringAsFixed(0)} ($tickets tix)",
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: primaryBlue),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
