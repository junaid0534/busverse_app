import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:bus_ticket_system/sub_admin/screens/counter_passenger_detail_screen.dart';

class CounterBookSeatScreen extends StatefulWidget {
  final BusModel bus;
  final DateTime selectedDate;
  final Map<String, dynamic>? userProfile;

  const CounterBookSeatScreen({
    super.key,
    required this.bus,
    required this.selectedDate,
    this.userProfile,
  });

  @override
  State<CounterBookSeatScreen> createState() => _CounterBookSeatScreenState();
}

class _CounterBookSeatScreenState extends State<CounterBookSeatScreen> {
  final List<int> _selectedSeats = [];
  final Map<int, String> _seatGenderMap = {};
  Map<int, String> _alreadyBookedSeatsMap = {}; // seatNumber -> "M" / "F"
  bool _isLoadingSeats = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color maleColor = Color(0xFF2563EB);
  static const Color femaleColor = Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();
    _loadBookedSeats();
  }

  Future<void> _loadBookedSeats() async {
    if (widget.bus.id == null) {
      if (mounted) setState(() => _isLoadingSeats = false);
      return;
    }

    final Map<int, String> temp = {};

    // 1. Local SQLite
    try {
      final localRows = await DBHelper.instance.getBookedSeatsWithGender(widget.bus.id!);
      for (var r in localRows) {
        final seat = int.tryParse(r['seatNumber'].toString()) ?? 0;
        final gender = (r['gender'] ?? 'M').toString().toUpperCase();
        if (seat > 0) temp[seat] = gender;
      }
    } catch (_) {}

    // 2. Supabase
    try {
      final onlineSeats = await SupabaseService.instance.getBookedSeats(widget.bus.id!);
      for (var r in onlineSeats) {
        final seat = int.tryParse(r['seat_number']?.toString() ?? '') ?? 0;
        final gender = (r['gender'] ?? 'M').toString().toUpperCase();
        if (seat > 0) temp[seat] = gender;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _alreadyBookedSeatsMap = temp;
        _isLoadingSeats = false;
      });
    }
  }

  void _onSeatTap(int seatNum) {
    if (_alreadyBookedSeatsMap.containsKey(seatNum)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Seat #$seatNum is already booked (${_alreadyBookedSeatsMap[seatNum] == 'F' ? 'Female' : 'Male'})"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedSeats.contains(seatNum)) {
      setState(() {
        _selectedSeats.remove(seatNum);
        _seatGenderMap.remove(seatNum);
      });
    } else {
      _showGenderPickerForSeat(seatNum);
    }
  }

  void _showGenderPickerForSeat(int seatNum) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Assign Gender for Seat #$seatNum",
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: darkText),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: subText),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: maleColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.male_rounded, size: 19),
                    label: const Text("Male (M)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      setState(() {
                        _selectedSeats.add(seatNum);
                        _seatGenderMap[seatNum] = "M";
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: femaleColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.female_rounded, size: 19),
                    label: const Text("Female (F)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      setState(() {
                        _selectedSeats.add(seatNum);
                        _seatGenderMap[seatNum] = "F";
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  double get _totalFare => widget.bus.fare * _selectedSeats.length;

  @override
  Widget build(BuildContext context) {
    final int totalSeats = widget.bus.seats > 0 ? widget.bus.seats : 40;

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
        title: Text(
          "${widget.bus.fromCity} ➔ ${widget.bus.toCity}",
          style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w600, fontSize: 15.5),
        ),
      ),
      body: Column(
        children: [
          // Color Legend Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem("Available", const Color(0xFFF8FAFC), borderColor: const Color(0xFFCBD5E1)),
                _buildLegendItem("Selected", primaryBlue),
                _buildLegendItem("Male", maleColor),
                _buildLegendItem("Female", femaleColor),
              ],
            ),
          ),

          const Divider(height: 1, color: borderColor),

          // Bus Seating Area
          Expanded(
            child: _isLoadingSeats
                ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 360),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Driver & Entrance Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: bgSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.meeting_room_outlined, size: 14, color: subText),
                                      SizedBox(width: 4),
                                      Text("Entry", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: subText)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withAlpha(15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: primaryBlue.withAlpha(40)),
                                  ),
                                  child: const Icon(Icons.airline_seat_recline_extra_rounded, size: 18, color: primaryBlue),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            const Divider(height: 1, color: borderColor),
                            const SizedBox(height: 14),

                            // Seats Grid
                            _buildBusGrid(totalSeats),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // Bottom Sticky Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: borderColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedSeats.isEmpty
                              ? "No seats selected"
                              : "${_selectedSeats.length} ${_selectedSeats.length == 1 ? 'Seat' : 'Seats'}: ${_selectedSeats.map((s) => '#$s').join(', ')}",
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: subText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "PKR ${_totalFare.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: darkText),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedSeats.isEmpty ? const Color(0xFFE2E8F0) : primaryBlue,
                        foregroundColor: _selectedSeats.isEmpty ? subText : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _selectedSeats.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CounterPassengerDetailScreen(
                                    bus: widget.bus,
                                    selectedSeats: _selectedSeats,
                                    seatGenderMap: _seatGenderMap,
                                    selectedDate: widget.selectedDate,
                                    userProfile: widget.userProfile,
                                  ),
                                ),
                              );
                            },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Passenger Details", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 15),
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

  Widget _buildLegendItem(String label, Color color, {Color? borderColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor ?? color, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: subText, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBusGrid(int totalSeats) {
    int rows = (totalSeats / 4).ceil();

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: rows,
      itemBuilder: (context, r) {
        int left1 = r * 4 + 1;
        int left2 = r * 4 + 2;
        int right1 = r * 4 + 3;
        int right2 = r * 4 + 4;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              if (left1 <= totalSeats) _buildSeatItem(left1) else const Expanded(child: SizedBox()),
              const SizedBox(width: 6),
              if (left2 <= totalSeats) _buildSeatItem(left2) else const Expanded(child: SizedBox()),
              Container(
                width: 28,
                alignment: Alignment.center,
                child: Text(
                  "${r + 1}",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFCBD5E1)),
                ),
              ),
              if (right1 <= totalSeats) _buildSeatItem(right1) else const Expanded(child: SizedBox()),
              const SizedBox(width: 6),
              if (right2 <= totalSeats) _buildSeatItem(right2) else const Expanded(child: SizedBox()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeatItem(int seatNumber) {
    final bool isBooked = _alreadyBookedSeatsMap.containsKey(seatNumber);
    final bool isSelected = _selectedSeats.contains(seatNumber);
    final String bookedGender = _alreadyBookedSeatsMap[seatNumber] ?? "M";
    final String selectedGender = _seatGenderMap[seatNumber] ?? "M";

    Color bgColor = const Color(0xFFF8FAFC);
    Color seatBorder = const Color(0xFFCBD5E1);
    Color contentColor = darkText;
    IconData seatIcon = Icons.airline_seat_recline_normal_rounded;

    if (isBooked) {
      bgColor = bookedGender == "F" ? femaleColor : maleColor;
      seatBorder = bgColor;
      contentColor = Colors.white;
      seatIcon = Icons.airline_seat_recline_normal_rounded;
    } else if (isSelected) {
      bgColor = selectedGender == "F" ? femaleColor : primaryBlue;
      seatBorder = bgColor;
      contentColor = Colors.white;
      seatIcon = Icons.airline_seat_recline_normal_rounded;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _onSeatTap(seatNumber),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: seatBorder, width: isSelected ? 1.4 : 1.1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (selectedGender == "F" ? femaleColor : primaryBlue).withValues(alpha: 0.25),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(seatIcon, size: 15, color: contentColor),
              const SizedBox(height: 2),
              Text(
                "$seatNumber",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
