import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/push_service.dart';
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/push_background.dart';

import 'firebase_options.dart';

// Global key so screens can update the app locale at runtime without restart.
// Use an untyped GlobalKey to avoid referencing a private state type in a public API.
final GlobalKey healthmateAppKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize quick, lightweight parts first so we can show UI.
  await Hive.initFlutter();

  // Start the app immediately; perform heavier service initialization
  // asynchronously so native splash and first paint aren't delayed.
  final langProvider = LanguageProvider();
  // initialize provider (loads saved language)
  await langProvider.init();
  runApp(
    ChangeNotifierProvider(create: (_) => langProvider, child: HealthmateApp(key: healthmateAppKey)),
  );

  // Do heavier, non-blocking initialization after the app has started.
  // Use microtask so initialization runs shortly after first frame without
  // blocking UI.
  Future.microtask(() => _initializeServices());
}

// _AppLifecycleObserver removed (unused) - lifecycle handling uses other helpers in the codebase.

// Keep a separate async initializer so we don't block runApp.
Future<void> _initializeServices() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    // If Firebase isn't configured or initialization fails, log and continue
    // so the app can still run (we have a shim for non-configured builds).
    // ignore: avoid_print
    print('Firebase.initializeApp failed: $e\n$st');
    return;
  }

  // Register background message handler for Firebase Messaging
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    // ignore: avoid_print
    print('Failed to register background handler: $e');
  }

  // Initialize push notifications (Firebase Messaging + local notifications)
  try {
    await PushService.init();
  } catch (e) {
    // ignore errors during initialization in development
    // ignore: avoid_print
    print('PushService.init failed: $e');
  }
}

class HealthmateApp extends StatefulWidget {
  const HealthmateApp({super.key});

  @override
  State<HealthmateApp> createState() => _HealthmateAppState();
}

class _HealthmateAppState extends State<HealthmateApp> {
  Locale? _locale;

  void setLocale(Locale? locale) {
    setState(() => _locale = locale);
  }

  @override
  void initState() {
    super.initState();
    // After first frame, ensure AppLocalizations loads the current provider language
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final providerLang = Provider.of<LanguageProvider>(context, listen: false).languageCode;
        // Preload assets for the current language so onGenerateTitle and other early widgets
        // get localized strings immediately when locale changes at runtime.
        AppLocalizations(Locale(providerLang)).loadFromAssets();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final providerLang = Provider.of<LanguageProvider>(context).languageCode;
    final activeLocale = _locale ?? Locale(providerLang);

    return MaterialApp(
      onGenerateTitle: (ctx) {
        try {
          final title = AppLocalizations.of(ctx).t('appTitle');
          // If the delegate hasn't loaded strings yet it returns the key itself.
          if (title == 'appTitle' || title.trim().isEmpty) return 'Healthmate';
          return title;
        } catch (_) {
          return 'Healthmate';
        }
      },
      locale: activeLocale,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        // AppLocalizations delegate
        AppLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('bn'),
        Locale('gu'),
        Locale('mr'),
        Locale('ta'),
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF0F9D8A),
          onPrimary: Colors.white,
          secondary: Color(0xFFAAF0DB),
          onSecondary: Colors.black87,
          error: Color(0xFFEB5757),
          onError: Colors.white,
          background: Color(0xFFFAFAFA),
          onBackground: Color(0xFF1F2937),
          surface: Colors.white,
          onSurface: Color(0xFF1F2937),
        ),
        textTheme: GoogleFonts.interTextTheme(const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF1F2937), fontSize: 16, height: 1.5),
          bodySmall: TextStyle(color: Color(0xFF4B5563), fontSize: 14, height: 1.5),
          headlineSmall: TextStyle(color: Color(0xFF0F172A), fontSize: 32, fontWeight: FontWeight.bold, height: 1.1),
          titleLarge: TextStyle(color: Color(0xFF111827), fontSize: 22, fontWeight: FontWeight.w600, height: 1.25),
        )),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFF0F9D8A), width: 1.8)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFFEB5757), width: 1.8)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16)), borderSide: BorderSide(color: Color(0xFFEB5757), width: 1.8)),
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          prefixIconColor: Color(0xFF64748B),
          suffixIconColor: Color(0xFF0F9D8A),
        ),
      ),
      home: SplashScreen(
        key: const Key('rootSplash'),
      ),
    );
  }
}
