import 'dart:io';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

// ...existing code...

class PushService {
  static FirebaseMessaging? _messaging;
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static bool _localInitialized = false;

  /// Initialize push service. This will attempt to wire up Firebase Messaging
  /// and local notifications. If Firebase is not configured (e.g. missing
  /// firebase_options.dart or google-services.json), initialization will fail
  /// gracefully and the app can continue to run without push support.
  static Future<void> init() async {
    try {
      _messaging = FirebaseMessaging.instance;

      // Request permissions on iOS only if Firebase initialized
      if (Platform.isIOS && Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      }

      // Android local notifications setup (guarded)
      try {
        // Use the default launcher icon name; adjust if your project uses a
        // different resource name. Some OEMs or build setups may omit the
        // expected resource which causes a native NPE; we catch that.
        const android = AndroidInitializationSettings('ic_launcher');
        const ios = DarwinInitializationSettings();
        await _local.initialize(const InitializationSettings(android: android, iOS: ios));
        _localInitialized = true;
      } catch (e, st) {
        // ignore: avoid_print
        print('Local notifications init failed: $e\n$st');
        _localInitialized = false;
      }

      // Request notifications permission on Android 13+ (Tiramisu)
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }

      // Create a default notification channel for Android
      const androidChannel = AndroidNotificationChannel('healthmate_alerts', 'Healthmate Alerts', importance: Importance.high);
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);

      // Obtain FCM token and subscribe only if Firebase is available
      if (Firebase.apps.isNotEmpty) {
        try {
          _messaging = FirebaseMessaging.instance;
          final token = await _messaging?.getToken();
          // ignore: avoid_print
          print('FCM token: $token');
          if (token != null) {
            // In production send token to your server
          }
          // Subscribe to a global topic for critical alerts (best-effort)
          await _messaging?.subscribeToTopic('healthmate_all');
        } catch (e, st) {
          // ignore: avoid_print
          print('Failed to get/subscribe token: $e\n$st');
        }
      } else {
        // ignore: avoid_print
        print('Firebase not initialized; skipping FCM token fetch/subscription');
      }

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          if (_localInitialized) _showLocalNotification(message);
        } catch (e, st) {
          // ignore: avoid_print
          print('Error showing local notification: $e\n$st');
        }
      });

      // Handle when the user taps a notification and opens the app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // The app can inspect message.data to route to specific screens.
        // For example: if (message.data['screen'] == 'article') navigate to article.
        // We'll only print for now; UI can call PushService.handleMessageOpen to
        // perform navigation logic when appropriate.
        // ignore: avoid_print
        print('Notification opened with data: ${message.data}');
      });
    } catch (e, st) {
      // If Firebase isn't configured, we don't want to crash the app.
      // ignore: avoid_print
      print('PushService.init failed (push disabled): $e\n$st');
      _messaging = null;
    }
  }

  /// Returns the FCM token or null if unavailable.
  static Future<String?> getToken() async {
    if (_messaging == null) return null;
    try {
      return await _messaging?.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Copy the FCM token to clipboard for easy testing.
  static Future<bool> copyTokenToClipboard(BuildContext context) async {
    final token = await getToken();
    if (token == null) {
      // ignore: avoid_print
      print('No FCM token available to copy');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FCM token not available')));
      }
      return false;
    }
    await Clipboard.setData(ClipboardData(text: token));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FCM token copied to clipboard')));
    }
    return true;
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails('healthmate_alerts', 'Healthmate Alerts', importance: Importance.max, priority: Priority.high);
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _local.show(notification.hashCode, notification.title ?? 'Healthmate', notification.body ?? '', details, payload: message.data.isNotEmpty ? message.data.toString() : null);
    } catch (e, st) {
      // ignore: avoid_print
      print('Failed to show local notification: $e\n$st');
    }
  }

  /// Show a simulated local notification (useful for quick manual testing
  /// when Firebase isn't configured). `title` and `body` are shown in a
  /// platform notification.
  static Future<void> simulateLocalNotification({required String title, required String body}) async {
    if (!_localInitialized) {
      // ignore: avoid_print
      print('Local notifications not initialized; cannot simulate notification');
      return;
    }
    try {
      final androidDetails = AndroidNotificationDetails('healthmate_alerts', 'Healthmate Alerts', importance: Importance.max, priority: Priority.high);
      const iosDetails = DarwinNotificationDetails();
      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _local.show(DateTime.now().millisecondsSinceEpoch.remainder(100000), title, body, details);
    } catch (e, st) {
      // ignore: avoid_print
      print('simulateLocalNotification failed: $e\n$st');
    }
  }
}
