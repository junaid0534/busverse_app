import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:bus_ticket_system/sub_admin/screens/ticket_receipt_slip_screen.dart';
import 'package:intl/intl.dart';

class CounterTicketBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;
  final BusModel? preSelectedBus;

  const CounterTicketBookingScreen({
    super.key,
    this.userProfile,
    this.preSelectedBus,
  });

  @override
  State<CounterTicketBookingScreen> createState() => _CounterTicketBookingScreenState();
}

class _CounterTicketBookingScreenState extends State<CounterTicketBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _passengerNameCtrl = TextEditingController();
  final TextEditingController _passengerPhoneCtrl = TextEditingController();
  final TextEditingController _passengerCnicCtrl = TextEditingController();
  final TextEditingController _cashReceivedCtrl = TextEditingController();

  // Selected State
  BusModel? _selectedBus;
  List<BusModel> _terminalBuses = [];
  bool _isLoadingBuses = true;
  bool _isLoadingSeats = false;
  bool _isIssuingTicket = false;

  final DateTime _selectedDate = DateTime.now();

  // Seat Selection State
  final List<int> _selectedSeats = [];
  final Map<int, String> _seatGenderMap = {};
  Map<int, String> _alreadyBookedSeatsMap = {}; // seatNumber -> "M" / "F"

  String _paymentMethod = "Cash at Counter";

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color maleColor = Color(0xFF2563EB);
  static const Color femaleColor = Color(0xFFEC4899);

  String get terminalCity => widget.userProfile?['terminalCity'] ?? 'Lahore';
  String get terminalName => widget.userProfile?['terminalName'] ?? 'Main Terminal Counter';
  String get agentName {
    final fn = widget.userProfile?['firstName'] ?? 'Terminal';
    final ln = widget.userProfile?['lastName'] ?? 'Agent';
    return "$fn $ln".trim();
  }

  @override
  void initState() {
    super.initState();
    _selectedBus = widget.preSelectedBus;
    _loadTerminalBuses();
  }

  @override
  void dispose() {
    _passengerNameCtrl.dispose();
    _passengerPhoneCtrl.dispose();
    _passengerCnicCtrl.dispose();
    _cashReceivedCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTerminalBuses() async {
    setState(() => _isLoadingBuses = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final dbBuses = await DBHelper.instance.getAllBuses();

      final cityLower = terminalCity.trim().toLowerCase();

      final filtered = dbBuses.where((b) {
        final from = (b['fromCity'] ?? '').toString().trim().toLowerCase();
        final date = (b['date'] ?? '').toString().trim();
        final matchesCity = cityLower.isEmpty || from.contains(cityLower) || cityLower.contains(from);
        return matchesCity && (date.isEmpty || date == dateStr);
      }).map((map) => BusModel.fromMap(map)).toList();

      final activeBuses = filtered.isNotEmpty
          ? filtered
          : dbBuses
              .where((b) {
                final from = (b['fromCity'] ?? '').toString().trim().toLowerCase();
                return cityLower.isEmpty || from.contains(cityLower) || cityLower.contains(from);
              })
              .map((map) => BusModel.fromMap(map))
              .toList();

      setState(() {
        _terminalBuses = activeBuses;
        _isLoadingBuses = false;
        if (_selectedBus == null && _terminalBuses.isNotEmpty) {
          _selectedBus = _terminalBuses.first;
        }
      });

      if (_selectedBus != null) {
        _loadBookedSeatsForBus(_selectedBus!);
      }
    } catch (e) {
      debugPrint("Error loading terminal buses: $e");
      if (mounted) setState(() => _isLoadingBuses = false);
    }
  }

  Future<void> _loadBookedSeatsForBus(BusModel bus) async {
    if (bus.id == null) return;
    setState(() {
      _isLoadingSeats = true;
      _selectedSeats.clear();
      _seatGenderMap.clear();
    });

    final Map<int, String> temp = {};

    // 1. Load from SQLite
    try {
      final localRows = await DBHelper.instance.getBookedSeatsWithGender(bus.id!);
      for (var r in localRows) {
        final seat = int.tryParse(r['seatNumber'].toString()) ?? 0;
        final gender = (r['gender'] ?? 'M').toString().toUpperCase();
        if (seat > 0) temp[seat] = gender;
      }
    } catch (e) {
      debugPrint("SQLite load booked seats error: $e");
    }

    // 2. Load from Supabase (if connected)
    try {
      final onlineSeats = await SupabaseService.instance.getBookedSeats(bus.id!);
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkText),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.male_rounded, size: 18),
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.female_rounded, size: 18),
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

  double get _unitFare => _selectedBus?.fare ?? 0.0;
  double get _totalFare => _unitFare * _selectedSeats.length;

  Future<void> _confirmAndIssueTicket() async {
    if (_selectedBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a bus schedule first"), backgroundColor: Colors.red),
      );
      return;
    }

    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least 1 seat"), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isIssuingTicket = true);

    try {
      final passengerName = _passengerNameCtrl.text.trim();
      final passengerPhone = _passengerPhoneCtrl.text.trim();
      final passengerCnic = _passengerCnicCtrl.text.trim();
      final travelDate = _selectedBus!.date.isNotEmpty
          ? _selectedBus!.date
          : DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 1. Save Bookings into SQLite
      for (int seat in _selectedSeats) {
        final gender = _seatGenderMap[seat] ?? "M";
        await DBHelper.instance.bookSeats(
          busId: _selectedBus!.id!,
          seats: [seat.toString()],
          gender: gender,
          date: travelDate,
          userId: 0, // Walk-in counter passenger
        );
      }

      // 2. Save Payment into SQLite
      final paymentId = await DBHelper.instance.insertPayment(
        busId: _selectedBus!.id!,
        seats: _selectedSeats,
        passengerName: passengerName,
        passengerEmail: "counter.$passengerPhone@busverse.pos",
        paymentMethod: _paymentMethod,
        accountNumber: "COUNTER-POS",
        date: travelDate,
        amount: _totalFare,
        passengerCnic: passengerCnic,
        passengerPhone: passengerPhone,
      );

      // 3. Sync with Supabase (if available)
      try {
        await SupabaseService.instance.createBooking(
          firebaseUid: "terminal_agent",
          userEmail: "counter.$passengerPhone@busverse.pos",
          busId: _selectedBus!.id!,
          seatNumbers: _selectedSeats,
          seatGenders: _seatGenderMap,
          bookingDate: travelDate,
        );
      } catch (_) {}

      if (mounted) {
        setState(() => _isIssuingTicket = false);

        // Open Ticket Receipt Slip Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TicketReceiptSlipScreen(
              ticketId: paymentId > 0 ? paymentId : DateTime.now().millisecondsSinceEpoch % 100000,
              bus: _selectedBus!,
              selectedSeats: List.from(_selectedSeats),
              seatGenderMap: Map.from(_seatGenderMap),
              passengerName: passengerName,
              passengerPhone: passengerPhone,
              passengerCnic: passengerCnic,
              totalAmount: _totalFare,
              paymentMethod: _paymentMethod,
              terminalCity: terminalCity,
              terminalName: terminalName,
              agentName: agentName,
              travelDate: travelDate,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error issuing counter ticket: $e");
      if (mounted) {
        setState(() => _isIssuingTicket = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error issuing ticket: $e"), backgroundColor: Colors.red),
        );
      }
    }
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
          "Counter Ticket Booking",
          style: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: _isLoadingBuses
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TERMINAL & BUS SCHEDULE SELECTOR
                  _buildBusSelectorCard(),

                  const SizedBox(height: 14),

                  // 2. SEAT LAYOUT MATRIX
                  if (_selectedBus != null) ...[
                    _buildSeatLayoutCard(),
                    const SizedBox(height: 14),
                  ],

                  // 3. PASSENGER FORM
                  _buildPassengerFormCard(),

                  const SizedBox(height: 14),

                  // 4. BILLING & FARE SUMMARY
                  _buildFareSummaryCard(),

                  const SizedBox(height: 20),

                  // 5. CONFIRM BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _isIssuingTicket ? null : _confirmAndIssueTicket,
                      child: _isIssuingTicket
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Issue Ticket & Print Slip",
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ─── 1. BUS SCHEDULE SELECTOR CARD ───
  Widget _buildBusSelectorCard() {
    return Container(
      width: double.infinity,
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
              const Text(
                "Departing Bus Schedule",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryBlue.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  terminalCity,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),

          if (_terminalBuses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  "No active buses found departing from this terminal.",
                  style: TextStyle(fontSize: 12, color: subText),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<BusModel>(
                  value: _selectedBus,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryBlue, size: 20),
                  items: _terminalBuses.map((bus) {
                    return DropdownMenuItem<BusModel>(
                      value: bus,
                      child: Text(
                        "${bus.busNumber} • ${bus.toCity} (${bus.time}) - Rs. ${bus.fare.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: darkText),
                      ),
                    );
                  }).toList(),
                  onChanged: (bus) {
                    if (bus != null) {
                      setState(() => _selectedBus = bus);
                      _loadBookedSeatsForBus(bus);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 2. SEAT LAYOUT MATRIX CARD ───
  Widget _buildSeatLayoutCard() {
    final totalSeats = _selectedBus?.seats ?? 40;
    final bookedCount = _alreadyBookedSeatsMap.length;
    final availableCount = totalSeats - bookedCount;

    return Container(
      width: double.infinity,
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
              const Text(
                "Select Seats",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
              ),
              Text(
                "$availableCount Available • ${_selectedSeats.length} Selected",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 10),

          // Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem("Available", const Color(0xFFF8FAFC), borderColor: const Color(0xFFCBD5E1)),
              _buildLegendItem("Selected", primaryBlue),
              _buildLegendItem("Male", maleColor),
              _buildLegendItem("Female", femaleColor),
            ],
          ),

          const SizedBox(height: 14),

          if (_isLoadingSeats)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: primaryBlue)))
          else
            _buildBusGrid(totalSeats),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {Color? borderColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
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
          style: const TextStyle(fontSize: 10.5, color: subText, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildBusGrid(int totalSeats) {
    int rows = (totalSeats / 4).ceil();

    return Column(
      children: [
        // Driver Row
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.airline_seat_recline_extra_rounded, size: 14, color: subText),
                SizedBox(width: 4),
                Text("Driver", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: subText)),
              ],
            ),
          ),
        ),

        // Seats 2x2 Grid
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows,
          itemBuilder: (context, r) {
            int left1 = r * 4 + 1;
            int left2 = r * 4 + 2;
            int right1 = r * 4 + 3;
            int right2 = r * 4 + 4;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (left1 <= totalSeats) _buildSeatWidget(left1) else const Expanded(child: SizedBox()),
                  const SizedBox(width: 6),
                  if (left2 <= totalSeats) _buildSeatWidget(left2) else const Expanded(child: SizedBox()),
                  const SizedBox(width: 24), // Aisle
                  if (right1 <= totalSeats) _buildSeatWidget(right1) else const Expanded(child: SizedBox()),
                  const SizedBox(width: 6),
                  if (right2 <= totalSeats) _buildSeatWidget(right2) else const Expanded(child: SizedBox()),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSeatWidget(int seatNum) {
    final isBooked = _alreadyBookedSeatsMap.containsKey(seatNum);
    final bookedGender = _alreadyBookedSeatsMap[seatNum];
    final isSelected = _selectedSeats.contains(seatNum);
    final selectedGender = _seatGenderMap[seatNum];

    // Determine colors & icon
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
        onTap: () => _onSeatTap(seatNum),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: seatBorder, width: isSelected ? 1.5 : 1.2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (selectedGender == "F" ? femaleColor : primaryBlue).withValues(alpha: 0.3),
                      blurRadius: 6,
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
                "$seatNum",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 3. PASSENGER FORM CARD ───
  Widget _buildPassengerFormCard() {
    return Container(
      width: double.infinity,
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompactField(
              controller: _passengerNameCtrl,
              label: "Passenger Name",
              validator: (v) => v == null || v.trim().isEmpty ? "Name is required" : null,
            ),
            const SizedBox(height: 10),

            _buildCompactField(
              controller: _passengerPhoneCtrl,
              label: "Mobile Number (for SMS Receipt)",
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Phone number is required";
                if (v.trim().length < 10) return "Valid phone number required";
                return null;
              },
            ),
            const SizedBox(height: 10),

            _buildCompactField(
              controller: _passengerCnicCtrl,
              label: "CNIC Number (Optional)",
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. FARE SUMMARY CARD ───
  Widget _buildFareSummaryCard() {
    return Container(
      width: double.infinity,
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
          const Text(
            "Payment & Fare Summary",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),

          _buildSummaryRow("Unit Ticket Fare", "Rs. ${_unitFare.toStringAsFixed(0)}"),
          const SizedBox(height: 6),
          _buildSummaryRow("Selected Seats (${_selectedSeats.length})", _selectedSeats.isNotEmpty ? _selectedSeats.join(", ") : "None"),
          const SizedBox(height: 6),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 8),
          _buildSummaryRow("Total Amount Payable", "Rs. ${_totalFare.toStringAsFixed(0)}", isBold: true, color: primaryBlue),

          const SizedBox(height: 14),

          // Payment Method selector
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Cash Counter")),
                  selected: _paymentMethod == "Cash at Counter",
                  selectedColor: primaryBlue,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _paymentMethod == "Cash at Counter" ? Colors.white : darkText,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _paymentMethod = "Cash at Counter");
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Online / Card")),
                  selected: _paymentMethod == "Card/Digital POS",
                  selectedColor: primaryBlue,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _paymentMethod == "Card/Digital POS" ? Colors.white : darkText,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _paymentMethod = "Card/Digital POS");
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 12.5 : 11.5,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: darkText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14.5 : 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: darkText),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: darkText),
          decoration: InputDecoration(
            filled: true,
            fillColor: bgSurface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
