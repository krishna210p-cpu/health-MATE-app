import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  // initialize to empty so callers can safely use t() before load()
  Map<String, String> _strings = {};

  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (loc != null) return loc;
    // Fallback: return a default English localization with empty strings
    return AppLocalizations(const Locale('en'));
  }

  Future<bool> load(BuildContext context) async {
    // Compatibility: allow loading via BuildContext or asset bundle directly.
    final name = 'lib/l10n/intl_${locale.languageCode}.arb';
    final data = await rootBundle.loadString(name);
    final Map<String,dynamic> jsonMap = json.decode(data);
    _strings = jsonMap.map((k,v) => MapEntry(k, v.toString()));
    return true;
  }

  // Internal convenience used by the delegate which doesn't have a BuildContext
  Future<bool> loadFromAssets() async {
    final name = 'lib/l10n/intl_${locale.languageCode}.arb';
    try {
      final data = await rootBundle.loadString(name);
      final Map<String,dynamic> jsonMap = json.decode(data);
      _strings = jsonMap.map((k,v) => MapEntry(k, v.toString()));
      return true;
    } catch (e) {
      // fallback to empty strings on error
      _strings = {};
      return false;
    }
  }

  String t(String key) => _strings[key] ?? key;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  // Keep this list in sync with MaterialApp.supportedLocales in main.dart
  @override
  bool isSupported(Locale locale) => ['en','hi','mr','bn','ta','te','kn','ml','gu','pa'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final loc = AppLocalizations(locale);
    await loc.loadFromAssets();
    return loc;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
