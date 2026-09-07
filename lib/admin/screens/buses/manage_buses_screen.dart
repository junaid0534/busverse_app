import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'add_edit_bus_screen.dart';

class ManageBusesScreen extends StatefulWidget {
  const ManageBusesScreen({super.key});

  @override
  State<ManageBusesScreen> createState() => _ManageBusesScreenState();
}

class _ManageBusesScreenState extends State<ManageBusesScreen> {
  DateTime selectedDate = DateTime.now();
  List<DateTime> next14Days = [];
  List<BusModel> buses = [];
  List<BusModel> filteredBuses = [];
  Map<int, int> bookedSeatsCount = {};
  bool isLoading = true;
  String searchQuery = "";
  String selectedBusClassFilter = "All";
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadBuses();
    DBHelper.instance.cleanOldBusesAndBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _generateDates() {
    next14Days = List.generate(14, (i) => DateTime.now().add(Duration(days: i)));
  }

  Future<void> _loadBuses() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final dateKey = _formatDate(selectedDate);
    final list = await DBHelper.instance.getBusesByDate(dateKey);

    List<BusModel> loadedBuses = list.map((e) => BusModel.fromMap(e)).toList();
    loadedBuses.sort((a, b) => a.time.compareTo(b.time));

    Map<int, int> tempCount = {};
    for (var bus in loadedBuses) {
      if (bus.id != null) {
        final bookedList = await DBHelper.instance.getBookedSeatsWithGender(bus.id!);
        tempCount[bus.id!] = bookedList.length;
      }
    }

    if (mounted) {
      setState(() {
        buses = loadedBuses;
        bookedSeatsCount = tempCount;
        _applySearchFilter();
        isLoading = false;
      });
    }
  }

  void _applySearchFilter() {
    final q = searchQuery.toLowerCase().trim();
    filteredBuses = buses.where((b) {
      final matchesQuery = q.isEmpty ||
          b.busName.toLowerCase().contains(q) ||
          b.busNumber.toLowerCase().contains(q) ||
          b.fromCity.toLowerCase().contains(q) ||
          b.toCity.toLowerCase().contains(q) ||
          b.busClass.toLowerCase().contains(q) ||
          b.routeVia.toLowerCase().contains(q);

      final matchesClass = selectedBusClassFilter == "All" ||
          b.busClass.toLowerCase() == selectedBusClassFilter.toLowerCase();

      return matchesQuery && matchesClass;
    }).toList();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String _dayName(DateTime dt) {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return names[dt.weekday % 7];
  }

  String _monthShort(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return m[d.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgSurface,

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Bus Schedules',
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: darkText, size: 22),
            tooltip: 'Refresh',
            onPressed: _loadBuses,
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ================= FLOATING ACTION BUTTON =================
      floatingActionButton: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
          label: const Text(
            "Add Bus",
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditBusScreen()),
            );
            await _loadBuses();
          },
        ),
      ),

      // ================= BODY =================
      body: Column(
        children: [
          // ─── 1. COMPACT DATE STRIP ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Select Travel Date",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: subText,
                        ),
                      ),
                      Text(
                        "${_dayName(selectedDate)}, ${selectedDate.day} ${_monthShort(selectedDate)} ${selectedDate.year}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 58,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: next14Days.length,
                    itemBuilder: (context, i) {
                      final d = next14Days[i];
                      final bool active = _formatDate(d) == _formatDate(selectedDate);
                      final bool isToday = _formatDate(d) == _formatDate(DateTime.now());

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDate = d;
                          });
                          _loadBuses();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: active ? primaryBlue : (isToday ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active
                                  ? primaryBlue
                                  : (isToday ? primaryBlue.withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
                              width: active ? 1.5 : 1,
                            ),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: primaryBlue.withValues(alpha: 0.28),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isToday ? "Today" : _dayName(d),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                                  color: active ? Colors.white70 : (isToday ? primaryBlue : subText),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                "${d.day}",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: active ? Colors.white : darkText,
                                ),
                              ),
                              Text(
                                _monthShort(d),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: active ? Colors.white70 : subText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ─── 2. SEARCH & CLASS DROPDOWN BAR ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                // Search Input Field
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                          _applySearchFilter();
                        });
                      },
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: darkText,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: "Search Bus",
                        hintStyle: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: primaryBlue),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, size: 18, color: subText),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    searchQuery = "";
                                    _applySearchFilter();
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Bus Class Filter Dropdown
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryBlue),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedBusClassFilter,
                      dropdownColor: Colors.white,
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                      ),
                      selectedItemBuilder: (context) {
                        return [
                          "All",
                          "Executive",
                          "Luxury",
                          "Business",
                          "Economy",
                          "Sleeper",
                        ].map((val) {
                          final label = val == "All" ? "All Classes" : val;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tune_rounded, color: Colors.white, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                      items: const [
                        DropdownMenuItem(
                          value: "All",
                          child: Text("All Classes", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                        ),
                        DropdownMenuItem(
                          value: "Executive",
                          child: Text("Executive", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                        ),
                        DropdownMenuItem(
                          value: "Luxury",
                          child: Text("Luxury", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                        ),
                        DropdownMenuItem(
                          value: "Business",
                          child: Text("Business", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                        ),
                        DropdownMenuItem(
                          value: "Economy",
                          child: Text("Economy", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                        ),
                        DropdownMenuItem(
                          value: "Sleeper",
                          child: Text("Sleeper", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText)),
                        ),
                      ],
                      onChanged: (String? newVal) {
                        if (newVal != null) {
                          setState(() {
                            selectedBusClassFilter = newVal;
                            _applySearchFilter();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 3. BUSES LIST ───
          Expanded(
            child: RefreshIndicator(
              color: primaryBlue,
              onRefresh: _loadBuses,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                  : filteredBuses.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 50),
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Icon(
                                      Icons.directions_bus_outlined,
                                      size: 42,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'No buses match "$searchQuery"'
                                        : 'No buses scheduled for this date',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: darkText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'Try searching with a different city or bus name'
                                        : 'Tap "+ Add Bus" to register a new schedule',
                                    style: const TextStyle(fontSize: 12, color: subText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                          itemCount: filteredBuses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) => _buildBusCard(filteredBuses[idx]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BUS SCHEDULE CARD ───
  Widget _buildBusCard(BusModel b) {
    final int booked = bookedSeatsCount[b.id!] ?? 0;
    final int totalSeats = b.seats > 0 ? b.seats : 36;
    final int seatsLeft = totalSeats - booked;
    final double occupancy = (booked / totalSeats).clamp(0.0, 1.0);

    Color statusColor = const Color(0xFF10B981);
    String statusText = "$seatsLeft Left";
    if (seatsLeft <= 0) {
      statusColor = const Color(0xFFEF4444);
      statusText = "Sold Out";
    } else if (seatsLeft <= 5) {
      statusColor = const Color(0xFFF59E0B);
      statusText = "Only $seatsLeft Left";
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Time, Bus Name, Bus Number, Fare ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_filled_rounded, size: 12, color: primaryBlue),
                    const SizedBox(width: 4),
                    Text(
                      b.time,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        b.busName.isNotEmpty ? b.busName : "BusVerse",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: darkText,
                        ),
                      ),
                    ),
                    if (b.busNumber.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          b.busNumber,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: subText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                "Rs. ${b.fare.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: darkText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Route: From -> To (Via) ──
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                b.fromCity,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: darkText,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 13, color: subText),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                b.toCity,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: darkText,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.busClass,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: subText,
                  ),
                ),
              ),
            ],
          ),

          if (b.routeVia.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 13),
              child: Text(
                "Via ${b.routeVia}",
                style: const TextStyle(color: subText, fontSize: 10.5),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── Seat Occupancy Progress Bar ──
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: occupancy,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      occupancy >= 1.0
                          ? const Color(0xFFEF4444)
                          : (occupancy > 0.75 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "$booked/$totalSeats Booked • $statusText",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // ── Action Buttons: Bookings / Seats, Edit, Delete ──
          Row(
            children: [
              // View Bookings Button
              InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/view_all_booking',
                    arguments: {
                      'busId': b.id,
                      'fromCity': b.fromCity,
                      'toCity': b.toCity,
                      'date': b.date,
                    },
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.confirmation_num_outlined, size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        booked > 0 ? "Bookings ($booked)" : "View Seats",
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Edit Button
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddEditBusScreen(bus: b)),
                  );
                  await _loadBuses();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Text(
                    "Edit",
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Delete Button
              InkWell(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                          SizedBox(width: 8),
                          Text(
                            "Delete Bus",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
                          ),
                        ],
                      ),
                      content: Text(
                        "Are you sure you want to delete ${b.busName} (${b.fromCity} → ${b.toCity}) at ${b.time}?",
                        style: const TextStyle(fontSize: 13, color: subText),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel", style: TextStyle(color: subText, fontWeight: FontWeight.w600)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && b.id != null) {
                    try {
                      await SupabaseService.instance.deleteBus(b.id!);
                    } catch (_) {}
                    await DBHelper.instance.deleteBus(b.id!);
                    await _loadBuses();
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  child: const Text(
                    "Delete",
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
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