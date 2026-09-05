import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';

class PassengerDetailScreen extends StatefulWidget {
  final BusModel bus;
  final List<int> selectedSeats;
  final String date;
  final Map<int, String>? genderMap;
  final int? userId;

  const PassengerDetailScreen({
    super.key,
    required this.bus,
    required this.selectedSeats,
    required this.date,
    this.genderMap,
    this.userId,
  });

  @override
  State<PassengerDetailScreen> createState() => _PassengerDetailScreenState();
}

class _PassengerDetailScreenState extends State<PassengerDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController cnicCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void dispose() {
    nameCtrl.dispose();
    cnicCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double totalFare = widget.selectedSeats.length * widget.bus.fare;

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
          "Passenger Details",
          style: TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── TRIP SUMMARY CARD ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E3C72),
                      Color(0xFF388AF6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.bus.fromCity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
                        Text(
                          widget.bus.toCity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_seat_rounded, color: Colors.white70, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              "Seats: ${widget.selectedSeats.map((s) => '#$s').join(', ')}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "PKR ${totalFare.toStringAsFixed(0)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ─── PASSENGER INFORMATION FORM ───
              Container(
                padding: const EdgeInsets.all(16),
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
                    const Text(
                      "Contact Information",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Ticket confirmation & invoice will be sent to these details",
                      style: TextStyle(fontSize: 11, color: subText),
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),

                    // Full Name
                    _buildField(
                      controller: nameCtrl,
                      label: "Primary Passenger Full Name",
                      hint: "e.g. Muhammad Ali",
                      icon: Icons.person_outline_rounded,
                      validator: (val) => val == null || val.trim().isEmpty ? "Please enter full name" : null,
                    ),

                    const SizedBox(height: 14),

                    // CNIC Number
                    _buildField(
                      controller: cnicCtrl,
                      label: "CNIC Number",
                      hint: "e.g. 35201-1234567-1",
                      icon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.trim().isEmpty ? "Please enter CNIC" : null,
                    ),

                    const SizedBox(height: 14),

                    // Phone Number
                    _buildField(
                      controller: phoneCtrl,
                      label: "Phone Number",
                      hint: "e.g. 0300 1234567",
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (val) => val == null || val.trim().isEmpty ? "Please enter phone number" : null,
                    ),

                    const SizedBox(height: 14),

                    // Email Address
                    _buildField(
                      controller: emailCtrl,
                      label: "Email Address (Optional)",
                      hint: "e.g. passenger@email.com",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── PROCEED BUTTON ───
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;

                    final passengerData = {
                      "name": nameCtrl.text.trim(),
                      "cnic": cnicCtrl.text.trim(),
                      "phone": phoneCtrl.text.trim(),
                      "email": emailCtrl.text.trim(),
                      "genderMap": widget.genderMap ?? {},
                      "userId": widget.userId ?? 0,
                      "gender": (widget.genderMap != null && widget.genderMap!.isNotEmpty)
                          ? widget.genderMap!.values.first
                          : "M",
                    };

                    Navigator.pushNamed(
                      context,
                      "/payment",
                      arguments: {
                        "bus": widget.bus,
                        "selectedSeats": widget.selectedSeats,
                        "date": widget.date,
                        "passengerData": passengerData,
                      },
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Proceed to Payment",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
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
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
            prefixIcon: Icon(icon, size: 18, color: primaryBlue),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
