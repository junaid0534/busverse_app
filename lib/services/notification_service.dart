import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bus_ticket_system/database/db_helper.dart';

// Top-level background handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _isInitialized = false;

  static const String channelId = 'busverse_booking_channel';
  static const String channelName = 'BusVerse Trip & Booking Alerts';
  static const String channelDescription = 'Real-time notifications for bus bookings, ticket confirmations and trip updates';

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize Local Notifications (Android & iOS)
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      // Create Android Notification Channel
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        // Request POST_NOTIFICATIONS runtime permission on Android 13+
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('Local Notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }

    // 2. Initialize FCM Push Notifications (Mobile only)
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        NotificationSettings settings = await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('FCM permission granted');
        }

        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          if (notification != null) {
            showGenericNotification(
              title: notification.title ?? "BusVerse Update",
              body: notification.body ?? "",
            );
          }
        });
      } catch (e) {
        debugPrint('FCM setup error: $e');
      }
    }
  }

  /// 🎟️ Realtime Ticket Booking Confirmation Notification
  Future<void> showBookingNotification({
    required String busName,
    required String fromCity,
    required String toCity,
    required List<dynamic> seats,
    required String date,
    required String passengerName,
    double? fare,
    String? refId,
  }) async {
    try {
      final String seatStr = seats.map((s) => "#$s").join(", ");
      final String fareStr = fare != null ? " • PKR ${fare.toStringAsFixed(0)}" : "";
      final String refStr = refId != null ? "Ref: $refId • " : "";

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final int notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final String title = '🎟️ Booking Confirmed! $fromCity → $toCity';
      final String body = 'Dear $passengerName, your ticket on $busName is confirmed for $date. Seat(s): $seatStr$fareStr. $refStr Have a safe journey with BusVerse!';

      await _localNotifications.show(
        notifId,
        title,
        body,
        platformDetails,
        payload: 'ticket_confirmed',
      );

      // Save notification to local database
      try {
        await DBHelper.instance.insertNotification(
          title: title,
          body: body,
          type: 'booking',
          routeFrom: fromCity,
          routeTo: toCity,
        );
      } catch (e) {
        debugPrint('Error storing booking notification to DB: $e');
      }
    } catch (e) {
      debugPrint('Error showing booking notification: $e');
    }
  }

  /// ❌ Ticket Cancellation Notification
  Future<void> showCancellationNotification({
    required String fromCity,
    required String toCity,
    required String seatNumber,
    String? date,
    String? refId,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      final int notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final String dateStr = (date != null && date.isNotEmpty) ? " for $date" : "";
      final String title = '❌ Ticket Cancelled ($fromCity → $toCity)';
      final String body = 'Your booking for Seat $seatNumber$dateStr (${refId ?? "BusVerse"}) has been cancelled. Refund credited to your wallet.';

      await _localNotifications.show(
        notifId,
        title,
        body,
        platformDetails,
        payload: 'ticket_cancelled',
      );

      // Save notification to local database
      try {
        await DBHelper.instance.insertNotification(
          title: title,
          body: body,
          type: 'cancellation',
          routeFrom: fromCity,
          routeTo: toCity,
        );
      } catch (e) {
        debugPrint('Error storing cancellation notification to DB: $e');
      }
    } catch (e) {
      debugPrint('Error showing cancellation notification: $e');
    }
  }

  /// 🔔 Generic Notification
  Future<void> showGenericNotification({
    required String title,
    required String body,
    String type = 'system',
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      );

      final int notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(notifId, title, body, platformDetails);

      // Save notification to local database
      try {
        await DBHelper.instance.insertNotification(
          title: title,
          body: body,
          type: type,
        );
      } catch (e) {
        debugPrint('Error storing generic notification to DB: $e');
      }
    } catch (e) {
      debugPrint('Error showing generic notification: $e');
    }
  }
}
