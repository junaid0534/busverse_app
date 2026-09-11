import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';

class TicketReceiptSlipScreen extends StatelessWidget {
  final int ticketId;
  final BusModel bus;
  final List<int> selectedSeats;
  final Map<int, String> seatGenderMap;
  final String passengerName;
  final String passengerPhone;
  final String passengerCnic;
  final double totalAmount;
  final String paymentMethod;
  final String terminalCity;
  final String terminalName;
  final String agentName;
  final String travelDate;

  const TicketReceiptSlipScreen({
    super.key,
    required this.ticketId,
    required this.bus,
    required this.selectedSeats,
    required this.seatGenderMap,
    required this.passengerName,
    required this.passengerPhone,
    required this.passengerCnic,
    required this.totalAmount,
    required this.paymentMethod,
    required this.terminalCity,
    required this.terminalName,
    required this.agentName,
    required this.travelDate,
  });

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final String pnr = "BV-${bus.id ?? 100}-$ticketId";

    return Scaffold(
      backgroundColor: bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Terminal Ticket Receipt",
          style: TextStyle(color: darkText, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Success Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withAlpha(15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withAlpha(40)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 6),
                  Text(
                    "Ticket Issued Successfully",
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Thermal Slip / Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: darkNavy,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "BUSVERSE EXPRESS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Terminal Counter Boarding Pass",
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "PNR: $pnr",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ticket Details
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        // Route & Bus Info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("ORIGIN", style: TextStyle(fontSize: 9.5, color: subText, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  bus.fromCity,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryBlue),
                                ),
                              ],
                            ),
                            const Icon(Icons.arrow_forward_rounded, color: primaryBlue, size: 18),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("DESTINATION", style: TextStyle(fontSize: 9.5, color: subText, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                  bus.toCity,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryBlue),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 1, color: borderColor),
                        const SizedBox(height: 12),

                        // Travel Details Grid
                        _buildSlipRow("Bus Number", bus.busNumber),
                        const SizedBox(height: 7),
                        _buildSlipRow("Bus Class", bus.busClass),
                        const SizedBox(height: 7),
                        _buildSlipRow("Travel Date", travelDate),
                        const SizedBox(height: 7),
                        _buildSlipRow("Departure Time", bus.time),
                        const SizedBox(height: 7),
                        _buildSlipRow(
                          "Booked Seats",
                          selectedSeats.map((s) => "#$s").join(", "),
                          isHighlight: true,
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 1, color: borderColor),
                        const SizedBox(height: 12),

                        // Passenger Details
                        _buildSlipRow("Passenger Name", passengerName),
                        const SizedBox(height: 7),
                        _buildSlipRow("Mobile Number", passengerPhone),
                        if (passengerCnic.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          _buildSlipRow("CNIC", passengerCnic),
                        ],

                        const SizedBox(height: 12),
                        const Divider(height: 1, color: borderColor),
                        const SizedBox(height: 12),

                        // Terminal & Agent Info
                        _buildSlipRow("Issuing Terminal", "$terminalCity ($terminalName)"),
                        const SizedBox(height: 7),
                        _buildSlipRow("Counter Agent", agentName),
                        const SizedBox(height: 7),
                        _buildSlipRow("Payment Method", paymentMethod),
                        const SizedBox(height: 10),

                        // Total Fare Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withAlpha(12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: primaryBlue.withAlpha(40)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "TOTAL FARE PAID",
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: darkText),
                              ),
                              Text(
                                "Rs. ${totalAmount.toStringAsFixed(0)}",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryBlue),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dotted Tear Line Indicator
                  Row(
                    children: List.generate(
                      30,
                      (index) => Expanded(
                        child: Container(
                          height: 1.5,
                          color: index.isEven ? borderColor : Colors.transparent,
                        ),
                      ),
                    ),
                  ),

                  // Barcode & Footer Notice
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, size: 50, color: darkNavy),
                        const SizedBox(height: 6),
                        Text(
                          "Please report to the departure bay 15 mins prior to departure.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10.5, color: subText.withAlpha(200)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions (Print & New Booking)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkNavy,
                      side: const BorderSide(color: darkNavy),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 17),
                    label: const Text("Print Slip", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Sending slip to Terminal Receipt Printer..."),
                          backgroundColor: primaryBlue,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text("New Booking", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: subText, fontWeight: FontWeight.w400)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
              color: isHighlight ? primaryBlue : darkText,
            ),
          ),
        ),
      ],
    );
  }
}
