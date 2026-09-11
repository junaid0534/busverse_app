import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:intl/intl.dart';
import 'shift_slip_screen.dart';
import 'shift_handover_screen.dart';

class ShiftReportScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const ShiftReportScreen({super.key, this.userProfile});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _shiftBookings = [];
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;
  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();

  // Active Shift & Registered Agents state
  Map<String, dynamic>? _activeShift;
  List<Map<String, dynamic>> _registeredAgents = [];

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
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
    final fn = widget.userProfile?['firstName'] ?? 'Terminal';
    final ln = widget.userProfile?['lastName'] ?? 'Agent';
    return "$fn $ln".trim();
  }

  String get currentAgentCode {
    if (_activeShift != null && _activeShift!['agentCode'] != null) {
      return _activeShift!['agentCode'];
    }
    return "AGT-101";
  }

  String get currentShiftType {
    if (_activeShift != null && _activeShift!['shiftType'] != null) {
      return _activeShift!['shiftType'];
    }
    return "Morning";
  }

  double get openingFloat {
    if (_activeShift != null && _activeShift!['openingFloat'] != null) {
      return (_activeShift!['openingFloat'] as num).toDouble();
    }
    return 5000.0;
  }
  String get agentEmail => widget.userProfile?['email'] ?? 'agent@busverse.com';

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
          _stats = stats;
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

  double get _totalRevenue {
    if (_stats['todayRevenue'] != null && (_stats['todayRevenue'] as num) > 0) {
      return (_stats['todayRevenue'] as num).toDouble();
    }
    return (_stats['totalRevenue'] as num?)?.toDouble() ?? 0.0;
  }

  int get _totalTickets {
    if (_stats['todayBookings'] != null && (_stats['todayBookings'] as int) > 0) {
      return _stats['todayBookings'] as int;
    }
    return _shiftBookings.length;
  }

  double get _cashRevenue {
    double cash = 0.0;
    for (var b in _shiftBookings) {
      final method = (b['paymentMethod'] ?? '').toString().toLowerCase();
      final fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
      if (method.contains('cash') || method.isEmpty) {
        cash += fare;
      }
    }
    return cash > 0 ? cash : _totalRevenue;
  }

  double get _digitalRevenue {
    double dig = 0.0;
    for (var b in _shiftBookings) {
      final method = (b['paymentMethod'] ?? '').toString().toLowerCase();
      final fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
      if (!method.contains('cash') && method.isNotEmpty) {
        dig += fare;
      }
    }
    return dig;
  }

  double get _netDrawerCash => openingFloat + _cashRevenue;

  List<Map<String, dynamic>> get _filteredBookings {
    if (_searchQuery.trim().isEmpty) return _shiftBookings;
    final q = _searchQuery.trim().toLowerCase();
    return _shiftBookings.where((b) {
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
          "Counter Shift & Handover",
          style: TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_rounded, color: darkNavy, size: 20),
            tooltip: "Manage Agents & PINs",
            onPressed: _showAgentManagementModal,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Shift Duty Card
                    _buildShiftHeaderCard(),

                    const SizedBox(height: 14),

                    // 2. Overview Financial KPIs
                    _buildKpiGrid(),

                    const SizedBox(height: 14),

                    // 3. Cash Drawer Reconciliation Card
                    _buildCashDrawerCard(),

                    const SizedBox(height: 16),

                    // 4. Shift Issued Tickets Header & Search
                    _buildTransactionsSectionHeader(),

                    const SizedBox(height: 10),

                    // 5. Shift Bookings List
                    _buildTransactionsList(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  // ─── 1. SHIFT DUTY HEADER CARD ───
  Widget _buildShiftHeaderCard() {
    final dateFormatted = DateFormat('EEEE, dd MMMM yyyy').format(_currentTime);
    final timeFormatted = DateFormat('hh:mm:ss a').format(_currentTime);
    final bool hasActiveShift = _activeShift != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.badge_rounded, color: primaryBlue, size: 20),
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
                                  currentAgentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: darkText),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  currentAgentCode,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: primaryBlue),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "$currentShiftType Shift • Float: PKR ${openingFloat.toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 11, color: subText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: hasActiveShift ? null : _showShiftInModal,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasActiveShift ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasActiveShift ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 3.5,
                        backgroundColor: hasActiveShift ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hasActiveShift ? "ON DUTY (PIN OK)" : "CLOCK IN REQUIRED",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: hasActiveShift ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metaInfo("TERMINAL LOCATION", "$terminalCity • $terminalName"),
              ),
              Expanded(
                child: _metaInfo("SHIFT DATE", dateFormatted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metaInfo("LIVE TIME", timeFormatted),
              ),
              Expanded(
                child: _metaInfo(
                  "SHIFT IN TIME",
                  _activeShift?['openingTime'] != null
                      ? DateFormat('hh:mm a').format(DateTime.parse(_activeShift!['openingTime']))
                      : "08:00 AM (Auto)",
                ),
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
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: subText)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
        ),
      ],
    );
  }

  // ─── 2. KPI GRID ───
  Widget _buildKpiGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: "Shift Total Revenue",
                value: "PKR ${_totalRevenue.toStringAsFixed(0)}",
                subtitle: "Total collections",
                icon: Icons.payments_rounded,
                color: primaryBlue,
                bgLight: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: "Tickets Issued",
                value: "$_totalTickets",
                subtitle: "Walk-in & counter",
                icon: Icons.confirmation_number_rounded,
                color: const Color(0xFF10B981),
                bgLight: const Color(0xFFF0FDF4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: "Cash at Counter",
                value: "PKR ${_cashRevenue.toStringAsFixed(0)}",
                subtitle: "Ticket cash sales",
                icon: Icons.point_of_sale_rounded,
                color: const Color(0xFFF59E0B),
                bgLight: const Color(0xFFFFFBEB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpiCard(
                title: "Card / Digital POS",
                value: "PKR ${_digitalRevenue.toStringAsFixed(0)}",
                subtitle: "Online / machine",
                icon: Icons.credit_card_rounded,
                color: const Color(0xFF8B5CF6),
                bgLight: const Color(0xFFF5F3FF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgLight,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subText),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(7)),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: subText),
          ),
        ],
      ),
    );
  }

  // ─── 3. CASH DRAWER CARD ───
  Widget _buildCashDrawerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                  color: darkNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: darkNavy),
              ),
              const SizedBox(width: 8),
              const Text(
                "Cash Drawer Reconciliation",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkText),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _drawerRow("Opening Drawer Float (Change)", "PKR ${openingFloat.toStringAsFixed(0)}", isMuted: true),
          const SizedBox(height: 6),
          _drawerRow("(+) Shift Cash Ticket Sales", "PKR ${_cashRevenue.toStringAsFixed(0)}", isPositive: true),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerRow(String title, String amount, {bool isPositive = false, bool isMuted = false}) {
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
            fontWeight: FontWeight.w600,
            color: isPositive ? const Color(0xFF16A34A) : (isMuted ? subText : darkText),
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

  // ─── BOTTOM ACTIONS BAR ───
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long_rounded, size: 16, color: darkNavy),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
              label: const Text("Shift Slip", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkNavy)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                      netDrawerCash: _netDrawerCash,
                      cashRevenue: _cashRevenue,
                      digitalRevenue: _digitalRevenue,
                      totalTickets: _totalTickets,
                    ),
                  ),
                );
                _loadShiftData();
              },
              label: const Text("PIN Handover & Out", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHIFT IN (PUNCH IN WITH PIN) MODAL ───
  void _showShiftInModal() {
    if (_registeredAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No agents found. Please register an agent first.")),
      );
      return;
    }

    Map<String, dynamic> selectedAgent = _registeredAgents.first;
    String shiftType = "Morning";
    final pinCtrl = TextEditingController();
    final floatCtrl = TextEditingController(text: "5000");

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

                  final opFloat = double.tryParse(floatCtrl.text.trim()) ?? 5000.0;
                  await DBHelper.instance.startShift(
                    agentId: selectedAgent['id'] as int,
                    agentName: selectedAgent['name'] ?? 'Agent',
                    agentCode: selectedAgent['agentCode'] ?? 'AGT-01',
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

  // ─── AGENT MANAGEMENT MODAL ───
  void _showAgentManagementModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_rounded, color: primaryBlue, size: 20),
                    SizedBox(width: 8),
                    Text("Counter Staff & PINs", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_rounded, color: primaryBlue, size: 20),
                  tooltip: "Register New Agent",
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showRegisterAgentDialog();
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _registeredAgents.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No agents registered for this terminal yet.", style: TextStyle(color: subText, fontSize: 12)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _registeredAgents.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: borderColor),
                      itemBuilder: (c, idx) {
                        final ag = _registeredAgents[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryBlue.withValues(alpha: 0.1),
                            child: Text(
                              (ag['name'] ?? 'A')[0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, color: primaryBlue),
                            ),
                          ),
                          title: Text(ag['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText)),
                          subtitle: Text("Code: ${ag['agentCode']} • PIN: •••• (${ag['phone'] ?? ''})", style: const TextStyle(fontSize: 11, color: subText)),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 16, color: primaryBlue),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showEditAgentDialog(ag);
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close", style: TextStyle(color: subText, fontSize: 12.5)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Register New Agent Dialog
  void _showRegisterAgentDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController(text: "AGT-10${_registeredAgents.length + 1}");
    final pinCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Register Counter Agent", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Full Name", labelStyle: TextStyle(fontSize: 12)),
              ),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: "Agent Code (e.g. AGT-104)", labelStyle: TextStyle(fontSize: 12)),
              ),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone Number", labelStyle: TextStyle(fontSize: 12)),
              ),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(labelText: "4-Digit Security PIN", counterText: "", labelStyle: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || pinCtrl.text.trim().length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Name and 4-digit PIN are required.")),
                );
                return;
              }
              await DBHelper.instance.addTerminalAgent(
                agentCode: codeCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                pin: pinCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                terminalCity: terminalCity,
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Agent registered successfully!"), backgroundColor: Color(0xFF16A34A)),
                );
                _loadShiftData();
              }
            },
            child: const Text("Register"),
          ),
        ],
      ),
    );
  }

  // Edit Agent PIN Dialog
  void _showEditAgentDialog(Map<String, dynamic> agent) {
    final nameCtrl = TextEditingController(text: agent['name'] ?? '');
    final pinCtrl = TextEditingController(text: agent['pin'] ?? '');
    final phoneCtrl = TextEditingController(text: agent['phone'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Edit ${agent['agentCode']}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Full Name", labelStyle: TextStyle(fontSize: 12)),
              ),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone Number", labelStyle: TextStyle(fontSize: 12)),
              ),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(labelText: "New 4-Digit PIN", counterText: "", labelStyle: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
            onPressed: () async {
              if (pinCtrl.text.trim().length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN must be 4 digits.")));
                return;
              }
              await DBHelper.instance.updateTerminalAgent(
                agentId: agent['id'] as int,
                name: nameCtrl.text.trim(),
                pin: pinCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agent updated!"), backgroundColor: Color(0xFF16A34A)));
                _loadShiftData();
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}
