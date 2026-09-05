// lib/admin/screens/bookings/view_all_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

class ViewAllBookingScreen extends StatefulWidget {
  final int? busId; // Optional, agar busId pass hua to sirf wo bus show kare
  const ViewAllBookingScreen({super.key, this.busId});

  @override
  State<ViewAllBookingScreen> createState() => _ViewAllBookingScreenState();
}

class _ViewAllBookingScreenState extends State<ViewAllBookingScreen> {
  List<Map<String, dynamic>> bookings = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  Future<void> fetchBookings() async {
    setState(() {
      loading = true;
    });

    final db = await DBHelper.instance.database;

    String query = '''
      SELECT b.id as bookingId, b.userId, b.busId, b.seatNumber, b.gender, b.bookingDate,
             u.firstName, u.lastName, u.cnic, u.phone,
             buses.busNumber, buses.fromCity, buses.toCity, buses.time, buses.date as busDate
      FROM bookings b
      LEFT JOIN users u ON b.userId = u.id
      LEFT JOIN buses ON b.busId = buses.id
    ''';

    List<dynamic> args = [];
    if (widget.busId != null) {
      query += ' WHERE b.busId = ?';
      args.add(widget.busId);
    }

    query += ' ORDER BY b.id ASC';

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

    setState(() {
      bookings = enriched;
      loading = false;
    });
  }

  Future<void> deleteBooking(int bookingId) async {
    final db = await DBHelper.instance.database;
    await db.delete('bookings', where: 'id=?', whereArgs: [bookingId]);
    await fetchBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bus Bookings"),
        backgroundColor: Colors.green,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : bookings.isEmpty
              ? const Center(child: Text("No bookings found"))
              : RefreshIndicator(
                  onRefresh: fetchBookings,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, idx) {
                      final b = bookings[idx];
                      final passengerName = ((b['firstName'] ?? '') as String).isNotEmpty
                          ? "${b['firstName'] ?? ''} ${b['lastName'] ?? ''}"
                          : "Guest";
                      final seat = b['seatNumber']?.toString() ?? '';
                      final bookingDate = b['bookingDate'] ?? '';
                      final busNumber = b['busNumber'] ?? '';
                      final route = "${b['fromCity'] ?? ''} → ${b['toCity'] ?? ''}";
                      final time = b['time'] ?? '';
                      final gender = b['gender'] ?? '';
                      final payment = b['payment'];

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      passengerName,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text("#${b['bookingId']}", style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text("Seat: $seat    Gender: $gender"),
                              const SizedBox(height: 6),
                              Text("Bus: $busNumber    Time: $time"),
                              const SizedBox(height: 6),
                              Text("Route: $route"),
                              const SizedBox(height: 6),
                              Text("Booked On: $bookingDate"),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.remove_red_eye),
                                    label: const Text("View Ticket"),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: () {
                                      final ticketData = {
                                        'passenger': {
                                          'name': passengerName,
                                          'cnic': b['cnic'] ?? '',
                                          'phone': b['phone'] ?? '',
                                        },
                                        'seats': [seat],
                                        'date': b['busDate'] ?? bookingDate,
                                        'paymentMethod': payment != null ? (payment['paymentMethod'] ?? '') : '',
                                        'bus': {
                                          'busNumber': b['busNumber'] ?? '',
                                          'fromCity': b['fromCity'] ?? '',
                                          'toCity': b['toCity'] ?? '',
                                          'time': b['time'] ?? '',
                                        },
                                      };
                                      Navigator.pushNamed(context, '/view_ticket', arguments: {'ticketData': ticketData});
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.delete),
                                    label: const Text("Delete"),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text("Confirm Delete"),
                                          content: const Text("Are you sure you want to delete this booking?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete")),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await deleteBooking(b['bookingId'] as int);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  if (payment != null)
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.receipt_long),
                                      label: const Text("Payment"),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          builder: (ctx) {
                                            return Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text("Passenger: ${payment['passengerName'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 6),
                                                  Text("Email: ${payment['email'] ?? ''}"),
                                                  const SizedBox(height: 6),
                                                  Text("Seats: ${payment['seats'] ?? ''}"),
                                                  const SizedBox(height: 6),
                                                  Text("Amount: ${payment['amount'] ?? ''}"),
                                                  const SizedBox(height: 6),
                                                  Text("Method: ${payment['paymentMethod'] ?? ''}"),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemCount: bookings.length,
                  ),
                ),
    );
  }
}
