// Generated minimal FirebaseOptions for Android using the uploaded
// android/app/google-services.json. This file provides FirebaseOptions
// so `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
// can succeed on Android. Replace or re-generate with the FlutterFire
// CLI for multi-platform support.

import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (Platform.isAndroid) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyCI6JeIbSndk_GzN1zJcXiWovgPR21F3Bs',
        appId: '1:3966940799:android:1eadaf244d1377596d714a',
        messagingSenderId: '3966940799',
        projectId: 'finalhealthmate-mb',
        storageBucket: 'finalhealthmate-mb.firebasestorage.app',
      );
    }
    // Web/iOS/etc not configured in this minimal file.
    return null;
  }
}
