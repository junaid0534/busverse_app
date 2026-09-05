import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';

class BookSeatScreen extends StatefulWidget {
  final BusModel bus;
  final DateTime selectedDate;
  final int userId;

  const BookSeatScreen({
    super.key,
    required this.bus,
    required this.selectedDate,
    required this.userId,
  });

  @override
  State<BookSeatScreen> createState() => _BookSeatScreenState();
}

class _BookSeatScreenState extends State<BookSeatScreen> {
  List<int> selectedSeats = [];
  Map<int, String> seatGender = {};
  Map<int, String> bookedSeatsMap = {};
  bool isLoading = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color maleColor = Color(0xFF2563EB);
  static const Color femaleColor = Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();
    loadBookedSeats();
  }

  Future<void> loadBookedSeats() async {
    if (widget.bus.id == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    Map<int, String> temp = {};

    // 1. Load from Local SQLite
    try {
      final rows = await DBHelper.instance.getBookedSeatsWithGender(widget.bus.id!);
      for (var r in rows) {
        int seat = int.tryParse(r['seatNumber'].toString()) ?? 0;
        String gender = (r['gender'] ?? "M").toString().toUpperCase();
        if (seat > 0) temp[seat] = gender;
      }
    } catch (e) {
      print("SQLite load booked seats error: $e");
    }

    // 2. Load and merge Supabase Live Bookings
    try {
      final onlineSeats = await SupabaseService.instance.getBookedSeats(widget.bus.id!);
      for (var r in onlineSeats) {
        int seat = int.tryParse(r['seat_number']?.toString() ?? '') ?? 0;
        String gender = (r['gender'] ?? 'M').toString().toUpperCase();
        if (seat > 0) temp[seat] = gender;
      }
    } catch (e) {
      print("Supabase load booked seats error: $e");
    }

    if (mounted) {
      setState(() {
        bookedSeatsMap = temp;
        isLoading = false;
      });
    }
  }

  // Modern Gender Selection Bottom Sheet
  Future<String?> _showGenderModal(int seatNumber) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Select Passenger for Seat #$seatNumber",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Please specify passenger gender for seat allocation",
                style: TextStyle(fontSize: 12, color: subText),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // Male Option
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, "M"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.man_rounded, size: 36, color: maleColor),
                            SizedBox(height: 6),
                            Text(
                              "Male",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: maleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Female Option
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, "F"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF2F8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFBCFE8), width: 1.5),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.woman_rounded, size: 36, color: femaleColor),
                            SizedBox(height: 6),
                            Text(
                              "Female",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: femaleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _onSeatTap(int seatNumber) async {
    if (bookedSeatsMap.containsKey(seatNumber)) return;

    if (selectedSeats.contains(seatNumber)) {
      setState(() {
        selectedSeats.remove(seatNumber);
        seatGender.remove(seatNumber);
      });
    } else {
      final gender = await _showGenderModal(seatNumber);
      if (gender != null) {
        setState(() {
          selectedSeats.add(seatNumber);
          seatGender[seatNumber] = gender;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateKey =
        "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";
    final double totalFare = selectedSeats.length * widget.bus.fare;
    final int totalBusSeats = widget.bus.seats > 0 ? widget.bus.seats : 40;
    final int totalRows = (totalBusSeats / 4).ceil();

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
        title: Column(
          children: [
            Text(
              "${widget.bus.fromCity} → ${widget.bus.toCity}",
              style: const TextStyle(
                color: darkText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "${widget.bus.time} • ${widget.bus.busClass}",
              style: const TextStyle(
                color: subText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── COLOR LEGEND STRIP ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legendItem("Available", Colors.white, borderColor: const Color(0xFF94A3B8)),
                _legendItem("Selected", primaryBlue),
                _legendItem("Male", maleColor),
                _legendItem("Female", femaleColor),
              ],
            ),
          ),

          // ─── VISUAL BUS CONTAINER (2x2 LAYOUT) ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Bus Driver & Entrance Area
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Entrance Door Indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.meeting_room_outlined, size: 14, color: subText),
                                  SizedBox(width: 4),
                                  Text(
                                    "Entry",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: subText),
                                  ),
                                ],
                              ),
                            ),

                            // Steering Wheel (Driver)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFD0E3FF)),
                              ),
                              child: const Icon(
                                Icons.sports_volleyball_rounded,
                                size: 20,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 14),

                      // 2x2 Seating Grid
                      ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: totalRows,
                        itemBuilder: (context, rowIndex) {
                          final int seat1 = rowIndex * 4 + 1;
                          final int seat2 = rowIndex * 4 + 2;
                          final int seat3 = rowIndex * 4 + 3;
                          final int seat4 = rowIndex * 4 + 4;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                // Left Pair (2 Seats)
                                Expanded(child: _buildSeatItem(seat1)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildSeatItem(seat2)),

                                // Walking Aisle / Corridor (Space)
                                Container(
                                  width: 32,
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${rowIndex + 1}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),

                                // Right Pair (2 Seats)
                                Expanded(child: _buildSeatItem(seat3)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildSeatItem(seat4)),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── BOTTOM STICKY ACTION BAR ───
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Selected Seats info & Total price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedSeats.isEmpty
                              ? "No seats selected"
                              : "${selectedSeats.length} ${selectedSeats.length == 1 ? 'Seat' : 'Seats'}: ${selectedSeats.map((s) => '#$s(${seatGender[s] ?? "M"})').join(', ')}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "PKR ${totalFare.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Proceed Button
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedSeats.isEmpty ? const Color(0xFFE2E8F0) : primaryBlue,
                        foregroundColor: selectedSeats.isEmpty ? subText : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: selectedSeats.isEmpty
                          ? null
                          : () {
                              final String travelDate = (widget.bus.date.isNotEmpty && widget.bus.date != "0000-00-00")
                                  ? widget.bus.date
                                  : dateKey;
                              Navigator.pushNamed(
                                context,
                                '/passenger_details',
                                arguments: {
                                  'bus': widget.bus,
                                  'selectedSeats': selectedSeats,
                                  'genderMap': seatGender,
                                  'date': travelDate,
                                  'userId': widget.userId,
                                },
                              );
                            },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Proceed",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── INDIVIDUAL PROFESSIONAL 2x2 SEAT WIDGET ───
  Widget _buildSeatItem(int seatNumber) {
    if (seatNumber > (widget.bus.seats > 0 ? widget.bus.seats : 40)) {
      return const SizedBox.shrink();
    }

    final bool isBooked = bookedSeatsMap.containsKey(seatNumber);
    final bool isSelected = selectedSeats.contains(seatNumber);
    final String bookedGender = bookedSeatsMap[seatNumber] ?? "M";
    final String selectedGender = seatGender[seatNumber] ?? "M";

    // Determine colors
    Color bgColor = const Color(0xFFF8FAFC);
    Color borderColor = const Color(0xFFCBD5E1);
    Color contentColor = darkText;
    IconData seatIcon = Icons.airline_seat_recline_normal_rounded;

    if (isBooked) {
      bgColor = bookedGender == "F" ? const Color(0xFFFCE7F3) : const Color(0xFFE2E8F0);
      borderColor = bookedGender == "F" ? femaleColor.withOpacity(0.4) : const Color(0xFF94A3B8);
      contentColor = bookedGender == "F" ? femaleColor : subText;
      seatIcon = Icons.block_rounded;
    } else if (isSelected) {
      bgColor = selectedGender == "F" ? femaleColor : primaryBlue;
      borderColor = selectedGender == "F" ? femaleColor : primaryBlue;
      contentColor = Colors.white;
      seatIcon = Icons.check_circle_rounded;
    }

    return GestureDetector(
      onTap: () => _onSeatTap(seatNumber),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (selectedGender == "F" ? femaleColor : primaryBlue).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(seatIcon, size: 16, color: contentColor),
            const SizedBox(height: 2),
            Text(
              "$seatNumber",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, {Color? borderColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor ?? color,
              width: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: subText,
          ),
        ),
      ],
    );
  }
}
