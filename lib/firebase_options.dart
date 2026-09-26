// File generated for Firebase Multi-Platform configuration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD4lQ2euwoeGwoRrY0jCk0CZ4_u_3L9QIE',
    appId: '1:571944175728:web:b1d8350bb9183952afccb5',
    messagingSenderId: '571944175728',
    projectId: 'busverse-app',
    authDomain: 'busverse-app.firebaseapp.com',
    storageBucket: 'busverse-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD4lQ2euwoeGwoRrY0jCk0CZ4_u_3L9QIE',
    appId: '1:571944175728:android:65f1d5241fd117d0afccb5',
    messagingSenderId: '571944175728',
    projectId: 'busverse-app',
    storageBucket: 'busverse-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD4lQ2euwoeGwoRrY0jCk0CZ4_u_3L9QIE',
    appId: '1:571944175728:ios:65f1d5241fd117d0afccb5',
    messagingSenderId: '571944175728',
    projectId: 'busverse-app',
    storageBucket: 'busverse-app.firebasestorage.app',
    iosBundleId: 'com.busverse.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD4lQ2euwoeGwoRrY0jCk0CZ4_u_3L9QIE',
    appId: '1:571944175728:web:b1d8350bb9183952afccb5',
    messagingSenderId: '571944175728',
    projectId: 'busverse-app',
    authDomain: 'busverse-app.firebaseapp.com',
    storageBucket: 'busverse-app.firebasestorage.app',
  );
}
