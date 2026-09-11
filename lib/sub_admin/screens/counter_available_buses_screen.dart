import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:bus_ticket_system/sub_admin/screens/counter_book_seat_screen.dart';
import 'package:intl/intl.dart';

class CounterAvailableBusesScreen extends StatefulWidget {
  final List<BusModel> buses;
  final String fromCity;
  final String toCity;
  final DateTime selectedDate;
  final Map<String, dynamic>? userProfile;

  const CounterAvailableBusesScreen({
    super.key,
    required this.buses,
    required this.fromCity,
    required this.toCity,
    required this.selectedDate,
    this.userProfile,
  });

  @override
  State<CounterAvailableBusesScreen> createState() => _CounterAvailableBusesScreenState();
}

class _CounterAvailableBusesScreenState extends State<CounterAvailableBusesScreen> {
  late List<BusModel> _currentBuses;
  Map<int, int> _bookedSeatsCount = {};

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _currentBuses = widget.buses;
    _loadBookedSeatsCount();
  }

  Future<void> _loadBookedSeatsCount() async {
    Map<int, int> tempCount = {};

    for (var bus in _currentBuses) {
      if (bus.id == null) continue;
      // 1. Supabase live booked seats
      try {
        final onlineSeats = await SupabaseService.instance.getBookedSeats(bus.id!);
        if (onlineSeats.isNotEmpty) {
          tempCount[bus.id!] = onlineSeats.length;
          continue;
        }
      } catch (_) {}

      // 2. Local SQLite
      try {
        final bookedList = await DBHelper.instance.getBookedSeatsWithGender(bus.id!);
        tempCount[bus.id!] = bookedList.length;
      } catch (_) {
        tempCount[bus.id!] = 0;
      }
    }

    if (mounted) {
      setState(() {
        _bookedSeatsCount = tempCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('EEE, dd MMM yyyy').format(widget.selectedDate);

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              "${widget.fromCity} ➔ ${widget.toCity}",
              style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w600, fontSize: 15.5),
            ),
            Text(
              dateFormatted,
              style: const TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _currentBuses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: primaryBlue.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_bus_filled_rounded, size: 42, color: primaryBlue),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No Buses Found for this Schedule",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: darkText),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "No active bus services found from ${widget.fromCity} to ${widget.toCity} on $dateFormatted.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: subText),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Change Search Details", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _currentBuses.length,
              itemBuilder: (context, index) {
                final bus = _currentBuses[index];
                return _buildBusCard(bus);
              },
            ),
    );
  }

  Widget _buildBusCard(BusModel bus) {
    final int booked = _bookedSeatsCount[bus.id] ?? 0;
    final int totalSeats = bus.seats > 0 ? bus.seats : 40;
    final int available = totalSeats - booked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          // Top Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryBlue.withAlpha(20),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        bus.busClass.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bus.busNumber,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: subText),
                    ),
                  ],
                ),
                Text(
                  "$available Seats Left",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: available > 5 ? const Color(0xFF10B981) : Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // Main Info Row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Departure Time & City
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bus.time,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: darkText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bus.fromCity,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subText),
                        ),
                      ],
                    ),

                    // Travel Arrow
                    const Column(
                      children: [
                        Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 18),
                        SizedBox(height: 2),
                        Icon(Icons.arrow_forward_rounded, color: subText, size: 13),
                      ],
                    ),

                    // Destination City
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Direct",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bus.toCity,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subText),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ─── SEAT OCCUPANCY PROGRESS LINE (BOOKED & AVAILABLE) ───
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.airline_seat_recline_normal_rounded, size: 13, color: primaryBlue),
                              const SizedBox(width: 4),
                              Text(
                                "$available Available",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: available > 5 ? const Color(0xFF059669) : Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "$booked / $totalSeats Booked",
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: subText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalSeats > 0 ? (booked / totalSeats).clamp(0.0, 1.0) : 0.0,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            (totalSeats > 0 && (booked / totalSeats) > 0.85)
                                ? const Color(0xFFEF4444)
                                : ((totalSeats > 0 && (booked / totalSeats) > 0.6) ? Colors.orange : primaryBlue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(height: 1, color: borderColor),
                const SizedBox(height: 10),

                // Bottom Row: Price & Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Fare per seat", style: TextStyle(fontSize: 10, color: subText)),
                        Text(
                          "PKR ${bus.fare.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: primaryBlue),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.event_seat_rounded, size: 15),
                      label: const Text(
                        "Select Seats",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CounterBookSeatScreen(
                              bus: bus,
                              selectedDate: widget.selectedDate,
                              userProfile: widget.userProfile,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
