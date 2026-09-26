import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bus_ticket_system/services/notification_service.dart';
import 'package:bus_ticket_system/user/screens/live_bus_tracking_screen.dart';
import 'view_ticket_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  final int userId;
  final String userEmail;

  const MyTicketsScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allTickets = [];
  bool _isLoading = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> combined = [];

    // Fetch User Profile for Fallbacks
    Map<String, dynamic>? userProfile;
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        userProfile = await SupabaseService.instance.getUserProfile(currentUid);
      }
      final currentEmail = widget.userEmail.isNotEmpty
          ? widget.userEmail
          : (FirebaseAuth.instance.currentUser?.email ?? '');
      if (userProfile == null && currentEmail.isNotEmpty) {
        final u = await DBHelper.instance.getUserByEmail(currentEmail);
        if (u is Map<String, dynamic>) {
          userProfile = u;
        }
      }
      if (userProfile == null && widget.userId > 0) {
        userProfile = await DBHelper.instance.getUserById(widget.userId);
      }
    } catch (e) {
      print("Error loading user profile in MyTickets: $e");
    }

    final String defaultUserName = userProfile != null
        ? "${userProfile['firstName'] ?? userProfile['first_name'] ?? ''} ${userProfile['lastName'] ?? userProfile['last_name'] ?? ''}".trim()
        : (FirebaseAuth.instance.currentUser?.displayName ?? "Valued Customer");
    final String defaultUserPhone = userProfile?['phone'] ?? userProfile?['user_phone'] ?? "";
    final String defaultUserCnic = userProfile?['cnic'] ?? userProfile?['user_cnic'] ?? "";

    // 1. Fetch from Supabase Bookings
    try {
      final queryKey = widget.userEmail.isNotEmpty
          ? widget.userEmail
          : (FirebaseAuth.instance.currentUser?.uid ?? widget.userId);
      final localBookings = await DBHelper.instance.getUserBookings(queryKey);
      for (var b in localBookings) {
        combined.add({
          ...b,
          'source': 'booking',
          'passengerName': (b['passengerName'] != null && b['passengerName'].toString().trim().isNotEmpty)
              ? b['passengerName']
              : (defaultUserName.isNotEmpty ? defaultUserName : "Valued Customer"),
          'passengerPhone': (b['passengerPhone'] != null && b['passengerPhone'].toString().trim().isNotEmpty)
              ? b['passengerPhone']
              : defaultUserPhone,
          'passengerCnic': (b['passengerCnic'] != null && b['passengerCnic'].toString().trim().isNotEmpty)
              ? b['passengerCnic']
              : defaultUserCnic,
          'paymentMethod': b['paymentMethod'] ?? "Paid Online",
        });
      }
    } catch (e) {
      print("Error loading Supabase bookings: $e");
    }

    // 2. Fallback to Payments table ONLY IF no bookings found in bookings table
    if (combined.isEmpty) {
      try {
        final payments = await DBHelper.instance.getPayments();
        final filterEmail = widget.userEmail.isNotEmpty
            ? widget.userEmail.toLowerCase()
            : (FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '');
        for (var p in payments) {
          final pEmail = (p['email'] ?? p['passengerEmail'] ?? '').toString().toLowerCase();
          if (pEmail == filterEmail || filterEmail.isEmpty || widget.userId == 0) {
            Map<String, dynamic>? bus;
            if (p['busId'] != null && p['busId'] is int) {
              bus = await DBHelper.instance.getBusById(p['busId'] as int);
            }

            combined.add({
              'source': 'payment',
              'bookingId': p['id'],
              'busId': p['busId'],
              'seatNumber': p['seats'] ?? "N/A",
              'passengerGender': "M",
              'bookingDate': p['date'] ?? "",
              'status': 'booked',
              'busName': bus?['busName'] ?? bus?['bus_name'] ?? "BusVerse Express",
              'fromCity': bus?['fromCity'] ?? bus?['from_city'] ?? "Multan",
              'toCity': bus?['toCity'] ?? bus?['to_city'] ?? "Lahore",
              'travelDate': (bus?['date'] != null && bus!['date'].toString().trim().isNotEmpty)
                  ? bus['date'].toString().trim()
                  : (p['date'] ?? ""),
              'time': bus?['time'] ?? "Scheduled",
              'busClass': bus?['busClass'] ?? bus?['bus_class'] ?? "Executive",
              'busNumber': bus?['busNumber'] ?? bus?['bus_number'] ?? "BV-Fleet",
              'fare': (p['amount'] != null && (p['amount'] as num) > 0)
                  ? (p['amount'] as num).toDouble()
                  : ((bus?['fare'] is num) ? (bus?['fare'] as num).toDouble() : 0.0),
              'passengerName': (p['passengerName'] != null && p['passengerName'].toString().trim().isNotEmpty)
                  ? p['passengerName']
                  : defaultUserName,
              'passengerPhone': (p['passengerPhone'] != null && p['passengerPhone'].toString().trim().isNotEmpty)
                  ? p['passengerPhone']
                  : defaultUserPhone,
              'passengerCnic': (p['passengerCnic'] != null && p['passengerCnic'].toString().trim().isNotEmpty)
                  ? p['passengerCnic']
                  : defaultUserCnic,
              'paymentMethod': p['paymentMethod'] ?? "Paid Online",
            });
          }
        }
      } catch (e) {
        print("Error loading payments fallback: $e");
      }
    }

    // Strict Deduplication
    final Set<String> seenKeys = {};
    final List<Map<String, dynamic>> deduped = [];

    for (var ticket in combined) {
      final String bId = (ticket['bookingId'] ?? '').toString();
      final String seatNum = ticket['seatNumber']?.toString().replaceAll('#', '').trim() ?? '';
      final String date = _formatDateOnly(ticket['travelDate']?.toString() ?? ticket['bookingDate']?.toString());
      final String from = ticket['fromCity']?.toString().toLowerCase().trim() ?? '';
      final String to = ticket['toCity']?.toString().toLowerCase().trim() ?? '';

      final String seatKey = "$from-$to-$date-seat-$seatNum";
      final String idKey = "ref-$bId";

      if (!seenKeys.contains(seatKey) && !seenKeys.contains(idKey)) {
        seenKeys.add(seatKey);
        seenKeys.add(idKey);
        deduped.add(ticket);
      }
    }

    if (mounted) {
      setState(() {
        _allTickets = deduped;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelTicket(Map<String, dynamic> ticket) async {
    final String source = ticket['source'] ?? 'booking';
    final int bId = (ticket['bookingId'] is int)
        ? ticket['bookingId']
        : int.tryParse(ticket['bookingId']?.toString() ?? '0') ?? 0;
    final int? busId = (ticket['busId'] is int)
        ? ticket['busId']
        : int.tryParse(ticket['busId']?.toString() ?? '');

    final bool success = await DBHelper.instance.cancelBooking(
      bookingId: bId,
      source: source,
      busId: busId,
      seatNumber: ticket['seatNumber'],
      userId: widget.userId,
      email: widget.userEmail,
    );

    // Cancel in Supabase Cloud if available
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        await SupabaseService.instance.cancelBooking(bookingId: bId);
      }
    } catch (_) {}

    if (!mounted) return;

    if (success) {
      // Trigger Realtime Cancellation Notification
      try {
        final String from = ticket['fromCity'] ?? 'Departure';
        final String to = ticket['toCity'] ?? 'Destination';
        final String seatStr = ticket['seatNumber']?.toString() ?? '';
        final String dateStr = ticket['travelDate']?.toString() ?? ticket['bookingDate']?.toString() ?? '';
        NotificationService.instance.showCancellationNotification(
          fromCity: from,
          toCity: to,
          seatNumber: seatStr,
          date: dateStr,
        );
      } catch (e) {
        debugPrint("Notification error on cancellation: $e");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ticket cancelled successfully. Refund initiated to wallet."),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _loadTickets();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot cancel ticket at this time."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter active vs completed/cancelled
    final activeTickets = _allTickets.where((t) {
      final status = (t['status'] ?? '').toString().toLowerCase();
      return status == 'booked' || status == 'confirmed' || status == 'active';
    }).toList();

    final pastTickets = _allTickets.where((t) {
      final status = (t['status'] ?? '').toString().toLowerCase();
      return status == 'cancelled' || status == 'completed' || status == 'past';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Bookings & Tickets",
          style: TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: subText,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: "Upcoming (${activeTickets.length})"),
                Tab(text: "Past / Cancelled (${pastTickets.length})"),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBlue))
          : TabBarView(
              controller: _tabController,
              children: [
                // ─── TAB 1: UPCOMING TICKETS ───
                RefreshIndicator(
                  color: primaryBlue,
                  onRefresh: _loadTickets,
                  child: activeTickets.isEmpty
                      ? _buildEmptyState(
                          title: "No Upcoming Bookings",
                          subtitle: "You don't have any active bus reservations at the moment.",
                          showBookButton: true,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: activeTickets.length,
                          itemBuilder: (context, index) {
                            return _buildTicketCard(activeTickets[index], isActive: true);
                          },
                        ),
                ),

                // ─── TAB 2: PAST / CANCELLED TICKETS ───
                RefreshIndicator(
                  color: primaryBlue,
                  onRefresh: _loadTickets,
                  child: pastTickets.isEmpty
                      ? _buildEmptyState(
                          title: "No Past Bookings",
                          subtitle: "Your travel history and cancelled tickets will show up here.",
                          showBookButton: false,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: pastTickets.length,
                          itemBuilder: (context, index) {
                            return _buildTicketCard(pastTickets[index], isActive: false);
                          },
                        ),
                ),
              ],
            ),
    );
  }

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

  // ─── PROFESSIONAL BOARDING PASS TICKET CARD ───
  Widget _buildTicketCard(Map<String, dynamic> t, {required bool isActive}) {
    final String fromCity = t['fromCity'] ?? "Departure";
    final String toCity = t['toCity'] ?? "Destination";
    final String rawDate = (t['travelDate'] != null && t['travelDate'].toString().trim().isNotEmpty)
        ? t['travelDate'].toString().trim()
        : (t['bookingDate']?.toString().trim() ?? "");
    final String date = _formatDateOnly(rawDate);
    final String time = t['time'] ?? "TBD";
    final String busClass = t['busClass'] ?? "Executive";
    final String busName = t['busName'] ?? "Junaid Movers";
    final dynamic rawFare = t['fare'];
    final double fare = (rawFare is num) ? rawFare.toDouble() : 0.0;
    final String seatNumber = t['seatNumber']?.toString() ?? "1";
    final String bookingRef = "BV-${t['bookingId'] ?? '9021'}";
    final int bookingId = t['bookingId'] is int ? t['bookingId'] : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isActive ? primaryBlue : subText,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          busName,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: darkText),
                        ),
                        Text(
                          "Ref: $bookingRef",
                          style: const TextStyle(fontSize: 10, color: subText, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.check_circle_rounded : Icons.history_rounded,
                        size: 12,
                        color: isActive ? const Color(0xFF16A34A) : subText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? "CONFIRMED" : "COMPLETED",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isActive ? const Color(0xFF16A34A) : subText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Journey Main Details
          Padding(
            padding: const EdgeInsets.all(16),
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
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trip_origin_rounded, size: 9, color: primaryBlue),
                            Expanded(
                              child: Divider(color: Color(0xFFCBD5E1), thickness: 1.2),
                            ),
                            Icon(Icons.directions_bus_rounded, size: 14, color: primaryBlue),
                            Expanded(
                              child: Divider(color: Color(0xFFCBD5E1), thickness: 1.2),
                            ),
                            Icon(Icons.location_on_rounded, size: 11, color: primaryBlue),
                          ],
                        ),
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

                const SizedBox(height: 14),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 12),

                // Date, Time, Seat, Class with comfortable spacing
                Row(
                  children: [
                    Expanded(flex: 4, child: _metaColumn("DATE", date)),
                    const SizedBox(width: 14),
                    Expanded(flex: 4, child: _metaColumn("DEPARTURE", time)),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: _metaColumn("SEAT", "#$seatNumber")),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: _metaColumn("CLASS", busClass)),
                  ],
                ),
              ],
            ),
          ),

          // Perforated Cutout Divider
          Row(
            children: [
              Container(
                width: 12,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
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
                          child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: 12,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          // Bottom Fare & Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TOTAL FARE", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: subText)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "PKR ${fare.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryBlue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Live GPS Track Button for Upcoming Active Tickets
                    if (isActive) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveBusTrackingScreen(ticketData: t),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                        ),
                        icon: const Icon(Icons.gps_fixed_rounded, size: 14),
                        label: const Text("Track Bus", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // View Digital E-Ticket Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewTicketScreen(
                              ticketData: {
                                "passenger": {
                                  "name": t['passengerName'] ?? "Valued Customer",
                                  "cnic": t['passengerCnic'] ?? "N/A",
                                  "phone": t['passengerPhone'] ?? "N/A",
                                },
                                "passengerName": t['passengerName'] ?? "Valued Customer",
                                "passengerCnic": t['passengerCnic'] ?? "N/A",
                                "passengerPhone": t['passengerPhone'] ?? "N/A",
                                "bus": {
                                  "busNumber": t['busNumber'] ?? "JND-101",
                                  "busClass": busClass,
                                  "busName": busName,
                                },
                                "seats": [seatNumber],
                                "date": date,
                                "time": time,
                                "fromCity": fromCity,
                                "toCity": toCity,
                                "paymentMethod": t['paymentMethod'] ?? "Paid Online",
                                "totalFare": fare,
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 15),
                      label: const Text("E-Ticket", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),

                    if (isActive && (bookingId > 0 || (t['busId'] != null))) ...[
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () => _showCancelDialog(t),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        child: const Text("Cancel", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: subText)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: darkText),
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(Map<String, dynamic> ticket) {
    final String fromCity = ticket['fromCity'] ?? "Departure";
    final String toCity = ticket['toCity'] ?? "Destination";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text("Cancel Booking?", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          "Are you sure you want to cancel your ticket for $fromCity → $toCity? 100% refund will be credited back to your wallet.",
          style: const TextStyle(fontSize: 12, color: subText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No, Keep Ticket", style: TextStyle(color: subText, fontSize: 12.5, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelTicket(ticket);
            },
            child: const Text("Yes, Cancel Ticket", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── EMPTY STATE WIDGET ───
  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required bool showBookButton,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number_outlined, size: 48, color: primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: darkText),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: subText),
            ),
            if (showBookButton) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/search_bus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.directions_bus_rounded, size: 18),
                label: const Text("Book Bus Ticket", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
