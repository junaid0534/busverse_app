import 'package:flutter/material.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'book_seat_screen.dart';

class AvailableBusesUserScreen extends StatefulWidget {
  final List<BusModel> buses;
  final DateTime selectedDate;
  final int userId;

  const AvailableBusesUserScreen({
    super.key,
    required this.buses,
    required this.selectedDate,
    required this.userId,
  });

  @override
  State<AvailableBusesUserScreen> createState() => _AvailableBusesUserScreenState();
}

class _AvailableBusesUserScreenState extends State<AvailableBusesUserScreen> {
  Map<int, int> bookedSeatsCount = {};
  bool isLoadingSeats = true;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkNavy = Color(0xFF1E3C72);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadBookedSeatsCount();
  }

  Future<void> _loadBookedSeatsCount() async {
    Map<int, int> tempCount = {};

    for (var bus in widget.buses) {
      if (bus.id == null) continue;
      // 1. Try Supabase live booked seats
      try {
        final onlineSeats = await SupabaseService.instance.getBookedSeats(bus.id!);
        if (onlineSeats.isNotEmpty) {
          tempCount[bus.id!] = onlineSeats.length;
          continue;
        }
      } catch (e) {
        print("Supabase seats load error: $e");
      }

      // 2. Fallback to local SQLite
      try {
        final bookedList = await DBHelper.instance.getBookedSeatsWithGender(bus.id!);
        tempCount[bus.id!] = bookedList.length;
      } catch (e) {
        tempCount[bus.id!] = 0;
      }
    }

    if (mounted) {
      setState(() {
        bookedSeatsCount = tempCount;
        isLoadingSeats = false;
      });
    }
  }

  String formatDate(DateTime d) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}, ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final activeBuses = widget.buses.where((bus) => !bus.isExpired).toList();
    final String fromCity = activeBuses.isNotEmpty
        ? activeBuses.first.fromCity
        : (widget.buses.isNotEmpty ? widget.buses.first.fromCity : "Departure");
    final String toCity = activeBuses.isNotEmpty
        ? activeBuses.first.toCity
        : (widget.buses.isNotEmpty ? widget.buses.first.toCity : "Destination");

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
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fromCity,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: primaryBlue),
                ),
                Text(
                  toCity,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              formatDate(widget.selectedDate),
              style: const TextStyle(
                color: subText,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── ROUTE SUMMARY BAR ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F7FF),
              border: Border(
                bottom: BorderSide(color: Color(0xFFD0E3FF), width: 0.8),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 18),
                const SizedBox(width: 8),
                Text(
                  "${activeBuses.length} Buses Available",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD0E3FF)),
                  ),
                  child: const Text(
                    "Direct Routes",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: darkNavy),
                  ),
                ),
              ],
            ),
          ),

          // ─── BUSES LIST ───
          Expanded(
            child: activeBuses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.departure_board_rounded, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          "No upcoming buses available",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "All scheduled buses for today have departed.\nPlease search for an upcoming date.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: subText),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: activeBuses.length,
                    itemBuilder: (context, index) {
                      return _AnimatedBusCard(
                        bus: activeBuses[index],
                        bookedCount: bookedSeatsCount[activeBuses[index].id ?? 0] ?? 0,
                        selectedDate: widget.selectedDate,
                        userId: widget.userId,
                        onSeatsUpdated: _loadBookedSeatsCount,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// ANIMATED BUS TICKET CARD WITH VERTICAL TIMELINE ROUTE & GLOWING BADGES
// =========================================================================
class _AnimatedBusCard extends StatefulWidget {
  final BusModel bus;
  final int bookedCount;
  final DateTime selectedDate;
  final int userId;
  final VoidCallback onSeatsUpdated;

  const _AnimatedBusCard({
    required this.bus,
    required this.bookedCount,
    required this.selectedDate,
    required this.userId,
    required this.onSeatsUpdated,
  });

  @override
  State<_AnimatedBusCard> createState() => _AnimatedBusCardState();
}

class _AnimatedBusCardState extends State<_AnimatedBusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    // Continuous subtle pulse animation for Discount & Class badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bus;
    final int seatsLeft = b.seats - widget.bookedCount;
    final bool isSoldOut = seatsLeft <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── TOP BAR: BUS NUMBER + ANIMATED CLASS & DISCOUNT ───
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                // Bus identification icon & number (if provided)
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.airport_shuttle_rounded, size: 15, color: primaryBlue),
                      ),
                      if (b.busNumber.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "Bus #${b.busNumber}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: darkText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Animated Bus Class Badge
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E3C72),
                            primaryBlue.withOpacity(_glowAnimation.value),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(_glowAnimation.value * 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        b.busClass,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    );
                  },
                ),

                // Animated Discount Tag (if available)
                if (b.discountLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3366), Color(0xFFFF6B4A)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3366).withOpacity(0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, size: 11, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                b.discountLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ─── MIDDLE: VERTICAL ROUTE TIMELINE (From on Top -> Arrow -> To on Bottom) ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual Timeline Indicator (From dot -> downward dashed line & arrow -> To dot)
                Column(
                  children: [
                    // From Dot
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: primaryBlue, width: 3.5),
                      ),
                    ),
                    // Vertical Journey Line with Downward Arrow in center
                    Container(
                      width: 2,
                      height: 14,
                      color: const Color(0xFFCBD5E1),
                    ),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F7FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: primaryBlue,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 14,
                      color: const Color(0xFFCBD5E1),
                    ),
                    // To Dot
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.redAccent, width: 3.5),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 14),

                // City Names & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FROM CITY (Top)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.fromCity,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                              ),
                            ),
                          ),
                          // Departure Time Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F7FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_filled_rounded, size: 13, color: primaryBlue),
                                const SizedBox(width: 4),
                                Text(
                                  b.time,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // VIA ROUTE (Middle)
                      if (b.routeVia.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.alt_route_rounded, size: 12, color: subText),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "Via ${b.routeVia}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: subText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 12),

                      const SizedBox(height: 6),

                      // TO CITY (Bottom)
                      Text(
                        b.toCity,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── AMENITIES & SEATS INFO ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                // Seats Left Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSoldOut
                        ? Colors.redAccent.withOpacity(0.1)
                        : primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.airline_seat_recline_extra_rounded,
                        size: 13,
                        color: isSoldOut ? Colors.redAccent : primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSoldOut ? "Sold Out" : "$seatsLeft Seats Left",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSoldOut ? Colors.redAccent : primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),

                // Refreshment tag
                if (b.refreshment)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant_rounded, size: 12, color: subText),
                        SizedBox(width: 4),
                        Text(
                          "Refreshment",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subText),
                        ),
                      ],
                    ),
                  ),

                // Driver Name (only if admin added driver)
                if (b.driverName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: subText),
                        const SizedBox(width: 4),
                        Text(
                          b.driverName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subText),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ─── BOTTOM ROW: FARE & SELECT SEATS ACTION ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                // Fare details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "PKR ${b.fare.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: darkText,
                          ),
                        ),
                        if (b.originalFare > b.fare) ...[
                          const SizedBox(width: 6),
                          Text(
                            "PKR ${b.originalFare.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Text(
                      "per seat",
                      style: TextStyle(fontSize: 10.5, color: subText),
                    ),
                  ],
                ),

                const Spacer(),

                // Select Seats Action Button
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSoldOut ? const Color(0xFFE2E8F0) : primaryBlue,
                      foregroundColor: isSoldOut ? subText : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isSoldOut
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookSeatScreen(
                                  bus: b,
                                  selectedDate: widget.selectedDate,
                                  userId: widget.userId,
                                ),
                              ),
                            ).then((_) {
                              widget.onSeatsUpdated();
                            });
                          },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSoldOut ? "Sold Out" : "Select Seats",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!isSoldOut) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ],
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
