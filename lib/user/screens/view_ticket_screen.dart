import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';

class ViewTicketScreen extends StatefulWidget {
  final Map<String, dynamic> ticketData;

  const ViewTicketScreen({
    super.key,
    required this.ticketData,
  });

  @override
  State<ViewTicketScreen> createState() => _ViewTicketScreenState();
}

class _ViewTicketScreenState extends State<ViewTicketScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  bool _isSaving = false;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  String _formatDateOnly(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return "";
    String clean = rawDate.trim();
    if (clean.contains('T')) {
      clean = clean.split('T')[0];
    } else if (clean.contains(' ')) {
      clean = clean.split(' ')[0];
    }
    return clean;
  }

  void _navigateHome(Map<String, dynamic> p, Map passenger) {
    final String email = (passenger["email"] != null && passenger["email"].toString().trim().isNotEmpty)
        ? passenger["email"].toString().trim()
        : (p["email"]?.toString().trim().isNotEmpty == true
            ? p["email"].toString().trim()
            : (FirebaseAuth.instance.currentUser?.email ?? ""));
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/welcome_login',
      (r) => false,
      arguments: {'userEmail': email},
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.ticketData;
    final passenger = (p["passenger"] is Map) ? p["passenger"] as Map : {};
    final dynamic busObj = p["bus"];

    String busNumber = "";
    String busClass = "Executive";
    if (busObj is BusModel) {
      busNumber = busObj.busNumber;
      busClass = busObj.busClass;
    } else if (busObj is Map) {
      busNumber = busObj["busNumber"] ?? busObj["bus_number"] ?? "";
      busClass = busObj["busClass"] ?? "Executive";
    }

    final List seats = p["seats"] ?? [];
    final String paymentMethod = p["paymentMethod"] ?? "Paid Online";
    final String fromCity = (p["fromCity"] != null && p["fromCity"].toString().trim().isNotEmpty)
        ? p["fromCity"].toString().trim()
        : (p["from"]?.toString().trim().isNotEmpty == true
            ? p["from"].toString().trim()
            : (busObj is BusModel ? busObj.fromCity : (busObj is Map ? (busObj["fromCity"] ?? "Departure") : "Departure")));
    final String toCity = (p["toCity"] != null && p["toCity"].toString().trim().isNotEmpty)
        ? p["toCity"].toString().trim()
        : (p["to"]?.toString().trim().isNotEmpty == true
            ? p["to"].toString().trim()
            : (busObj is BusModel ? busObj.toCity : (busObj is Map ? (busObj["toCity"] ?? "Destination") : "Destination")));
    final String time = (p["time"] != null && p["time"].toString().trim().isNotEmpty)
        ? p["time"].toString().trim()
        : (busObj is BusModel ? busObj.time : (busObj is Map ? (busObj["time"] ?? "Scheduled") : "Scheduled"));
    final String rawDate = (p["travelDate"] != null && p["travelDate"].toString().trim().isNotEmpty)
        ? p["travelDate"].toString().trim()
        : ((busObj is BusModel && busObj.date.isNotEmpty && busObj.date != "0000-00-00")
            ? busObj.date
            : (busObj is Map && busObj["date"] != null && busObj["date"].toString().trim().isNotEmpty && busObj["date"] != "0000-00-00")
                ? busObj["date"].toString().trim()
                : (p["date"]?.toString().trim() ?? ""));
    final String date = _formatDateOnly(rawDate);

    final String passengerName = (passenger["name"] != null && passenger["name"].toString().trim().isNotEmpty)
        ? passenger["name"].toString().trim()
        : (p["passengerName"]?.toString().trim().isNotEmpty == true ? p["passengerName"] : "Valued Customer");

    final String passengerCnic = (passenger["cnic"] != null && passenger["cnic"].toString().trim().isNotEmpty)
        ? passenger["cnic"].toString().trim()
        : (p["passengerCnic"]?.toString().trim().isNotEmpty == true ? p["passengerCnic"] : "N/A");

    final String passengerPhone = (passenger["phone"] != null && passenger["phone"].toString().trim().isNotEmpty)
        ? passenger["phone"].toString().trim()
        : (p["passengerPhone"]?.toString().trim().isNotEmpty == true ? p["passengerPhone"] : "N/A");

    final String rawBookingTime = (p["bookingTimestamp"] ?? p["createdAt"] ?? "").toString().trim();
    String bookingTimeFormatted = "";
    if (rawBookingTime.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawBookingTime);
        bookingTimeFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
      } catch (_) {
        bookingTimeFormatted = rawBookingTime;
      }
    }

    final String bookingRef = "BV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          "E-Ticket Confirmation",
          style: TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 18),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              _navigateHome(p, passenger);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          children: [
            // ─── TICKET CAPTURE AREA ───
            Screenshot(
              controller: screenshotController,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top Header Bar
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [darkNavy, primaryBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "Bus",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: "Verse",
                                      style: TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Booking Ref: $bookingRef",
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  "CONFIRMED",
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Route & Schedule details
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("FROM", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: subText)),
                                    const SizedBox(height: 2),
                                    Text(
                                      fromCity,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: darkText),
                                    ),
                                  ],
                                ),
                              ),
                              const Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 18),
                                    Icon(Icons.arrow_forward_rounded, color: subText, size: 14),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text("TO", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: subText)),
                                    const SizedBox(height: 2),
                                    Text(
                                      toCity,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: darkText),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                          const SizedBox(height: 14),

                          // Date, Time, Bus Class with comfortable spacing
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _ticketMeta("TRAVEL DATE", date, alignment: Alignment.centerLeft),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 5,
                                child: _ticketMeta("DEPARTURE TIME", time, alignment: Alignment.center),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: _ticketMeta("CLASS", busClass, alignment: Alignment.centerRight),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Ticket Cutout Divider
                    Row(
                      children: [
                        Container(
                          width: 14,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Flex(
                                direction: Axis.horizontal,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                mainAxisSize: MainAxisSize.max,
                                children: List.generate(
                                  (constraints.constrainWidth() / 10).floor(),
                                  (_) => const SizedBox(
                                    width: 5,
                                    height: 1.5,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          width: 14,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Passenger Details & Seats
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ticketRow("Passenger Name", passengerName),
                          _ticketRow("CNIC Number", passengerCnic),
                          _ticketRow("Phone Number", passengerPhone),
                          _ticketRow("Booked Seats", seats.map((s) => "Seat #$s").join(", ")),
                          _ticketRow("Payment Method", paymentMethod),
                          if (busNumber.isNotEmpty) _ticketRow("Bus Number", busNumber),
                          if (bookingTimeFormatted.isNotEmpty) _ticketRow("Booked On", bookingTimeFormatted),

                          const SizedBox(height: 16),

                          // QR / Barcode Simulation
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(Icons.qr_code_2_rounded, size: 68, color: darkNavy),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Scan at bus terminal boarding gate",
                                  style: TextStyle(fontSize: 10, color: subText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── ACTION BUTTONS ───
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.share_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : saveAndShareTicket,
                label: const Text(
                  "Share / Save Ticket",
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.home_rounded, size: 18, color: primaryBlue),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryBlue, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _navigateHome(p, passenger);
                },
                label: const Text(
                  "Back to Home",
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: primaryBlue),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _ticketMeta(String label, String value, {Alignment alignment = Alignment.centerLeft}) {
    return Column(
      crossAxisAlignment: alignment == Alignment.centerRight
          ? CrossAxisAlignment.end
          : (alignment == Alignment.center ? CrossAxisAlignment.center : CrossAxisAlignment.start),
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: subText)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText)),
        ),
      ],
    );
  }

  Widget _ticketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: subText)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkText),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> saveAndShareTicket() async {
    setState(() => _isSaving = true);
    try {
      final Uint8List? image = await screenshotController.capture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = File("${directory.path}/busverse_ticket.png");

      await imagePath.writeAsBytes(image);
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: "BusVerse Official E-Ticket",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sharing ticket: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
