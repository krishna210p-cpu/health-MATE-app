import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This handler must be a top-level function. Keep it lightweight.
  log('Handling a background message: ${message.messageId}');
}
