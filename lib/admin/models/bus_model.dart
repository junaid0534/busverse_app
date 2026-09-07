// lib/admin/models/bus_model.dart

class BusModel {
  int? id;

  String busName;
  String routeName;

  String fromCity;
  String toCity;
  String routeVia;

  String date;
  String day;
  String time;

  String busClass;
  int seats;

  double fare;
  double originalFare;

  int discount;
  String discountLabel;

  bool refreshment;

  String busNumber;
  String driverName;

  String createdAt;

  BusModel({
    this.id,
    required this.busName,
    required this.routeName,
    required this.fromCity,
    required this.toCity,
    required this.routeVia,
    required this.date,
    required this.day,
    required this.time,
    required this.busClass,
    required this.seats,
    required this.fare,
    required this.originalFare,
    required this.discount,
    required this.discountLabel,
    required this.refreshment,
    required this.busNumber,
    required this.driverName,
    required this.createdAt,
  });

  // -----------------------------
  // Convert DB → Model
  // -----------------------------
  factory BusModel.fromMap(Map<String, dynamic> map) {
    return BusModel(
      id: map['id'],
      busName: map['busName'] ?? "",
      routeName: map['routeName'] ?? "",
      fromCity: map['fromCity'] ?? "",
      toCity: map['toCity'] ?? "",
      routeVia: map['routeVia'] ?? "",
      date: map['date'] ?? "",
      day: map['day'] ?? "",
      time: map['time'] ?? "",
      busClass: map['busClass'] ?? "",
      seats: map['seats'] ?? 0,
      fare: (map['fare'] as num).toDouble(),
      originalFare: (map['originalFare'] as num).toDouble(),
      discount: map['discount'] ?? 0,
      discountLabel: map['discountLabel'] ?? "",
      refreshment: (map['refreshment'] ?? 0) == 1,
      busNumber: map['busNumber'] ?? "",
      driverName: map['driverName'] ?? "",
      createdAt: map['createdAt'] ?? "",
    );
  }

  // -----------------------------
  // Temporary getters (Safe)
  // -----------------------------

  /// Some screens expect "bus.name"
  String get name => busName;

  /// Some screens expect "bus.totalSeats"
  int get totalSeats => seats;

  /// Temporary default since booking stored in other table
  int get bookedSeats => 0;

  /// Safe empty booked seats list (avoid null crash)
  List<int> get bookedSeatsList => [];

  /// Some code uses "bus.from"
  String get from => fromCity;

  // -----------------------------
  // Convert Model → DB map
  // -----------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'busName': busName,
      'routeName': routeName,
      'fromCity': fromCity,
      'toCity': toCity,
      'routeVia': routeVia,
      'date': date,
      'day': day,
      'time': time,
      'busClass': busClass,
      'seats': seats,
      'fare': fare,
      'originalFare': originalFare,
      'discount': discount,
      'discountLabel': discountLabel,
      'refreshment': refreshment ? 1 : 0,
      'busNumber': busNumber,
      'driverName': driverName,
      'createdAt': createdAt,
    };
  }

  /// ⏰ Check if bus departure date/time is in the past
  bool get isExpired => isBusExpired(date, time);

  static bool isBusExpired(String dateStr, String timeStr) {
    if (dateStr.isEmpty) return false;
    try {
      final now = DateTime.now();

      // 1. Parse Date (Supports yyyy-MM-dd, dd-MM-yyyy, yyyy/MM/dd, etc.)
      DateTime? busDate;
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            busDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else {
            busDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      } else if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            busDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          } else {
            busDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        }
      }

      busDate ??= DateTime.tryParse(dateStr);
      if (busDate == null) return false;

      final today = DateTime(now.year, now.month, now.day);
      final busDay = DateTime(busDate.year, busDate.month, busDate.day);

      // If departure day was yesterday or earlier, it's expired
      if (busDay.isBefore(today)) {
        return true;
      }
      // If departure day is tomorrow or later, it's NOT expired
      if (busDay.isAfter(today)) {
        return false;
      }

      // If departure day is TODAY: check departure time
      if (timeStr.isEmpty) return false;

      int hour = 0;
      int minute = 0;

      String cleanTime = timeStr.trim().toUpperCase();
      final bool isPM = cleanTime.contains('PM');
      final bool isAM = cleanTime.contains('AM');

      cleanTime = cleanTime.replaceAll('AM', '').replaceAll('PM', '').trim();
      final timeParts = cleanTime.split(':');

      if (timeParts.isNotEmpty) {
        hour = int.tryParse(timeParts[0].trim()) ?? 0;
        if (timeParts.length > 1) {
          final minPart = timeParts[1].trim().split(' ')[0];
          minute = int.tryParse(minPart) ?? 0;
        }

        if (isPM && hour < 12) {
          hour += 12;
        } else if (isAM && hour == 12) {
          hour = 0;
        }

        final departureDateTime = DateTime(busDate.year, busDate.month, busDate.day, hour, minute);
        return departureDateTime.isBefore(now);
      }
    } catch (_) {}
    return false;
  }
}
