import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:intl/intl.dart';
import 'shift_slip_screen.dart';
import 'shift_handover_screen.dart';
import 'counter_staff_screen.dart';

class ShiftReportScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const ShiftReportScreen({super.key, this.userProfile});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _shiftBookings = [];
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  // Active Shift & Registered Agents state
  Map<String, dynamic>? _activeShift;
  List<Map<String, dynamic>> _registeredAgents = [];

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  String get terminalCity => widget.userProfile?['terminalCity'] ?? 'Lahore';
  String get terminalName => widget.userProfile?['terminalName'] ?? 'Main Terminal Counter';

  String get currentAgentName {
    if (_activeShift != null && _activeShift!['agentName'] != null) {
      return _activeShift!['agentName'];
    }
    if (_registeredAgents.isNotEmpty) {
      return _registeredAgents.first['name'] ?? 'Not Clocked In';
    }
    final fn = widget.userProfile?['firstName'] ?? '';
    final ln = widget.userProfile?['lastName'] ?? '';
    final full = "$fn $ln".trim();
    if (full.isNotEmpty) return full;
    return widget.userProfile?['name'] ?? 'Not Clocked In';
  }

  String get currentAgentCode {
    if (_activeShift != null && _activeShift!['agentCode'] != null) {
      return _activeShift!['agentCode'];
    }
    if (_registeredAgents.isNotEmpty) {
      return _registeredAgents.first['agentCode'] ?? '-';
    }
    return widget.userProfile?['agentCode'] ?? '-';
  }

  String get currentShiftType {
    if (_activeShift != null && _activeShift!['shiftType'] != null) {
      return _activeShift!['shiftType'];
    }
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 14) return "Morning";
    if (hour >= 14 && hour < 22) return "Evening";
    return "Night";
  }

  double get openingFloat {
    if (_activeShift != null && _activeShift!['openingFloat'] != null) {
      return (_activeShift!['openingFloat'] as num).toDouble();
    }
    return 0.0;
  }
  String get agentEmail => widget.userProfile?['email'] ?? '';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
    _loadShiftData();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);
    try {
      await DBHelper.instance.ensureAgentAndShiftTables();
      final stats = await DBHelper.instance.getSubAdminStats(terminalCity);
      final bookings = (stats['recentBookings'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final active = await DBHelper.instance.getActiveShift(terminalCity);
      final agents = await DBHelper.instance.getTerminalAgents(terminalCity: terminalCity);

      if (mounted) {
        setState(() {
          _shiftBookings = bookings;
          _activeShift = active;
          _registeredAgents = agents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading shift report: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isBookingInCurrentShift(Map<String, dynamic> b) {
    if (_activeShift == null || _activeShift!['openingTime'] == null) {
      return false;
    }
    final openingStr = _activeShift!['openingTime'].toString();
    final shiftStart = DateTime.tryParse(openingStr);
    if (shiftStart == null) return true;

    final crAt = b['createdAt']?.toString() ?? b['created_at']?.toString() ?? '';
    if (crAt.isNotEmpty) {
      final dt = DateTime.tryParse(crAt);
      if (dt != null) {
        return dt.isAfter(shiftStart) || dt.isAtSameMomentAs(shiftStart);
      }
    }

    final bDate = b['bookingDate']?.toString() ?? b['booking_date']?.toString() ?? '';
    if (bDate.isNotEmpty) {
      final dt = DateTime.tryParse(bDate);
      if (dt != null) {
        return dt.isAfter(shiftStart) || dt.isAtSameMomentAs(shiftStart);
      }
    }
    return false;
  }

  List<Map<String, dynamic>> get _currentShiftBookings {
    if (_activeShift == null) return [];
    return _shiftBookings.where(_isBookingInCurrentShift).toList();
  }

  double get _totalRevenue {
    double total = 0.0;
    for (var b in _currentShiftBookings) {
      final fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
      total += fare;
    }
    return total;
  }

  int get _totalTickets => _currentShiftBookings.length;

  double get _cashRevenue {
    double cash = 0.0;
    for (var b in _currentShiftBookings) {
      final method = (b['paymentMethod'] ?? b['payment_method'] ?? '').toString().toLowerCase();
      final fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
      if (method.contains('cash') || method.isEmpty) {
        cash += fare;
      }
    }
    return cash;
  }

  double get _digitalRevenue {
    double dig = 0.0;
    for (var b in _currentShiftBookings) {
      final method = (b['paymentMethod'] ?? b['payment_method'] ?? '').toString().toLowerCase();
      final fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
      if (!method.contains('cash') && method.isNotEmpty) {
        dig += fare;
      }
    }
    return dig;
  }

  double get _netDrawerCash => openingFloat + _cashRevenue;

  List<Map<String, dynamic>> get _filteredBookings {
    if (_searchQuery.trim().isEmpty) return _currentShiftBookings;
    final q = _searchQuery.trim().toLowerCase();
    return _currentShiftBookings.where((b) {
      final name = (b['passengerName'] ?? '').toString().toLowerCase();
      final phone = (b['passengerPhone'] ?? '').toString().toLowerCase();
      final seat = (b['seatNumber'] ?? '').toString().toLowerCase();
      final to = (b['toCity'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || seat.contains(q) || to.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Manage Shift",
          style: TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_outlined, color: primaryBlue, size: 22),
            tooltip: "Counter Staff & PINs",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CounterStaffScreen(
                    terminalCity: terminalCity,
                    terminalName: terminalName,
                  ),
                ),
              );
              _loadShiftData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryBlue, size: 20),
            tooltip: "Refresh Data",
            onPressed: _loadShiftData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : RefreshIndicator(
              onRefresh: _loadShiftData,
              color: primaryBlue,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Shift Duty Card
                    _buildShiftHeaderCard(),

                    const SizedBox(height: 12),

                    // 2. Overview Financial KPIs (4 Cards in 1 Row)
                    _buildKpiGrid(),

                    const SizedBox(height: 12),

                    // 3. Cash Drawer Reconciliation Card
                    _buildCashDrawerCard(),

                    const SizedBox(height: 12),

                    // 4. Inline Shift Slip & Handover Action Buttons
                    _buildInlineShiftActions(),

                    const SizedBox(height: 16),

                    // 5. Shift Issued Tickets Header & Search
                    _buildTransactionsSectionHeader(),

                    const SizedBox(height: 10),

                    // 6. Shift Bookings List
                    _buildTransactionsList(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── 1. SHIFT DUTY HEADER CARD ───
  Widget _buildShiftHeaderCard() {
    final dateFormatted = DateFormat('dd MMM yyyy').format(_currentTime);
    final dayFormatted = DateFormat('EEE').format(_currentTime);
    final timeFormatted = DateFormat('hh:mm:ss a').format(_currentTime);
    final bool hasActiveShift = _activeShift != null;
    final inTimeFormatted = _activeShift?['openingTime'] != null
        ? DateFormat('hh:mm a').format(DateTime.parse(_activeShift!['openingTime']))
        : "08:00 AM (Auto)";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Agent Name & Shift Type + Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEFF6FF),
                child: Text(
                  currentAgentName.isNotEmpty ? currentAgentName[0].toUpperCase() : 'A',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryBlue),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentAgentName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$currentShiftType Shift • Float: PKR ${openingFloat.toStringAsFixed(0)}",
                      style: const TextStyle(fontSize: 11.5, color: subText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: hasActiveShift ? null : _showShiftInModal,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: hasActiveShift ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasActiveShift ? const Color(0xFFBFDBFE) : const Color(0xFFFCD34D),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 3.5,
                        backgroundColor: hasActiveShift ? primaryBlue : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasActiveShift ? "ON DUTY" : "CLOCK IN",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hasActiveShift ? primaryBlue : const Color(0xFFD97706),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 10),

          // Metadata Grid
          Row(
            children: [
              Expanded(
                child: _metaInfo("TERMINAL LOCATION", "$terminalCity • $terminalName"),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metaInfo("SHIFT DATE", "$dayFormatted, $dateFormatted"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metaInfo("LIVE TIME", timeFormatted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metaInfo("SHIFT IN TIME", inTimeFormatted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: subText, letterSpacing: 0.3),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: darkText),
        ),
      ],
    );
  }

  // ─── 2. 4 KPI CARDS IN 1 ROW (ALL BLUE THEME) ───
  Widget _buildKpiGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildCompactKpiCard(
            heading: "Revenue",
            value: "PKR ${_totalRevenue.toStringAsFixed(0)}",
            icon: Icons.payments_rounded,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildCompactKpiCard(
            heading: "Tickets",
            value: "$_totalTickets",
            icon: Icons.confirmation_number_rounded,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildCompactKpiCard(
            heading: "Cash",
            value: "PKR ${_cashRevenue.toStringAsFixed(0)}",
            icon: Icons.point_of_sale_rounded,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildCompactKpiCard(
            heading: "Card/Digital",
            value: "PKR ${_digitalRevenue.toStringAsFixed(0)}",
            icon: Icons.credit_card_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactKpiCard({
    required String heading,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryBlue, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            heading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subText,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primaryBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. CASH DRAWER CARD ───
  Widget _buildCashDrawerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
              const Text(
                "Cash Drawer Reconciliation",
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: darkText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _drawerRow("Opening Drawer Float (Change)", "PKR ${openingFloat.toStringAsFixed(0)}", isMuted: true),
          const SizedBox(height: 6),
          _drawerRow("(+) Shift Cash Ticket Sales", "PKR ${_cashRevenue.toStringAsFixed(0)}", isBlue: true),
          const SizedBox(height: 6),
          _drawerRow("(+) Card / Digital POS Sales", "PKR ${_digitalRevenue.toStringAsFixed(0)}", isMuted: true),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
                  ),
                  Text(
                    "Float + Cash Sales (Due for handover)",
                    style: TextStyle(fontSize: 10, color: subText),
                  ),
                ],
              ),
              Text(
                "PKR ${_netDrawerCash.toStringAsFixed(0)}",
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: primaryBlue),
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

  // ─── 4. INLINE ACTION BUTTONS (UNDER CASH RECONCILIATION) ───
  Widget _buildInlineShiftActions() {
    return Row(
      children: [
        // Shift Slip Button
        Expanded(
          flex: 4,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_rounded, size: 16, color: primaryBlue),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: const Color(0xFFEFF6FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShiftSlipScreen(
                    shiftData: {
                      'terminalCity': terminalCity,
                      'agentName': currentAgentName,
                      'agentCode': currentAgentCode,
                      'shiftType': currentShiftType,
                      'openingFloat': openingFloat,
                      'totalTickets': _totalTickets,
                      'cashRevenue': _cashRevenue,
                      'digitalRevenue': _digitalRevenue,
                      'netDrawerCash': _netDrawerCash,
                    },
                  ),
                ),
              );
            },
            label: const Text(
              "Shift Slip",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryBlue),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // PIN Handover & Out Button
        Expanded(
          flex: 6,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.swap_horiz_rounded, size: 17),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
            onPressed: () async {
              final active = _activeShift ?? {
                'id': 1,
                'agentId': _registeredAgents.isNotEmpty ? _registeredAgents.first['id'] : 1,
                'agentName': currentAgentName,
                'agentCode': currentAgentCode,
                'shiftType': currentShiftType,
                'openingFloat': openingFloat,
              };
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShiftHandoverScreen(
                    activeShift: active,
                    registeredAgents: _registeredAgents,
                    terminalCity: terminalCity,
                    terminalName: terminalName,
                    totalTickets: _totalTickets,
                    cashRevenue: _cashRevenue,
                    digitalRevenue: _digitalRevenue,
                    netDrawerCash: _netDrawerCash,
                  ),
                ),
              );
              _loadShiftData();
            },
            label: const Text(
              "PIN Handover & Out",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 4. TRANSACTIONS SECTION HEADER & SEARCH ───
  Widget _buildTransactionsSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  "Shift Issued Tickets",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkText),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${_filteredBookings.length}",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primaryBlue),
                  ),
                ),
              ],
            ),
            if (_activeShift == null)
              TextButton.icon(
                icon: const Icon(Icons.login_rounded, size: 14, color: primaryBlue),
                label: const Text("Punch In", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: primaryBlue)),
                onPressed: _showShiftInModal,
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 13, color: darkText),
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: "Search passenger name, phone, seat...",
            hintStyle: const TextStyle(fontSize: 12, color: subText),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: subText),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: subText),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = "");
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
          ),
        ),
      ],
    );
  }

  // ─── 5. TRANSACTIONS LIST ───
  Widget _buildTransactionsList() {
    if (_filteredBookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 36, color: subText),
            SizedBox(height: 8),
            Text(
              "No tickets issued in current shift",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: subText),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredBookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final booking = _filteredBookings[index];
        final name = booking['passengerName'] ?? 'Walk-in Passenger';
        final phone = booking['passengerPhone'] ?? 'N/A';
        final seat = booking['seatNumber']?.toString() ?? 'N/A';
        final fare = (booking['fare'] as num?)?.toDouble() ?? 0.0;
        final from = booking['fromCity'] ?? terminalCity;
        final to = booking['toCity'] ?? 'Destination';
        final method = booking['paymentMethod'] ?? 'Cash';
        final isCash = method.toString().toLowerCase().contains('cash');
        final gender = booking['gender'] ?? booking['passengerGender'] ?? 'M';

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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCash ? const Color(0xFFFEF3C7) : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    "S$seat",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCash ? const Color(0xFFD97706) : const Color(0xFF7C3AED),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: (gender == 'F' ? Colors.pink : Colors.blue).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            gender == 'F' ? 'F' : 'M',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: gender == 'F' ? Colors.pink : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$from ➔ $to",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primaryBlue),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Phone: $phone • $method",
                      style: const TextStyle(fontSize: 10, color: subText),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "PKR ${fare.toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: darkText),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "CONFIRMED",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── SHIFT IN (PUNCH IN WITH PIN) MODAL ───
  void _showShiftInModal() {
    if (_registeredAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("No staff registered. Please add a counter agent first."),
          action: SnackBarAction(
            label: "Add Staff",
            textColor: Colors.amber,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CounterStaffScreen(
                    terminalCity: terminalCity,
                    terminalName: terminalName,
                  ),
                ),
              );
              _loadShiftData();
            },
          ),
        ),
      );
      return;
    }

    Map<String, dynamic> selectedAgent = _registeredAgents.first;
    final hour = DateTime.now().hour;
    String shiftType = (hour >= 6 && hour < 14)
        ? "Morning"
        : (hour >= 14 && hour < 22 ? "Evening" : "Night");
    final pinCtrl = TextEditingController();
    final floatCtrl = TextEditingController(text: "0");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.login_rounded, color: primaryBlue, size: 20),
                SizedBox(width: 8),
                Text("Agent Shift Clock-In", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select duty agent and enter 4-digit security PIN to punch in at counter.",
                    style: TextStyle(fontSize: 11.5, color: subText),
                  ),
                  const SizedBox(height: 14),

                  // Agent Selector
                  const Text("DUTY AGENT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subText)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: selectedAgent['id'] as int,
                        items: _registeredAgents.map((ag) {
                          return DropdownMenuItem<int>(
                            value: ag['id'] as int,
                            child: Text("${ag['name']} (${ag['agentCode']})", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedAgent = _registeredAgents.firstWhere((a) => a['id'] == val);
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Shift Type
                  const Text("SHIFT TIMING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subText)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: shiftType,
                        items: const [
                          DropdownMenuItem(value: "Morning", child: Text("Morning (08:00 AM - 04:00 PM)", style: TextStyle(fontSize: 12.5))),
                          DropdownMenuItem(value: "Evening", child: Text("Evening (04:00 PM - 12:00 AM)", style: TextStyle(fontSize: 12.5))),
                          DropdownMenuItem(value: "Night", child: Text("Night (12:00 AM - 08:00 AM)", style: TextStyle(fontSize: 12.5))),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => shiftType = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Opening Drawer Float
                  const Text("OPENING CASH FLOAT (PKR)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: floatCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.money_rounded, size: 18, color: primaryBlue),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4-Digit PIN
                  const Text("SECURITY PIN (4 DIGITS)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subText)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 4),
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "••••",
                      prefixIcon: const Icon(Icons.pin_rounded, size: 18, color: primaryBlue),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: subText, fontSize: 12.5)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final pin = pinCtrl.text.trim();
                  if (pin.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a 4-digit PIN.")),
                    );
                    return;
                  }

                  final verified = await DBHelper.instance.verifyAgentPin(selectedAgent['id'] as int, pin);
                  if (verified == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Invalid PIN! Verification failed."), backgroundColor: Colors.red),
                      );
                    }
                    return;
                  }

                  final opFloat = double.tryParse(floatCtrl.text.trim()) ?? 0.0;
                  await DBHelper.instance.startShift(
                    agentId: selectedAgent['id'] as int,
                    agentName: selectedAgent['name'] ?? 'Agent',
                    agentCode: selectedAgent['agentCode'] ?? '-',
                    shiftType: shiftType,
                    openingFloat: opFloat,
                    terminalCity: terminalCity,
                    terminalName: terminalName,
                  );

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Shift Started: ${selectedAgent['name']} is ON DUTY!"),
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                    );
                    _loadShiftData();
                  }
                },
                child: const Text("Verify & Clock In", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }
}

