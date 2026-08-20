import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save user profile locally and to Firestore.
  static Future<bool> saveUser({required String name, required int age, required String gender}) async {
    try {
      // Ensure Firebase is initialized before attempting Firestore write
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
      } catch (e) {
        // If initialization fails, proceed to save locally only
      }
      final now = DateTime.now().toUtc();
      final prefs = await SharedPreferences.getInstance();
      // Save locally
      await prefs.setString('user_name', name);
      await prefs.setInt('user_age', age);
      await prefs.setString('user_gender', gender);
      await prefs.setBool('user_saved_to_firestore', false);

      // Attempt to save to Firestore
      final doc = await _db.collection('users').add({
        'name': name,
        'age': age,
        'gender': gender,
        'created_at': now.toIso8601String(),
      });

      // mark saved
      await prefs.setBool('user_saved_to_firestore', true);
      await prefs.setString('user_firestore_doc', doc.id);
      return true;
    } catch (e) {
      // If Firestore write fails, keep local copy and return false
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('user_saved_to_firestore', false);
      } catch (_) {}
      return false;
    }
  }

  /// Return true if we've already saved a user profile locally
  static Future<bool> hasLocalUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user_name');
  }

  /// For automated test: write a sample test user
  static Future<bool> saveTestUser() async {
    return saveUser(name: 'Test', age: 20, gender: 'male');
  }
}
