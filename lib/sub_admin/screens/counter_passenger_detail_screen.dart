import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:bus_ticket_system/sub_admin/screens/ticket_receipt_slip_screen.dart';
import 'package:intl/intl.dart';

class CounterPassengerDetailScreen extends StatefulWidget {
  final BusModel bus;
  final List<int> selectedSeats;
  final Map<int, String> seatGenderMap;
  final DateTime selectedDate;
  final Map<String, dynamic>? userProfile;

  const CounterPassengerDetailScreen({
    super.key,
    required this.bus,
    required this.selectedSeats,
    required this.seatGenderMap,
    required this.selectedDate,
    this.userProfile,
  });

  @override
  State<CounterPassengerDetailScreen> createState() => _CounterPassengerDetailScreenState();
}

class _CounterPassengerDetailScreenState extends State<CounterPassengerDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _cnicCtrl = TextEditingController();
  final TextEditingController _cashReceivedCtrl = TextEditingController();

  String _paymentMethod = "Cash at Counter";
  double _changeDue = 0.0;
  bool _isIssuing = false;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  String get terminalCity => widget.userProfile?['terminalCity'] ?? 'Lahore';
  String get terminalName => widget.userProfile?['terminalName'] ?? 'Main Terminal Counter';
  String get agentName {
    final fn = widget.userProfile?['firstName'] ?? 'Terminal';
    final ln = widget.userProfile?['lastName'] ?? 'Agent';
    return "$fn $ln".trim();
  }

  double get _totalFare => widget.bus.fare * widget.selectedSeats.length;

  @override
  void initState() {
    super.initState();
    _cashReceivedCtrl.addListener(_calcChange);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cnicCtrl.dispose();
    _cashReceivedCtrl.dispose();
    super.dispose();
  }

  void _calcChange() {
    final received = double.tryParse(_cashReceivedCtrl.text.trim()) ?? 0.0;
    setState(() {
      _changeDue = received >= _totalFare ? received - _totalFare : 0.0;
    });
  }

  Future<void> _confirmAndIssueTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isIssuing = true);

    try {
      final passengerName = _nameCtrl.text.trim();
      final passengerPhone = _phoneCtrl.text.trim();
      final passengerCnic = _cnicCtrl.text.trim();
      final travelDate = widget.bus.date.isNotEmpty
          ? widget.bus.date
          : DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      // 1. Insert into SQLite (Dedicated terminal_bookings table + bookings + payments)
      final bookingId = await DBHelper.instance.insertTerminalBooking(
        busId: widget.bus.id!,
        seatNumbers: widget.selectedSeats,
        seatGenders: widget.seatGenderMap,
        passengerName: passengerName,
        passengerPhone: passengerPhone,
        passengerCnic: passengerCnic,
        totalAmount: _totalFare,
        paymentMethod: _paymentMethod,
        terminalCity: terminalCity,
        terminalName: terminalName,
        agentName: agentName,
        bookingDate: travelDate,
      );

      // 2. Sync with Supabase (terminal_bookings + payments + bookings)
      try {
        await SupabaseService.instance.createTerminalBooking(
          busId: widget.bus.id!,
          seatNumbers: widget.selectedSeats,
          seatGenders: widget.seatGenderMap,
          passengerName: passengerName,
          passengerPhone: passengerPhone,
          passengerCnic: passengerCnic,
          totalAmount: _totalFare,
          paymentMethod: _paymentMethod,
          terminalCity: terminalCity,
          terminalName: terminalName,
          agentName: agentName,
          bookingDate: travelDate,
        );
      } catch (e) {
        debugPrint("Supabase terminal booking sync error: $e");
      }

      if (mounted) {
        setState(() => _isIssuing = false);

        // Open Ticket Receipt Slip Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TicketReceiptSlipScreen(
              ticketId: bookingId > 0 ? bookingId : DateTime.now().millisecondsSinceEpoch % 100000,
              bus: widget.bus,
              selectedSeats: List.from(widget.selectedSeats),
              seatGenderMap: Map.from(widget.seatGenderMap),
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
        setState(() => _isIssuing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error issuing ticket: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final travelDateFormatted = widget.bus.date.isNotEmpty
        ? widget.bus.date
        : DateFormat('dd MMM yyyy').format(widget.selectedDate);

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
        title: const Text(
          "Passenger & Payment",
          style: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Travel Summary Card
              _buildSummaryCard(travelDateFormatted),

              const SizedBox(height: 12),

              // 2. Passenger Details Form Card
              _buildPassengerDetailsCard(),

              const SizedBox(height: 12),

              // 3. Counter Payment & Change Card
              _buildPaymentCard(),

              const SizedBox(height: 20),

              // 4. Submit & Print Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _isIssuing ? null : _confirmAndIssueTicket,
                  child: _isIssuing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          "Confirm & Issue Ticket Slip",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String dateStr) {
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
              Text(
                "${widget.bus.fromCity} ➔ ${widget.bus.toCity}",
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: primaryBlue),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  widget.bus.busClass.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniInfo("Departure", "${widget.bus.time} • $dateStr"),
              _buildMiniInfo("Seats (${widget.selectedSeats.length})", widget.selectedSeats.map((s) => "#$s").join(", "), isRight: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: subText, fontWeight: FontWeight.w400)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText)),
      ],
    );
  }

  Widget _buildPassengerDetailsCard() {
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
          _buildInputField(
            controller: _nameCtrl,
            label: "Passenger Full Name",
            validator: (v) => v == null || v.trim().isEmpty ? "Passenger name is required" : null,
          ),
          const SizedBox(height: 10),

          _buildInputField(
            controller: _phoneCtrl,
            label: "Mobile Number (SMS Receipt)",
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return "Mobile number is required";
              if (v.trim().length < 10) return "Valid phone number required";
              return null;
            },
          ),
          const SizedBox(height: 10),

          _buildInputField(
            controller: _cnicCtrl,
            label: "CNIC Number (Optional)",
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
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
            "Counter Billing & Payment",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Payable Fare", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: darkText)),
              Text("PKR ${_totalFare.toStringAsFixed(0)}", style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: primaryBlue)),
            ],
          ),

          const SizedBox(height: 12),

          // Payment mode selector
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("Cash at Counter")),
                  selected: _paymentMethod == "Cash at Counter",
                  selectedColor: primaryBlue,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: _paymentMethod == "Cash at Counter" ? FontWeight.w600 : FontWeight.w500,
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
                  label: const Center(child: Text("Card / POS")),
                  selected: _paymentMethod == "Card / Digital POS",
                  selectedColor: primaryBlue,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: _paymentMethod == "Card / Digital POS" ? FontWeight.w600 : FontWeight.w500,
                    color: _paymentMethod == "Card / Digital POS" ? Colors.white : darkText,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _paymentMethod = "Card / Digital POS");
                  },
                ),
              ),
            ],
          ),

          if (_paymentMethod == "Cash at Counter") ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _cashReceivedCtrl,
                    label: "Cash Received (PKR)",
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Change Due", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: subText)),
                      const SizedBox(height: 5),
                      Container(
                        height: 40,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          "PKR ${_changeDue.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _changeDue > 0 ? const Color(0xFF10B981) : darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField({
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: darkText),
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
