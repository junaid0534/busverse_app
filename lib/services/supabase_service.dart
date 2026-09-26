import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/user_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  SupabaseClient get client => Supabase.instance.client;

  // ============================================================
  // ROUTES
  // ============================================================
  Future<int> insertRoute(Map<String, dynamic> route) async {
    try {
      final map = Map<String, dynamic>.from(route);
      map.remove('id');
      final res = await client.from('routes').insert(map).select('id').maybeSingle();
      return (res?['id'] as num?)?.toInt() ?? 1;
    } catch (e) {
      debugPrint('Error inserting route: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getRoutes() async {
    try {
      final res = await client.from('routes').select().order('id', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching routes: $e');
      return [];
    }
  }

  Future<int> updateRoute(int id, Map<String, dynamic> data) async {
    try {
      final map = Map<String, dynamic>.from(data);
      map.remove('id');
      await client.from('routes').update(map).eq('id', id);
      return 1;
    } catch (e) {
      debugPrint('Error updating route: $e');
      return 0;
    }
  }

  Future<int> deleteRoute(int id) async {
    try {
      await client.from('routes').delete().eq('id', id);
      return 1;
    } catch (e) {
      debugPrint('Error deleting route: $e');
      return 0;
    }
  }

  // ============================================================
  // BUSES & SEARCH
  // ============================================================
  Future<List<Map<String, dynamic>>> getAllBuses() async {
    try {
      final response = await client.from('buses').select().order('id', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching buses from Supabase: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBuses() async => await getAllBuses();

  Future<Map<String, dynamic>?> getBusById(int id) async {
    try {
      final response = await client.from('buses').select().eq('id', id).maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error fetching bus by id: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getBusesByDate(String dateKey) async {
    try {
      final response = await client.from('buses').select().eq('date', dateKey).order('id', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching buses by date: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBusesByDateRaw(String dateKey) async => await getBusesByDate(dateKey);

  Future<List<Map<String, dynamic>>> getBusesByRouteAndType(String from, String to, String? busClass) async {
    try {
      dynamic query = client.from('buses').select();
      if (from.isNotEmpty) query = query.ilike('fromCity', '%$from%');
      if (to.isNotEmpty) query = query.ilike('toCity', '%$to%');
      if (busClass != null && busClass.isNotEmpty && busClass.toLowerCase() != 'all types') {
        query = query.eq('busClass', busClass);
      }

      final response = await query.order('id', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching buses by route: $e');
      return [];
    }
  }

  Future<List<BusModel>> searchBuses({
    String? fromCity,
    String? toCity,
    String? from,
    String? to,
    String? date,
    String? busClass,
  }) async {
    try {
      final f = (fromCity ?? from ?? '').trim();
      final t = (toCity ?? to ?? '').trim();
      dynamic query = client.from('buses').select();
      if (f.isNotEmpty) {
        query = query.ilike('fromCity', '%$f%');
      }
      if (t.isNotEmpty) {
        query = query.ilike('toCity', '%$t%');
      }
      if (date != null && date.trim().isNotEmpty) {
        query = query.eq('date', date.trim());
      }
      if (busClass != null && busClass.trim().isNotEmpty && busClass.toLowerCase() != 'all' && busClass.toLowerCase() != 'all types') {
        query = query.eq('busClass', busClass.trim());
      }
      final res = await query.order('id', ascending: true);
      return (res as List).map((e) => BusModel.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error searchBuses in Supabase: $e');
      return [];
    }
  }

  Future<List<String>> getAllFromCities() async {
    try {
      final response = await client.from('buses').select('fromCity');
      final list = (response as List)
          .map((e) => (e['fromCity'] ?? e['from_city'] ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      list.sort();
      return list;
    } catch (e) {
      return ["Lahore", "Islamabad", "Rawalpindi", "Karachi", "Faisalabad", "Multan", "Peshawar", "Quetta"];
    }
  }

  Future<List<String>> getAllToCities() async {
    try {
      final response = await client.from('buses').select('toCity');
      final list = (response as List)
          .map((e) => (e['toCity'] ?? e['to_city'] ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      list.sort();
      return list;
    } catch (e) {
      return ["Lahore", "Islamabad", "Rawalpindi", "Karachi", "Faisalabad", "Multan", "Peshawar", "Quetta"];
    }
  }

  Future<int?> insertBus(BusModel bus) async {
    try {
      final map = bus.toMap();
      map.remove('id');

      final response = await client
          .from('buses')
          .insert(map)
          .select('id')
          .maybeSingle();
      return response?['id'] as int?;
    } catch (e) {
      debugPrint('Error inserting bus into Supabase: $e');
      return null;
    }
  }

  Future<bool> updateBus(dynamic idOrBus, [BusModel? busParam]) async {
    try {
      int id;
      BusModel bus;
      if (idOrBus is BusModel) {
        bus = idOrBus;
        id = bus.id!;
      } else if (idOrBus is int && busParam != null) {
        id = idOrBus;
        bus = busParam;
      } else {
        return false;
      }
      final map = bus.toMap();
      map.remove('id');
      await client.from('buses').update(map).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating bus in Supabase: $e');
      return false;
    }
  }

  Future<bool> deleteBus(int busId) async {
    try {
      try {
        await client.from('bookings').delete().eq('bus_id', busId);
      } catch (_) {
        await client.from('bookings').delete().eq('busId', busId);
      }
      await client.from('buses').delete().eq('id', busId);
      return true;
    } catch (e) {
      debugPrint('Error deleting bus from Supabase: $e');
      return false;
    }
  }

  Future<void> cleanOldBusesAndBookings() async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final oldBuses = await client.from('buses').select('id').lt('date', todayStr);
      final ids = (oldBuses as List).map((b) => b['id'] as int).toList();
      if (ids.isNotEmpty) {
        try {
          await client.from('bookings').delete().inFilter('bus_id', ids);
        } catch (_) {
          await client.from('bookings').delete().inFilter('busId', ids);
        }
        await client.from('buses').delete().inFilter('id', ids);
      }
    } catch (e) {
      debugPrint('Error cleaning old buses: $e');
    }
  }

  // ============================================================
  // USERS & AUTH
  // ============================================================
  Future<void> registerUser(UserModel user) async {
    try {
      final map = user.toMap();
      map.remove('id');
      await client.from('users').insert(map);
    } catch (e) {
      debugPrint('Error registering user in Supabase: $e');
    }
  }

  Future<Map<String, dynamic>?> loginUser(String email, String pass) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPass = pass.trim();

      // 1. Check dedicated Terminals table (Sub-Admin / Terminal Manager)
      try {
        final termRes = await client
            .from('terminals')
            .select()
            .ilike('email', cleanEmail)
            .maybeSingle();
        if (termRes != null) {
          final storedPass = (termRes['password'] ?? termRes['pass'] ?? termRes['pin'] ?? '').toString().trim();
          if (storedPass.isNotEmpty && storedPass == cleanPass) {
            final m = Map<String, dynamic>.from(termRes);
            m['role'] = 'sub_admin';
            m['firstName'] = termRes['manager_first_name'] ?? termRes['first_name'] ?? termRes['firstName'] ?? 'Manager';
            m['lastName'] = termRes['manager_last_name'] ?? termRes['last_name'] ?? termRes['lastName'] ?? '';
            m['name'] = '${m['firstName']} ${m['lastName']}'.trim();
            m['terminalCity'] = termRes['terminal_city'] ?? termRes['city'] ?? termRes['terminalCity'] ?? '';
            m['terminal_city'] = m['terminalCity'];
            m['terminalName'] = termRes['terminal_name'] ?? termRes['name'] ?? termRes['terminalName'] ?? '${m['terminalCity']} Main Terminal';
            m['terminal_name'] = m['terminalName'];
            m['status'] = termRes['status'] ?? 'active';
            m['phone'] = termRes['phone'] ?? termRes['manager_phone'] ?? '';
            m['cnic'] = termRes['cnic'] ?? '';
            return _normalizeUserMap(m);
          }
        }
      } catch (_) {}

      // 2. Check dedicated Drivers table
      try {
        final driverRes = await client
            .from('drivers')
            .select()
            .ilike('email', cleanEmail)
            .maybeSingle();
        if (driverRes != null) {
          final storedPass = (driverRes['password'] ?? driverRes['pass'] ?? driverRes['pin'] ?? '').toString().trim();
          if (storedPass.isNotEmpty && storedPass == cleanPass) {
            final m = _normalizeUserMap(driverRes);
            m['role'] = 'driver';
            return m;
          }
        }
      } catch (_) {}

      // 3. Check Users & Sub-Admins table
      final response = await client
          .from('users')
          .select()
          .ilike('email', cleanEmail)
          .maybeSingle();

      if (response != null) {
        final storedPass = response['password'] ?? response['pass'] ?? response['pin'];
        if (storedPass != null) {
          if (storedPass.toString().trim() == cleanPass) {
            return _normalizeUserMap(response);
          }
          return null;
        }
        return _normalizeUserMap(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error logging in user with Supabase: $e');
      return null;
    }
  }

  Map<String, dynamic> _normalizeUserMap(Map<String, dynamic> u) {
    final m = Map<String, dynamic>.from(u);
    final fn = m['first_name'] ?? m['firstName'] ?? '';
    final ln = m['last_name'] ?? m['lastName'] ?? '';
    m['firstName'] = fn;
    m['first_name'] = fn;
    m['lastName'] = ln;
    m['last_name'] = ln;
    m['name'] = m['name'] ?? ('$fn $ln').trim();
    m['phone'] = m['phone'] ?? m['user_phone'] ?? '';
    m['cnic'] = m['cnic'] ?? m['user_cnic'] ?? '';
    m['gender'] = m['gender'] ?? 'Male';
    m['role'] = m['role'] ?? 'user';
    m['status'] = m['status'] ?? 'active';
    m['terminalCity'] = m['terminal_city'] ?? m['terminalCity'] ?? '';
    m['terminal_city'] = m['terminalCity'];
    m['terminalName'] = m['terminal_name'] ?? m['terminalName'] ?? '';
    m['terminal_name'] = m['terminalName'];
    m['licenseNo'] = m['license_no'] ?? m['licenseNo'] ?? m['region'] ?? '';
    m['license_no'] = m['licenseNo'];
    m['assignedBusId'] = m['assigned_bus_id'] ?? m['assignedBusId'] ?? m['street'] ?? '';
    m['assigned_bus_id'] = m['assignedBusId'];
    m['assignedBusNumber'] = m['assigned_bus_number'] ?? m['assignedBusNumber'] ?? m['zip'] ?? '';
    m['assigned_bus_number'] = m['assignedBusNumber'];
    m['assignedRoute'] = m['assigned_route'] ?? m['assignedRoute'] ?? m['city'] ?? '';
    m['assigned_route'] = m['assignedRoute'];
    m['firebaseUid'] = m['firebaseUid'] ?? m['firebase_uid'] ?? '';
    m['firebase_uid'] = m['firebaseUid'];
    m['email'] = (m['email'] ?? '').toString().trim().toLowerCase();
    return m;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();
      if (response != null) {
        return _normalizeUserMap(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserById(dynamic id) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response != null) {
        return _normalizeUserMap(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updatePassword(String email, String pass) async {
    try {
      await client.from('users').update({'password': pass}).eq('email', email.trim().toLowerCase());
    } catch (e) {
      debugPrint('Error updating password: $e');
    }
  }

  Future<void> updateUser(dynamic id, Map<String, dynamic> data) async {
    try {
      final map = Map<String, dynamic>.from(data);
      map.remove('id');
      await client.from('users').update(map).eq('id', id);
    } catch (e) {
      debugPrint('Error updating user: $e');
    }
  }

  Future<void> deleteUser(dynamic id) async {
    try {
      await client.from('users').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting user: $e');
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await client.from('users').select().order('id', ascending: true);
      return (response as List).map((map) => UserModel.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // BOOKINGS & SEATS
  // ============================================================
  Future<List<Map<String, dynamic>>> getBookedSeats(dynamic busId) async {
    try {
      final id = busId is int ? busId : int.tryParse(busId.toString()) ?? 0;
      dynamic response;
      try {
        response = await client
            .from('bookings')
            .select('seat_number, gender')
            .eq('bus_id', id)
            .order('seat_number', ascending: true);
      } catch (_) {
        try {
          response = await client
              .from('bookings')
              .select('seatNumber, gender')
              .eq('busId', id)
              .order('seatNumber', ascending: true);
        } catch (_) {
          response = await client
              .from('bookings')
              .select()
              .eq('bus_id', id);
        }
      }

      return (response as List).map<Map<String, dynamic>>((e) {
        final seat = (e['seat_number'] ?? e['seatNumber'] ?? '').toString().trim();
        return {
          'seatNumber': seat,
          'seat_number': seat,
          'gender': e['gender'] ?? 'M',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching booked seats: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBookedSeatsWithGender(dynamic busId) async {
    return await getBookedSeats(busId);
  }

  Future<void> bookSeats({
    required int busId,
    required dynamic seats,
    required String gender,
    required String date,
    int userId = 0,
    String? userEmail,
  }) async {
    try {
      List<String> seatList = [];
      if (seats is List) {
        seatList = seats.map((s) => s.toString().trim()).toList();
      } else if (seats is String) {
        seatList = seats.split(',').map((s) => s.trim()).toList();
      }

      final nowIso = DateTime.now().toIso8601String();
      final effectiveUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final effectiveEmail = userEmail ?? (FirebaseAuth.instance.currentUser?.email ?? '');

      final rows = seatList.map((seat) => {
        'bus_id': busId,
        'firebase_uid': effectiveUid,
        'user_email': effectiveEmail,
        'seat_number': seat,
        'gender': gender,
        'booking_date': date,
        'status': 'Confirmed',
        'created_at': nowIso,
      }).toList();

      try {
        await client.from('bookings').insert(rows);
      } catch (e1) {
        final camelRows = seatList.map((seat) => {
          'busId': busId,
          'firebase_uid': effectiveUid,
          'user_email': effectiveEmail,
          'seatNumber': seat,
          'gender': gender,
          'bookingDate': date,
          'status': 'Confirmed',
          'createdAt': nowIso,
        }).toList();
        await client.from('bookings').insert(camelRows);
      }
    } catch (e) {
      debugPrint('Error booking seats in Supabase: $e');
    }
  }

  Future<void> createBooking({
    required String firebaseUid,
    required String userEmail,
    required int busId,
    required dynamic seatNumbers,
    required dynamic seatGenders,
    required String bookingDate,
  }) async {
    try {
      List<String> seats = [];
      if (seatNumbers is List) {
        seats = seatNumbers.map((s) => s.toString().trim()).toList();
      }

      final nowIso = DateTime.now().toIso8601String();
      final rows = seats.map((seat) {
        String g = 'Male';
        if (seatGenders is Map) {
          g = (seatGenders[seat] ?? seatGenders[int.tryParse(seat)] ?? 'Male').toString();
        }
        return {
          'bus_id': busId,
          'firebase_uid': firebaseUid,
          'user_email': userEmail,
          'seat_number': seat,
          'gender': g,
          'booking_date': bookingDate,
          'status': 'Confirmed',
          'created_at': nowIso,
        };
      }).toList();

      try {
        await client.from('bookings').insert(rows);
      } catch (e1) {
        final camelRows = seats.map((seat) {
          String g = 'Male';
          if (seatGenders is Map) {
            g = (seatGenders[seat] ?? seatGenders[int.tryParse(seat)] ?? 'Male').toString();
          }
          return {
            'busId': busId,
            'firebase_uid': firebaseUid,
            'user_email': userEmail,
            'seatNumber': seat,
            'gender': g,
            'bookingDate': bookingDate,
            'status': 'Confirmed',
            'createdAt': nowIso,
          };
        }).toList();
        await client.from('bookings').insert(camelRows);
      }
    } catch (e) {
      debugPrint('Error createBooking: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserBookings(dynamic userIdOrEmail) async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      String? email;
      String? uid;

      if (userIdOrEmail != null && userIdOrEmail.toString().isNotEmpty && userIdOrEmail.toString() != '0') {
        final s = userIdOrEmail.toString().trim();
        if (s.contains('@')) {
          email = s.toLowerCase();
        } else {
          uid = s;
        }
      }

      if (email == null && authUser?.email != null && authUser!.email!.isNotEmpty) {
        email = authUser.email!.trim().toLowerCase();
      }
      if (uid == null && authUser?.uid != null && authUser!.uid.isNotEmpty) {
        uid = authUser.uid;
      }

      dynamic query = client.from('bookings').select('*, buses(*)');
      if (email != null && uid != null && email.isNotEmpty && uid.isNotEmpty) {
        query = query.or('user_email.eq.$email,firebase_uid.eq.$uid');
      } else if (email != null && email.isNotEmpty) {
        query = query.eq('user_email', email);
      } else if (uid != null && uid.isNotEmpty) {
        query = query.eq('firebase_uid', uid);
      }

      final response = await query.order('id', ascending: false);
      return (response as List).map<Map<String, dynamic>>((row) {
        final bus = row['buses'] as Map<String, dynamic>?;
        final map = Map<String, dynamic>.from(row);
        map['bookingId'] = map['id'];
        map['seatNumber'] = map['seat_number'] ?? map['seatNumber'] ?? 'N/A';
        map['passengerGender'] = map['gender'] ?? 'Male';
        map['bookingDate'] = map['booking_date'] ?? map['bookingDate'] ?? '';
        map['status'] = map['status'] ?? 'Confirmed';
        map['busId'] = map['bus_id'] ?? map['busId'];
        if (bus != null) {
          map['busName'] = bus['busName'] ?? bus['bus_name'] ?? 'BusVerse Express';
          map['busNumber'] = bus['busNumber'] ?? bus['bus_number'] ?? 'BV-Fleet';
          map['fromCity'] = bus['fromCity'] ?? bus['from_city'] ?? '';
          map['toCity'] = bus['toCity'] ?? bus['to_city'] ?? '';
          map['routeVia'] = bus['routeVia'] ?? bus['route_via'] ?? '';
          map['time'] = bus['time'] ?? '';
          map['travelDate'] = bus['date'] ?? bus['travel_date'] ?? map['bookingDate'] ?? '';
          map['busClass'] = bus['busClass'] ?? bus['bus_class'] ?? 'Executive';
          map['fare'] = (bus['fare'] is num) ? (bus['fare'] as num).toDouble() : 0.0;
        }
        return map;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching user bookings: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllBookingsAdmin({int? limit, int? busId}) async {
    try {
      dynamic query = client.from('bookings').select('*, buses(*)');
      if (busId != null && busId > 0) {
        query = query.or('bus_id.eq.$busId,busId.eq.$busId');
      }
      if (limit != null && limit > 0) {
        query = query.limit(limit);
      }
      final response = await query.order('id', ascending: false);

      Map<String, Map<String, dynamic>> usersByEmail = {};
      Map<String, Map<String, dynamic>> usersByUid = {};
      try {
        final usersRes = await client.from('users').select('*');
        for (var u in (usersRes as List)) {
          final uMap = Map<String, dynamic>.from(u);
          if (uMap['email'] != null) usersByEmail[uMap['email'].toString().toLowerCase()] = uMap;
          if (uMap['firebase_uid'] != null) usersByUid[uMap['firebase_uid'].toString()] = uMap;
        }
      } catch (_) {}

      final list = (response as List).map<Map<String, dynamic>>((row) {
        final bus = row['buses'] as Map<String, dynamic>?;
        final uEmail = (row['user_email'] ?? '').toString().toLowerCase();
        final uUid = (row['firebase_uid'] ?? '').toString();
        final user = usersByEmail[uEmail] ?? usersByUid[uUid];

        final fn = user?['first_name'] ?? user?['firstName'] ?? '';
        final ln = user?['last_name'] ?? user?['lastName'] ?? '';

        return {
          'bookingId': row['id'],
          'seatNumber': row['seat_number'] ?? row['seatNumber'] ?? 'N/A',
          'passengerGender': row['gender'] ?? 'Male',
          'bookingDate': row['booking_date'] ?? row['bookingDate'] ?? '',
          'status': row['status'] ?? 'Confirmed',
          'userId': row['user_id'] ?? row['userId'] ?? 0,
          'busId': row['bus_id'] ?? row['busId'],
          'busName': bus?['busName'] ?? bus?['bus_name'] ?? 'BusVerse Express',
          'busNumber': bus?['busNumber'] ?? bus?['bus_number'] ?? 'BV-Fleet',
          'fromCity': bus?['fromCity'] ?? bus?['from_city'] ?? '',
          'toCity': bus?['toCity'] ?? bus?['to_city'] ?? '',
          'routeVia': bus?['routeVia'] ?? bus?['route_via'] ?? '',
          'travelDate': bus?['date'] ?? bus?['travel_date'] ?? row['booking_date'] ?? '',
          'time': bus?['time'] ?? '',
          'busClass': bus?['busClass'] ?? bus?['bus_class'] ?? '',
          'fare': bus?['fare'] ?? 0.0,
          'firstName': fn,
          'lastName': ln,
          'cnic': user?['cnic'] ?? '',
          'phone': user?['phone'] ?? '',
        };
      }).toList();
      return list;
    } catch (e) {
      debugPrint('Error fetching all bookings: $e');
      return [];
    }
  }

  Future<bool> deleteBooking(int bookingId) async {
    try {
      await client.from('bookings').delete().eq('id', bookingId);
      return true;
    } catch (e) {
      debugPrint('Error deleting booking: $e');
      return false;
    }
  }

  Future<bool> cancelBooking({
    dynamic bookingId,
    String? source,
    int? busId,
    dynamic seatNumber,
    int userId = 0,
    String? email,
  }) async {
    try {
      if (bookingId != null) {
        final bIdInt = int.tryParse(bookingId.toString()) ?? 0;
        if (bIdInt > 0) {
          await client.from('bookings').delete().eq('id', bIdInt);
          try {
            await client.from('terminal_bookings').delete().eq('id', bIdInt);
          } catch (_) {}
          return true;
        }
      }
      if (busId != null && seatNumber != null) {
        try {
          await client.from('bookings').delete().eq('bus_id', busId).eq('seat_number', seatNumber.toString());
        } catch (_) {
          await client.from('bookings').delete().eq('busId', busId).eq('seatNumber', seatNumber.toString());
        }
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('Error canceling booking: $e');
      return false;
    }
  }

  // ============================================================
  // PAYMENTS
  // ============================================================
  Future<int> insertPayment({
    required int busId,
    required dynamic seats,
    required String passengerName,
    required String passengerEmail,
    required String paymentMethod,
    required String accountNumber,
    String? date,
    double? amount,
    String? passengerCnic,
    String? passengerPhone,
  }) async {
    try {
      String seatsStr = '';
      if (seats is List) {
        seatsStr = seats.join(', ');
      } else {
        seatsStr = seats?.toString() ?? '';
      }

      final dateVal = date ?? DateTime.now().toIso8601String().split('T')[0];
      final nowIso = DateTime.now().toIso8601String();

      try {
        final res = await client.from('payments').insert({
          'bus_id': busId,
          'seats': seatsStr,
          'passenger_name': passengerName,
          'email': passengerEmail,
          'payment_method': paymentMethod,
          'account_number': accountNumber,
          'date': dateVal,
          'amount': amount ?? 0.0,
          'passenger_cnic': passengerCnic ?? '',
          'passenger_phone': passengerPhone ?? '',
          'created_at': nowIso,
        }).select('id').maybeSingle();

        return (res?['id'] as num?)?.toInt() ?? 1;
      } catch (_) {
        final res = await client.from('payments').insert({
          'busId': busId,
          'seats': seatsStr,
          'passengerName': passengerName,
          'passengerEmail': passengerEmail,
          'paymentMethod': paymentMethod,
          'accountNumber': accountNumber,
          'date': dateVal,
          'amount': amount ?? 0.0,
          'passengerCnic': passengerCnic ?? '',
          'passengerPhone': passengerPhone ?? '',
          'createdAt': nowIso,
        }).select('id').maybeSingle();

        return (res?['id'] as num?)?.toInt() ?? 1;
      }
    } catch (e) {
      debugPrint('Error inserting payment in Supabase: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getPayments({int? busId}) async {
    try {
      dynamic query = client.from('payments').select();
      if (busId != null && busId > 0) {
        query = query.or('bus_id.eq.$busId,busId.eq.$busId');
      }
      final res = await query.order('id', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching payments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPaymentById(int id) async {
    try {
      final res = await client.from('payments').select().eq('id', id).maybeSingle();
      return res;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // TERMINAL BOOKINGS
  // ============================================================
  Future<int> insertTerminalBooking({
    required int busId,
    required dynamic seatNumbers,
    required dynamic seatGenders,
    required String passengerName,
    required String passengerPhone,
    required String passengerCnic,
    required double totalAmount,
    required String paymentMethod,
    required String terminalCity,
    required String terminalName,
    required String agentName,
    required String bookingDate,
  }) async {
    try {
      List<String> seats = [];
      if (seatNumbers is List) {
        seats = seatNumbers.map((s) => s.toString().trim()).toList();
      }

      final seatNumbersStr = seats.join(', ');
      final seatGendersStr = seats.map((s) {
        String g = 'M';
        if (seatGenders is Map) {
          final val = (seatGenders[s] ?? seatGenders[int.tryParse(s)] ?? 'M').toString();
          g = val.startsWith('F') || val.startsWith('f') ? 'F' : 'M';
        }
        return "$s:$g";
      }).join(', ');

      int terminalBookingId = 1;
      final nowIso = DateTime.now().toIso8601String();

      try {
        final res = await client.from('terminal_bookings').insert({
          'bus_id': busId,
          'seat_numbers': seatNumbersStr,
          'seat_genders': seatGendersStr,
          'passenger_name': passengerName,
          'passenger_phone': passengerPhone,
          'passenger_cnic': passengerCnic,
          'fare': totalAmount,
          'payment_method': paymentMethod,
          'terminal_city': terminalCity,
          'terminal_name': terminalName,
          'agent_name': agentName,
          'booking_date': bookingDate,
          'status': 'Confirmed',
          'created_at': nowIso,
        }).select('id').maybeSingle();
        terminalBookingId = (res?['id'] as num?)?.toInt() ?? 1;
      } catch (_) {
        try {
          final res = await client.from('terminal_bookings').insert({
            'busId': busId,
            'seatNumbers': seatNumbersStr,
            'seatGenders': seatGendersStr,
            'passengerName': passengerName,
            'passengerPhone': passengerPhone,
            'passengerCnic': passengerCnic,
            'fare': totalAmount,
            'paymentMethod': paymentMethod,
            'terminalCity': terminalCity,
            'terminalName': terminalName,
            'agentName': agentName,
            'bookingDate': bookingDate,
            'status': 'Confirmed',
            'createdAt': nowIso,
          }).select('id').maybeSingle();
          terminalBookingId = (res?['id'] as num?)?.toInt() ?? 1;
        } catch (_) {}
      }

      // Also book seats into main bookings table
      for (final seat in seats) {
        String gender = 'Male';
        if (seatGenders is Map) {
          final val = (seatGenders[seat] ?? seatGenders[int.tryParse(seat)] ?? 'Male').toString();
          gender = val.toLowerCase().contains('female') ? 'Female' : 'Male';
        }
        await bookSeats(
          busId: busId,
          seats: [seat],
          gender: gender,
          date: bookingDate,
          userId: 0,
          userEmail: "counter.$passengerPhone@busverse.pos",
        );
      }

      // Also record payment
      await insertPayment(
        busId: busId,
        seats: seatNumbersStr,
        passengerName: passengerName,
        passengerEmail: "counter.$passengerPhone@busverse.pos",
        paymentMethod: paymentMethod,
        accountNumber: "COUNTER-POS",
        date: bookingDate,
        amount: totalAmount,
        passengerCnic: passengerCnic,
        passengerPhone: passengerPhone,
      );

      return terminalBookingId;
    } catch (e) {
      debugPrint('Error insertTerminalBooking: $e');
      return 0;
    }
  }

  Future<int> createTerminalBooking({
    required int busId,
    required dynamic seatNumbers,
    required dynamic seatGenders,
    required String passengerName,
    required String passengerPhone,
    required String passengerCnic,
    required double totalAmount,
    required String paymentMethod,
    required String terminalCity,
    required String terminalName,
    required String agentName,
    required String bookingDate,
  }) async {
    return await insertTerminalBooking(
      busId: busId,
      seatNumbers: seatNumbers,
      seatGenders: seatGenders,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      passengerCnic: passengerCnic,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      terminalCity: terminalCity,
      terminalName: terminalName,
      agentName: agentName,
      bookingDate: bookingDate,
    );
  }

  Future<List<Map<String, dynamic>>> getTerminalBookings({int? busId, String? terminalCity}) async {
    try {
      dynamic query = client.from('terminal_bookings').select('*');
      if (busId != null && busId > 0) {
        try {
          query = query.eq('bus_id', busId);
        } catch (_) {
          query = query.eq('busId', busId);
        }
      }
      if (terminalCity != null && terminalCity.isNotEmpty && terminalCity.toLowerCase() != 'all') {
        try {
          query = query.ilike('terminal_city', '%$terminalCity%');
        } catch (_) {
          query = query.ilike('terminalCity', '%$terminalCity%');
        }
      }
      final res = await query.order('id', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);

      try {
        final busesList = await getAllBuses();
        final busesMap = {for (var b in busesList) (b['id']?.toString() ?? ''): b};
        for (var map in list) {
          final bId = (map['bus_id'] ?? map['busId'] ?? '').toString();
          if (busesMap.containsKey(bId)) {
            final bus = busesMap[bId]!;
            map['busNumber'] ??= bus['busNumber'] ?? bus['bus_number'];
            map['fromCity'] ??= bus['fromCity'] ?? bus['from_city'];
            map['toCity'] ??= bus['toCity'] ?? bus['to_city'];
            map['time'] ??= bus['time'];
            map['travelDate'] ??= bus['date'] ?? bus['travel_date'];
          }
        }
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('Error getTerminalBookings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getTerminalBookingById(int id) async {
    try {
      final res = await client.from('terminal_bookings').select('*').eq('id', id).maybeSingle();
      if (res == null) return null;
      final map = Map<String, dynamic>.from(res);
      final bId = (map['bus_id'] ?? map['busId'] ?? '').toString();
      if (bId.isNotEmpty) {
        try {
          final bus = await getBusById(int.tryParse(bId) ?? 0);
          if (bus != null) {
            map['busNumber'] ??= bus['busNumber'] ?? bus['bus_number'];
            map['fromCity'] ??= bus['fromCity'] ?? bus['from_city'];
            map['toCity'] ??= bus['toCity'] ?? bus['to_city'];
            map['time'] ??= bus['time'];
            map['travelDate'] ??= bus['date'] ?? bus['travel_date'];
          }
        } catch (_) {}
      }
      return map;
    } catch (e) {
      return null;
    }
  }

  Future<int> deleteTerminalBooking(int id) async {
    try {
      await client.from('terminal_bookings').delete().eq('id', id);
      return 1;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // SUB-ADMINS & MANAGERS
  // ============================================================
  // TERMINALS & SUB-ADMINS (DEDICATED TERMINALS TABLE + USERS FALLBACK)
  // ============================================================
  Future<List<Map<String, dynamic>>> getSubAdmins() async {
    try {
      // 1. Try dedicated terminals table
      try {
        final resTerminals = await client.from('terminals').select().order('id', ascending: true);
        if (resTerminals is List && resTerminals.isNotEmpty) {
          return (resTerminals).map<Map<String, dynamic>>((t) {
            final m = Map<String, dynamic>.from(t);
            m['terminalCity'] = m['terminal_city'] ?? m['city'] ?? m['terminalCity'] ?? '';
            m['terminalName'] = m['terminal_name'] ?? m['name'] ?? m['terminalName'] ?? '';
            m['firstName'] = m['manager_first_name'] ?? m['first_name'] ?? m['firstName'] ?? '';
            m['lastName'] = m['manager_last_name'] ?? m['last_name'] ?? m['lastName'] ?? '';
            m['phone'] = m['phone'] ?? m['manager_phone'] ?? '';
            m['email'] = m['email'] ?? '';
            m['status'] = m['status'] ?? 'active';
            return m;
          }).toList();
        }
      } catch (_) {}

      // 2. Fallback to users table (role = 'sub_admin')
      final res = await client.from('users').select().eq('role', 'sub_admin').order('id', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error getSubAdmins: $e');
      return [];
    }
  }

  Future<int> insertSubAdmin(UserModel user) async {
    user.role = 'sub_admin';
    final city = user.terminalCity ?? '';
    final termName = user.terminalName ?? '$city Main Terminal';

    // 1. Try inserting into dedicated terminals table
    try {
      final terminalRow = {
        'terminal_city': city,
        'terminal_name': termName,
        'manager_first_name': user.firstName,
        'manager_last_name': user.lastName,
        'email': user.email.toLowerCase().trim(),
        'password': user.password.trim(),
        'phone': user.phone.trim(),
        'cnic': user.cnic.trim(),
        'status': user.status,
      };
      final res = await client.from('terminals').insert(terminalRow).select('id').maybeSingle();
      if (res != null && res['id'] != null) {
        // Also keep users table in sync for login if needed
        try {
          final map = user.toMap();
          map.remove('id');
          await client.from('users').insert(map);
        } catch (_) {}
        return (res['id'] as num).toInt();
      }
    } catch (e1) {
      debugPrint('Note: insert into terminals table failed ($e1), falling back to users table.');
    }

    // 2. Fallback to users table
    try {
      final map = user.toMap();
      map.remove('id');
      final res = await client.from('users').insert(map).select('id').maybeSingle();
      return (res?['id'] as num?)?.toInt() ?? 1;
    } catch (e) {
      debugPrint('Error insertSubAdmin: $e');
      return 0;
    }
  }

  Future<int> updateSubAdmin(dynamic id, UserModel user) async {
    user.role = 'sub_admin';
    final city = user.terminalCity ?? '';
    final termName = user.terminalName ?? '$city Main Terminal';

    try {
      final terminalRow = {
        'terminal_city': city,
        'terminal_name': termName,
        'manager_first_name': user.firstName,
        'manager_last_name': user.lastName,
        'email': user.email.toLowerCase().trim(),
        'password': user.password.trim(),
        'phone': user.phone.trim(),
        'cnic': user.cnic.trim(),
        'status': user.status,
      };
      await client.from('terminals').update(terminalRow).eq('id', id);
      return 1;
    } catch (_) {}

    try {
      final map = user.toMap();
      map.remove('id');
      await client.from('users').update(map).eq('id', id);
      return 1;
    } catch (e) {
      debugPrint('Error updateSubAdmin: $e');
      return 0;
    }
  }

  Future<int> toggleSubAdminStatus(dynamic id, String currentStatus) async {
    final newStatus = currentStatus.toLowerCase() == 'active' ? 'suspended' : 'active';
    try {
      await client.from('terminals').update({'status': newStatus}).eq('id', id);
      return 1;
    } catch (_) {}

    try {
      await client.from('users').update({'status': newStatus}).eq('id', id);
      return 1;
    } catch (e) {
      debugPrint('Error toggleSubAdminStatus: $e');
      return 0;
    }
  }

  Future<int> deleteSubAdmin(dynamic id) async {
    try {
      await client.from('terminals').delete().eq('id', id);
      return 1;
    } catch (_) {}

    try {
      await client.from('users').delete().match({'id': id, 'role': 'sub_admin'});
      return 1;
    } catch (e) {
      debugPrint('Error deleteSubAdmin: $e');
      return 0;
    }
  }

  // ============================================================
  // DRIVERS & FLEET CAPTAINS (DEDICATED DRIVERS TABLE)
  // ============================================================
  Future<List<Map<String, dynamic>>> getDrivers() async {
    try {
      try {
        final res = await client.from('drivers').select().order('id', ascending: true);
        if (res is List && res.isNotEmpty) {
          return res.map<Map<String, dynamic>>((row) => _normalizeUserMap(row)).toList();
        }
      } catch (e1) {
        debugPrint('Note: drivers table fetch skipped: $e1');
      }

      // Fallback to users table
      final resUsers = await client.from('users').select().eq('role', 'driver').order('id', ascending: true);
      return (resUsers as List).map<Map<String, dynamic>>((row) => _normalizeUserMap(row)).toList();
    } catch (e) {
      debugPrint('Error getDrivers: $e');
      return [];
    }
  }

  Future<int> insertDriver(Map<String, dynamic> driverData) async {
    final cleanEmail = (driverData['email'] ?? '').toString().trim().toLowerCase();
    final fName = driverData['first_name'] ?? driverData['firstName'] ?? '';
    final lName = driverData['last_name'] ?? driverData['lastName'] ?? '';
    final pass = driverData['password'] ?? '';
    final phone = driverData['phone'] ?? '';
    final cnic = driverData['cnic'] ?? '';
    final license = driverData['license_no'] ?? driverData['licenseNo'] ?? driverData['region'] ?? '';
    final busId = driverData['assigned_bus_id'] ?? driverData['assignedBusId'] ?? driverData['street'] ?? '';
    final busNum = driverData['assigned_bus_number'] ?? driverData['assignedBusNumber'] ?? driverData['zip'] ?? '';
    final route = driverData['assigned_route'] ?? driverData['assignedRoute'] ?? driverData['city'] ?? '';
    final status = driverData['status'] ?? 'active';

    // 1. Dedicated drivers table
    try {
      final driverRow = {
        'first_name': fName,
        'last_name': lName,
        'email': cleanEmail,
        'password': pass,
        'phone': phone,
        'cnic': cnic,
        'status': status,
        'license_no': license,
        'assigned_bus_id': busId.toString(),
        'assigned_bus_number': busNum.toString(),
        'assigned_route': route.toString(),
      };
      final res = await client.from('drivers').insert(driverRow).select('id').maybeSingle();
      if (res != null && res['id'] != null) {
        return (res['id'] as num).toInt();
      }
      return 1;
    } catch (e1) {
      debugPrint('Error inserting into drivers table: $e1');
      rethrow;
    }
  }

  Future<int> updateDriver(dynamic id, Map<String, dynamic> driverData) async {
    final cleanEmail = (driverData['email'] ?? '').toString().trim().toLowerCase();
    final fName = driverData['first_name'] ?? driverData['firstName'] ?? '';
    final lName = driverData['last_name'] ?? driverData['lastName'] ?? '';
    final pass = driverData['password'] ?? '';
    final phone = driverData['phone'] ?? '';
    final cnic = driverData['cnic'] ?? '';
    final license = driverData['license_no'] ?? driverData['licenseNo'] ?? driverData['region'] ?? '';
    final busId = driverData['assigned_bus_id'] ?? driverData['assignedBusId'] ?? driverData['street'] ?? '';
    final busNum = driverData['assigned_bus_number'] ?? driverData['assignedBusNumber'] ?? driverData['zip'] ?? '';
    final route = driverData['assigned_route'] ?? driverData['assignedRoute'] ?? driverData['city'] ?? '';
    final status = driverData['status'] ?? 'active';

    try {
      final driverRow = {
        'first_name': fName,
        'last_name': lName,
        'email': cleanEmail,
        'password': pass,
        'phone': phone,
        'cnic': cnic,
        'status': status,
        'license_no': license,
        'assigned_bus_id': busId.toString(),
        'assigned_bus_number': busNum.toString(),
        'assigned_route': route.toString(),
      };
      await client.from('drivers').update(driverRow).eq('id', id);
      return 1;
    } catch (_) {}

    try {
      final userRow = {
        'firstName': fName,
        'lastName': lName,
        'email': cleanEmail,
        'password': pass,
        'phone': phone,
        'cnic': cnic,
        'role': 'driver',
        'status': status,
        'region': license,
        'street': busId.toString(),
        'zip': busNum.toString(),
        'city': route.toString(),
      };
      await client.from('users').update(userRow).eq('id', id);
      return 1;
    } catch (e) {
      debugPrint('Error updateDriver: $e');
      return 0;
    }
  }

  Future<int> toggleDriverStatus(dynamic id, String currentStatus) async {
    try {
      final newStatus = currentStatus.toLowerCase() == 'active' ? 'suspended' : 'active';
      try {
        await client.from('drivers').update({'status': newStatus}).eq('id', id);
        return 1;
      } catch (_) {}
      await client.from('users').update({'status': newStatus}).eq('id', id);
      return 1;
    } catch (e) {
      debugPrint('Error toggleDriverStatus: $e');
      return 0;
    }
  }

  Future<int> deleteDriver(dynamic id) async {
    try {
      try {
        await client.from('drivers').delete().eq('id', id);
        return 1;
      } catch (_) {}
      await client.from('users').delete().match({'id': id, 'role': 'driver'});
      return 1;
    } catch (e) {
      debugPrint('Error deleteDriver: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getTripPassengers({required int busId, String? date}) async {
    try {
      dynamic query = client.from('bookings').select('*, users(*)').eq('bus_id', busId);
      if (date != null && date.isNotEmpty) {
        query = query.or('booking_date.ilike.%$date%,bookingDate.ilike.%$date%');
      }
      final res = await query.order('seat_number', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // TERMINAL AGENTS & COUNTER SHIFTS
  // ============================================================
  Future<List<Map<String, dynamic>>> getTerminalAgents({String? terminalCity}) async {
    return await getTerminalAgentsFromCloud(terminalCity);
  }

  Future<List<Map<String, dynamic>>> getTerminalAgentsFromCloud(String? terminalCity) async {
    try {
      dynamic query = client.from('terminal_agents').select().eq('status', 'active');
      if (terminalCity != null && terminalCity.isNotEmpty && terminalCity.toLowerCase() != 'all') {
        try {
          final response = await query.ilike('terminal_city', '%$terminalCity%').order('id', ascending: true);
          return List<Map<String, dynamic>>.from(response);
        } catch (_) {
          final response = await query.ilike('terminalCity', '%$terminalCity%').order('id', ascending: true);
          return List<Map<String, dynamic>>.from(response);
        }
      }
      final response = await query.order('id', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<int> addTerminalAgent({
    required String agentCode,
    required String name,
    required String pin,
    required String phone,
    required String terminalCity,
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      try {
        final res = await client.from('terminal_agents').insert({
          'agent_code': agentCode,
          'name': name,
          'pin': pin,
          'phone': phone,
          'terminal_city': terminalCity,
          'status': 'active',
          'created_at': nowIso,
        }).select('id').maybeSingle();
        return (res?['id'] as num?)?.toInt() ?? 1;
      } catch (_) {
        final res = await client.from('terminal_agents').insert({
          'agentCode': agentCode,
          'name': name,
          'pin': pin,
          'phone': phone,
          'terminalCity': terminalCity,
          'status': 'active',
          'createdAt': nowIso,
        }).select('id').maybeSingle();
        return (res?['id'] as num?)?.toInt() ?? 1;
      }
    } catch (e) {
      debugPrint('Error addTerminalAgent: $e');
      return 0;
    }
  }

  Future<int> updateTerminalAgent({
    required dynamic agentId,
    required String name,
    required String pin,
    required String phone,
  }) async {
    try {
      await client.from('terminal_agents').update({
        'name': name,
        'pin': pin,
        'phone': phone,
      }).eq('id', agentId);
      return 1;
    } catch (e) {
      debugPrint('Error updateTerminalAgent: $e');
      return 0;
    }
  }

  Future<int> deleteTerminalAgent(dynamic agentId, {String? agentCode}) async {
    try {
      if (agentId != null && agentId != 0) {
        await client.from('terminal_agents').delete().eq('id', agentId);
      } else if (agentCode != null && agentCode.isNotEmpty) {
        try {
          await client.from('terminal_agents').delete().eq('agent_code', agentCode);
        } catch (_) {
          await client.from('terminal_agents').delete().eq('agentCode', agentCode);
        }
      }
      return 1;
    } catch (e) {
      debugPrint('Error deleteTerminalAgent: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> verifyAgentPin(dynamic agentId, String pin) async {
    try {
      final res = await client
          .from('terminal_agents')
          .select()
          .eq('id', agentId)
          .eq('pin', pin)
          .eq('status', 'active')
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error verifying agent pin: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getActiveShift(String terminalCity) async {
    try {
      dynamic query = client.from('counter_shifts').select().eq('status', 'active');
      if (terminalCity.isNotEmpty && terminalCity.toLowerCase() != 'all') {
        try {
          return await query.ilike('terminal_city', '%$terminalCity%').order('id', ascending: false).maybeSingle();
        } catch (_) {
          return await query.ilike('terminalCity', '%$terminalCity%').order('id', ascending: false).maybeSingle();
        }
      }
      return await query.order('id', ascending: false).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<int> startShift({
    required dynamic agentId,
    required String agentName,
    required String agentCode,
    required String shiftType,
    required double openingFloat,
    required String terminalCity,
    required String terminalName,
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      try {
        await client
            .from('counter_shifts')
            .update({'status': 'closed', 'closing_time': nowIso})
            .eq('status', 'active')
            .ilike('terminal_city', '%$terminalCity%');
      } catch (_) {}

      try {
        final res = await client.from('counter_shifts').insert({
          'terminal_city': terminalCity,
          'terminal_name': terminalName,
          'agent_id': agentId,
          'agent_name': agentName,
          'agent_code': agentCode,
          'shift_type': shiftType,
          'opening_time': nowIso,
          'opening_float': openingFloat,
          'cash_sales': 0.0,
          'digital_sales': 0.0,
          'closing_cash': 0.0,
          'tickets_count': 0,
          'status': 'active',
          'handover_pin_verified': 1,
        }).select('id').maybeSingle();

        return (res?['id'] as num?)?.toInt() ?? 1;
      } catch (_) {
        final res = await client.from('counter_shifts').insert({
          'terminalCity': terminalCity,
          'terminalName': terminalName,
          'agentId': agentId,
          'agentName': agentName,
          'agentCode': agentCode,
          'shiftType': shiftType,
          'openingTime': nowIso,
          'openingFloat': openingFloat,
          'cashSales': 0.0,
          'digitalSales': 0.0,
          'closingCash': 0.0,
          'ticketsCount': 0,
          'status': 'active',
          'handoverPinVerified': 1,
        }).select('id').maybeSingle();

        return (res?['id'] as num?)?.toInt() ?? 1;
      }
    } catch (e) {
      debugPrint('Error startShift: $e');
      return 0;
    }
  }

  Future<bool> closeAndHandoverShift({
    required dynamic currentShiftId,
    required double closingCash,
    required double cashSales,
    required double digitalSales,
    required int ticketsCount,
    required dynamic nextAgentId,
    required String nextAgentName,
    required String nextAgentCode,
    required String nextShiftType,
    required double nextOpeningFloat,
    required String terminalCity,
    required String terminalName,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      try {
        await client.from('counter_shifts').update({
          'status': 'closed',
          'closing_time': now,
          'closing_cash': closingCash,
          'cash_sales': cashSales,
          'digital_sales': digitalSales,
          'tickets_count': ticketsCount,
        }).eq('id', currentShiftId);

        await client.from('counter_shifts').insert({
          'terminal_city': terminalCity,
          'terminal_name': terminalName,
          'agent_id': nextAgentId,
          'agent_name': nextAgentName,
          'agent_code': nextAgentCode,
          'shift_type': nextShiftType,
          'opening_time': now,
          'opening_float': nextOpeningFloat,
          'cash_sales': 0.0,
          'digital_sales': 0.0,
          'closing_cash': 0.0,
          'tickets_count': 0,
          'status': 'active',
          'handover_pin_verified': 1,
        });
      } catch (_) {
        await client.from('counter_shifts').update({
          'status': 'closed',
          'closingTime': now,
          'closingCash': closingCash,
          'cashSales': cashSales,
          'digitalSales': digitalSales,
          'ticketsCount': ticketsCount,
        }).eq('id', currentShiftId);

        await client.from('counter_shifts').insert({
          'terminalCity': terminalCity,
          'terminalName': terminalName,
          'agentId': nextAgentId,
          'agentName': nextAgentName,
          'agentCode': nextAgentCode,
          'shiftType': nextShiftType,
          'openingTime': now,
          'openingFloat': nextOpeningFloat,
          'cashSales': 0.0,
          'digitalSales': 0.0,
          'closingCash': 0.0,
          'ticketsCount': 0,
          'status': 'active',
          'handoverPinVerified': 1,
        });
      }

      return true;
    } catch (e) {
      debugPrint('Error closeAndHandoverShift: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getShiftHistory(String terminalCity) async {
    try {
      dynamic query = client.from('counter_shifts').select();
      if (terminalCity.isNotEmpty && terminalCity.toLowerCase() != 'all') {
        try {
          final res = await query.ilike('terminal_city', '%$terminalCity%').order('id', ascending: false).limit(30);
          return List<Map<String, dynamic>>.from(res);
        } catch (_) {
          final res = await query.ilike('terminalCity', '%$terminalCity%').order('id', ascending: false).limit(30);
          return List<Map<String, dynamic>>.from(res);
        }
      }
      final res = await query.order('id', ascending: false).limit(30);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // STATS (ADMIN & SUB-ADMIN)
  // ============================================================
  Future<Map<String, dynamic>> getAdminStats() async {
    int totalBuses = 0;
    int totalRoutes = 0;
    int totalUsers = 0;
    int totalSubAdmins = 0;
    int totalBookings = 0;
    int todayBookings = 0;
    double totalRevenue = 0.0;
    int totalComplaints = 0;
    int totalFeedbacks = 0;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    // 1. Buses count
    try {
      final busesRes = await client.from('buses').select('id');
      totalBuses = (busesRes as List).length;
    } catch (_) {}

    // 2. Routes count
    try {
      final routesRes = await client.from('routes').select('id');
      totalRoutes = (routesRes as List).length;
    } catch (_) {
      // Fallback: Calculate unique routes directly from buses table
      try {
        final busRoutes = await client.from('buses').select('from_city, to_city');
        final Set<String> uniqueRoutes = {};
        for (var b in busRoutes as List) {
          final f = (b['from_city'] ?? '').toString().trim();
          final t = (b['to_city'] ?? '').toString().trim();
          if (f.isNotEmpty && t.isNotEmpty) {
            uniqueRoutes.add('$f->$t');
          }
        }
        totalRoutes = uniqueRoutes.length;
      } catch (_) {
        try {
          final busRoutes = await client.from('buses').select('fromCity, toCity');
          final Set<String> uniqueRoutes = {};
          for (var b in busRoutes as List) {
            final f = (b['fromCity'] ?? '').toString().trim();
            final t = (b['toCity'] ?? '').toString().trim();
            if (f.isNotEmpty && t.isNotEmpty) {
              uniqueRoutes.add('$f->$t');
            }
          }
          totalRoutes = uniqueRoutes.length;
        } catch (_) {}
      }
    }

    // 3. Users & Sub-Admins count
    try {
      final usersRes = await client.from('users').select('id, role');
      totalUsers = (usersRes as List).length;
      totalSubAdmins = (usersRes).where((u) => (u['role'] ?? '').toString().toLowerCase() == 'sub_admin').length;
    } catch (e) {
      try {
        final usersRes = await client.from('users').select('id');
        totalUsers = (usersRes as List).length;
      } catch (e2) {
        debugPrint('Note: Error fetching users count: $e2');
      }
    }

    // 4. Bookings count & Today Bookings
    try {
      dynamic bookingsRes;
      try {
        bookingsRes = await client.from('bookings').select('id, booking_date');
      } catch (_) {
        try {
          bookingsRes = await client.from('bookings').select('id, bookingDate');
        } catch (_) {
          bookingsRes = await client.from('bookings').select('id');
        }
      }
      if (bookingsRes is List) {
        totalBookings += bookingsRes.length;
        for (var b in bookingsRes) {
          final d = (b['booking_date'] ?? b['bookingDate'] ?? '').toString();
          if (d.startsWith(todayStr)) todayBookings++;
        }
      }
    } catch (e) {
      debugPrint('Note: Error fetching bookings count: $e');
    }

    // Also add terminal_bookings if present
    try {
      final tBookingsRes = await client.from('terminal_bookings').select('id, booking_date, fare');
      if (tBookingsRes is List) {
        totalBookings += tBookingsRes.length;
        for (var tb in tBookingsRes) {
          final d = (tb['booking_date'] ?? tb['bookingDate'] ?? '').toString();
          if (d.startsWith(todayStr)) todayBookings++;
          totalRevenue += (tb['fare'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {}

    // 5. Payments / Revenue
    try {
      final paymentsRes = await client.from('payments').select('amount');
      if (paymentsRes is List) {
        for (var p in paymentsRes) {
          totalRevenue += (p['amount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (e) {
      debugPrint('Note: Error fetching payments revenue: $e');
    }

    // 6. Complaints count
    try {
      final complainsRes = await client.from('complain').select('id');
      totalComplaints = (complainsRes as List).length;
    } catch (_) {}

    // 7. Feedbacks count
    try {
      final feedbackRes = await client.from('feedback').select('id');
      totalFeedbacks = (feedbackRes as List).length;
    } catch (_) {}

    return {
      'totalBuses': totalBuses,
      'totalRoutes': totalRoutes,
      'totalUsers': totalUsers,
      'totalSubAdmins': totalSubAdmins,
      'totalBookings': totalBookings,
      'totalComplaints': totalComplaints,
      'totalFeedbacks': totalFeedbacks,
      'todayBookings': todayBookings,
      'totalRevenue': totalRevenue,
    };
  }

  Future<Map<String, dynamic>> getSubAdminStats(String terminalCity) async {
    try {
      final cityTrimmed = terminalCity.trim().toLowerCase();
      final buses = await getAllBuses();
      final terminalBuses = buses.where((b) {
        final from = (b['fromCity'] ?? b['from_city'] ?? '').toString().trim().toLowerCase();
        return cityTrimmed.isEmpty || cityTrimmed == 'all' || from.contains(cityTrimmed);
      }).toList();

      final bookings = await getTerminalBookings(terminalCity: terminalCity);
      final todayStr = DateTime.now().toIso8601String().split('T')[0];

      int todayBookings = 0;
      double totalRevenue = 0.0;
      double todayRevenue = 0.0;

      for (var b in bookings) {
        final fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
        final d = (b['booking_date'] ?? b['bookingDate'] ?? b['createdAt'] ?? '').toString();
        totalRevenue += fare;
        if (d.startsWith(todayStr)) {
          todayBookings++;
          todayRevenue += fare;
        }
      }

      return {
        'totalBuses': terminalBuses.length,
        'todayBuses': terminalBuses.length,
        'todayBusesList': terminalBuses,
        'totalBookings': bookings.length,
        'todayBookings': todayBookings > 0 ? todayBookings : bookings.length,
        'recentBookings': bookings.take(10).toList(),
        'totalRevenue': totalRevenue,
        'todayRevenue': todayRevenue > 0 ? todayRevenue : totalRevenue,
      };
    } catch (e) {
      debugPrint('Error getSubAdminStats: $e');
      return {
        'totalBuses': 0,
        'todayBuses': 0,
        'todayBusesList': [],
        'totalBookings': 0,
        'todayBookings': 0,
        'recentBookings': [],
        'totalRevenue': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> getAllTerminalsLiveStats() async {
    try {
      final subAdmins = await getSubAdmins();
      dynamic allShifts = [];
      try {
        allShifts = await client.from('counter_shifts').select().order('id', ascending: false);
      } catch (_) {}

      dynamic allBookings = [];
      try {
        allBookings = await client.from('terminal_bookings').select().order('id', ascending: false);
      } catch (_) {}

      dynamic allAgents = [];
      try {
        allAgents = await client.from('terminal_agents').select().eq('status', 'active');
      } catch (_) {}

      final todayStr = DateTime.now().toIso8601String().split('T')[0];

      final Map<String, Map<String, dynamic>> terminalMap = {};

      for (var sub in subAdmins) {
        final city = (sub['terminalCity'] ?? sub['terminal_city'] ?? '').toString().trim();
        if (city.isNotEmpty) {
          terminalMap[city.toLowerCase()] = {
            'city': city,
            'terminalName': sub['terminalName'] ?? sub['terminal_name'] ?? '$city Main Terminal',
            'subAdmin': sub,
          };
        }
      }

      // Also include any terminals that have real active/past shifts or agents even if no manager is assigned
      for (var s in (allShifts as List)) {
        final c = (s['terminal_city'] ?? s['terminalCity'] ?? '').toString().trim();
        if (c.isNotEmpty && !terminalMap.containsKey(c.toLowerCase())) {
          terminalMap[c.toLowerCase()] = {
            'city': c,
            'terminalName': s['terminal_name'] ?? s['terminalName'] ?? '$c Terminal',
            'subAdmin': null,
          };
        }
      }

      for (var a in (allAgents as List)) {
        final c = (a['terminal_city'] ?? a['terminalCity'] ?? '').toString().trim();
        if (c.isNotEmpty && !terminalMap.containsKey(c.toLowerCase())) {
          terminalMap[c.toLowerCase()] = {
            'city': c,
            'terminalName': '$c Terminal',
            'subAdmin': null,
          };
        }
      }

      int overallActiveShifts = 0;
      int overallTodayBookings = 0;
      double overallTodayRevenue = 0.0;
      double overallDrawerCash = 0.0;

      final List<Map<String, dynamic>> terminalList = [];

      for (var entry in terminalMap.entries) {
        final cityKey = entry.key;
        final displayCity = entry.value['city'] as String;
        final terminalName = entry.value['terminalName'] as String;
        final subAdmin = entry.value['subAdmin'] as Map<String, dynamic>?;

        final activeShift = (allShifts).firstWhere(
          (s) {
            final c = (s['terminal_city'] ?? s['terminalCity'] ?? '').toString().toLowerCase();
            return c == cityKey && s['status'] == 'active';
          },
          orElse: () => null,
        );

        final isShiftActive = activeShift != null;
        if (isShiftActive) overallActiveShifts++;

        final tBookings = (allBookings).where(
          (b) {
            final c = (b['terminal_city'] ?? b['terminalCity'] ?? '').toString().toLowerCase();
            return c == cityKey;
          },
        ).toList();

        int todayBookings = 0;
        double todayRevenue = 0.0;
        double shiftCash = 0.0;
        double shiftDigital = 0.0;

        for (var tb in tBookings) {
          final fare = (tb['fare'] as num?)?.toDouble() ?? 0.0;
          final method = (tb['payment_method'] ?? tb['paymentMethod'] ?? '').toString().toLowerCase();
          final bDate = (tb['booking_date'] ?? tb['bookingDate'] ?? '').toString();
          if (bDate.startsWith(todayStr) || tBookings.length <= 5) {
            todayBookings++;
            todayRevenue += fare;
            if (method.contains('cash') || method.isEmpty) {
              shiftCash += fare;
            } else {
              shiftDigital += fare;
            }
          }
        }

        final double openingFloat = (activeShift?['opening_float'] ?? activeShift?['openingFloat'] as num?)?.toDouble() ?? 0.0;
        final double netDrawerCash = openingFloat + shiftCash;
        if (isShiftActive) overallDrawerCash += netDrawerCash;
        overallTodayBookings += todayBookings;
        overallTodayRevenue += todayRevenue;

        final agentCount = (allAgents).where((a) {
          final c = (a['terminal_city'] ?? a['terminalCity'] ?? '').toString().toLowerCase();
          return c == cityKey;
        }).length;

        terminalList.add({
          'city': displayCity,
          'cityKey': cityKey,
          'terminalName': terminalName,
          'subAdmin': subAdmin,
          'managerName': subAdmin != null ? "${subAdmin['first_name'] ?? subAdmin['firstName'] ?? ''} ${subAdmin['last_name'] ?? subAdmin['lastName'] ?? ''}".trim() : "Unassigned",
          'managerPhone': subAdmin?['phone'] ?? '',
          'managerStatus': subAdmin?['status'] ?? 'inactive',
          'isShiftActive': isShiftActive,
          'activeShift': activeShift,
          'dutyAgentName': activeShift?['agent_name'] ?? activeShift?['agentName'] ?? '',
          'dutyAgentCode': activeShift?['agent_code'] ?? activeShift?['agentCode'] ?? '',
          'shiftType': activeShift?['shift_type'] ?? activeShift?['shiftType'] ?? '',
          'shiftOpeningTime': activeShift?['opening_time'] ?? activeShift?['openingTime'] ?? '',
          'openingFloat': openingFloat,
          'shiftCashSales': shiftCash,
          'shiftDigitalSales': shiftDigital,
          'shiftBookingsCount': todayBookings,
          'netDrawerCash': netDrawerCash,
          'todayBookings': todayBookings,
          'todayRevenue': todayRevenue,
          'todayCash': shiftCash,
          'todayDigital': shiftDigital,
          'registeredAgentsCount': agentCount,
          'scheduledBusesToday': 4,
          'recentBookingsCount': tBookings.length,
        });
      }

      terminalList.sort((a, b) {
        if (a['isShiftActive'] != b['isShiftActive']) {
          return (b['isShiftActive'] as bool) ? 1 : -1;
        }
        return (b['todayRevenue'] as num).compareTo(a['todayRevenue'] as num);
      });

      return {
        'totalTerminals': terminalList.length,
        'activeShiftsCount': overallActiveShifts,
        'todayBookingsCount': overallTodayBookings,
        'todayTotalRevenue': overallTodayRevenue,
        'overallDrawerCash': overallDrawerCash,
        'terminals': terminalList,
      };
    } catch (e) {
      debugPrint('Error getAllTerminalsLiveStats: $e');
      return {
        'totalTerminals': 0,
        'activeShiftsCount': 0,
        'todayBookingsCount': 0,
        'todayTotalRevenue': 0.0,
        'overallDrawerCash': 0.0,
        'terminals': [],
      };
    }
  }

  Future<Map<String, dynamic>> getTerminalLiveDeepDive(String terminalCity) async {
    final cityTrimmed = terminalCity.trim().toLowerCase();
    final subAdmin = (await getSubAdmins()).where((s) {
      final c = (s['terminal_city'] ?? s['terminalCity'] ?? '').toString().toLowerCase();
      return c == cityTrimmed;
    }).firstOrNull;

    final activeShift = await getActiveShift(terminalCity);
    final agents = await getTerminalAgents(terminalCity: terminalCity);
    final history = await getShiftHistory(terminalCity);
    final bookings = await getTerminalBookings(terminalCity: terminalCity);
    final allBuses = (await getAllBuses()).where((b) {
      final c = (b['fromCity'] ?? b['from_city'] ?? '').toString().toLowerCase();
      return c.contains(cityTrimmed);
    }).toList();

    double shiftCash = 0.0;
    double shiftDigital = 0.0;
    double todayRevenue = 0.0;
    for (var b in bookings) {
      final fare = (b['fare'] as num?)?.toDouble() ?? 0.0;
      final method = (b['payment_method'] ?? b['paymentMethod'] ?? '').toString().toLowerCase();
      todayRevenue += fare;
      if (method.contains('cash') || method.isEmpty) {
        shiftCash += fare;
      } else {
        shiftDigital += fare;
      }
    }

    final double openingFloat = (activeShift?['opening_float'] ?? activeShift?['openingFloat'] as num?)?.toDouble() ?? 0.0;

    return {
      'terminalCity': terminalCity,
      'terminalName': subAdmin?['terminal_name'] ?? subAdmin?['terminalName'] ?? activeShift?['terminal_name'] ?? activeShift?['terminalName'] ?? "$terminalCity Main Terminal",
      'subAdmin': subAdmin,
      'activeShift': activeShift,
      'isShiftActive': activeShift != null,
      'openingFloat': openingFloat,
      'shiftCash': shiftCash,
      'shiftDigital': shiftDigital,
      'shiftBookingsCount': bookings.length,
      'netDrawerCash': openingFloat + shiftCash,
      'todayRevenue': todayRevenue,
      'todayCash': shiftCash,
      'todayDigital': shiftDigital,
      'totalBookingsCount': bookings.length,
      'bookings': bookings,
      'agents': agents,
      'departingBuses': allBuses,
      'shiftHistory': history,
    };
  }

  // ============================================================
  // NOTIFICATIONS, FEEDBACK, COMPLAINTS
  // ============================================================
  Future<int> insertNotification({
    dynamic userId,
    String? userEmail,
    required String title,
    required String body,
    String type = 'system',
    String? routeFrom,
    String? routeTo,
    String? dataJson,
  }) async {
    try {
      final res = await client.from('notifications').insert({
        'user_id': userId ?? 0,
        'user_email': userEmail ?? '',
        'title': title,
        'body': body,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
        'route_from': routeFrom ?? '',
        'route_to': routeTo ?? '',
        'data_json': dataJson ?? '',
      }).select('id').maybeSingle();
      return (res?['id'] as num?)?.toInt() ?? 1;
    } catch (_) {
      try {
        final res = await client.from('notifications').insert({
          'userId': userId ?? 0,
          'userEmail': userEmail ?? '',
          'title': title,
          'body': body,
          'type': type,
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': 0,
          'routeFrom': routeFrom ?? '',
          'routeTo': routeTo ?? '',
          'dataJson': dataJson ?? '',
        }).select('id').maybeSingle();
        return (res?['id'] as num?)?.toInt() ?? 1;
      } catch (_) {
        return 0;
      }
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications({
    dynamic userId,
    String? userEmail,
    String? typeFilter,
  }) async {
    try {
      dynamic query = client.from('notifications').select();
      if (userId is int && userId > 0) {
        query = query.or('user_id.eq.$userId,userId.eq.$userId');
      } else if (userEmail != null && userEmail.isNotEmpty) {
        query = query.or('user_email.eq.$userEmail,userEmail.eq.$userEmail');
      }
      if (typeFilter != null && typeFilter.isNotEmpty && typeFilter.toLowerCase() != 'all') {
        query = query.eq('type', typeFilter);
      }
      final res = await query.order('id', ascending: false).limit(50);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(dynamic userIdOrEmail) async {
    return await getNotifications(
      userId: userIdOrEmail is int ? userIdOrEmail : null,
      userEmail: userIdOrEmail is String ? userIdOrEmail : null,
    );
  }

  Future<int> getUnreadNotificationsCount({dynamic userId, String? userEmail}) async {
    try {
      dynamic query = client.from('notifications').select('id');
      try {
        query = query.eq('is_read', 0);
      } catch (_) {
        query = query.eq('isRead', 0);
      }
      final res = await query;
      return (res as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> markNotificationAsRead(dynamic id) async {
    try {
      try {
        await client.from('notifications').update({'is_read': 1}).eq('id', id);
      } catch (_) {
        await client.from('notifications').update({'isRead': 1}).eq('id', id);
      }
      return 1;
    } catch (_) {
      return 0;
    }
  }

  Future<int> markAllNotificationsAsRead({dynamic userId, String? userEmail}) async {
    try {
      try {
        await client.from('notifications').update({'is_read': 1});
      } catch (_) {
        await client.from('notifications').update({'isRead': 1});
      }
      return 1;
    } catch (_) {
      return 0;
    }
  }

  Future<int> deleteNotification(dynamic id) async {
    try {
      await client.from('notifications').delete().eq('id', id);
      return 1;
    } catch (_) {
      return 0;
    }
  }

  Future<int> clearAllNotifications({dynamic userId, String? userEmail}) async {
    try {
      await client.from('notifications').delete();
      return 1;
    } catch (_) {
      return 0;
    }
  }

  Future<int> insertFeedback({
    dynamic userId,
    required String message,
    String? userEmail,
  }) async {
    try {
      final res = await client.from('feedback').insert({
        'user_email': userEmail ?? '',
        'message': message,
        'date': DateTime.now().toIso8601String().split('T')[0],
      }).select('id').maybeSingle();
      return (res?['id'] as num?)?.toInt() ?? 1;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getFeedbacks() async {
    try {
      final res = await client.from('feedback').select().order('id', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllFeedbacks() async => await getFeedbacks();

  Future<int> insertComplain({
    dynamic userId,
    required String message,
    String? userEmail,
  }) async {
    try {
      final res = await client.from('complain').insert({
        'user_email': userEmail ?? '',
        'message': message,
        'date': DateTime.now().toIso8601String().split('T')[0],
      }).select('id').maybeSingle();
      return (res?['id'] as num?)?.toInt() ?? 1;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getComplains() async {
    try {
      final res = await client.from('complain').select().order('id', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllComplains() async => await getComplains();

  Future<bool> addFeedback(String userEmail, String message) async {
    await insertFeedback(userId: 0, message: message, userEmail: userEmail);
    return true;
  }

  Future<bool> addComplain(String userEmail, String message) async {
    await insertComplain(userId: 0, message: message, userEmail: userEmail);
    return true;
  }

  Future<Map<String, dynamic>?> getUserProfile(String firebaseUid) async {
    try {
      final res = await client.from('users').select().eq('firebase_uid', firebaseUid).maybeSingle();
      if (res != null) {
        return _normalizeUserMap(res);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> upsertUserProfile({
    required String firebaseUid,
    required String email,
    String? firstName,
    String? lastName,
    String? phone,
    String? cnic,
    String? gender,
    String? street,
    String? city,
    String? region,
    String? zip,
  }) async {
    try {
      await client.from('users').upsert({
        'firebase_uid': firebaseUid,
        'email': email.trim().toLowerCase(),
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null) 'phone': phone,
        if (cnic != null) 'cnic': cnic,
        if (gender != null) 'gender': gender,
        if (street != null) 'street': street,
        if (city != null) 'city': city,
        if (region != null) 'region': region,
        if (zip != null) 'zip': zip,
      }, onConflict: 'firebase_uid');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // LIVE GPS & FLEET RADAR
  // ============================================================
  Future<bool> updateBusLocation({
    required int busId,
    required double latitude,
    required double longitude,
    double speed = 0.0,
    double heading = 0.0,
    String? nextStop,
    int? etaMinutes,
    String status = 'in_transit',
  }) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      await client.from('bus_locations').upsert({
        'bus_id': busId,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed,
        'heading': heading,
        'next_stop': nextStop ?? '',
        'eta_minutes': etaMinutes ?? 0,
        'status': status,
        'last_updated': nowIso,
      }, onConflict: 'bus_id');
      return true;
    } catch (e) {
      debugPrint('Note: updateBusLocation in Supabase: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getBusLiveLocation(int busId) async {
    try {
      final res = await client
          .from('bus_locations')
          .select()
          .eq('bus_id', busId)
          .maybeSingle();
      return res;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllActiveBusLocations() async {
    try {
      final res = await client
          .from('bus_locations')
          .select('*, buses(*)');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      return [];
    }
  }

  Future<void> ensureAgentAndShiftTables() async {}
  Future<void> ensureTerminalBookingsTable() async {}
  Future<void> ensureUserRoleColumns() async {}
  Future<void> ensureNotificationsTable() async {}
}
