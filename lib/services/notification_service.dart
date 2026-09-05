import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level background handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // FCM only runs on mobile/web natively, skip on Windows/Linux desktop to avoid crashes
    if (!Platform.isAndroid && !Platform.isIOS) {
      print('FCM: Push notifications skipped on Desktop platform');
      return;
    }

    try {
      // Request permission for push notifications
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      }

      // Background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received foreground notification: ${message.notification?.title}');
      });

      // Get device FCM token
      String? token = await _fcm.getToken();
      print('FCM Token: $token');
    } catch (e) {
      print('FCM Initialization error: $e');
    }
  }
}
