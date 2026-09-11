// lib/admin/screens/bookings/view_all_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  String channelFilter = "All"; // "All", "Online App", "POS Counter"
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
      final terminalBookings = await DBHelper.instance.getTerminalBookings();

      final enriched = rows.map((r) {
        final seatStr = r['seatNumber']?.toString() ?? '';
        final int busId = r['busId'] is int ? r['busId'] as int : int.tryParse(r['busId']?.toString() ?? '') ?? 0;
        final int seatNum = int.tryParse(seatStr) ?? 0;

        // 1. Check if there's a match in terminal_bookings
        Map<String, dynamic>? matchedTerminal;
        for (final tb in terminalBookings) {
          final tbBusId = tb['busId'] is int ? tb['busId'] as int : int.tryParse(tb['busId']?.toString() ?? '') ?? 0;
          final tbSeat = tb['seatNumber']?.toString() ?? '';
          if (tbBusId == busId && (tbSeat == seatStr || tb['seatNumber'] == seatNum)) {
            matchedTerminal = tb;
            break;
          }
        }

        // 2. Check if there's a match in payments
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

        // Extract clean passenger info
        String finalName = "";
        String finalPhone = "";
        String finalCnic = "";
        bool isTerminal = false;
        String channel = "Online App";
        String terminalCity = "";
        String terminalName = "";
        String agentName = "";

        if (matchedTerminal != null) {
          finalName = (matchedTerminal['passengerName'] ?? '').toString().trim();
          finalPhone = (matchedTerminal['passengerPhone'] ?? '').toString().trim();
          finalCnic = (matchedTerminal['passengerCnic'] ?? '').toString().trim();
          terminalCity = (matchedTerminal['terminalCity'] ?? '').toString().trim();
          terminalName = (matchedTerminal['terminalName'] ?? '').toString().trim();
          agentName = (matchedTerminal['agentName'] ?? '').toString().trim();
          isTerminal = true;
          channel = "POS Counter";
        } else if (matchedPayment != null && (matchedPayment['passengerName'] != null && matchedPayment['passengerName'].toString().trim().isNotEmpty)) {
          finalName = (matchedPayment['passengerName'] ?? '').toString().trim();
          finalPhone = (matchedPayment['passengerPhone'] ?? matchedPayment['accountNumber'] ?? '').toString().trim();
          finalCnic = (matchedPayment['passengerCnic'] ?? '').toString().trim();
          if (matchedPayment['accountNumber'] == "COUNTER-POS" || r['userId'] == 0) {
            isTerminal = true;
            channel = "POS Counter";
          }
        }

        if (finalName.isEmpty) {
          final userFullName = "${r['firstName'] ?? ''} ${r['lastName'] ?? ''}".trim();
          if (userFullName.isNotEmpty) {
            finalName = userFullName;
          } else if (r['userEmail'] != null && r['userEmail'].toString().trim().isNotEmpty) {
            finalName = r['userEmail'].toString().trim();
          } else {
            finalName = isTerminal ? "Counter Passenger" : "Guest Passenger";
          }
        }

        if (finalPhone.isEmpty) {
          finalPhone = (r['userPhone'] ?? '').toString().trim();
        }
        if (finalCnic.isEmpty) {
          finalCnic = (r['userCnic'] ?? '').toString().trim();
        }

        return {
          ...r,
          'passengerName': finalName,
          'passengerPhone': finalPhone,
          'passengerCnic': finalCnic,
          'isTerminal': isTerminal,
          'channel': channel,
          'terminalCity': terminalCity,
          'terminalName': terminalName,
          'agentName': agentName,
          'payment': matchedPayment,
          'terminal': matchedTerminal,
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
      final passengerName = (b['passengerName'] ?? '').toString().toLowerCase();
      final userEmail = (b['userEmail'] ?? '').toString().toLowerCase();
      final userPhone = (b['passengerPhone'] ?? b['userPhone'] ?? '').toString().toLowerCase();
      final userCnic = (b['passengerCnic'] ?? b['userCnic'] ?? '').toString().toLowerCase();
      final seat = (b['seatNumber'] ?? '').toString().toLowerCase();
      final from = (b['fromCity'] ?? '').toString().toLowerCase();
      final to = (b['toCity'] ?? '').toString().toLowerCase();
      final busName = (b['busName'] ?? '').toString().toLowerCase();
      final busNumber = (b['busNumber'] ?? '').toString().toLowerCase();
      final terminalCity = (b['terminalCity'] ?? '').toString().toLowerCase();
      final agentName = (b['agentName'] ?? '').toString().toLowerCase();
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
          terminalCity.contains(q) ||
          agentName.contains(q) ||
          bookingId.contains(q);

      final isPaid = b['payment'] != null || b['isTerminal'] == true;
      final matchesPayment = paymentFilter == "All" ||
          (paymentFilter == "Paid" && isPaid) ||
          (paymentFilter == "Pending" && !isPaid);

      final matchesChannel = channelFilter == "All" ||
          (channelFilter == "POS Counter" && b['isTerminal'] == true) ||
          (channelFilter == "Online App" && b['isTerminal'] != true);

      return matchesQuery && matchesPayment && matchesChannel;
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

  String _formatBookingDateTime(Map<String, dynamic> b) {
    final terminal = b['terminal'] as Map<String, dynamic>?;
    final payment = b['payment'] as Map<String, dynamic>?;

    final String raw = (terminal?['createdAt'] ?? b['createdAt'] ?? payment?['createdAt'] ?? payment?['date'] ?? b['bookingDate'] ?? '').toString().trim();

    if (raw.isNotEmpty) {
      try {
        final dt = DateTime.parse(raw);
        return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
      } catch (_) {
        return raw;
      }
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
  }

  void _showPaymentDetails(Map<String, dynamic> b) {
    final payment = b['payment'] as Map<String, dynamic>?;
    final terminal = b['terminal'] as Map<String, dynamic>?;
    final String passengerName = (b['passengerName'] ?? '').toString().trim();
    final String seat = (b['seatNumber'] ?? '').toString();
    final double fare = (b['fare'] as num?)?.toDouble() ?? (payment?['amount'] as num?)?.toDouble() ?? 0.0;
    final String method = (payment?['paymentMethod'] ?? terminal?['paymentMethod'] ?? (b['isTerminal'] == true ? 'Cash / Counter POS' : 'Paid Online')).toString();
    final String bookingTimestamp = _formatBookingDateTime(b);
    final String busTime = (b['time'] ?? 'N/A').toString();
    final String travelDate = (b['busDate'] ?? b['bookingDate'] ?? 'N/A').toString();
    final String terminalName = (b['terminalName'] ?? '').toString().trim();
    final String terminalCity = (b['terminalCity'] ?? '').toString().trim();
    final String displayTerminal = terminalName.isNotEmpty
        ? (terminalCity.isNotEmpty ? "$terminalCity • $terminalName" : terminalName)
        : (terminalCity.isNotEmpty ? "$terminalCity Terminal" : "POS Counter");

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
                  "Booking & Payment Receipt",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildReceiptRow("Passenger", passengerName.isNotEmpty ? passengerName : 'Guest Passenger'),
            _buildReceiptRow("Seat Number", "Seat #$seat"),
            _buildReceiptRow("Route", "${b['fromCity'] ?? ''} → ${b['toCity'] ?? ''}"),
            _buildReceiptRow("Payment Method", method),
            _buildReceiptRow("Total Paid", "Rs. ${fare.toStringAsFixed(0)}", isHighlight: true),
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            _buildReceiptRow("Booked On (Time)", bookingTimestamp, isHighlight: false),
            _buildReceiptRow("Bus Departure", "$busTime ($travelDate)"),
            if (b['isTerminal'] == true)
              _buildReceiptRow("POS Terminal", displayTerminal),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: subText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                color: isHighlight ? const Color(0xFF10B981) : darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 5.0;
          const dashSpace = 4.0;
          final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return const SizedBox(
                width: dashWidth,
                height: 1.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.all(Radius.circular(1)),
                  ),
                ),
              );
            }),
          );
        },
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

      // ================= SCROLLABLE BODY =================
      body: RefreshIndicator(
        color: primaryBlue,
        onRefresh: () => fetchBookings(),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryBlue))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // ─── 1. TOP SEARCH & FILTER BAR (SCROLLABLE WITH SCREEN) ───
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Input & Payment Filter Dropdown
                          Row(
                            children: [
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
                                      hintText: "Search name, phone, CNIC, seat...",
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
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: paymentFilter,
                                    dropdownColor: Colors.white,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: subText, size: 18),
                                    items: const [
                                      DropdownMenuItem(value: "All", child: Text("All Status", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: darkText))),
                                      DropdownMenuItem(value: "Paid", child: Text("Paid", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)))),
                                      DropdownMenuItem(value: "Pending", child: Text("Pending", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)))),
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

                          const SizedBox(height: 10),

                          // Channel Filter Segment Chips (All, Online App, POS Counter)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildChannelFilterChip("All", "All Bookings", Icons.all_inclusive_rounded),
                                const SizedBox(width: 6),
                                _buildChannelFilterChip("Online App", "Online App", Icons.phone_android_rounded),
                                const SizedBox(width: 6),
                                _buildChannelFilterChip("POS Counter", "POS Terminal", Icons.point_of_sale_rounded),
                              ],
                            ),
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
                                  fontWeight: FontWeight.w600,
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
                                        fontWeight: FontWeight.w700,
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
                  ),

                  const SliverToBoxAdapter(
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),

                  // ─── 2. BOOKINGS LIST ITEMS (WITH DOTTED DIVIDERS) ───
                  if (filteredBookings.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
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
                                  fontSize: 14.5,
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
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final int itemIndex = index ~/ 2;
                            if (index.isOdd) {
                              return _buildDottedDivider();
                            }
                            return _buildBookingTicketCard(filteredBookings[itemIndex]);
                          },
                          childCount: filteredBookings.length * 2 - 1,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildChannelFilterChip(String filterKey, String label, IconData icon) {
    final bool isSelected = channelFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          channelFilter = filterKey;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryBlue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : subText,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── COMPACT STREAMLINED BOOKING TICKET CARD ───
  Widget _buildBookingTicketCard(Map<String, dynamic> b) {
    final int bookingId = b['bookingId'] as int;
    final String passengerName = (b['passengerName'] ?? '').toString().trim().isNotEmpty
        ? (b['passengerName'] ?? '').toString().trim()
        : (b['userEmail'] ?? 'Guest Passenger');

    final dynamic seat = b['seatNumber'] ?? '';
    final String fromCity = b['fromCity'] ?? '';
    final String toCity = b['toCity'] ?? '';
    final String time = b['time'] ?? '';
    final String busDate = b['busDate'] ?? b['bookingDate'] ?? '';
    final double fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
    final bool isTerminal = b['isTerminal'] == true;
    final String bookingTimestamp = _formatBookingDateTime(b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Top Row: Passenger Name, Channel Badge & Seat No (No Image Icon) ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isTerminal ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isTerminal ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Text(
                            isTerminal ? "POS Counter" : "Online App",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isTerminal ? const Color(0xFFB45309) : primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "#$bookingId",
                          style: const TextStyle(fontSize: 10.5, color: subText, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Text(
                  "Seat $seat",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // ── 2. Route (From & To) + Fare ──
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      fromCity,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded, size: 13, color: subText),
                    ),
                    Text(
                      toCity,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                fare > 0 ? "Rs. ${fare.toStringAsFixed(0)}" : "Rs. 0",
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: primaryBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── 3. Date & Time ──
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 13, color: subText),
              const SizedBox(width: 4),
              Text(
                "$time • $busDate",
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: subText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 4. 3 Action Buttons (Receipt, Ticket, Cancel) ──
          Row(
            children: [
              // Button 1: Receipt
              Expanded(
                child: InkWell(
                  onTap: () => _showPaymentDetails(b),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text(
                        "Receipt",
                        style: TextStyle(
                          color: darkText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Button 2: Ticket
              Expanded(
                child: InkWell(
                  onTap: () {
                    final ticketData = {
                      'passenger': {
                        'name': passengerName,
                        'cnic': b['passengerCnic'] ?? b['userCnic'] ?? '',
                        'phone': b['passengerPhone'] ?? b['userPhone'] ?? '',
                      },
                      'seats': [seat.toString()],
                      'date': busDate,
                      'travelDate': busDate,
                      'bookingTimestamp': bookingTimestamp,
                      'paymentMethod': b['payment'] != null ? (b['payment']['paymentMethod'] ?? '') : (isTerminal ? 'POS Counter' : 'Online'),
                      'bus': {
                        'busNumber': b['busNumber'] ?? '',
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
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Center(
                      child: Text(
                        "Ticket",
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Button 3: Cancel
              Expanded(
                child: InkWell(
                  onTap: () => _deleteBooking(b),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: const Center(
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

