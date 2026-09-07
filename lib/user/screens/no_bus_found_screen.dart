import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/db_helper.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'available_buses_screen.dart';

class NoBusFoundScreen extends StatefulWidget {
  final String fromCity;
  final String toCity;
  final DateTime selectedDate;
  final String busClass;
  final int userId;

  const NoBusFoundScreen({
    super.key,
    required this.fromCity,
    required this.toCity,
    required this.selectedDate,
    required this.busClass,
    required this.userId,
  });

  @override
  State<NoBusFoundScreen> createState() => _NoBusFoundScreenState();
}

class _NoBusFoundScreenState extends State<NoBusFoundScreen> {
  static const Color primaryBlue = Color(0xFF388AF6);
  static const Color darkText = Color(0xFF1E293B);
  static const Color subText = Color(0xFF64748B);

  bool _isSearching = false;

  Future<void> _searchForDate(DateTime targetDate) async {
    setState(() => _isSearching = true);

    final String formattedDate = DateFormat('yyyy-MM-dd').format(targetDate);
    List<BusModel> foundBuses = [];

    // 1. Try Supabase
    try {
      foundBuses = await SupabaseService.instance.searchBuses(
        fromCity: widget.fromCity,
        toCity: widget.toCity,
        date: formattedDate,
        busClass: widget.busClass == "All Types" ? null : widget.busClass,
      );
    } catch (_) {}

    // 2. Fallback to SQLite
    if (foundBuses.isEmpty) {
      try {
        final raw = await DBHelper.instance.getBusesByRouteAndType(
          widget.fromCity,
          widget.toCity,
          widget.busClass == "All Types" ? null : widget.busClass,
        );
        final local = raw.map((e) => BusModel.fromMap(e)).toList();
        foundBuses = local.where((b) => b.date == formattedDate && !b.isExpired).toList();
      } catch (_) {}
    }

    foundBuses = foundBuses.where((b) => !b.isExpired).toList();

    if (!mounted) return;
    setState(() => _isSearching = false);

    if (foundBuses.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AvailableBusesUserScreen(
            buses: foundBuses,
            selectedDate: targetDate,
            userId: widget.userId,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "No buses available for ${DateFormat('dd MMM yyyy').format(targetDate)}",
          ),
          backgroundColor: const Color(0xFFE11D48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAnotherDate() async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate.isBefore(today) ? today : widget.selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: darkText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _searchForDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime tomorrow = widget.selectedDate.add(const Duration(days: 1));
    final String formattedDate = DateFormat('dd MMM yyyy').format(widget.selectedDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSearching
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryBlue),
                  SizedBox(height: 16),
                  Text(
                    "Checking bus availability...",
                    style: TextStyle(color: subText, fontSize: 14),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // ─── MINIMAL SLEEK ICON ───
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_bus_outlined,
                          size: 48,
                          color: subText,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ─── TITLE & SUBTITLE ───
                    const Text(
                      "No Buses Found",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: darkText,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 10),

                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: subText,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: "We couldn't find any active departures from\n"),
                          TextSpan(
                            text: "${widget.fromCity} → ${widget.toCity}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: darkText,
                            ),
                          ),
                          const TextSpan(text: " on "),
                          TextSpan(
                            text: formattedDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                          const TextSpan(text: "."),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ─── ACTION 1: CHECK TOMORROW ───
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _searchForDate(tomorrow),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Check Tomorrow (${DateFormat('dd MMM').format(tomorrow)})",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─── ACTION 2: CHANGE DATE ───
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _pickAnotherDate,
                        icon: const Icon(Icons.calendar_month_rounded, size: 18, color: darkText),
                        label: const Text(
                          "Change Date",
                          style: TextStyle(
                            color: darkText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ─── ACTION 3: MODIFY SEARCH LINK ───
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Modify Route or Search",
                        style: TextStyle(
                          color: subText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
}
