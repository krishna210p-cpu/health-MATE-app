import 'package:flutter/material.dart';
import '../main.dart';
import 'main_scaffold.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../language_provider.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  // Only show languages we have ARB files for right now.
  final List<Map<String,String>> languages = [
    {'code':'en','name':'English'},
    {'code':'hi','name':'हिन्दी'},
    {'code':'mr','name':'मराठी'},
    {'code':'bn','name':'বাংলা'},
    {'code':'gu','name':'ગુજરાતી'},
    {'code':'ta','name':'தமிழ்'},
  ];

  void _chooseLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    if (!mounted) return;
    // Load localized strings for the chosen locale, then replace route stack with Home
    await AppLocalizations(Locale(code)).loadFromAssets();
    // Update the Provider so widgets update; don't depend on the healthmateAppKey internals
    try {
      final ctx = healthmateAppKey.currentContext ?? context;
      Provider.of<LanguageProvider>(ctx, listen: false).setLanguage(code);
    } catch (_) {}

    // Replace routes with MainScaffold so the bottom navigation is available
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainScaffold()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    // load localization strings for this locale
    // AppLocalizations.load is safe to call in build; implementation is defensive
    AppLocalizations.of(context).load(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('selectLanguage'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(AppLocalizations.of(context).t('selectLanguage'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ...languages.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical:8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56), textStyle: const TextStyle(fontSize:18)),
                    onPressed: () => _chooseLanguage(l['code']!),
                    child: Text(l['name']!),
                  ),
                ))
              ],
            ),
          ),
        ),
      ),
    );
  }
}
