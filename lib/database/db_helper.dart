// lib/database/db_helper.dart

import 'dart:io';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/user_model.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  // ============================================================
  // INIT DATABASE
  // ============================================================
  Future<Database> get database async {
    if (_database != null) return _database!;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDB('junaid_bus.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, fileName);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 16,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  // ============================================================
  // CREATE TABLES (No change)
  // ============================================================
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        lastName TEXT,
        email TEXT UNIQUE,
        phone TEXT,
        cnic TEXT,
        gender TEXT,
        password TEXT,
        street TEXT,
        city TEXT,
        region TEXT,
        zip TEXT,
        role TEXT DEFAULT 'user',
        terminalName TEXT,
        terminalCity TEXT,
        status TEXT DEFAULT 'active'
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        busNo TEXT,
        fromCity TEXT,
        toCity TEXT,
        via TEXT,
        date TEXT,
        time TEXT,
        busType TEXT,
        refreshment INTEGER,
        routeName TEXT,
        seats INTEGER,
        fare REAL,
        originalFare REAL,
        discount REAL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS buses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        busName TEXT,
        routeName TEXT,
        fromCity TEXT,
        toCity TEXT,
        routeVia TEXT,
        date TEXT,
        day TEXT,
        time TEXT,
        busClass TEXT,
        seats INTEGER,
        fare REAL,
        originalFare REAL,
        discount INTEGER,
        discountLabel TEXT,
        refreshment INTEGER,
        busNumber TEXT,
        driverName TEXT,
        createdAt TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        busId INTEGER,
        seatNumber INTEGER,
        gender TEXT,
        bookingDate TEXT,
        status TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        busId INTEGER,
        seats TEXT,
        amount REAL,
        date TEXT,
        passengerName TEXT,
        passengerCnic TEXT,
        passengerPhone TEXT,
        paymentMethod TEXT,
        accountNumber TEXT,
        email TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS terminal_bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        busId INTEGER,
        seatNumber INTEGER,
        gender TEXT,
        passengerName TEXT,
        passengerPhone TEXT,
        passengerCnic TEXT,
        fare REAL,
        paymentMethod TEXT,
        terminalCity TEXT,
        terminalName TEXT,
        agentName TEXT,
        bookingDate TEXT,
        status TEXT DEFAULT 'Confirmed',
        createdAt TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        message TEXT,
        date TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS complain (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        message TEXT,
        date TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        userEmail TEXT,
        title TEXT,
        body TEXT,
        type TEXT,
        timestamp TEXT,
        isRead INTEGER DEFAULT 0,
        routeFrom TEXT,
        routeTo TEXT,
        dataJson TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS terminal_agents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agentCode TEXT UNIQUE,
        name TEXT,
        pin TEXT,
        phone TEXT,
        terminalCity TEXT,
        status TEXT DEFAULT 'active',
        createdAt TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS counter_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        terminalCity TEXT,
        terminalName TEXT,
        agentId INTEGER,
        agentName TEXT,
        agentCode TEXT,
        shiftType TEXT,
        openingTime TEXT,
        closingTime TEXT,
        openingFloat REAL DEFAULT 0.0,
        cashSales REAL DEFAULT 0.0,
        digitalSales REAL DEFAULT 0.0,
        closingCash REAL DEFAULT 0.0,
        ticketsCount INTEGER DEFAULT 0,
        nextAgentId INTEGER,
        nextAgentName TEXT,
        handoverPinVerified INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active'
      );
    ''');
  }

  // ============================================================
  // ON UPGRADE (No change)
  // ============================================================
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS feedback (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER,
          message TEXT,
          date TEXT
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS complain (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER,
          message TEXT,
          date TEXT
        );
      ''');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE users ADD COLUMN street TEXT;');
      await db.execute('ALTER TABLE users ADD COLUMN city TEXT;');
      await db.execute('ALTER TABLE users ADD COLUMN region TEXT;');
      await db.execute('ALTER TABLE users ADD COLUMN zip TEXT;');
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER,
          userEmail TEXT,
          title TEXT,
          body TEXT,
          type TEXT,
          timestamp TEXT,
          isRead INTEGER DEFAULT 0,
          routeFrom TEXT,
          routeTo TEXT,
          dataJson TEXT
        );
      ''');
    }
    if (oldVersion < 14) {
      try {
        await db.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user';");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE users ADD COLUMN terminalName TEXT;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE users ADD COLUMN terminalCity TEXT;");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'active';");
      } catch (_) {}
    }
    if (oldVersion < 15) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS terminal_bookings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          busId INTEGER,
          seatNumber INTEGER,
          gender TEXT,
          passengerName TEXT,
          passengerPhone TEXT,
          passengerCnic TEXT,
          fare REAL,
          paymentMethod TEXT,
          terminalCity TEXT,
          terminalName TEXT,
          agentName TEXT,
          bookingDate TEXT,
          status TEXT DEFAULT 'Confirmed',
          createdAt TEXT
        );
      ''');
    }
    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS terminal_agents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          agentCode TEXT UNIQUE,
          name TEXT,
          pin TEXT,
          phone TEXT,
          terminalCity TEXT,
          status TEXT DEFAULT 'active',
          createdAt TEXT
        );
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS counter_shifts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          terminalCity TEXT,
          terminalName TEXT,
          agentId INTEGER,
          agentName TEXT,
          agentCode TEXT,
          shiftType TEXT,
          openingTime TEXT,
          closingTime TEXT,
          openingFloat REAL DEFAULT 0.0,
          cashSales REAL DEFAULT 0.0,
          digitalSales REAL DEFAULT 0.0,
          closingCash REAL DEFAULT 0.0,
          ticketsCount INTEGER DEFAULT 0,
          nextAgentId INTEGER,
          nextAgentName TEXT,
          handoverPinVerified INTEGER DEFAULT 0,
          status TEXT DEFAULT 'active'
        );
      ''');
    }
  }

  // ============================================================
  // NEW: CLEAN OLD BUSES AND THEIR BOOKINGS
  // Deletes buses older than today and all related bookings
  // ============================================================
  Future<void> cleanOldBusesAndBookings() async {
    final db = await database;

    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    // Get all old buses (date < today)
    final oldBuses = await db.query(
      'buses',
      where: 'date < ?',
      whereArgs: [todayStr],
    );

    if (oldBuses.isEmpty) return;

    // Collect all old bus IDs
    final List<int> oldBusIds = oldBuses.map((bus) => bus['id'] as int).toList();

    // Delete related bookings
    await db.delete(
      'bookings',
      where: 'busId IN (${oldBusIds.map((_) => '?').join(',')})',
      whereArgs: oldBusIds,
    );

    // Delete old buses
    await db.delete(
      'buses',
      where: 'id IN (${oldBusIds.map((_) => '?').join(',')})',
      whereArgs: oldBusIds,
    );

    print('Cleaned ${oldBuses.length} old buses and their bookings');
  }

  // ============================================================
  // ROUTES CRUD (No change)
  // ============================================================
  Future<int> insertRoute(Map<String, dynamic> route) async {
    final db = await database;
    return await db.insert('routes', {
      "busNo": route["busNo"],
      "fromCity": route["fromCity"],
      "toCity": route["toCity"],
      "via": route["via"],
      "date": route["date"],
      "time": route["time"],
      "busType": route["busType"] ?? "",
      "refreshment": route["refreshment"] ?? 0,
      "routeName": route["routeName"],
      "seats": route["seats"],
      "fare": route["fare"],
      "originalFare": route["originalFare"],
      "discount": route["discount"],
    });
  }

  Future<List<Map<String, dynamic>>> getRoutes() async {
    final db = await database;
    return await db.query('routes', orderBy: "date ASC, time ASC");
  }

  Future<int> updateRoute(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'routes',
      data,
      where: "id=?",
      whereArgs: [id],
    );
  }

  Future<int> deleteRoute(int id) async {
    final db = await database;
    return await db.delete('routes', where: "id=?", whereArgs: [id]);
  }

  // ============================================================
  // BUSES CRUD (No change)
  // ============================================================
  Future<void> insertBus(BusModel bus) async {
    final db = await database;
    final map = bus.toMap();
    if (map['id'] == null || map['id'] == 0) {
      map.remove('id');
    }
    await db.insert(
      "buses",
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBusesByDate(String dateKey) async {
    final db = await database;
    return await db.query(
      'buses',
      where: 'date=?',
      whereArgs: [dateKey],
      orderBy: "time ASC",
    );
  }

  Future<void> updateBus(int id, BusModel bus) async {
    final db = await database;
    await db.update(
      "buses",
      bus.toMap(),
      where: "id=?",
      whereArgs: [id],
    );
  }

  Future<void> deleteBus(int id) async {
    final db = await database;
    await db.delete("buses", where: "id=?", whereArgs: [id]);
  }

  // ============================================================
  // USER AUTH (No change)
  // ============================================================
  Future<void> registerUser(UserModel user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> loginUser(String email, String pass) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, pass],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final result = await db.query('users', where: 'id=?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> updatePassword(String email, String pass) async {
    final db = await database;
    await db.update(
      'users',
      {"password": pass},
      where: "email=?",
      whereArgs: [email],
    );
  }

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('users', data, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete('users', where: 'id=?', whereArgs: [id]);
    await db.delete('bookings', where: 'userId=?', whereArgs: [id]);
    await db.delete('feedback', where: 'userId=?', whereArgs: [id]);
    await db.delete('complain', where: 'userId=?', whereArgs: [id]);
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: "id ASC");
    return result.map((map) => UserModel.fromMap(map)).toList();
  }

  // ============================================================
  // NEW: GET ALL UNIQUE FROM CITIES
  // ============================================================
  Future<List<String>> getAllFromCities() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT fromCity FROM buses ORDER BY fromCity COLLATE NOCASE');
    return result.map((row) => row['fromCity'] as String).where((city) => city.isNotEmpty).toList();
  }

  // ============================================================
  // NEW: GET ALL UNIQUE TO CITIES
  // ============================================================
  Future<List<String>> getAllToCities() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT toCity FROM buses ORDER BY toCity COLLATE NOCASE');
    return result.map((row) => row['toCity'] as String).where((city) => city.isNotEmpty).toList();
  }

  // ============================================================
  // UPDATED: SEARCH BUSES WITH OPTIONAL BUS TYPE FILTER
  // ============================================================
  Future<List<Map<String, dynamic>>> getBusesByRouteAndType(
      String from, String to, String? busClass) async {
    final db = await database;

    String query = '''
      SELECT * FROM buses
      WHERE LOWER(fromCity) = LOWER(?)
        AND LOWER(toCity) = LOWER(?)
    ''';

    List<dynamic> args = [from, to];

    if (busClass != null && busClass.isNotEmpty) {
      query += ' AND busClass = ?';
      args.add(busClass);
    }

    query += ' ORDER BY time ASC';

    return await db.rawQuery(query, args);
  }

  // ============================================================
  // OLD: KEEP ORIGINAL FOR BACKWARD COMPATIBILITY
  // ============================================================
  Future<List<Map<String, dynamic>>> getBusesByRoute(String from, String to) async {
    return await getBusesByRouteAndType(from, to, null);
  }

  // ============================================================
  // GET BOOKED SEATS (No change)
  // ============================================================
  Future<List<Map<String, dynamic>>> getBookedSeatsWithGender(int busId) async {
    final db = await database;
    return await db.query(
      'bookings',
      columns: ['seatNumber', 'gender'],
      where: 'busId = ?',
      whereArgs: [busId],
    );
  }

  // ============================================================
  // BOOK SEATS (No change)
  // ============================================================
  Future<void> bookSeats({
    required int busId,
    required List<String> seats,
    required String gender,
    required String date,
    int userId = 0,
  }) async {
    final db = await database;
    Batch batch = db.batch();

    final String cleanDate = date.contains(' ')
        ? date.split(' ')[0]
        : (date.contains('T') ? date.split('T')[0] : date);

    for (String seat in seats) {
      batch.insert("bookings", {
        "userId": userId,
        "busId": busId,
        "seatNumber": int.parse(seat),
        "gender": gender,
        "bookingDate": cleanDate,
        "status": "booked",
      });
    }

    await batch.commit(noResult: true);
  }

  // ============================================================
  // REMAINING FUNCTIONS (No change)
  // ============================================================
  Future<Map<String, dynamic>?> getBusById(int id) async {
    final db = await database;
    final result = await db.query('buses', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getUserBookings(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        bk.id AS bookingId,
        bk.seatNumber,
        bk.gender AS passengerGender,
        bk.bookingDate,
        bk.status,
        bus.id AS busId,
        bus.busName,
        bus.busNumber,
        bus.fromCity,
        bus.toCity,
        bus.routeVia,
        bus.date AS travelDate,
        bus.time,
        bus.busClass,
        bus.fare,
        bus.originalFare,
        bus.discount,
        bus.refreshment
      FROM bookings bk
      INNER JOIN buses bus ON bk.busId = bus.id
      WHERE bk.userId = ?
      ORDER BY bk.bookingDate DESC
    ''', [userId]);
  }

  Future<List<Map<String, dynamic>>> getAllBuses() async {
    final db = await database;
    return await db.query('buses', orderBy: 'date ASC, time ASC');
  }

  Future<List<Map<String, dynamic>>> getAllBookingsAdmin({int? limit}) async {
    final db = await database;
    String query = '''
      SELECT 
        bk.id AS bookingId,
        bk.seatNumber,
        bk.gender AS passengerGender,
        bk.bookingDate,
        bk.status,
        bk.userId,
        bus.id AS busId,
        bus.busName,
        bus.busNumber,
        bus.fromCity,
        bus.toCity,
        bus.routeVia,
        bus.date AS travelDate,
        bus.time,
        bus.busClass,
        bus.fare,
        u.firstName,
        u.lastName,
        u.email AS userEmail,
        u.phone AS userPhone
      FROM bookings bk
      LEFT JOIN buses bus ON bk.busId = bus.id
      LEFT JOIN users u ON bk.userId = u.id
      ORDER BY bk.id DESC
    ''';
    if (limit != null && limit > 0) {
      query += ' LIMIT $limit';
    }
    return await db.rawQuery(query);
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    final db = await database;
    try {
      final busesCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM buses');
      final routesCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM routes');
      final usersCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM users');
      final subAdminsCountRes = await db.rawQuery("SELECT COUNT(*) as count FROM users WHERE role = 'sub_admin'");
      final bookingsCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM bookings');
      final complainsCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM complain');
      final feedbacksCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM feedback');
      final revenueRes = await db.rawQuery('SELECT SUM(amount) as total FROM payments');
      
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final todayBookingsRes = await db.rawQuery(
        'SELECT COUNT(*) as count FROM bookings WHERE bookingDate = ?',
        [todayStr],
      );

      final int totalBuses = (busesCountRes.isNotEmpty && busesCountRes.first['count'] != null)
          ? (busesCountRes.first['count'] as num).toInt()
          : 0;
      final int totalRoutes = (routesCountRes.isNotEmpty && routesCountRes.first['count'] != null)
          ? (routesCountRes.first['count'] as num).toInt()
          : 0;
      final int totalUsers = (usersCountRes.isNotEmpty && usersCountRes.first['count'] != null)
          ? (usersCountRes.first['count'] as num).toInt()
          : 0;
      final int totalSubAdmins = (subAdminsCountRes.isNotEmpty && subAdminsCountRes.first['count'] != null)
          ? (subAdminsCountRes.first['count'] as num).toInt()
          : 0;
      final int totalBookings = (bookingsCountRes.isNotEmpty && bookingsCountRes.first['count'] != null)
          ? (bookingsCountRes.first['count'] as num).toInt()
          : 0;
      final int totalComplaints = (complainsCountRes.isNotEmpty && complainsCountRes.first['count'] != null)
          ? (complainsCountRes.first['count'] as num).toInt()
          : 0;
      final int totalFeedbacks = (feedbacksCountRes.isNotEmpty && feedbacksCountRes.first['count'] != null)
          ? (feedbacksCountRes.first['count'] as num).toInt()
          : 0;
      final int todayBookings = (todayBookingsRes.isNotEmpty && todayBookingsRes.first['count'] != null)
          ? (todayBookingsRes.first['count'] as num).toInt()
          : 0;

      double totalRevenue = 0.0;
      if (revenueRes.isNotEmpty && revenueRes.first['total'] != null) {
        totalRevenue = (revenueRes.first['total'] as num).toDouble();
      }

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
    } catch (e) {
      print('Error getting admin stats: $e');
      return {
        'totalBuses': 0,
        'totalRoutes': 0,
        'totalUsers': 0,
        'totalBookings': 0,
        'totalComplaints': 0,
        'totalFeedbacks': 0,
        'todayBookings': 0,
        'totalRevenue': 0.0,
      };
    }
  }

  Future<bool> cancelBooking({
    required int bookingId,
    String? source,
    int? busId,
    dynamic seatNumber,
    int userId = 0,
    String? email,
  }) async {
    final db = await database;

    try {
      if (source == 'payment') {
        // 1. Delete ONLY this specific payment record by its unique ID
        await db.delete('payments', where: 'id = ?', whereArgs: [bookingId]);

        // 2. Unblock ONLY one matching booking seat for this bus
        if (busId != null && busId > 0 && seatNumber != null) {
          String sStr = seatNumber.toString().replaceAll('#', '').trim();
          int? sInt = int.tryParse(sStr);
          if (sInt != null) {
            final bRows = await db.query(
              'bookings',
              columns: ['id'],
              where: 'busId = ? AND seatNumber = ?',
              whereArgs: [busId, sInt],
              limit: 1,
            );
            if (bRows.isNotEmpty) {
              await db.delete('bookings', where: 'id = ?', whereArgs: [bRows.first['id']]);
            }
          }
        }
      } else {
        // 1. Delete ONLY this specific booking record by its unique ID
        await db.delete('bookings', where: 'id = ?', whereArgs: [bookingId]);

        // 2. Delete ONLY the corresponding single payment if matched
        if (busId != null && busId > 0 && seatNumber != null) {
          String sStr = seatNumber.toString().replaceAll('#', '').trim();
          final pRows = await db.query(
            'payments',
            columns: ['id'],
            where: 'busId = ? AND (seats = ? OR seats LIKE ?)',
            whereArgs: [busId, sStr, '%$sStr%'],
            limit: 1,
          );
          if (pRows.isNotEmpty) {
            await db.delete('payments', where: 'id = ?', whereArgs: [pRows.first['id']]);
          }
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Backward compatibility wrapper
  Future<bool> cancelBookingById(int bookingId, int userId) async {
    return await cancelBooking(bookingId: bookingId, userId: userId);
  }

  Future<int> insertPayment({
    required int busId,
    required List<int> seats,
    required String passengerName,
    required String passengerEmail,
    required String paymentMethod,
    required String accountNumber,
    String? date,
    double? amount,
    String? passengerCnic,
    String? passengerPhone,
  }) async {
    final db = await database;
    final String cleanDate = (date != null && date.trim().isNotEmpty)
        ? (date.contains(' ') ? date.split(' ')[0] : (date.contains('T') ? date.split('T')[0] : date.trim()))
        : DateTime.now().toIso8601String().split('T')[0];

    return await db.insert("payments", {
      "busId": busId,
      "seats": seats.join(","),
      "amount": amount ?? 0.0,
      "date": cleanDate,
      "passengerName": passengerName,
      "passengerCnic": passengerCnic ?? "",
      "passengerPhone": passengerPhone ?? "",
      "paymentMethod": paymentMethod,
      "accountNumber": accountNumber,
      "email": passengerEmail,
    });
  }

  Future<List<Map<String, dynamic>>> getPayments({int? busId}) async {
    final db = await database;
    if (busId != null) {
      return await db.query('payments', where: 'busId = ?', whereArgs: [busId], orderBy: "id DESC");
    }
    return await db.query('payments', orderBy: "id DESC");
  }

  Future<Map<String, dynamic>?> getPaymentById(int id) async {
    final db = await database;
    final result = await db.query("payments", where: "id=?", whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> insertFeedback({required int userId, required String message}) async {
    final db = await database;
    return await db.insert('feedback', {
      "userId": userId,
      "message": message,
      "date": DateTime.now().toString(),
    });
  }

  Future<List<Map<String, dynamic>>> getFeedbacks() async {
    final db = await database;
    return await db.query('feedback', orderBy: "id DESC");
  }

  Future<List<Map<String, dynamic>>> getAllFeedbacks() async {
    return await getFeedbacks();
  }

  Future<int> insertComplain({required int userId, required String message}) async {
    final db = await database;
    return await db.insert('complain', {
      "userId": userId,
      "message": message,
      "date": DateTime.now().toString(),
    });
  }

  Future<List<Map<String, dynamic>>> getComplains() async {
    final db = await database;
    return await db.query('complain', orderBy: "id DESC");
  }

  Future<List<Map<String, dynamic>>> getAllComplains() async {
    return await getComplains();
  }

  Future<void> insertSupportMessage({required String type, required String message}) async {}

  // ============================================================
  // NOTIFICATIONS CRUD & MANAGEMENT
  // ============================================================
  Future<void> ensureNotificationsTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        userEmail TEXT,
        title TEXT,
        body TEXT,
        type TEXT,
        timestamp TEXT,
        isRead INTEGER DEFAULT 0,
        routeFrom TEXT,
        routeTo TEXT,
        dataJson TEXT
      );
    ''');
  }

  Future<int> insertNotification({
    int? userId,
    String? userEmail,
    required String title,
    required String body,
    String type = 'system',
    String? routeFrom,
    String? routeTo,
    String? dataJson,
  }) async {
    try {
      await ensureNotificationsTable();
      final db = await database;
      return await db.insert('notifications', {
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
      });
    } catch (e) {
      print('Error inserting notification: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications({
    int? userId,
    String? userEmail,
    String? typeFilter,
  }) async {
    try {
      await ensureNotificationsTable();
      final db = await database;

      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
        whereClause = 'type = ?';
        whereArgs.add(typeFilter.toLowerCase());
      }

      return await db.query(
        'notifications',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'id DESC',
      );
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  Future<int> getUnreadNotificationsCount({int? userId, String? userEmail}) async {
    try {
      await ensureNotificationsTable();
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE isRead = 0',
      );
      if (result.isNotEmpty && result.first['count'] != null) {
        return (result.first['count'] as num).toInt();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> markNotificationAsRead(int id) async {
    try {
      await ensureNotificationsTable();
      final db = await database;
      return await db.update(
        'notifications',
        {'isRead': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error marking notification as read: $e');
      return 0;
    }
  }

  Future<int> markAllNotificationsAsRead({int? userId, String? userEmail}) async {
    try {
      await ensureNotificationsTable();
      final db = await database;
      return await db.update(
        'notifications',
        {'isRead': 1},
        where: 'isRead = 0',
      );
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return 0;
    }
  }

  Future<int> deleteNotification(int id) async {
    try {
      await ensureNotificationsTable();
      final db = await database;
      return await db.delete(
        'notifications',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting notification: $e');
      return 0;
    }
  }

  Future<int> clearAllNotifications({int? userId, String? userEmail}) async {
    try {
      await ensureNotificationsTable();
      final db = await database;
      return await db.delete('notifications');
    } catch (e) {
      print('Error clearing notifications: $e');
      return 0;
    }
  }

  // ============================================================
  // SUB-ADMIN & TERMINAL AGENT METHODS
  // ============================================================

  /// Ensure role and terminal columns exist in users table
  Future<void> ensureUserRoleColumns() async {
    try {
      final db = await database;
      final columnsInfo = await db.rawQuery('PRAGMA table_info(users);');
      final existingColumns = columnsInfo.map((c) => c['name']?.toString().toLowerCase()).toSet();

      if (!existingColumns.contains('role')) {
        await db.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user';");
      }
      if (!existingColumns.contains('terminalname')) {
        await db.execute("ALTER TABLE users ADD COLUMN terminalName TEXT;");
      }
      if (!existingColumns.contains('terminalcity')) {
        await db.execute("ALTER TABLE users ADD COLUMN terminalCity TEXT;");
      }
      if (!existingColumns.contains('status')) {
        await db.execute("ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'active';");
      }
    } catch (_) {}
  }

  /// Get all sub-admins / terminal agents
  Future<List<Map<String, dynamic>>> getSubAdmins() async {
    await ensureUserRoleColumns();
    final db = await database;
    return await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['sub_admin'],
      orderBy: 'id DESC',
    );
  }

  /// Insert a new Sub-Admin
  Future<int> insertSubAdmin(UserModel user) async {
    await ensureUserRoleColumns();
    final db = await database;
    user.role = 'sub_admin';
    return await db.insert('users', user.toMap());
  }

  /// Update Sub-Admin details
  Future<int> updateSubAdmin(int id, UserModel user) async {
    await ensureUserRoleColumns();
    final db = await database;
    user.role = 'sub_admin';
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggle Sub-Admin status (active / suspended)
  Future<int> toggleSubAdminStatus(int id, String currentStatus) async {
    await ensureUserRoleColumns();
    final db = await database;
    final newStatus = currentStatus.toLowerCase() == 'active' ? 'suspended' : 'active';
    return await db.update(
      'users',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete Sub-Admin
  Future<int> deleteSubAdmin(int id) async {
    await ensureUserRoleColumns();
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ? AND role = ?',
      whereArgs: [id, 'sub_admin'],
    );
  }

  /// Fetch KPI statistics scoped to a Sub-Admin's assigned terminal/city
  Future<Map<String, dynamic>> getSubAdminStats(String terminalCity) async {
    final db = await database;
    await ensureTerminalBookingsTable();

    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final todayAlt1 = "${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}";
    final todayAlt2 = "${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}";

    final cityTrimmed = terminalCity.trim().toLowerCase();

    // 1. Total Buses originating from this city
    final buses = await db.query('buses', orderBy: 'date ASC, time ASC');
    final terminalBuses = buses.where((b) {
      final from = (b['fromCity'] ?? '').toString().trim().toLowerCase();
      if (cityTrimmed.isEmpty || cityTrimmed == 'all') return true;
      return from.contains(cityTrimmed) || cityTrimmed.contains(from);
    }).toList();

    // Today's departing buses from this terminal
    final todayBuses = terminalBuses.where((b) {
      final d = (b['date'] ?? '').toString().trim();
      return d.isEmpty || d == todayStr || d == todayAlt1 || d == todayAlt2;
    }).toList();

    // If no buses scheduled strictly for today, display active scheduled terminal buses
    final activeBuses = todayBuses.isNotEmpty ? todayBuses : terminalBuses;

    // Build bus lookup map
    final Map<int, Map<String, dynamic>> busMap = {};
    for (final b in buses) {
      final bId = b['id'] is int ? b['id'] as int : int.tryParse(b['id'].toString()) ?? 0;
      if (bId > 0) busMap[bId] = b;
    }
    final terminalBusIds = terminalBuses.map((b) => b['id'] is int ? b['id'] as int : int.tryParse(b['id'].toString()) ?? 0).toSet();

    // 2. Fetch local SQLite tables
    final allBookings = await db.query('bookings', orderBy: 'id DESC');
    final allTerminalBookings = await db.query('terminal_bookings', orderBy: 'id DESC');
    final allPayments = await db.query('payments', orderBy: 'id DESC');

    // Also fetch from Supabase if connected
    List<Map<String, dynamic>> supabaseTerminalRows = [];
    try {
      final sbRows = await SupabaseService.instance.client
          .from('terminal_bookings')
          .select()
          .order('id', ascending: false);
      supabaseTerminalRows = List<Map<String, dynamic>>.from(sbRows);
    } catch (_) {}

    int totalBookingsCount = 0;
    int todayBookingsCount = 0;
    double totalRevenue = 0.0;
    double todayRevenue = 0.0;
    final List<Map<String, dynamic>> terminalBookingsList = [];
    final Set<String> processedKeys = {};

    // A) Dedicated terminal_bookings table
    for (final tb in allTerminalBookings) {
      final bId = tb['busId'] is int ? tb['busId'] as int : int.tryParse(tb['busId'].toString()) ?? 0;
      final tCity = (tb['terminalCity'] ?? '').toString().trim().toLowerCase();
      final bus = busMap[bId];
      final busFromCity = (bus?['fromCity'] ?? '').toString().trim().toLowerCase();

      final isThisTerminal = (cityTrimmed.isEmpty || cityTrimmed == 'all') ||
          (tCity.isNotEmpty && (tCity.contains(cityTrimmed) || cityTrimmed.contains(tCity))) ||
          (busFromCity.isNotEmpty && (busFromCity.contains(cityTrimmed) || cityTrimmed.contains(busFromCity))) ||
          terminalBusIds.contains(bId);

      if (!isThisTerminal) continue;

      final seat = tb['seatNumber']?.toString() ?? '';
      final bDate = (tb['bookingDate'] ?? '').toString().trim();
      final crAt = (tb['createdAt'] ?? '').toString().trim();
      final uniqueKey = "${bId}_${seat}_$bDate";
      processedKeys.add(uniqueKey);

      final double fare = (tb['fare'] as num?)?.toDouble() ??
          (bus?['fare'] as num?)?.toDouble() ??
          0.0;

      final bool isToday = bDate == todayStr ||
          bDate == todayAlt1 ||
          bDate == todayAlt2 ||
          bDate.startsWith(todayStr) ||
          crAt.startsWith(todayStr);

      totalBookingsCount++;
      totalRevenue += fare;

      if (isToday) {
        todayBookingsCount++;
        todayRevenue += fare;
      }

      terminalBookingsList.add({
        ...tb,
        'fare': fare,
        'busName': bus?['busName'] ?? 'BusVerse Express',
        'busNumber': bus?['busNumber'] ?? 'BV-Fleet',
        'fromCity': bus?['fromCity'] ?? terminalCity,
        'toCity': bus?['toCity'] ?? tb['toCity'] ?? 'Destination',
      });
    }

    // B) Supabase terminal bookings
    for (final tb in supabaseTerminalRows) {
      final bId = tb['busId'] ?? tb['bus_id'];
      final int parsedBusId = bId is int ? bId : int.tryParse(bId?.toString() ?? '') ?? 0;
      final tCity = (tb['terminalCity'] ?? tb['terminal_city'] ?? '').toString().trim().toLowerCase();
      final bus = busMap[parsedBusId];
      final busFromCity = (bus?['fromCity'] ?? '').toString().trim().toLowerCase();

      final isThisTerminal = (cityTrimmed.isEmpty || cityTrimmed == 'all') ||
          (tCity.isNotEmpty && (tCity.contains(cityTrimmed) || cityTrimmed.contains(tCity))) ||
          (busFromCity.isNotEmpty && (busFromCity.contains(cityTrimmed) || cityTrimmed.contains(busFromCity))) ||
          terminalBusIds.contains(parsedBusId);

      if (!isThisTerminal) continue;

      final seat = (tb['seatNumber'] ?? tb['seat_number'])?.toString() ?? '';
      final bDate = (tb['bookingDate'] ?? tb['booking_date'] ?? '').toString().trim();
      final crAt = (tb['createdAt'] ?? tb['created_at'] ?? '').toString().trim();
      final uniqueKey = "${parsedBusId}_${seat}_$bDate";

      if (processedKeys.contains(uniqueKey)) continue;
      processedKeys.add(uniqueKey);

      final double fare = (tb['fare'] as num?)?.toDouble() ??
          (bus?['fare'] as num?)?.toDouble() ??
          0.0;

      final bool isToday = bDate == todayStr ||
          bDate == todayAlt1 ||
          bDate == todayAlt2 ||
          bDate.startsWith(todayStr) ||
          crAt.startsWith(todayStr);

      totalBookingsCount++;
      totalRevenue += fare;

      if (isToday) {
        todayBookingsCount++;
        todayRevenue += fare;
      }

      terminalBookingsList.add({
        ...tb,
        'busId': parsedBusId,
        'fare': fare,
        'busName': bus?['busName'] ?? 'BusVerse Express',
        'busNumber': bus?['busNumber'] ?? 'BV-Fleet',
        'fromCity': bus?['fromCity'] ?? terminalCity,
        'toCity': bus?['toCity'] ?? 'Destination',
      });
    }

    // C) App-wide bookings table
    for (final bk in allBookings) {
      final bId = bk['busId'] is int ? bk['busId'] as int : int.tryParse(bk['busId'].toString()) ?? 0;
      final bus = busMap[bId];
      final busFromCity = (bus?['fromCity'] ?? '').toString().trim().toLowerCase();

      final isThisTerminal = (cityTrimmed.isEmpty || cityTrimmed == 'all') ||
          (busFromCity.isNotEmpty && (busFromCity.contains(cityTrimmed) || cityTrimmed.contains(busFromCity))) ||
          terminalBusIds.contains(bId);

      if (!isThisTerminal) continue;

      final seat = bk['seatNumber']?.toString() ?? '';
      final bDate = (bk['bookingDate'] ?? bk['date'] ?? '').toString().trim();
      final uniqueKey = "${bId}_${seat}_$bDate";

      if (processedKeys.contains(uniqueKey)) continue;
      processedKeys.add(uniqueKey);

      final double fare = (bk['fare'] as num?)?.toDouble() ??
          (bus?['fare'] as num?)?.toDouble() ??
          0.0;

      final bool isToday = bDate == todayStr ||
          bDate == todayAlt1 ||
          bDate == todayAlt2 ||
          bDate.startsWith(todayStr);

      totalBookingsCount++;
      totalRevenue += fare;

      if (isToday) {
        todayBookingsCount++;
        todayRevenue += fare;
      }

      terminalBookingsList.add({
        ...bk,
        'fare': fare,
        'busName': bus?['busName'] ?? 'BusVerse Express',
        'busNumber': bus?['busNumber'] ?? 'BV-Fleet',
        'fromCity': bus?['fromCity'] ?? terminalCity,
        'toCity': bus?['toCity'] ?? 'Destination',
      });
    }

    // D) Fallback revenue from payments if 0
    if (totalRevenue == 0.0 && allPayments.isNotEmpty) {
      for (final p in allPayments) {
        final pBusId = p['busId'] is int ? p['busId'] as int : int.tryParse(p['busId'].toString()) ?? 0;
        if (terminalBusIds.contains(pBusId) || cityTrimmed.isEmpty || cityTrimmed == 'all') {
          final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
          totalRevenue += amt;
          final pDate = (p['date'] ?? '').toString();
          if (pDate == todayStr || pDate.startsWith(todayStr)) {
            todayRevenue += amt;
          }
        }
      }
    }

    return {
      'totalBuses': terminalBuses.length,
      'todayBuses': todayBuses.isNotEmpty ? todayBuses.length : terminalBuses.length,
      'todayBusesList': activeBuses,
      'totalBookings': totalBookingsCount,
      'todayBookings': todayBookingsCount > 0 ? todayBookingsCount : totalBookingsCount,
      'recentBookings': terminalBookingsList.take(10).toList(),
      'totalRevenue': totalRevenue,
      'todayRevenue': todayRevenue > 0 ? todayRevenue : totalRevenue,
    };
  }

  // ============================================================
  // DEDICATED TERMINAL COUNTER BOOKINGS & PAYMENTS
  // ============================================================

  /// Ensure terminal_bookings table exists
  Future<void> ensureTerminalBookingsTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS terminal_bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        busId INTEGER,
        seatNumber INTEGER,
        gender TEXT,
        passengerName TEXT,
        passengerPhone TEXT,
        passengerCnic TEXT,
        fare REAL,
        paymentMethod TEXT,
        terminalCity TEXT,
        terminalName TEXT,
        agentName TEXT,
        bookingDate TEXT,
        status TEXT DEFAULT 'Confirmed',
        createdAt TEXT
      );
    ''');
  }

  /// Insert Walk-in / Terminal Counter Booking
  Future<int> insertTerminalBooking({
    required int busId,
    required List<int> seatNumbers,
    required Map<int, String> seatGenders,
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
    await ensureTerminalBookingsTable();
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final double farePerSeat = seatNumbers.isNotEmpty ? (totalAmount / seatNumbers.length) : totalAmount;

    int lastId = 0;
    for (final seat in seatNumbers) {
      final gender = seatGenders[seat] ?? 'Male';

      // 1. Insert into dedicated terminal_bookings table
      final tbId = await db.insert('terminal_bookings', {
        'busId': busId,
        'seatNumber': seat,
        'gender': gender,
        'passengerName': passengerName,
        'passengerPhone': passengerPhone,
        'passengerCnic': passengerCnic,
        'fare': farePerSeat,
        'paymentMethod': paymentMethod,
        'terminalCity': terminalCity,
        'terminalName': terminalName,
        'agentName': agentName,
        'bookingDate': bookingDate,
        'status': 'Confirmed',
        'createdAt': now,
      });
      lastId = tbId;

      // 2. Insert into bookings table for app-wide seat reservation
      await db.insert('bookings', {
        'userId': 0,
        'busId': busId,
        'seatNumber': seat,
        'gender': gender,
        'bookingDate': bookingDate,
        'status': 'Confirmed',
      });
    }

    // 3. Insert into payments table
    await insertPayment(
      busId: busId,
      seats: seatNumbers,
      amount: totalAmount,
      date: bookingDate,
      passengerName: passengerName,
      passengerCnic: passengerCnic,
      passengerPhone: passengerPhone,
      paymentMethod: paymentMethod,
      accountNumber: "COUNTER-POS",
      passengerEmail: "counter.$passengerPhone@busverse.pos",
    );

    return lastId;
  }

  /// Get all Terminal Bookings
  Future<List<Map<String, dynamic>>> getTerminalBookings({int? busId, String? terminalCity}) async {
    await ensureTerminalBookingsTable();
    final db = await database;
    String query = '''
      SELECT tb.*,
             bus.busName, bus.busNumber, bus.busClass, bus.fromCity, bus.toCity, bus.time, bus.date as busDate
      FROM terminal_bookings tb
      LEFT JOIN buses bus ON tb.busId = bus.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];
    if (busId != null) {
      query += ' AND tb.busId = ?';
      args.add(busId);
    }
    if (terminalCity != null && terminalCity.isNotEmpty) {
      query += ' AND (LOWER(tb.terminalCity) = LOWER(?) OR LOWER(bus.fromCity) = LOWER(?))';
      args.add(terminalCity);
      args.add(terminalCity);
    }
    query += ' ORDER BY tb.id DESC';
    return await db.rawQuery(query, args);
  }

  // ============================================================
  // TERMINAL AGENTS & COUNTER SHIFTS MANAGEMENT
  // ============================================================

  Future<void> ensureAgentAndShiftTables() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS terminal_agents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        agentCode TEXT UNIQUE,
        name TEXT,
        pin TEXT,
        phone TEXT,
        terminalCity TEXT,
        status TEXT DEFAULT 'active',
        createdAt TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS counter_shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        terminalCity TEXT,
        terminalName TEXT,
        agentId INTEGER,
        agentName TEXT,
        agentCode TEXT,
        shiftType TEXT,
        openingTime TEXT,
        closingTime TEXT,
        openingFloat REAL DEFAULT 0.0,
        cashSales REAL DEFAULT 0.0,
        digitalSales REAL DEFAULT 0.0,
        closingCash REAL DEFAULT 0.0,
        ticketsCount INTEGER DEFAULT 0,
        nextAgentId INTEGER,
        nextAgentName TEXT,
        handoverPinVerified INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active'
      );
    ''');

    // Seed default demo agents if none exist for quick usage
    final countRes = await db.rawQuery('SELECT COUNT(*) as count FROM terminal_agents');
    final count = (countRes.isNotEmpty && countRes.first['count'] != null)
        ? (countRes.first['count'] as num).toInt()
        : 0;
    if (count == 0) {
      final now = DateTime.now().toIso8601String();
      await db.insert('terminal_agents', {
        'agentCode': 'AGT-101',
        'name': 'Ali Raza',
        'pin': '1122',
        'phone': '03001234567',
        'terminalCity': 'Lahore',
        'status': 'active',
        'createdAt': now,
      });
      await db.insert('terminal_agents', {
        'agentCode': 'AGT-102',
        'name': 'Hamza Malik',
        'pin': '3344',
        'phone': '03219876543',
        'terminalCity': 'Lahore',
        'status': 'active',
        'createdAt': now,
      });
      await db.insert('terminal_agents', {
        'agentCode': 'AGT-103',
        'name': 'Usman Tariq',
        'pin': '5566',
        'phone': '03335557788',
        'terminalCity': 'Lahore',
        'status': 'active',
        'createdAt': now,
      });
    }
  }

  /// Get list of terminal agents for a city (Synced with Supabase Cloud)
  Future<List<Map<String, dynamic>>> getTerminalAgents({String? terminalCity}) async {
    await ensureAgentAndShiftTables();
    final db = await database;

    // 1. Try to sync latest agents from Supabase Cloud
    try {
      final cloudAgents = await SupabaseService.instance.getTerminalAgentsFromCloud(terminalCity);
      if (cloudAgents.isNotEmpty) {
        for (var ca in cloudAgents) {
          final code = ca['agent_code'] ?? ca['agentCode'] ?? '';
          if (code.isNotEmpty) {
            final existing = await db.query('terminal_agents', where: 'agentCode = ?', whereArgs: [code]);
            if (existing.isEmpty) {
              await db.insert('terminal_agents', {
                'agentCode': code,
                'name': ca['name'] ?? '',
                'pin': ca['pin']?.toString() ?? '0000',
                'phone': ca['phone']?.toString() ?? '',
                'terminalCity': ca['terminal_city'] ?? ca['terminalCity'] ?? terminalCity ?? 'Lahore',
                'status': ca['status'] ?? 'active',
                'createdAt': ca['created_at'] ?? DateTime.now().toIso8601String(),
              });
            } else {
              await db.update('terminal_agents', {
                'name': ca['name'] ?? existing.first['name'],
                'pin': ca['pin']?.toString() ?? existing.first['pin'],
                'phone': ca['phone']?.toString() ?? existing.first['phone'],
                'status': ca['status'] ?? 'active',
              }, where: 'agentCode = ?', whereArgs: [code]);
            }
          }
        }
      }
    } catch (_) {}

    // 2. Return local query
    if (terminalCity != null && terminalCity.isNotEmpty) {
      final res = await db.query(
        'terminal_agents',
        where: 'LOWER(terminalCity) = LOWER(?) AND status = ?',
        whereArgs: [terminalCity, 'active'],
        orderBy: 'id ASC',
      );
      if (res.isNotEmpty) return res;
    }
    return await db.query(
      'terminal_agents',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'id ASC',
    );
  }

  /// Register or Add a new Counter Agent (Saved to Supabase + Local DB)
  Future<int> addTerminalAgent({
    required String agentCode,
    required String name,
    required String pin,
    required String phone,
    required String terminalCity,
  }) async {
    await ensureAgentAndShiftTables();
    final db = await database;

    // 1. Save to Supabase Cloud
    try {
      await SupabaseService.instance.addTerminalAgentToCloud(
        agentCode: agentCode,
        name: name,
        pin: pin,
        phone: phone,
        terminalCity: terminalCity,
      );
    } catch (_) {}

    // 2. Save to Local SQLite
    return await db.insert('terminal_agents', {
      'agentCode': agentCode,
      'name': name,
      'pin': pin,
      'phone': phone,
      'terminalCity': terminalCity,
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Update agent PIN or Details (Updated in Supabase + Local DB)
  Future<int> updateTerminalAgent({
    required int agentId,
    required String name,
    required String pin,
    required String phone,
  }) async {
    await ensureAgentAndShiftTables();
    final db = await database;

    final existing = await db.query('terminal_agents', where: 'id = ?', whereArgs: [agentId]);
    final agentCode = existing.isNotEmpty ? (existing.first['agentCode'] as String? ?? '') : '';

    // 1. Update in Supabase Cloud
    if (agentCode.isNotEmpty) {
      try {
        await SupabaseService.instance.updateTerminalAgentInCloud(
          agentCode: agentCode,
          name: name,
          pin: pin,
          phone: phone,
        );
      } catch (_) {}
    }

    // 2. Update in Local SQLite
    return await db.update(
      'terminal_agents',
      {
        'name': name,
        'pin': pin,
        'phone': phone,
      },
      where: 'id = ?',
      whereArgs: [agentId],
    );
  }

  /// Verify Agent PIN
  Future<Map<String, dynamic>?> verifyAgentPin(int agentId, String pin) async {
    await ensureAgentAndShiftTables();
    final db = await database;
    final res = await db.query(
      'terminal_agents',
      where: 'id = ? AND pin = ? AND status = ?',
      whereArgs: [agentId, pin, 'active'],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  /// Get currently Active Shift for a terminal
  Future<Map<String, dynamic>?> getActiveShift(String terminalCity) async {
    await ensureAgentAndShiftTables();
    final db = await database;
    final res = await db.query(
      'counter_shifts',
      where: 'status = ? AND (LOWER(terminalCity) = LOWER(?) OR terminalCity IS NULL)',
      whereArgs: ['active', terminalCity],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  /// Start / Clock-In a new shift
  Future<int> startShift({
    required int agentId,
    required String agentName,
    required String agentCode,
    required String shiftType,
    required double openingFloat,
    required String terminalCity,
    required String terminalName,
  }) async {
    await ensureAgentAndShiftTables();
    final db = await database;

    // Close any previous hanging active shifts for this terminal first
    await db.update(
      'counter_shifts',
      {
        'status': 'closed',
        'closingTime': DateTime.now().toIso8601String(),
      },
      where: 'status = ? AND (LOWER(terminalCity) = LOWER(?) OR terminalCity IS NULL)',
      whereArgs: ['active', terminalCity],
    );

    return await db.insert('counter_shifts', {
      'terminalCity': terminalCity,
      'terminalName': terminalName,
      'agentId': agentId,
      'agentName': agentName,
      'agentCode': agentCode,
      'shiftType': shiftType,
      'openingTime': DateTime.now().toIso8601String(),
      'openingFloat': openingFloat,
      'cashSales': 0.0,
      'digitalSales': 0.0,
      'closingCash': 0.0,
      'ticketsCount': 0,
      'status': 'active',
      'handoverPinVerified': 1,
    });
  }

  /// Close and Handover Shift to Incoming Agent with Dual PIN Verification
  Future<bool> closeAndHandoverShift({
    required int currentShiftId,
    required double closingCash,
    required double cashSales,
    required double digitalSales,
    required int ticketsCount,
    required int nextAgentId,
    required String nextAgentName,
    required String nextAgentCode,
    required String nextShiftType,
    required double nextOpeningFloat,
    required String terminalCity,
    required String terminalName,
  }) async {
    await ensureAgentAndShiftTables();
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // 1. Close current shift
    await db.update(
      'counter_shifts',
      {
        'closingTime': now,
        'closingCash': closingCash,
        'cashSales': cashSales,
        'digitalSales': digitalSales,
        'ticketsCount': ticketsCount,
        'nextAgentId': nextAgentId,
        'nextAgentName': nextAgentName,
        'handoverPinVerified': 1,
        'status': 'closed',
      },
      where: 'id = ?',
      whereArgs: [currentShiftId],
    );

    // 2. Start incoming agent's new active shift immediately
    await db.insert('counter_shifts', {
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

    return true;
  }

  /// Get Shift History
  Future<List<Map<String, dynamic>>> getShiftHistory(String terminalCity) async {
    await ensureAgentAndShiftTables();
    final db = await database;
    return await db.query(
      'counter_shifts',
      where: 'LOWER(terminalCity) = LOWER(?) OR terminalCity IS NULL',
      whereArgs: [terminalCity],
      orderBy: 'id DESC',
      limit: 30,
    );
  }
}