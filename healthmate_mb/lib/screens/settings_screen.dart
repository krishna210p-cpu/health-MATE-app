import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import 'language_selection.dart';
import 'today_tip_screen.dart';
import 'account_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TextEditingController();
  final _emergencyController = TextEditingController();
  String _userName = '';
  DateTime? _userDob;
  String _userGender = 'female';
  // token removed - not used in this trimmed settings UI

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _controller.text = prefs.getString('newsapi_key') ?? '';
    _emergencyController.text = prefs.getString('emergency_number') ?? '112';
    _userName = prefs.getString('user_name') ?? '';
    final dobStr = prefs.getString('user_dob');
    if (dobStr != null) _userDob = DateTime.tryParse(dobStr);
    _userGender = prefs.getString('user_gender') ?? 'female';
  if (!mounted) return;
  setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('newsapi_key', _controller.text.trim());
    await prefs.setString('emergency_number', _emergencyController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).t('settings_title')} ${AppLocalizations.of(context).t('save')}')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('settings_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Profile header
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(_userName.isNotEmpty ? _userName : AppLocalizations.of(context).t('profile')),
                  subtitle: Text('${AppLocalizations.of(context).t('account')}: ${_userDob != null ? '${_userDob!.day}/${_userDob!.month}/${_userDob!.year}' : '--'} • ${_userGender[0].toUpperCase()}${_userGender.substring(1)}'),
                  trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _editProfile),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications),
                      title: Text(AppLocalizations.of(context).t('notifications')),
                      subtitle: Text(AppLocalizations.of(context).t('todayTip')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TodayTipScreen())); },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.call),
                      title: Text(AppLocalizations.of(context).t('emergency')),
                      subtitle: Text(_emergencyController.text.isNotEmpty ? _emergencyController.text : '112'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(onPressed: _editEmergencyNumber, icon: const Icon(Icons.edit)),
                        IconButton(onPressed: _testCall, icon: const Icon(Icons.phone)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height:12),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(AppLocalizations.of(context).t('selectLanguage')),
                    subtitle: Text(AppLocalizations.of(context).t('app_language')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      // open language selector
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(AppLocalizations.of(context).t('account')),
                    subtitle: Text(AppLocalizations.of(context).t('settings_title')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen())); },
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // Small actions: Save API key and test notifications
              Row(children: [Expanded(child: ElevatedButton(onPressed: _save, child: Text(AppLocalizations.of(context).t('save')))), const SizedBox(width:8), ElevatedButton.icon(onPressed: () async { await PushService.simulateLocalNotification(title: AppLocalizations.of(context).t('topStories'), body: AppLocalizations.of(context).t('todayTip')); }, icon: const Icon(Icons.notifications_active), label: Text(AppLocalizations.of(context).t('notifications')))])
            ],
          ),
        ),
      ),
    );
  }

  // Profile display helpers removed; using local state variables instead.

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _userName);
    DateTime? dob = _userDob;
    String gender = _userGender;
    final result = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context).t('account')),
        content: StatefulBuilder(builder: (c, setSt) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: AppLocalizations.of(context).t('name'))),
            const SizedBox(height:8),
            Row(children: [Expanded(child: Text(dob == null ? AppLocalizations.of(context).t('dateOfBirth') : '${dob!.day}/${dob!.month}/${dob!.year}')), IconButton(onPressed: () async { final picked = await showDatePicker(context: ctx, initialDate: dob ?? DateTime(1990), firstDate: DateTime(1900), lastDate: DateTime.now()); if (picked != null) setSt(()=> dob = picked); }, icon: const Icon(Icons.calendar_today))]),
            const SizedBox(height:8),
            Row(children: [Text(AppLocalizations.of(context).t('gender') + ':'), const SizedBox(width:12), DropdownButton<String>(value: gender, items: [DropdownMenuItem(value: 'female', child: Text(AppLocalizations.of(context).t('female'))), DropdownMenuItem(value: 'male', child: Text(AppLocalizations.of(context).t('male')))], onChanged: (v){ if (v==null) return; setSt(()=> gender = v); })])
          ]);
        }),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context).t('cancel'))), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(AppLocalizations.of(context).t('save')))],
      );
    });
    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      final newName = nameController.text.trim();
      if (newName.isNotEmpty) {
        _userName = newName;
        await prefs.setString('user_name', newName);
      }
      if (dob != null) {
        _userDob = dob;
        await prefs.setString('user_dob', dob!.toIso8601String());
      }
      _userGender = gender;
      await prefs.setString('user_gender', _userGender);
      if (!mounted) return;
      setState(() {});
    }
  }


  void _editEmergencyNumber() async {
    final newNumber = await showDialog<String>(context: context, builder: (ctx) {
      final c = TextEditingController(text: _emergencyController.text);
      return AlertDialog(
        title: Text(AppLocalizations.of(context).t('emergency')),
        content: TextField(controller: c, keyboardType: TextInputType.phone, decoration: InputDecoration(hintText: AppLocalizations.of(context).t('emergency'))),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context).t('save'))), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: Text(AppLocalizations.of(context).t('save')))],
      );
    });
    if (newNumber != null && newNumber.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emergency_number', newNumber);
      _emergencyController.text = newNumber;
      if (!mounted) return;
      setState(() {});
    }
  }

  void _testCall() async {
    final num = _emergencyController.text.isNotEmpty ? _emergencyController.text : '112';
    final uri = Uri(scheme: 'tel', path: num);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('could_not_open_dialer'))));
    }
  }
}
