import 'package:bus_ticket_system/admin/models/bus_model.dart';
import 'package:bus_ticket_system/database/user_model.dart';
import 'package:bus_ticket_system/services/supabase_service.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  DBHelper._init();

  final SupabaseService _sb = SupabaseService.instance;

  // ============================================================
  // BUSES & ROUTES
  // ============================================================
  Future<void> cleanOldBusesAndBookings() async => await _sb.cleanOldBusesAndBookings();

  Future<int> insertRoute(Map<String, dynamic> route) async => await _sb.insertRoute(route);
  Future<List<Map<String, dynamic>>> getRoutes() async => await _sb.getRoutes();
  Future<int> updateRoute(int id, Map<String, dynamic> data) async => await _sb.updateRoute(id, data);
  Future<int> deleteRoute(int id) async => await _sb.deleteRoute(id);

  Future<void> insertBus(BusModel bus) async => await _sb.insertBus(bus);
  Future<List<Map<String, dynamic>>> getBusesByDate(String dateKey) async => await _sb.getBusesByDateRaw(dateKey);
  Future<void> updateBus(int id, BusModel bus) async => await _sb.updateBus(id, bus);
  Future<void> deleteBus(int id) async => await _sb.deleteBus(id);
  Future<List<Map<String, dynamic>>> getAllBuses() async => await _sb.getAllBuses();
  Future<Map<String, dynamic>?> getBusById(int id) async => await _sb.getBusById(id);

  Future<List<String>> getAllFromCities() async => await _sb.getAllFromCities();
  Future<List<String>> getAllToCities() async => await _sb.getAllToCities();
  Future<List<Map<String, dynamic>>> getBusesByRouteAndType(String from, String to, String? busClass) async =>
      await _sb.getBusesByRouteAndType(from, to, busClass);
  Future<List<Map<String, dynamic>>> getBusesByRoute(String from, String to) async =>
      await _sb.getBusesByRouteAndType(from, to, null);

  Future<List<BusModel>> searchBuses({
    String? fromCity,
    String? toCity,
    String? from,
    String? to,
    String? date,
    String? busClass,
  }) async =>
      await _sb.searchBuses(
        fromCity: fromCity,
        toCity: toCity,
        from: from,
        to: to,
        date: date,
        busClass: busClass,
      );

  // ============================================================
  // USERS & AUTH
  // ============================================================
  Future<void> registerUser(UserModel user) async => await _sb.registerUser(user);
  Future<dynamic> loginUser(String email, String pass) async => await _sb.loginUser(email, pass);
  Future<Map<String, dynamic>?> getUserByEmail(String email) async => await _sb.getUserByEmail(email);
  Future<Map<String, dynamic>?> getUserById(dynamic id) async => await _sb.getUserById(id);
  Future<void> updatePassword(String email, String pass) async => await _sb.updatePassword(email, pass);
  Future<void> updateUser(dynamic id, Map<String, dynamic> data) async => await _sb.updateUser(id, data);
  Future<void> deleteUser(dynamic id) async => await _sb.deleteUser(id);
  Future<List<UserModel>> getAllUsers() async => await _sb.getAllUsers();

  // ============================================================
  // BOOKINGS & SEATS
  // ============================================================
  Future<List<Map<String, dynamic>>> getBookedSeats(dynamic busId) async =>
      await _sb.getBookedSeats(busId);

  Future<List<Map<String, dynamic>>> getBookedSeatsWithGender(dynamic busId) async =>
      await _sb.getBookedSeatsWithGender(busId);

  Future<void> bookSeats({
    required int busId,
    required dynamic seats,
    required String gender,
    required String date,
    int userId = 0,
    String? userEmail,
  }) async =>
      await _sb.bookSeats(
        busId: busId,
        seats: seats,
        gender: gender,
        date: date,
        userId: userId,
        userEmail: userEmail,
      );

  Future<List<Map<String, dynamic>>> getUserBookings(dynamic userId) async =>
      await _sb.getUserBookings(userId);

  Future<List<Map<String, dynamic>>> getAllBookingsAdmin({int? limit, int? busId}) async =>
      await _sb.getAllBookingsAdmin(limit: limit, busId: busId);

  Future<bool> deleteBooking(int bookingId) async =>
      await _sb.deleteBooking(bookingId);

  Future<bool> cancelBooking({
    dynamic bookingId,
    String? source,
    int? busId,
    dynamic seatNumber,
    int userId = 0,
    String? email,
  }) async =>
      await _sb.cancelBooking(
        bookingId: bookingId,
        source: source,
        busId: busId,
        seatNumber: seatNumber,
        userId: userId,
        email: email,
      );

  Future<bool> cancelBookingById(int bookingId, int userId) async =>
      await _sb.cancelBooking(bookingId: bookingId, userId: userId);

  // ============================================================
  // PAYMENTS & TERMINAL BOOKINGS
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
  }) async =>
      await _sb.insertPayment(
        busId: busId,
        seats: seats,
        amount: amount,
        date: date,
        passengerName: passengerName,
        passengerCnic: passengerCnic,
        passengerPhone: passengerPhone,
        paymentMethod: paymentMethod,
        accountNumber: accountNumber,
        passengerEmail: passengerEmail,
      );

  Future<List<Map<String, dynamic>>> getPayments({int? busId}) async =>
      await _sb.getPayments(busId: busId);

  Future<Map<String, dynamic>?> getPaymentById(int id) async {
    final list = await _sb.getPayments();
    return list.where((p) => p['id'] == id).firstOrNull;
  }

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
  }) async =>
      await _sb.insertTerminalBooking(
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

  Future<List<Map<String, dynamic>>> getTerminalBookings({int? busId, String? terminalCity}) async =>
      await _sb.getTerminalBookings(busId: busId, terminalCity: terminalCity);

  // ============================================================
  // SUB-ADMINS & KPI STATS
  // ============================================================
  Future<void> ensureUserRoleColumns() async => await _sb.ensureUserRoleColumns();
  Future<List<Map<String, dynamic>>> getSubAdmins() async => await _sb.getSubAdmins();
  Future<int> insertSubAdmin(UserModel user) async => await _sb.insertSubAdmin(user);
  Future<int> updateSubAdmin(dynamic id, UserModel user) async => await _sb.updateSubAdmin(id, user);
  Future<int> toggleSubAdminStatus(dynamic id, String currentStatus) async =>
      await _sb.toggleSubAdminStatus(id, currentStatus);
  Future<int> deleteSubAdmin(dynamic id) async => await _sb.deleteSubAdmin(id);

  // ============================================================
  // DRIVERS & FLEET CAPTAINS
  // ============================================================
  Future<List<Map<String, dynamic>>> getDrivers() async => await _sb.getDrivers();
  Future<int> insertDriver(Map<String, dynamic> driverData) async => await _sb.insertDriver(driverData);
  Future<int> updateDriver(dynamic id, Map<String, dynamic> driverData) async => await _sb.updateDriver(id, driverData);
  Future<int> toggleDriverStatus(dynamic id, String currentStatus) async => await _sb.toggleDriverStatus(id, currentStatus);
  Future<int> deleteDriver(dynamic id) async => await _sb.deleteDriver(id);
  Future<List<Map<String, dynamic>>> getTripPassengers({required int busId, String? date}) async =>
      await _sb.getTripPassengers(busId: busId, date: date);

  Future<Map<String, dynamic>> getAdminStats() async => await _sb.getAdminStats();
  Future<Map<String, dynamic>> getSubAdminStats(String terminalCity) async =>
      await _sb.getSubAdminStats(terminalCity);
  Future<Map<String, dynamic>> getAllTerminalsLiveStats() async =>
      await _sb.getAllTerminalsLiveStats();
  Future<Map<String, dynamic>> getTerminalLiveDeepDive(String terminalCity) async =>
      await _sb.getTerminalLiveDeepDive(terminalCity);

  // ============================================================
  // TERMINAL AGENTS & COUNTER SHIFTS
  // ============================================================
  Future<void> ensureAgentAndShiftTables() async => await _sb.ensureAgentAndShiftTables();
  Future<void> ensureTerminalBookingsTable() async => await _sb.ensureTerminalBookingsTable();

  Future<List<Map<String, dynamic>>> getTerminalAgents({String? terminalCity}) async =>
      await _sb.getTerminalAgents(terminalCity: terminalCity);

  Future<int> addTerminalAgent({
    required String agentCode,
    required String name,
    required String pin,
    required String phone,
    required String terminalCity,
  }) async =>
      await _sb.addTerminalAgent(
        agentCode: agentCode,
        name: name,
        pin: pin,
        phone: phone,
        terminalCity: terminalCity,
      );

  Future<int> updateTerminalAgent({
    required dynamic agentId,
    required String name,
    required String pin,
    required String phone,
  }) async =>
      await _sb.updateTerminalAgent(
        agentId: agentId,
        name: name,
        pin: pin,
        phone: phone,
      );

  Future<int> deleteTerminalAgent(dynamic agentId, {String? agentCode}) async =>
      await _sb.deleteTerminalAgent(agentId, agentCode: agentCode);

  Future<Map<String, dynamic>?> verifyAgentPin(dynamic agentId, String pin) async =>
      await _sb.verifyAgentPin(agentId, pin);

  Future<Map<String, dynamic>?> getActiveShift(String terminalCity) async =>
      await _sb.getActiveShift(terminalCity);

  Future<int> startShift({
    required dynamic agentId,
    required String agentName,
    required String agentCode,
    required String shiftType,
    required double openingFloat,
    required String terminalCity,
    required String terminalName,
  }) async =>
      await _sb.startShift(
        agentId: agentId,
        agentName: agentName,
        agentCode: agentCode,
        shiftType: shiftType,
        openingFloat: openingFloat,
        terminalCity: terminalCity,
        terminalName: terminalName,
      );

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
  }) async =>
      await _sb.closeAndHandoverShift(
        currentShiftId: currentShiftId,
        closingCash: closingCash,
        cashSales: cashSales,
        digitalSales: digitalSales,
        ticketsCount: ticketsCount,
        nextAgentId: nextAgentId,
        nextAgentName: nextAgentName,
        nextAgentCode: nextAgentCode,
        nextShiftType: nextShiftType,
        nextOpeningFloat: nextOpeningFloat,
        terminalCity: terminalCity,
        terminalName: terminalName,
      );

  Future<List<Map<String, dynamic>>> getShiftHistory(String terminalCity) async =>
      await _sb.getShiftHistory(terminalCity);

  // ============================================================
  // NOTIFICATIONS, FEEDBACK, COMPLAINTS
  // ============================================================
  Future<void> ensureNotificationsTable() async => await _sb.ensureNotificationsTable();

  Future<int> insertNotification({
    dynamic userId,
    String? userEmail,
    required String title,
    required String body,
    String type = 'system',
    String? routeFrom,
    String? routeTo,
    String? dataJson,
  }) async =>
      await _sb.insertNotification(
        userId: userId,
        userEmail: userEmail,
        title: title,
        body: body,
        type: type,
        routeFrom: routeFrom,
        routeTo: routeTo,
        dataJson: dataJson,
      );

  Future<List<Map<String, dynamic>>> getNotifications({
    dynamic userId,
    String? userEmail,
    String? typeFilter,
  }) async =>
      await _sb.getNotifications(
        userId: userId,
        userEmail: userEmail,
        typeFilter: typeFilter,
      );

  Future<int> getUnreadNotificationsCount({dynamic userId, String? userEmail}) async =>
      await _sb.getUnreadNotificationsCount(userId: userId, userEmail: userEmail);

  Future<int> markNotificationAsRead(dynamic id) async =>
      await _sb.markNotificationAsRead(id);

  Future<int> markAllNotificationsAsRead({dynamic userId, String? userEmail}) async =>
      await _sb.markAllNotificationsAsRead(userId: userId, userEmail: userEmail);

  Future<int> deleteNotification(dynamic id) async =>
      await _sb.deleteNotification(id);

  Future<int> clearAllNotifications({dynamic userId, String? userEmail}) async =>
      await _sb.clearAllNotifications(userId: userId, userEmail: userEmail);

  Future<int> insertFeedback({required dynamic userId, required String message, String? userEmail}) async =>
      await _sb.insertFeedback(userId: userId, message: message, userEmail: userEmail);

  Future<List<Map<String, dynamic>>> getFeedbacks() async => await _sb.getFeedbacks();
  Future<List<Map<String, dynamic>>> getAllFeedbacks() async => await _sb.getAllFeedbacks();
  Future<int> insertComplain({required dynamic userId, required String message, String? userEmail}) async =>
      await _sb.insertComplain(userId: userId, message: message, userEmail: userEmail);

  Future<List<Map<String, dynamic>>> getComplains() async => await _sb.getComplains();
  Future<List<Map<String, dynamic>>> getAllComplains() async => await _sb.getAllComplains();
  Future<void> insertSupportMessage({required String type, required String message}) async {}

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
  }) async =>
      await _sb.updateBusLocation(
        busId: busId,
        latitude: latitude,
        longitude: longitude,
        speed: speed,
        heading: heading,
        nextStop: nextStop,
        etaMinutes: etaMinutes,
        status: status,
      );

  Future<Map<String, dynamic>?> getBusLiveLocation(int busId) async =>
      await _sb.getBusLiveLocation(busId);

  Future<List<Map<String, dynamic>>> getAllActiveBusLocations() async =>
      await _sb.getAllActiveBusLocations();
}
