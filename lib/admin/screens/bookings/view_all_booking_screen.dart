// lib/admin/screens/bookings/view_all_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class ViewAllBookingScreen extends StatefulWidget {
  final int? busId;
  final String? fromCity;
  final String? toCity;
  final String? date;

  const ViewAllBookingScreen({
    super.key,
    this.busId,
    this.fromCity,
    this.toCity,
    this.date,
  });

  @override
  State<ViewAllBookingScreen> createState() => _ViewAllBookingScreenState();
}

class _ViewAllBookingScreenState extends State<ViewAllBookingScreen> {
  List<Map<String, dynamic>> allBookings = [];
  List<Map<String, dynamic>> filteredBookings = [];
  bool isLoading = true;
  String searchQuery = "";
  String paymentFilter = "All"; // "All", "Paid", "Pending"
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);
  static const Color bgSurface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchBookings({int? specificBusId}) async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final db = await DBHelper.instance.database;

      String query = '''
        SELECT b.id as bookingId, b.userId, b.busId, b.seatNumber, b.gender, b.bookingDate, b.status,
               u.firstName, u.lastName, u.cnic as userCnic, u.phone as userPhone, u.email as userEmail,
               buses.busName, buses.busNumber, buses.busClass, buses.fare, buses.routeVia,
               buses.fromCity, buses.toCity, buses.time, buses.date as busDate
        FROM bookings b
        LEFT JOIN users u ON b.userId = u.id
        LEFT JOIN buses ON b.busId = buses.id
        WHERE 1=1
      ''';

      List<dynamic> args = [];
      final effectiveBusId = specificBusId ?? widget.busId;

      if (effectiveBusId != null) {
        query += ' AND b.busId = ?';
        args.add(effectiveBusId);
      }

      if (widget.fromCity != null && widget.fromCity!.isNotEmpty) {
        query += ' AND buses.fromCity = ?';
        args.add(widget.fromCity);
      }

      if (widget.toCity != null && widget.toCity!.isNotEmpty) {
        query += ' AND buses.toCity = ?';
        args.add(widget.toCity);
      }

      if (widget.date != null && widget.date!.isNotEmpty) {
        query += ' AND (buses.date = ? OR b.bookingDate = ?)';
        args.add(widget.date);
        args.add(widget.date);
      }

      query += ' ORDER BY b.id DESC';

      final rows = await db.rawQuery(query, args);
      final payments = await DBHelper.instance.getPayments();

      final enriched = rows.map((r) {
        final seatStr = r['seatNumber']?.toString() ?? '';
        Map<String, dynamic>? matchedPayment;
        for (final p in payments) {
          if (p['busId'] == r['busId']) {
            final pSeats = (p['seats'] ?? '').toString().split(',').map((s) => s.trim()).toList();
            if (pSeats.contains(seatStr)) {
              matchedPayment = p;
              break;
            }
          }
        }
        return {
          ...r,
          'payment': matchedPayment,
        };
      }).toList();

      if (mounted) {
        setState(() {
          allBookings = enriched;
          _applyFilters();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final q = searchQuery.toLowerCase().trim();
    filteredBookings = allBookings.where((b) {
      final passengerName = "${b['firstName'] ?? ''} ${b['lastName'] ?? ''}".trim().toLowerCase();
      final userEmail = (b['userEmail'] ?? '').toString().toLowerCase();
      final userPhone = (b['userPhone'] ?? '').toString().toLowerCase();
      final userCnic = (b['userCnic'] ?? '').toString().toLowerCase();
      final seat = (b['seatNumber'] ?? '').toString().toLowerCase();
      final from = (b['fromCity'] ?? '').toString().toLowerCase();
      final to = (b['toCity'] ?? '').toString().toLowerCase();
      final busName = (b['busName'] ?? '').toString().toLowerCase();
      final busNumber = (b['busNumber'] ?? '').toString().toLowerCase();
      final bookingId = "#${b['bookingId']}".toLowerCase();

      final matchesQuery = q.isEmpty ||
          passengerName.contains(q) ||
          userEmail.contains(q) ||
          userPhone.contains(q) ||
          userCnic.contains(q) ||
          seat == q ||
          seat.contains(q) ||
          from.contains(q) ||
          to.contains(q) ||
          busName.contains(q) ||
          busNumber.contains(q) ||
          bookingId.contains(q);

      final isPaid = b['payment'] != null;
      final matchesPayment = paymentFilter == "All" ||
          (paymentFilter == "Paid" && isPaid) ||
          (paymentFilter == "Pending" && !isPaid);

      return matchesQuery && matchesPayment;
    }).toList();
  }

  Future<void> _deleteBooking(Map<String, dynamic> b) async {
    final int bookingId = b['bookingId'] as int;
    final int? busId = b['busId'] as int?;
    final dynamic seat = b['seatNumber'];
    final int userId = b['userId'] ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text(
              "Cancel Booking",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to cancel and delete Booking #$bookingId (Seat #$seat)? This will unblock the seat for other passengers.",
          style: const TextStyle(fontSize: 13, color: subText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep", style: TextStyle(color: subText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Cancel Booking", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBHelper.instance.cancelBooking(
        bookingId: bookingId,
        busId: busId,
        seatNumber: seat,
        userId: userId,
      );
      await fetchBookings();
    }
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 22),
                SizedBox(width: 8),
                Text(
                  "Payment Receipt",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildReceiptRow("Passenger", payment['passengerName'] ?? 'N/A'),
            _buildReceiptRow("Account / Phone", payment['accountNumber'] ?? payment['passengerPhone'] ?? 'N/A'),
            _buildReceiptRow("Payment Method", payment['paymentMethod'] ?? 'Standard'),
            _buildReceiptRow("Booked Seats", "${payment['seats'] ?? ''}"),
            _buildReceiptRow("Total Paid", "Rs. ${payment['amount'] ?? '0'}", isHighlight: true),
            _buildReceiptRow("Payment Date", "${payment['date'] ?? ''}"),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: subText)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
              color: isHighlight ? const Color(0xFF10B981) : darkText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = allBookings.length;
    final int paidCount = allBookings.where((b) => b['payment'] != null).length;

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
          "Passenger Bookings",
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
            onPressed: () => fetchBookings(),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ================= BODY =================
      body: Column(
        children: [
          // ─── 1. TOP SEARCH & FILTER BAR ───
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Input
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              searchQuery = val;
                              _applyFilters();
                            });
                          },
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: darkText),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: "Search passenger, seat, CNIC, route...",
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 19, color: primaryBlue),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.cancel_rounded, size: 17, color: subText),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        searchQuery = "";
                                        _applyFilters();
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

                    // Payment Filter Dropdown
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
                          value: paymentFilter,
                          dropdownColor: Colors.white,
                          icon: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                          ),
                          selectedItemBuilder: (context) {
                            return ["All", "Paid", "Pending"].map((val) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tune_rounded, color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    val,
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
                            DropdownMenuItem(value: "All", child: Text("All Status", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText))),
                            DropdownMenuItem(value: "Paid", child: Text("Paid Only", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText))),
                            DropdownMenuItem(value: "Pending", child: Text("Pending Only", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText))),
                          ],
                          onChanged: (String? newVal) {
                            if (newVal != null) {
                              setState(() {
                                paymentFilter = newVal;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Stats / Filter Info Chip Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${filteredBookings.length} of $totalCount Bookings ($paidCount Paid)",
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: subText,
                      ),
                    ),
                    if (widget.busId != null)
                      InkWell(
                        onTap: () => fetchBookings(specificBusId: null),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            "Clear Bus Filter",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ─── 2. BOOKINGS LIST ───
          Expanded(
            child: RefreshIndicator(
              color: primaryBlue,
              onRefresh: () => fetchBookings(),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryBlue))
                  : filteredBookings.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 60),
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
                                    child: const Icon(
                                      Icons.confirmation_number_outlined,
                                      size: 42,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'No bookings match "$searchQuery"'
                                        : 'No passenger bookings found',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: darkText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'When passengers book seats, tickets will appear here',
                                    style: TextStyle(fontSize: 12, color: subText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: filteredBookings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) => _buildBookingTicketCard(filteredBookings[idx]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── MODERN BOOKING TICKET CARD ───
  Widget _buildBookingTicketCard(Map<String, dynamic> b) {
    final int bookingId = b['bookingId'] as int;
    final String fName = b['firstName'] ?? '';
    final String lName = b['lastName'] ?? '';
    final String passengerName = "$fName $lName".trim().isNotEmpty
        ? "$fName $lName".trim()
        : (b['userEmail'] ?? 'Guest Passenger');

    final dynamic seat = b['seatNumber'] ?? '';
    final String gender = (b['gender'] ?? 'Male').toString();
    final String busName = b['busName'] ?? 'Bus';
    final String busNumber = b['busNumber'] ?? '';
    final String busClass = b['busClass'] ?? 'Standard';
    final String fromCity = b['fromCity'] ?? '';
    final String toCity = b['toCity'] ?? '';
    final String time = b['time'] ?? '';
    final String busDate = b['busDate'] ?? b['bookingDate'] ?? '';
    final String phone = b['userPhone'] ?? '';
    final String cnic = b['userCnic'] ?? '';
    final double fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
    final Map<String, dynamic>? payment = b['payment'] as Map<String, dynamic>?;
    final bool isPaid = payment != null;

    final bool isMale = gender.toLowerCase().startsWith('m');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Passenger Info & Seat Badge ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                // Passenger Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isMale ? const Color(0xFFEFF6FF) : const Color(0xFFFDF2F8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isMale ? const Color(0xFFBFDBFE) : const Color(0xFFFBCFE8),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isMale ? Icons.person_rounded : Icons.person_2_rounded,
                      color: isMale ? primaryBlue : const Color(0xFFDB2777),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "Ticket #$bookingId • ${gender.toUpperCase()}",
                        style: const TextStyle(fontSize: 11, color: subText, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Seat Number Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_seat_rounded, size: 13, color: primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        "Seat $seat",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Middle: Route & Bus Details ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route: From -> To
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      fromCity,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: darkText,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded, size: 13, color: subText),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      toCity,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: darkText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      fare > 0 ? "Rs. ${fare.toStringAsFixed(0)}" : "",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: darkText,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Bus schedule info & payment badge
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: subText),
                    const SizedBox(width: 4),
                    Text(
                      "$time ($busDate)",
                      style: const TextStyle(fontSize: 11.5, color: subText, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "$busName ${busNumber.isNotEmpty ? '• $busNumber' : ''} ($busClass)",
                        style: const TextStyle(fontSize: 10.5, color: subText, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),

                if (phone.isNotEmpty || cnic.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (phone.isNotEmpty) ...[
                        const Icon(Icons.phone_outlined, size: 12, color: subText),
                        const SizedBox(width: 3),
                        Text(phone, style: const TextStyle(fontSize: 11, color: subText)),
                      ],
                      if (phone.isNotEmpty && cnic.isNotEmpty)
                        const Text(" • ", style: TextStyle(color: subText, fontSize: 11)),
                      if (cnic.isNotEmpty) ...[
                        const Icon(Icons.badge_outlined, size: 12, color: subText),
                        const SizedBox(width: 3),
                        Text(cnic, style: const TextStyle(fontSize: 11, color: subText)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom Action Toolbar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Payment Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                        size: 12,
                        color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPaid ? (payment['paymentMethod'] ?? 'Paid') : 'Pending Pay',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // View Receipt Button (if paid)
                if (isPaid) ...[
                  InkWell(
                    onTap: () => _showPaymentDetails(payment),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        "Receipt",
                        style: TextStyle(
                          color: darkText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // View Ticket Button
                InkWell(
                  onTap: () {
                    final ticketData = {
                      'passenger': {
                        'name': passengerName,
                        'cnic': cnic,
                        'phone': phone,
                      },
                      'seats': [seat.toString()],
                      'date': busDate,
                      'paymentMethod': payment != null ? (payment['paymentMethod'] ?? '') : 'Counter',
                      'bus': {
                        'busNumber': busNumber,
                        'fromCity': fromCity,
                        'toCity': toCity,
                        'time': time,
                      },
                    };
                    Navigator.pushNamed(
                      context,
                      '/view_ticket',
                      arguments: {'ticketData': ticketData},
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Text(
                      "Ticket",
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Cancel / Delete Button
                InkWell(
                  onTap: () => _deleteBooking(b),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: const Text(
                      "Cancel",
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
          ),
        ],
      ),
    );
  }
}

