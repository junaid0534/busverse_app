import 'dart:io';
import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:bus_ticket_system/database/db_helper.dart';

// AUTH SCREENS
import 'package:bus_ticket_system/screens/splash_screen.dart';
import 'package:bus_ticket_system/screens/auth/welcome_screen.dart';
import 'package:bus_ticket_system/screens/auth/login_screen.dart';
import 'package:bus_ticket_system/screens/auth/signup_screen.dart';
import 'package:bus_ticket_system/screens/auth/welcome_login_screen.dart';

// USER SCREENS
import 'package:bus_ticket_system/user/screens/search_bus_screen.dart';
import 'package:bus_ticket_system/user/screens/available_buses_screen.dart';
import 'package:bus_ticket_system/user/screens/book_seat_screen.dart';
import 'package:bus_ticket_system/user/screens/passenger_detail_screen.dart';
import 'package:bus_ticket_system/user/screens/payment_screen.dart';
import 'package:bus_ticket_system/user/screens/view_ticket_screen.dart';
import 'package:bus_ticket_system/user/screens/my_tickets_screen.dart';
import 'package:bus_ticket_system/user/screens/notifications_screen.dart';
import 'package:bus_ticket_system/user/screens/no_bus_found_screen.dart';
import 'package:bus_ticket_system/user/screens/cargo_tracking_screen.dart';
import 'package:bus_ticket_system/user/screens/support_screen.dart';
import 'package:bus_ticket_system/user/screens/complain_screen.dart';
import 'package:bus_ticket_system/user/screens/feedback_screen.dart';

// ACCOUNT SCREENS
import 'package:bus_ticket_system/user/screens/my_account_screen.dart';
import 'package:bus_ticket_system/user/screens/edit_basic_info_screen.dart'; // Single all-in-one edit screen

// WALLET SCREENS
import 'package:bus_ticket_system/user/screens/my_wallet_screen.dart';
import 'package:bus_ticket_system/user/screens/topup_wallet_screen.dart';

// ADMIN SCREENS
import 'package:bus_ticket_system/admin/screens/admin_login_screen.dart';
import 'package:bus_ticket_system/admin/screens/admin_dashboard_screen.dart';
import 'package:bus_ticket_system/admin/screens/buses/manage_buses_screen.dart';
import 'package:bus_ticket_system/admin/screens/buses/add_edit_bus_screen.dart';
import 'package:bus_ticket_system/admin/screens/all_users_screen.dart';
import 'package:bus_ticket_system/admin/screens/routes/manage_routes_screen.dart';
import 'package:bus_ticket_system/admin/screens/routes/add_edit_route_screen.dart';
import 'package:bus_ticket_system/admin/screens/bookings/view_all_booking_screen.dart';

// NEW ADMIN SCREENS
import 'package:bus_ticket_system/admin/screens/admin_feedback_screen.dart';
import 'package:bus_ticket_system/admin/screens/admin_complains_screen.dart';
import 'package:bus_ticket_system/admin/screens/sub_admins/manage_sub_admins_screen.dart';
import 'package:bus_ticket_system/admin/screens/sub_admins/add_edit_sub_admin_screen.dart';
import 'package:bus_ticket_system/sub_admin/screens/sub_admin_dashboard_screen.dart';
import 'package:bus_ticket_system/sub_admin/screens/counter_ticket_booking_screen.dart';
import 'package:bus_ticket_system/sub_admin/screens/counter_search_bus_screen.dart';

// BACKEND CONFIG & SERVICES
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:bus_ticket_system/config/backend_config.dart';
import 'package:bus_ticket_system/services/notification_service.dart';

// DB FFI for desktop
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite Desktop FFI
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: BackendConfig.supabaseUrl,
      anonKey: BackendConfig.supabaseAnonKey,
    );
    print('Supabase initialized successfully');
  } catch (e) {
    print('Supabase initialization error: $e');
  }

  // Initialize Firebase (on Android / iOS)
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      await Firebase.initializeApp();
      await NotificationService.instance.initialize();
      print('Firebase initialized successfully');
    }
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus Ticket System',
      initialRoute: '/splash',
      routes: {
        // ================= SPLASH & AUTH =================
        '/splash': (context) => const SplashScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/welcome_login': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String userEmail = '';
          if (args != null && args is Map && args['userEmail'] != null) {
            userEmail = args['userEmail'];
          }
          return WelcomeLoginScreen(userEmail: userEmail);
        },

        // ================= USER =================
        '/search_bus': (context) => const SearchBusScreen(),
        '/cargo_tracking': (context) => const CargoTrackingScreen(),
        '/available_buses': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return AvailableBusesUserScreen(
            buses: args['buses'],
            selectedDate: args['selectedDate'],
            userId: args['userId'],
          );
        },
        '/no_bus_found': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return NoBusFoundScreen(
            fromCity: args['fromCity'],
            toCity: args['toCity'],
            selectedDate: args['selectedDate'],
            busClass: args['busClass'] ?? 'All Types',
            userId: args['userId'] ?? 1,
          );
        },
        '/book_seat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return BookSeatScreen(
            bus: args['bus'],
            selectedDate: args['selectedDate'],
            userId: args['userId'],
          );
        },
        '/passenger_details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return PassengerDetailScreen(
            bus: args['bus'],
            selectedSeats: List<int>.from(args['selectedSeats']),
            date: args['date'],
            genderMap: args['genderMap'] != null ? Map<int, String>.from(args['genderMap']) : null,
            userId: args['userId'],
          );
        },
        '/payment': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return PaymentScreen(
            bus: args['bus'],
            selectedSeats: List<int>.from(args['selectedSeats']),
            date: args['date'],
            passengerData: args['passengerData'],
          );
        },
        '/view_ticket': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return ViewTicketScreen(ticketData: args['ticketData']);
        },
        '/my_tickets': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return MyTicketsScreen(
            userId: args['userId'],
            userEmail: args['userEmail'],
          );
        },
        '/notifications': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          return NotificationsScreen(
            userId: args['userId'] ?? 1,
            userEmail: args['userEmail'] ?? '',
          );
        },

        // ================= WALLET =================
        '/my_wallet': (context) => const MyWalletScreen(),
        '/topup_wallet': (context) => const TopupWalletScreen(),

        // ================= SUPPORT, COMPLAINTS & FEEDBACK =================
        '/support': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          return SupportScreen(userId: args['userId'] ?? 0);
        },
        '/complain': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          return ComplainScreen(userId: args['userId'] ?? 0);
        },
        '/feedback': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          return FeedbackScreen(userId: args['userId'] ?? 0);
        },

        // ================= ACCOUNT SCREENS =================
        '/my_account': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return MyAccountScreen(
            userId: args['userId'],
            userEmail: args['userEmail'],
          );
        },
        '/edit_basic_info': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return EditBasicInfoScreen(
            userId: args['userId'],
            userEmail: args['userEmail'],
          );
        },

        // ================= ADMIN =================
        '/admin_login': (context) => const AdminLoginScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/manage_buses': (context) => const ManageBusesScreen(),
        '/manage_routes': (context) => const ManageRoutesScreen(),
        '/add_edit_route': (context) => const AddEditRouteScreen(),
        '/add_edit_bus': (context) => const AddEditBusScreen(),
        '/view_all_booking': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
          return ViewAllBookingScreen(
            busId: args['busId'],
            fromCity: args['fromCity'],
            toCity: args['toCity'],
            date: args['date'],
          );
        },
        '/all_users': (context) => const AllUsersScreen(),

        // NEW ADMIN ROUTES
        '/admin_feedbacks': (context) => const AdminFeedbackScreen(),
        '/admin_complains': (context) => const AdminComplainsScreen(),
        '/manage_sub_admins': (context) => const ManageSubAdminsScreen(),
        '/add_edit_sub_admin': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return AddEditSubAdminScreen(existing: args);
        },
        '/sub_admin_dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return SubAdminDashboardScreen(userProfile: args);
        },
        '/counter_ticket_booking': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CounterTicketBookingScreen(userProfile: args);
        },
        '/counter_search_bus': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CounterSearchBusScreen(userProfile: args);
        },
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('404 - Page Not Found', style: TextStyle(fontSize: 24)),
            ),
          ),
        );
      },
    );
  }
}