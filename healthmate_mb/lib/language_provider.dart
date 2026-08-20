import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _languageCode = 'en'; // default English

  String get languageCode => _languageCode;

  void setLanguage(String code) {
    _languageCode = code;
    // persist selection so app restarts remember it
    try {
      SharedPreferences.getInstance().then((prefs) => prefs.setString('language_code', code));
    } catch (_) {}
    notifyListeners();
    // Note: FCM topic subscription is handled by PushService when Firebase is available.
  }

  // Load saved language from SharedPreferences if available
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('language_code');
      if (code != null && code.isNotEmpty) {
        _languageCode = code;
        notifyListeners();
      }
    } catch (_) {}
  }
}
