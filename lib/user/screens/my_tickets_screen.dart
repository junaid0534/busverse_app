import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      if (widget.userId > 0) {
        userProfile = await DBHelper.instance.getUserById(widget.userId);
      } else if (widget.userEmail.isNotEmpty) {
        final u = await DBHelper.instance.getUserByEmail(widget.userEmail);
        if (u is Map<String, dynamic>) {
          userProfile = u;
        }
      }
    } catch (e) {
      print("Error loading user profile in MyTickets: $e");
    }

    final String defaultUserName = userProfile != null
        ? "${userProfile['firstName'] ?? ''} ${userProfile['lastName'] ?? ''}".trim()
        : "Valued Customer";
    final String defaultUserPhone = userProfile?['phone'] ?? "";
    final String defaultUserCnic = userProfile?['cnic'] ?? "";

    // 1. Fetch from local SQLite Bookings
    try {
      final localBookings = await DBHelper.instance.getUserBookings(widget.userId);
      for (var b in localBookings) {
        combined.add({
          ...b,
          'passengerName': defaultUserName.isNotEmpty ? defaultUserName : "Valued Customer",
          'passengerPhone': defaultUserPhone,
          'passengerCnic': defaultUserCnic,
          'paymentMethod': "Paid Online",
        });
      }
    } catch (e) {
      print("Error loading SQLite bookings: $e");
    }

    // 2. Fetch from local SQLite Payments table
    try {
      final payments = await DBHelper.instance.getPayments();
      for (var p in payments) {
        if (p['email'] == widget.userEmail || widget.userEmail.isEmpty || widget.userId == 0) {
          // Check if already in combined
          bool exists = combined.any((b) =>
              b['bookingId'] == p['id'] ||
              (b['busId'] != null && b['busId'] == p['busId'] && b['travelDate'] == p['date']));
          if (!exists) {
            Map<String, dynamic>? bus;
            if (p['busId'] != null && p['busId'] is int) {
              bus = await DBHelper.instance.getBusById(p['busId'] as int);
            }

            combined.add({
              'bookingId': p['id'],
              'busId': p['busId'],
              'seatNumber': p['seats'] ?? "N/A",
              'passengerGender': "M",
              'bookingDate': p['date'] ?? "",
              'status': 'booked',
              'busName': bus?['busName'] ?? "Junaid Movers",
              'fromCity': bus?['fromCity'] ?? "Departure",
              'travelDate': (bus?['date'] != null && bus!['date'].toString().trim().isNotEmpty)
                  ? bus['date'].toString().trim()
                  : (p['date'] ?? ""),
              'time': bus?['time'] ?? "Scheduled",
              'busClass': bus?['busClass'] ?? "Executive",
              'busNumber': bus?['busNumber'] ?? "JND-101",
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
      }
    } catch (e) {
      print("Error loading payments: $e");
    }

    // 3. Cloud Supabase Sync (if user is logged in with Firebase)
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        final cloudBookings = await SupabaseService.instance.getUserBookings(currentUid);
        for (var cb in cloudBookings) {
          final bus = cb['buses'] ?? {};
          combined.add({
            'bookingId': cb['id'],
            'seatNumber': cb['seat_number']?.toString() ?? "N/A",
            'passengerGender': cb['gender'] ?? "M",
            'bookingDate': cb['booking_date'] ?? "",
            'status': cb['status'] ?? 'booked',
            'busName': bus['busName'] ?? "Junaid Movers",
            'fromCity': bus['fromCity'] ?? "Departure",
            'toCity': bus['toCity'] ?? "Destination",
            'travelDate': bus['date'] ?? cb['booking_date'] ?? "",
            'time': bus['time'] ?? "Scheduled",
            'busClass': bus['busClass'] ?? "Executive",
            'busNumber': bus['busNumber'] ?? "JND-101",
            'fare': (bus['fare'] is num) ? (bus['fare'] as num).toDouble() : 0.0,
            'passengerName': defaultUserName,
            'passengerPhone': defaultUserPhone,
            'passengerCnic': defaultUserCnic,
            'paymentMethod': "Paid Online",
          });
        }
      }
    } catch (e) {
      print("Error loading cloud bookings: $e");
    }

    if (mounted) {
      setState(() {
        _allTickets = combined;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelTicket(int bookingId) async {
    final bool success = await DBHelper.instance.cancelBooking(bookingId, widget.userId);
    if (!mounted) return;

    if (success) {
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Bookings & Tickets",
          style: TextStyle(
            color: darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: darkText),
                        ),
                        Text(
                          "Ref: $bookingRef",
                          style: const TextStyle(fontSize: 10, color: subText, fontWeight: FontWeight.w600),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
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
                          const Text("FROM", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: subText)),
                          const SizedBox(height: 2),
                          Text(
                            fromCity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
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
                            Icon(Icons.trip_origin_rounded, size: 10, color: primaryBlue),
                            Expanded(
                              child: Divider(color: Color(0xFFCBD5E1), thickness: 1.2),
                            ),
                            Icon(Icons.directions_bus_rounded, size: 15, color: primaryBlue),
                            Expanded(
                              child: Divider(color: Color(0xFFCBD5E1), thickness: 1.2),
                            ),
                            Icon(Icons.location_on_rounded, size: 12, color: primaryBlue),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("TO", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: subText)),
                          const SizedBox(height: 2),
                          Text(
                            toCity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: darkText),
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
                      const Text("TOTAL FARE", style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: subText)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "PKR ${fare.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryBlue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      label: const Text("E-Ticket", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),

                    if (isActive && bookingId > 0) ...[
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () => _showCancelDialog(bookingId, fromCity, toCity),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        child: const Text("Cancel", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: subText)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: darkText),
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(int bookingId, String fromCity, String toCity) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text("Cancel Booking?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Are you sure you want to cancel your ticket for $fromCity → $toCity? 100% refund will be credited back to your wallet.",
          style: const TextStyle(fontSize: 13, color: subText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No, Keep Ticket", style: TextStyle(color: subText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelTicket(bookingId);
            },
            child: const Text("Yes, Cancel Ticket"),
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
              child: const Icon(Icons.confirmation_number_outlined, size: 54, color: primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: darkText),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: subText),
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
                label: const Text("Book Bus Ticket", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
