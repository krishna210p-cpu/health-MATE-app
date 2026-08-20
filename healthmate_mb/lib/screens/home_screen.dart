import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/news_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../language_provider.dart';
import 'dart:async';
import 'package:healthmate_mb/l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'settings_screen.dart';
import '../services/in_app_message_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/sos_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// ...news UI moved to HealthNewsScreen; related imports removed
import 'saved_screen.dart';
import 'nearby_screen.dart';
import 'report_screen.dart';
import 'book_screen.dart';
import 'vaccine_screen.dart';
import '../health_news_screen.dart';
import '../health_campaigns_screen.dart';
import '../services/user_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NewsService _newsService = NewsService();
  List<Article> _articles = [];
  String _emergencyNumber = '112';
  // news loading moved to HealthNewsScreen
  DateTime? _lastUpdated;
  String _currentLang = 'en';
  String _selectedScope = 'All';
  String _userName = 'User';
  int _healthScore = 86;
  late final _LifecycleEventHandler _lifecycleHandler;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh on resume
    _lifecycleHandler = _LifecycleEventHandler(resumeCallBack: () async => await _load());
    WidgetsBinding.instance.addObserver(_lifecycleHandler);
    // After initial load, check for in-app messages to show
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Avoid awaiting with BuildContext across async gaps by using then() and local context capture
      final ctx = context;
      InAppMessageService.checkAndShowMessages(ctx, 'app_start').then((_) {
        if (_lastUpdated == null) InAppMessageService.checkAndShowMessages(ctx, 'first_open');
      }).catchError((_){});
    });
    // prompt for user profile after first frame (MaterialApp is available)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Avoid awaiting with BuildContext across async gaps in post frame callbacks
      _maybeCollectUserProfile();
      // Fire and forget local delay
      Future.delayed(const Duration(milliseconds: 300)).catchError((_){});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleHandler);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload feed when app language changes
    try {
      final lang = Provider.of<LanguageProvider>(context).languageCode;
      if (lang != _currentLang) {
        _currentLang = lang;
        // fire-and-forget reload
        _load();
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final dynamic rawConn = await Connectivity().checkConnectivity();
    ConnectivityResult conn;
    if (rawConn is List && rawConn.isNotEmpty) {
      // Some plugin versions or platforms may return a list; take the first entry
      conn = rawConn.first as ConnectivityResult;
    } else if (rawConn is ConnectivityResult) {
      conn = rawConn;
    } else {
      // Fallback: assume connected
      conn = ConnectivityResult.wifi;
    }
    if (conn == ConnectivityResult.none) {
      _articles = await _newsService.loadCachedArticles();
      // read cached last_updated from Hive
      try {
        final box = await Hive.openBox('articles_box');
        final lu = box.get('last_updated');
        if (lu is String) _lastUpdated = DateTime.tryParse(lu);
      } catch (_) {}
    } else {
      // Use LanguageProvider to get current language
      String lang = 'en';
      try {
        final providerLang = Provider.of<LanguageProvider>(context, listen: false).languageCode;
        if (_currentLang != providerLang) {
          _currentLang = providerLang;
          // ignore: avoid_print
          print('Language set to $_currentLang - reloading feed');
        }
        lang = _currentLang;
      } catch (_) {
        // Fallback to SharedPreferences if Provider not available
        final prefsFallback = await SharedPreferences.getInstance();
        lang = prefsFallback.getString('language_code') ?? 'en';
        if (_currentLang != lang) _currentLang = lang;
      }
      final prefs = await SharedPreferences.getInstance();
      _emergencyNumber = prefs.getString('emergency_number') ?? '112';
      _userName = prefs.getString('user_name') ?? _userName;
      final dobStr = prefs.getString('user_dob');
      if (dobStr != null) {
        try {
          final dob = DateTime.parse(dobStr);
          final age = DateTime.now().difference(dob).inDays ~/ 365;
          _healthScore = (100 - (age.clamp(0, 80))).clamp(40, 99);
        } catch (_) {}
      }

      // Try to fetch fresh data but fall back to cache quickly if network is slow.
      try {
  // Attempt network fetch (timeout quickly). Log results.
  // ignore: avoid_print
  print('NewsService: fetching with lang=$lang scope=$_selectedScope');
  final results = await _newsService.getArticles(forceRefresh: true, lang: lang, scope: _selectedScope).timeout(const Duration(seconds: 8));
  // Count by source for logs
  final counts = <String,int>{};
  for (final it in results) { counts[it.source] = (counts[it.source] ?? 0) + 1; }
  // ignore: avoid_print
  print('NewsService: fetched ${results.length} items; bySource=$counts');
        if (results.isNotEmpty) {
          _articles = results;
          await _newsService.cacheArticlesForLang(_articles, lang);
          _lastUpdated = DateTime.now();
        } else {
          _articles = await _newsService.loadCachedArticlesForLang(lang);
          // read cached last_updated from Hive for this language
          try {
            final box = await Hive.openBox('articles_box');
            final lu = box.get('last_updated_$lang');
            if (lu is String) _lastUpdated = DateTime.tryParse(lu) ?? DateTime.now();
          } catch (_) { _lastUpdated = DateTime.now(); }
        }
      } catch (e) {
        // On timeout or error use cache immediately and kick off a background refresh
        _articles = await _newsService.loadCachedArticlesForLang(lang);
        _lastUpdated = DateTime.now();
        _newsService.getArticles(forceRefresh: true, lang: lang, scope: _selectedScope).then((fresh) async {
          if (fresh.isNotEmpty) {
            await _newsService.cacheArticlesForLang(fresh, lang);
            setState(() {
              _articles = fresh..sort((a,b)=>b.publishedDate.compareTo(a.publishedDate));
              _lastUpdated = DateTime.now();
            });
          }
        }).catchError((_){});
      }
    }
    // Ensure newest first
    _articles.sort((a,b) => b.publishedDate.compareTo(a.publishedDate));
  if (!mounted) return;
  setState(() {});
  }

  Future<void> _maybeCollectUserProfile() async {
    try {
      final has = await UserService.hasLocalUser();
      if (has) return;
      if (!mounted) return;
      final result = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) {
        final nameCtrl = TextEditingController();
        final ageCtrl = TextEditingController();
        String gender = 'male';
        return AlertDialog(
            title: Text(AppLocalizations.of(ctx).t('welcome_dialog_title')),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(ctx).t('label_name'))),
              TextField(controller: ageCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(ctx).t('age_label')), keyboardType: TextInputType.number),
              StatefulBuilder(builder: (c, setS) => DropdownButton<String>(value: gender, items: [DropdownMenuItem(value: 'male', child: Text(AppLocalizations.of(ctx).t('male'))), DropdownMenuItem(value: 'female', child: Text(AppLocalizations.of(ctx).t('female')))], onChanged: (v){ if (v!=null) setS(()=>gender=v); })),
            ]),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: Text(AppLocalizations.of(ctx).t('skip'))), TextButton(onPressed: () => Navigator.of(ctx).pop({'name': nameCtrl.text, 'age': int.tryParse(ageCtrl.text) ?? 0, 'gender': gender}), child: Text(AppLocalizations.of(ctx).t('save')))],
          );
      });
      if (result != null) {
        final ok = await UserService.saveUser(name: result['name'] ?? 'User', age: result['age'] ?? 0, gender: result['gender'] ?? 'male');
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Your data has been saved successfully!')));
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save user data to Firestore (saved locally).')));
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('User profile collection failed: $e');
    }
  }

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // News feed rendering was moved to HealthNewsScreen so Home no longer renders inline news.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('appTitle')),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedScreen())), icon: const Icon(Icons.bookmark)),
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NearbyScreen())), icon: const Icon(Icons.map)),
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings))
        ],
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () async {
          if (!mounted) return;
          showModalBottomSheet(
            context: context,
            builder: (ctx) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.call),
                      title: Text(AppLocalizations.of(context).t('call_emergency')),
                      onTap: () async {
                          Navigator.of(ctx).pop();
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await SOSService.openDialer(_emergencyNumber);
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('call_emergency'))));
                          }
                        },
                    ),
                    ListTile(
                      leading: const Icon(Icons.sms),
                      title: Text(AppLocalizations.of(context).t('send_sos_sms')),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final messenger = ScaffoldMessenger.of(context);
                        final pos = await SOSService.getLocation();
                        final msg = pos != null ? 'SOS: I need help. My location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}' : 'SOS: I need help.';
                        try {
                          await SOSService.sendSms(_emergencyNumber, msg);
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('send_sos_sms'))));
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        child: FloatingActionButton.extended(
          onPressed: () async {
            final Uri tel = Uri(scheme: 'tel', path: _emergencyNumber);
            final messenger = ScaffoldMessenger.of(context);
              try {
              final launched = await launchUrl(tel);
              if (!launched) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('could_not_open_dialer'))));
              }
            } catch (e) {
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('could_not_open_dialer'))));
            }
          },
          label: Text(AppLocalizations.of(context).t('emergency')),
          icon: const Icon(Icons.call),
          backgroundColor: Colors.redAccent,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Greeting + Health Score
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Allow long localized greetings to wrap safely
                            Text(
                              AppLocalizations.of(context).t('greeting').replaceAll('{name}', _userName),
                              style: Theme.of(context).textTheme.headlineSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(_lastUpdated != null ? '${AppLocalizations.of(context).t('lastUpdated')}: ${_formatAgo(_lastUpdated!)}' : '${AppLocalizations.of(context).t('lastUpdated')}: --', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          children: [
                            Text(AppLocalizations.of(context).t('healthScore'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('$_healthScore', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ChoiceChip(label: Text(AppLocalizations.of(context).t('all')), selected: _selectedScope=='All', onSelected: (v){ setState(()=>_selectedScope='All'); _load();}),
                  const SizedBox(width:8),
                  ChoiceChip(label: Text(AppLocalizations.of(context).t('local')), selected: _selectedScope=='Local', onSelected: (v){ setState(()=>_selectedScope='Local'); _load();}),
                  const SizedBox(width:8),
                  ChoiceChip(label: Text(AppLocalizations.of(context).t('national')), selected: _selectedScope=='National', onSelected: (v){ setState(()=>_selectedScope='National'); _load();}),
                  const SizedBox(width:8),
                  ChoiceChip(label: Text(AppLocalizations.of(context).t('international')), selected: _selectedScope=='International', onSelected: (v){ setState(()=>_selectedScope='International'); _load();}),
                ],),
              ),

              // Campaigns quick card (appears as the first prominent option)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthCampaignsScreen())),
                child: Card(
                  color: Colors.teal[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(children: [
                      const Icon(Icons.event, size: 28, color: Colors.teal),
                      const SizedBox(width: 12),
                      Expanded(child: Text(AppLocalizations.of(context).t('campaigns'), style: Theme.of(context).textTheme.headlineSmall)),
                      const Icon(Icons.chevron_right, color: Colors.grey)
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick actions (moved up to sit directly below Campaigns as requested)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(onPressed: () async { final Uri tel = Uri(scheme: 'tel', path: _emergencyNumber); await launchUrl(tel); }, icon: const Icon(Icons.call), label: Text(AppLocalizations.of(context).t('emergency')), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent)),
                      ElevatedButton.icon(onPressed: () async { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NearbyScreen())); }, icon: const Icon(Icons.local_hospital), label: Text(AppLocalizations.of(context).t('nearby'))),
                      ElevatedButton.icon(onPressed: () async { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthNewsScreen())); }, icon: const Icon(Icons.health_and_safety), label: Text(AppLocalizations.of(context).t('topStories'))),
                      ElevatedButton.icon(onPressed: () async { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportScreen())); }, icon: const Icon(Icons.report), label: Text(AppLocalizations.of(context).t('report'))),
                      ElevatedButton.icon(onPressed: () async { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaccineScreen())); }, icon: const Icon(Icons.vaccines), label: Text(AppLocalizations.of(context).t('vaccine_info'))),
                      ElevatedButton.icon(onPressed: () async { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthCampaignsScreen())); }, icon: const Icon(Icons.event), label: Text(AppLocalizations.of(context).t('campaigns'))),
                      ElevatedButton.icon(onPressed: () async { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookScreen())); }, icon: const Icon(Icons.calendar_today), label: Text(AppLocalizations.of(context).t('book'))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function()? resumeCallBack;
  _LifecycleEventHandler({this.resumeCallBack});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (resumeCallBack != null) resumeCallBack!();
    }
  }

}
