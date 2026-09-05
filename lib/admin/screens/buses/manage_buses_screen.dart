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
  List<DateTime> next10Days = [];
  List<BusModel> buses = [];
  Map<int, int> bookedSeatsCount = {};

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _generateDates();
    _loadBuses();
    DBHelper.instance.cleanOldBusesAndBookings();
  }

  void _generateDates() {
    next10Days = List.generate(10, (i) => DateTime.now().add(Duration(days: i)));
  }

  Future<void> _loadBuses() async {
    final dateKey = _formatDate(selectedDate);
    final list = await DBHelper.instance.getBusesByDate(dateKey);

    List<BusModel> loadedBuses = list.map((e) => BusModel.fromMap(e)).toList();
    loadedBuses.sort((a, b) => a.time.compareTo(b.time));

    Map<int, int> tempCount = {};
    for (var bus in loadedBuses) {
      final bookedList = await DBHelper.instance.getBookedSeatsWithGender(bus.id!);
      tempCount[bus.id!] = bookedList.length;
    }

    if (mounted) {
      setState(() {
        buses = loadedBuses;
        bookedSeatsCount = tempCount;
      });
    }
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
      backgroundColor: const Color(0xFFF8FAFC),
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
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          "Add Bus",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditBusScreen()),
          );
          await _loadBuses();
        },
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // -------------------- DATE SELECTOR ---------------------
          SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: next10Days.length,
              itemBuilder: (context, i) {
                final d = next10Days[i];
                final active = _formatDate(d) == _formatDate(selectedDate);

                return GestureDetector(
                  onTap: () {
                    setState(() => selectedDate = d);
                    _loadBuses();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 66,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? primaryBlue : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? primaryBlue : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: active ? primaryBlue.withOpacity(0.25) : Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dayName(d),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white70 : subText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${d.day}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : darkText,
                            ),
                          ),
                          Text(
                            _monthShort(d),
                            style: TextStyle(
                              fontSize: 10,
                              color: active ? Colors.white70 : subText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // -------------------- BUSES LIST ---------------------
          Expanded(
            child: RefreshIndicator(
              color: primaryBlue,
              onRefresh: _loadBuses,
              child: buses.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 60),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.directions_bus_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'No buses scheduled for this date',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: subText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap "+ Add Bus" to register a new schedule',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: buses.length,
                      itemBuilder: (context, idx) => _busCard(buses[idx]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _busCard(BusModel b) {
    final int booked = bookedSeatsCount[b.id!] ?? 0;
    final int seatsLeft = b.seats - booked;
    final Color seatsTextColor = seatsLeft <= 0 ? Colors.redAccent : primaryBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Timing, Bus Number, Class, Fare
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: primaryBlue),
                    const SizedBox(width: 4),
                    Text(
                      b.time,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  b.busClass,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: subText,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                "PKR ${b.fare.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Route: From -> To
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, size: 14, color: primaryBlue),
              const SizedBox(width: 6),
              Text(
                b.fromCity,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: darkText),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 14, color: subText),
              ),
              const Icon(Icons.location_on_rounded, size: 14, color: Colors.redAccent),
              const SizedBox(width: 4),
              Text(
                b.toCity,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: darkText),
              ),
            ],
          ),

          if (b.routeVia.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                "Via ${b.routeVia}",
                style: const TextStyle(color: subText, fontSize: 11),
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Bottom Bar: Seats Left, Edit & Delete Buttons
          Row(
            children: [
              Icon(Icons.airline_seat_recline_extra_rounded, size: 16, color: seatsTextColor),
              const SizedBox(width: 4),
              Text(
                "$seatsLeft Seats Left",
                style: TextStyle(
                  color: seatsTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (b.busNumber.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text("•  ${b.busNumber}", style: const TextStyle(fontSize: 11, color: subText)),
              ],
              const Spacer(),
              // Edit button
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AddEditBusScreen(bus: b)),
                  );
                  await _loadBuses();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Edit",
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete button
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text("Delete Bus Schedule"),
                      content: const Text("Are you sure you want to delete this bus schedule?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Delete", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await SupabaseService.instance.deleteBus(b.id!);
                    } catch (e) {
                      print("Supabase delete error: $e");
                    }
                    await DBHelper.instance.deleteBus(b.id!);
                    await _loadBuses();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}