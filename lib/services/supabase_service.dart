import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin/models/bus_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  SupabaseClient get client => Supabase.instance.client;

  // ============================================================
  // BUSES CRUD & SEARCH
  // ============================================================
  Future<List<BusModel>> getBusesByDate(String date) async {
    try {
      final response = await client
          .from('buses')
          .select()
          .eq('date', date)
          .order('time', ascending: true);

      return (response as List).map((e) => BusModel.fromMap(e)).toList();
    } catch (e) {
      print('Error fetching buses from Supabase: $e');
      return [];
    }
  }

  Future<List<BusModel>> searchBuses({
    required String fromCity,
    required String toCity,
    required String date,
    String? busClass,
  }) async {
    try {
      var query = client
          .from('buses')
          .select()
          .ilike('fromCity', '%$fromCity%')
          .ilike('toCity', '%$toCity%')
          .eq('date', date);

      if (busClass != null && busClass != 'All Types') {
        query = query.eq('busClass', busClass);
      }

      final response = await query.order('time', ascending: true);
      return (response as List).map((e) => BusModel.fromMap(e)).toList();
    } catch (e) {
      print('Error searching buses from Supabase: $e');
      return [];
    }
  }

  Future<int?> insertBus(BusModel bus) async {
    try {
      final map = bus.toMap();
      map.remove('id'); // Let PostgreSQL generate identity ID

      final response = await client
          .from('buses')
          .insert(map)
          .select('id')
          .single();
      return response['id'] as int?;
    } catch (e) {
      print('Error inserting bus into Supabase: $e');
      return null;
    }
  }

  Future<bool> updateBus(BusModel bus) async {
    try {
      if (bus.id == null) return false;
      await client.from('buses').update(bus.toMap()).eq('id', bus.id!);
      return true;
    } catch (e) {
      print('Error updating bus in Supabase: $e');
      return false;
    }
  }

  Future<bool> deleteBus(int busId) async {
    try {
      await client.from('buses').delete().eq('id', busId);
      return true;
    } catch (e) {
      print('Error deleting bus from Supabase: $e');
      return false;
    }
  }

  // ============================================================
  // REAL-TIME SEAT BOOKINGS & LIVE STREAM
  // ============================================================
  Future<List<Map<String, dynamic>>> getBookedSeats(int busId) async {
    try {
      final response = await client
          .from('bookings')
          .select('seat_number, gender, status')
          .eq('bus_id', busId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching booked seats: $e');
      return [];
    }
  }

  /// Realtime Stream for Seat Bookings (Multi-device live sync)
  Stream<List<Map<String, dynamic>>> streamBookedSeats(int busId) {
    return client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('bus_id', busId);
  }

  Future<bool> createBooking({
    required String firebaseUid,
    required String userEmail,
    required int busId,
    required List<int> seatNumbers,
    required Map<int, String> seatGenders,
    required String bookingDate,
  }) async {
    try {
      final rows = seatNumbers.map((seat) {
        return {
          'firebase_uid': firebaseUid,
          'user_email': userEmail,
          'bus_id': busId,
          'seat_number': seat,
          'gender': seatGenders[seat] ?? 'M',
          'booking_date': bookingDate,
          'status': 'Confirmed',
        };
      }).toList();

      await client.from('bookings').insert(rows);
      return true;
    } catch (e) {
      print('Error creating booking: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserBookings(String firebaseUid) async {
    try {
      final response = await client
          .from('bookings')
          .select('*, buses(*)')
          .eq('firebase_uid', firebaseUid)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user bookings: $e');
      return [];
    }
  }

  // ============================================================
  // PAYMENTS
  // ============================================================
  Future<bool> insertPayment({
    required int busId,
    required String seats,
    required double amount,
    required String date,
    required String passengerName,
    required String passengerCnic,
    required String passengerPhone,
    required String paymentMethod,
    required String accountNumber,
    required String email,
  }) async {
    try {
      await client.from('payments').insert({
        'bus_id': busId,
        'seats': seats,
        'amount': amount,
        'date': date,
        'passenger_name': passengerName,
        'passenger_cnic': passengerCnic,
        'passenger_phone': passengerPhone,
        'payment_method': paymentMethod,
        'account_number': accountNumber,
        'email': email,
      });
      return true;
    } catch (e) {
      print('Error inserting payment: $e');
      return false;
    }
  }

  // ============================================================
  // FEEDBACK & COMPLAINTS
  // ============================================================
  Future<bool> addFeedback(String userEmail, String message) async {
    try {
      final now = DateTime.now().toIso8601String().split('T')[0];
      await client.from('feedback').insert({
        'user_email': userEmail,
        'message': message,
        'date': now,
      });
      return true;
    } catch (e) {
      print('Error sending feedback: $e');
      return false;
    }
  }

  Future<bool> addComplain(String userEmail, String message) async {
    try {
      final now = DateTime.now().toIso8601String().split('T')[0];
      await client.from('complain').insert({
        'user_email': userEmail,
        'message': message,
        'date': now,
      });
      return true;
    } catch (e) {
      print('Error sending complain: $e');
      return false;
    }
  }

  // ============================================================
  // USER PROFILES
  // ============================================================
  Future<Map<String, dynamic>?> getUserProfile(String firebaseUid) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
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
        'email': email,
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
      print('Error upserting profile: $e');
      return false;
    }
  }
}
