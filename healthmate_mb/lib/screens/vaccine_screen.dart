import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../language_provider.dart';
import '../services/vaccine_service.dart';
import '../services/translate_service.dart';
import 'package:hive/hive.dart';
import 'package:healthmate_mb/l10n/app_localizations.dart';

class VaccineScreen extends StatefulWidget {
  const VaccineScreen({super.key});

  @override
  State<VaccineScreen> createState() => _VaccineScreenState();
}

class _VaccineScreenState extends State<VaccineScreen> {
  DateTime? _dob;
  String _gender = 'female';
  Map<int, String> _translatedNames = {};
  Map<int, String> _translatedStatuses = {};
  // persisted cache per-language: maps language -> map(index -> translated string)
  Map<String, Map<int, String>> _persistedNameCache = {};
  Map<String, Map<int, String>> _persistedStatusCache = {};
  String _currentLang = 'en';

  @override
  void initState() {
    super.initState();
    _loadSaved();
    // After first frame, capture current language and translate recommendations if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = Provider.of<LanguageProvider>(context, listen: false).languageCode;
      _currentLang = lang;
      _translateRecommendationsInBackground();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild when app language changes so localized labels update
    final lang = Provider.of<LanguageProvider>(context).languageCode;
    final prev = _currentLang;
    _currentLang = lang;
    if (prev != _currentLang) {
      // clear previous translations when language changes
      _translatedNames.clear();
      _translatedStatuses.clear();
      // trigger translation pass in background
      _translateRecommendationsInBackground();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final dobStr = prefs.getString('user_dob');
    final gender = prefs.getString('user_gender') ?? 'female';
    if (dobStr != null) {
      final d = DateTime.tryParse(dobStr);
      setState(() {
        _dob = d;
        _gender = gender;
      });
    }
    // Load persisted translation caches (Hive)
    try {
      final box = await Hive.openBox('vaccine_translations');
      final rawNames = box.get('names', defaultValue: {}) as Map?;
      final rawStatuses = box.get('statuses', defaultValue: {}) as Map?;
      if (rawNames != null) {
        rawNames.forEach((lang, m) {
          try {
            final map = Map<int,String>.from((m as Map).map((k,v) => MapEntry(int.parse(k.toString()), v.toString())));
            _persistedNameCache[lang.toString()] = map;
          } catch (_) {}
        });
      }
      if (rawStatuses != null) {
        rawStatuses.forEach((lang, m) {
          try {
            final map = Map<int,String>.from((m as Map).map((k,v) => MapEntry(int.parse(k.toString()), v.toString())));
            _persistedStatusCache[lang.toString()] = map;
          } catch (_) {}
        });
      }
    } catch (_) {}
  }

  Future<void> _save(DateTime? dob) async {
    final prefs = await SharedPreferences.getInstance();
    if (dob != null) await prefs.setString('user_dob', dob.toIso8601String());
    await prefs.setString('user_gender', _gender);
  }

  int _ageYears() {
    if (_dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    if (now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) age--;
    return age;
  }
  // Vaccine recommendations are provided by VaccineService.recommendations(age: gender:)

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 25);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1900), lastDate: now);
    if (picked != null) {
      setState(() => _dob = picked);
      await _save(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _ageYears();
  final recs = VaccineService.recommendations(age: age, gender: _gender);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('vaccine_info'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(child: Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
            Row(children: [
              const Icon(Icons.cake),
              const SizedBox(width: 12),
              Expanded(child: Text(_dob != null ? '${AppLocalizations.of(context).t('dateOfBirth')}: ${_dob!.day}/${_dob!.month}/${_dob!.year}' : AppLocalizations.of(context).t('dob_not_set'))),
              ElevatedButton(onPressed: _pickDob, child: Text(AppLocalizations.of(context).t('set_dob')))
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text('${AppLocalizations.of(context).t('gender')}: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _gender,
                items: [
                  DropdownMenuItem(value: 'female', child: Text(AppLocalizations.of(context).t('female'))),
                  DropdownMenuItem(value: 'male', child: Text(AppLocalizations.of(context).t('male'))),
                ],
                onChanged: (v) async { if (v==null) return; setState(()=>_gender=v); await _save(_dob); },
              ),
            ])
          ]))),
          const SizedBox(height: 12),
          Text('${AppLocalizations.of(context).t('age_label')}: $age ${AppLocalizations.of(context).t('years')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(child: ListView.builder(itemCount: recs.length, itemBuilder: (ctx,i){
            final r = recs[i];
            // colour based on raw status markers used by VaccineService
            Color col = r['status']=='✔ up-to-date' ? Colors.green : r['status']=='⚠ due' ? Colors.orange : Colors.red;
            // localized vaccine name and status (use background-translated overrides when available)
            final baseName = _localizedVaccineName(r['name']!, context);
            final baseStatus = _localizedStatus(r['status']!, context);
            final localName = _translatedNames.containsKey(i) && _translatedNames[i]!.isNotEmpty ? _translatedNames[i]! : baseName;
            final localStatus = _translatedStatuses.containsKey(i) && _translatedStatuses[i]!.isNotEmpty ? _translatedStatuses[i]! : baseStatus;
            final localAge = _localizedAgeDesc(r['age'] ?? '', context);
            return Card(child: ListTile(leading: Icon(Icons.medical_services, color: col), title: Text(localName), subtitle: Text('$localAge • $localStatus')));
          })),
        ]),
      ),
    );
  }

  void _translateRecommendationsInBackground() {
    // Only translate for non-English languages and when TranslateService is available
    if (_currentLang == 'en') return;
    final age = _ageYears();
    final recs = VaccineService.recommendations(age: age, gender: _gender);
    // If we have persisted translations for this language, load them into runtime maps and return
    if (_persistedNameCache.containsKey(_currentLang) || _persistedStatusCache.containsKey(_currentLang)) {
      final names = _persistedNameCache[_currentLang] ?? {};
      final stats = _persistedStatusCache[_currentLang] ?? {};
      _translatedNames = Map.from(names);
      _translatedStatuses = Map.from(stats);
      if (mounted) setState(() {});
      return;
    }
    for (var i = 0; i < recs.length; i++) {
      final r = recs[i];
      final baseName = _localizedVaccineName(r['name']!, context);
      final baseStatus = _localizedStatus(r['status']!, context);
      // Skip translation if already translated
      if (_translatedNames.containsKey(i) || baseName.isEmpty) {
        // still may need status
      }
      // Translate name
      Future(() async {
        try {
          final tn = await TranslateService.translate(baseName, _currentLang);
          if (tn != null && tn.isNotEmpty) {
            _translatedNames[i] = tn;
            if (mounted) setState(() {});
          }
        } catch (_) {}
      });
      // Translate status
      Future(() async {
        try {
          final ts = await TranslateService.translate(baseStatus, _currentLang);
          if (ts != null && ts.isNotEmpty) {
            _translatedStatuses[i] = ts;
            // persist this status for the language
            _persistedStatusCache[_currentLang] = (_persistedStatusCache[_currentLang] ?? {})..[i] = ts;
            try {
              final box = await Hive.openBox('vaccine_translations');
              await box.put('statuses', _persistedStatusCache.map((k,v) => MapEntry(k, v.map((ik,iv) => MapEntry(ik.toString(), iv)))));
            } catch (_) {}
            if (mounted) setState(() {});
          }
        } catch (_) {}
      });
    }
    // after scheduling translations for names, persist any completed name translations as they arrive
    Future(() async {
      // small wait to let the individual translates complete
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final box = await Hive.openBox('vaccine_translations');
        await box.put('names', _persistedNameCache.map((k,v) => MapEntry(k, v.map((ik,iv) => MapEntry(ik.toString(), iv)))));
      } catch (_) {}
    });
  }

  String _localizedVaccineName(String rawName, BuildContext context) {
    final t = AppLocalizations.of(context);
    // Normalize and remove punctuation to improve matching reliability
    var n = rawName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
    if (n.contains('diphtheria') && n.contains('tetanus')) return t.t('vaccine_dpt_full');
    if (n.contains('dpt') || n.contains('diphtheria') || n.contains('pertussis')) return t.t('vaccine_dpt');
    if (n.contains('bcg')) return t.t('vaccine_bcg');
    if (n.contains('opv') || n.contains('ipv')) return t.t('vaccine_opv_ipv');
    if (n.contains('tetanus') && !n.contains('diphtheria')) return t.t('vaccine_tetanus_booster');
    if (n.contains('typhoid')) return t.t('vaccine_typhoid');
    if (n.contains('hpv')) return t.t('vaccine_hpv');
    if (n.contains('influenza') || n.contains('flu')) return t.t('vaccine_influenza');
    if (n.contains('no specific')) return t.t('vaccine_none');
    // fallback to raw name or to a readable English fallback if localization key not present
    // If the localized text looks like a key (contains underscore) then provide a friendly English fallback
    final possibleKey = rawName;
    final localized = t.t(possibleKey);
    if (localized.isNotEmpty && !localized.contains('_') && localized != possibleKey) return localized;
    // friendly English fallbacks for a few well-known keys
    final fallbacks = <String, String>{
      'vaccine_typhoid': 'Typhoid vaccine',
      'vaccine_dpt': 'DPT (Diphtheria, Pertussis, Tetanus)',
      'vaccine_dpt_full': 'DPT (Diphtheria, Pertussis, Tetanus)',
      'vaccine_bcg': 'BCG',
      'vaccine_opv_ipv': 'Polio (OPV/IPV)',
      'vaccine_tetanus_booster': 'Tetanus booster',
      'vaccine_hpv': 'HPV (Human Papillomavirus)',
      'vaccine_influenza': 'Influenza (Flu)',
      'vaccine_none': 'No specific vaccine',
    };
    if (fallbacks.containsKey(possibleKey)) return fallbacks[possibleKey]!;
    return rawName;
  }

  String _localizedStatus(String rawStatus, BuildContext context) {
    final t = AppLocalizations.of(context);
    // Map common raw markers to localizable keys first
    final lowered = rawStatus.toLowerCase();
    String key = '';
    if (lowered.contains('up-to-date') || lowered.contains('up to date') || lowered.contains('✔')) key = 'status_up_to_date';
    else if (lowered.contains('taken')) key = 'status_taken';
    else if (lowered.contains('due') || lowered.contains('⚠')) key = 'status_due';
    if (key.isNotEmpty) {
      final localized = t.t(key);
      if (localized.isNotEmpty && !localized.contains('_') && localized != key) return localized;
      // fallback English phrases
      final fallbacks = {'status_up_to_date': 'Up to date', 'status_taken': 'Taken', 'status_due': 'Due'};
      return fallbacks[key] ?? rawStatus;
    }
    return rawStatus;
  }

  String _localizedAgeDesc(String rawAge, BuildContext context) {
    final t = AppLocalizations.of(context);
    final a = rawAge.toLowerCase();
    if (a.contains('at birth')) return t.t('age_at_birth');
    if (a.contains('every 10')) return t.t('age_every_10_years');
    if (a.contains('annually') || a.contains('annual')) return t.t('age_annually_60');
    if (a.contains('from 2') || a.contains('2 years')) return t.t('age_from_2_years');
    if (a.contains('booster')) return t.t('age_booster_schedule');
    // fallback: return rawAge (will often contain numbers and be fine)
    return rawAge;
  }
}
