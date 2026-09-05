// lib/database/db_helper.dart

import 'dart:io';
import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/user_model.dart';
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
        version: 12,
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
        zip TEXT
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
    await db.insert("buses", bus.toMap());
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

  Future<dynamic> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query('users', where: 'email=?', whereArgs: [email]);
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

  Future<bool> cancelBooking(int bookingId, int userId) async {
    final db = await database;
    final check = await db.query(
      'bookings',
      where: 'id = ? AND userId = ? AND status = ?',
      whereArgs: [bookingId, userId, 'booked'],
    );

    if (check.isEmpty) return false;

    await db.delete('bookings', where: 'id = ? AND userId = ?', whereArgs: [bookingId, userId]);
    return true;
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

  Future<List<Map<String, dynamic>>> getPayments() async {
    final db = await database;
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
}