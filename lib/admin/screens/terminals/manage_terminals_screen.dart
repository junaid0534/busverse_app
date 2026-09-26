import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/admin/screens/sub_admins/add_edit_sub_admin_screen.dart';
import 'package:bus_ticket_system/admin/screens/terminals/terminal_detail_screen.dart';

class ManageTerminalsScreen extends StatefulWidget {
  const ManageTerminalsScreen({super.key});

  @override
  State<ManageTerminalsScreen> createState() => _ManageTerminalsScreenState();
}

class _ManageTerminalsScreenState extends State<ManageTerminalsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic> _summaryData = {};
  List<Map<String, dynamic>> _terminals = [];
  List<Map<String, dynamic>> _filteredTerminals = [];

  String _searchQuery = "";
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = "all"; // "all", "active", "closed", or specific city

  Timer? _pollingTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color cardBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTerminalsData();
    // Auto-refresh real-time polling every 8 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadTerminalsData(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTerminalsData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await DBHelper.instance.getAllTerminalsLiveStats();
      if (mounted) {
        setState(() {
          _summaryData = data;
          _terminals = (data['terminals'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          _applyFilters();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading terminal data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> list = List.from(_terminals);

    // 1. Status / City filter
    if (_selectedFilter == "active") {
      list = list.where((t) => t['isShiftActive'] == true).toList();
    } else if (_selectedFilter == "closed") {
      list = list.where((t) => t['isShiftActive'] == false).toList();
    } else if (_selectedFilter != "all") {
      list = list.where((t) => (t['city'] ?? '').toString().toLowerCase() == _selectedFilter.toLowerCase()).toList();
    }

    // 2. Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((t) {
        final city = (t['city'] ?? '').toString().toLowerCase();
        final name = (t['terminalName'] ?? '').toString().toLowerCase();
        final manager = (t['managerName'] ?? '').toString().toLowerCase();
        final agent = (t['dutyAgentName'] ?? '').toString().toLowerCase();
        final code = (t['dutyAgentCode'] ?? '').toString().toLowerCase();
        return city.contains(q) || name.contains(q) || manager.contains(q) || agent.contains(q) || code.contains(q);
      }).toList();
    }

    _filteredTerminals = list;
  }

  Future<void> _openAddSubAdmin() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditSubAdminScreen()),
    );
    if (res == true) {
      _loadTerminalsData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalTerminals = _summaryData['totalTerminals'] ?? _terminals.length;
    final int activeShifts = _summaryData['activeShiftsCount'] ?? 0;
    final int todayBookings = _summaryData['todayBookingsCount'] ?? 0;
    final double todayRevenue = (_summaryData['todayTotalRevenue'] as num?)?.toDouble() ?? 0.0;
    final double overallCash = (_summaryData['overallDrawerCash'] as num?)?.toDouble() ?? 0.0;

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                "Manage Terminals",
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            // Live Real-Time Badge with pulse
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (ctx, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                          "LIVE",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF15803D),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Live Data",
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue),
                  )
                : const Icon(Icons.refresh_rounded, color: primaryBlue, size: 22),
            onPressed: () {
              setState(() => _isRefreshing = true);
              _loadTerminalsData(silent: true);
            },
          ),
          IconButton(
            tooltip: "Assign / Add Terminal Manager",
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_location_alt_rounded, color: primaryBlue, size: 18),
            ),
            onPressed: _openAddSubAdmin,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : RefreshIndicator(
              color: primaryBlue,
              onRefresh: () => _loadTerminalsData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Overall Live KPI Banner (4 Cards in 1 Row)
                    _buildOverviewKpiRow(
                      totalTerminals: totalTerminals,
                      activeShifts: activeShifts,
                      todayBookings: todayBookings,
                      todayRevenue: todayRevenue,
                      overallCash: overallCash,
                    ),

                    const SizedBox(height: 16),

                    // 2. Search & Filter Bar
                    _buildSearchAndFilters(),

                    const SizedBox(height: 16),

                    // 3. Terminals Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Terminals Nationwide",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${_filteredTerminals.length}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "Auto-synced: ${DateFormat('hh:mm:ss a').format(DateTime.now())}",
                          style: const TextStyle(fontSize: 10.5, color: subText, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 4. Terminals Cards List
                    if (_filteredTerminals.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredTerminals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _buildTerminalCard(_filteredTerminals[i]),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── 1. OVERVIEW KPI ROW ───
  Widget _buildOverviewKpiRow({
    required int totalTerminals,
    required int activeShifts,
    required int todayBookings,
    required double todayRevenue,
    required double overallCash,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 16, color: primaryBlue),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Live Terminal Network Overview",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$activeShifts / $totalTerminals Active",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.store_rounded,
                  title: "Terminals",
                  value: "$totalTerminals",
                  badge: "$activeShifts Live",
                  badgeColor: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.confirmation_number_rounded,
                  title: "Tickets",
                  value: "$todayBookings",
                  badge: "Counter",
                  badgeColor: const Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.payments_rounded,
                  title: "Revenue",
                  value: "PKR ${todayRevenue.toStringAsFixed(0)}",
                  badge: "Live",
                  badgeColor: primaryBlue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMiniStat(
                  icon: Icons.point_of_sale_rounded,
                  title: "Drawers",
                  value: "PKR ${overallCash.toStringAsFixed(0)}",
                  badge: "Cash",
                  badgeColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String title,
    required String value,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 16, color: primaryBlue),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: badgeColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: subText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: primaryBlue,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. SEARCH & FILTER SECTION ───
  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Container(
          height: 44,
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
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applyFilters();
              });
            },
            style: const TextStyle(fontSize: 13, color: darkText, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: "Search city, terminal, agent, manager...",
              hintStyle: const TextStyle(fontSize: 12.5, color: subText),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: primaryBlue),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: subText),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = "";
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Filter Chips Horizontal List
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip("all", "All Terminals (${_terminals.length})", Icons.layers_rounded),
              const SizedBox(width: 6),
              _buildFilterChip("active", "🟢 Live Active Shifts", Icons.bolt_rounded, isHighlight: true),
              const SizedBox(width: 6),
              _buildFilterChip("closed", "⚪ Shift Closed", Icons.pause_circle_outline_rounded),
              ..._terminals.map((t) {
                final city = (t['city'] ?? '').toString();
                if (city.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _buildFilterChip(city.toLowerCase(), city, Icons.location_city_rounded),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, {bool isHighlight = false}) {
    final bool isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = key;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : (isHighlight ? const Color(0xFFF0FDF4) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? primaryBlue
                : (isHighlight ? const Color(0xFF86EFAC) : borderColor),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : (isHighlight ? const Color(0xFF16A34A) : subText),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isHighlight ? const Color(0xFF15803D) : darkText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. HIGH PERFORMANCE TERMINAL CARD ───
  Widget _buildTerminalCard(Map<String, dynamic> terminal) {
    final String city = terminal['city'] ?? 'Terminal';
    final String terminalName = terminal['terminalName'] ?? "$city Terminal";
    final bool isShiftActive = terminal['isShiftActive'] == true;
    final String dutyAgent = terminal['dutyAgentName'] ?? '';
    final String dutyAgentCode = terminal['dutyAgentCode'] ?? '';
    final String shiftType = terminal['shiftType'] ?? 'General';
    final String shiftInTime = terminal['shiftOpeningTime'] ?? '';
    final double netDrawerCash = (terminal['netDrawerCash'] as num?)?.toDouble() ?? 0.0;
    final double todayRevenue = (terminal['todayRevenue'] as num?)?.toDouble() ?? 0.0;
    final int todayBookings = terminal['todayBookings'] ?? 0;
    final int registeredAgents = terminal['registeredAgentsCount'] ?? 0;
    final int scheduledBuses = terminal['scheduledBusesToday'] ?? 0;
    final String managerName = terminal['managerName'] ?? 'Unassigned';

    String formattedShiftIn = '';
    if (shiftInTime.isNotEmpty) {
      final dt = DateTime.tryParse(shiftInTime);
      if (dt != null) formattedShiftIn = DateFormat('hh:mm a').format(dt);
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isShiftActive ? primaryBlue.withValues(alpha: 0.35) : borderColor,
          width: isShiftActive ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isShiftActive
                ? primaryBlue.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TerminalDetailScreen(terminalCity: city),
              ),
            ).then((_) => _loadTerminalsData(silent: true));
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: City & Station + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isShiftActive
                            ? primaryBlue.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        size: 22,
                        color: isShiftActive ? primaryBlue : subText,
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
                                  city,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: darkText,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: bgSurface,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  "POS Terminal",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isShiftActive ? primaryBlue : subText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            terminalName,
                            style: const TextStyle(fontSize: 11.5, color: subText, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Live Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isShiftActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isShiftActive ? const Color(0xFF86EFAC) : borderColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 3.5,
                            backgroundColor: isShiftActive ? const Color(0xFF16A34A) : subText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isShiftActive ? "SHIFT OPEN" : "CLOSED",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isShiftActive ? const Color(0xFF15803D) : subText,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Duty Agent or Manager Status Banner
                if (isShiftActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: primaryBlue,
                          child: Icon(Icons.person_rounded, size: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dutyAgent,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: darkText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "Duty Agent ($dutyAgentCode) • $shiftType Shift${formattedShiftIn.isNotEmpty ? ' • In at $formattedShiftIn' : ''}",
                                style: const TextStyle(fontSize: 10, color: subText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("Drawer Cash", style: TextStyle(fontSize: 9, color: subText, fontWeight: FontWeight.w600)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "PKR ${netDrawerCash.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.manage_accounts_rounded, size: 16, color: subText),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Incharge: $managerName",
                            style: const TextStyle(fontSize: 11, color: darkText, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Off duty",
                          style: TextStyle(fontSize: 9.5, color: subText, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: borderColor),
                const SizedBox(height: 10),

                // 3-Column Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.payments_rounded,
                        label: "Today Sales",
                        value: "PKR ${todayRevenue.toStringAsFixed(0)}",
                        valueColor: primaryBlue,
                      ),
                    ),
                    Container(height: 20, width: 1, color: borderColor),
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.receipt_long_rounded,
                        label: "Tickets",
                        value: "$todayBookings Sold",
                        valueColor: darkText,
                      ),
                    ),
                    Container(height: 20, width: 1, color: borderColor),
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.people_outline_rounded,
                        label: "Staff/Buses",
                        value: "$registeredAgents Staff • $scheduledBuses Buses",
                        valueColor: subText,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Bottom Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Live Terminal Monitor",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isShiftActive ? primaryBlue : subText,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: isShiftActive ? primaryBlue : subText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: subText),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 9.5, color: subText, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_off_rounded, size: 44, color: subText),
          const SizedBox(height: 12),
          const Text(
            "No Terminals Found",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: darkText),
          ),
          const SizedBox(height: 4),
          const Text(
            "Try changing your search query or filter selection.",
            style: TextStyle(fontSize: 12, color: subText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text("Reset Filters", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _searchQuery = "";
                _selectedFilter = "all";
                _applyFilters();
              });
            },
          ),
        ],
      ),
    );
  }
}
