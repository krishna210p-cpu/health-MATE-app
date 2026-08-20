import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  DateTime? _dob;
  String _gender = 'female';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? '';
      _email = prefs.getString('user_email') ?? '';
      final dobStr = prefs.getString('user_dob');
      if (dobStr != null) _dob = DateTime.tryParse(dobStr);
      _gender = prefs.getString('user_gender') ?? 'female';
    });
  }

  Future<void> _edit() async {
    final nameController = TextEditingController(text: _name);
    DateTime? dob = _dob;
    String gender = _gender;
    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context).t('profile')),
        content: StatefulBuilder(builder: (c, setSt) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: InputDecoration(labelText: AppLocalizations.of(context).t('name'))),
            const SizedBox(height:8),
            Row(children: [Expanded(child: Text(dob == null ? AppLocalizations.of(context).t('dateOfBirth') : '${dob!.day}/${dob!.month}/${dob!.year}')), IconButton(onPressed: () async { final picked = await showDatePicker(context: ctx, initialDate: dob ?? DateTime(1990), firstDate: DateTime(1900), lastDate: DateTime.now()); if (picked != null) setSt(()=> dob = picked); }, icon: const Icon(Icons.calendar_today))]),
            const SizedBox(height:8),
            Row(children: [Text(AppLocalizations.of(context).t('gender')), const SizedBox(width:12), DropdownButton<String>(value: gender, items: const [DropdownMenuItem(value: 'female', child: Text('Female')), DropdownMenuItem(value: 'male', child: Text('Male'))], onChanged: (v){ if (v==null) return; setSt(()=> gender = v); })])
          ]);
        }),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context).t('cancel'))), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(AppLocalizations.of(context).t('save')))],
      );
    });
    if (res == true) {
      final prefs = await SharedPreferences.getInstance();
      final newName = nameController.text.trim();
      if (newName.isNotEmpty) {
        _name = newName;
        await prefs.setString('user_name', newName);
      }
      if (dob != null) {
        _dob = dob;
  final String iso = dob!.toIso8601String();
        await prefs.setString('user_dob', iso);
      }
      _gender = gender;
      await prefs.setString('user_gender', _gender);
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _editEmail() async {
    final controller = TextEditingController(text: _email);
    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context).t('email')),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: 'you@example.com')),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context).t('cancel'))), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(AppLocalizations.of(context).t('save')))],
      );
    });
    if (res == true) {
      final val = controller.text.trim();
      final prefs = await SharedPreferences.getInstance();
      _email = val;
      await prefs.setString('user_email', _email);
      // Try to write to Firestore if available
      try {
        if (Firebase.apps.isNotEmpty) {
          final col = FirebaseFirestore.instance.collection('profiles');
          await col.add({'name': _name, 'email': _email, 'dob': _dob?.toIso8601String(), 'gender': _gender, 'ts': FieldValue.serverTimestamp()});
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('profile'))),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(_name.isNotEmpty ? _name : AppLocalizations.of(context).t('profile')), subtitle: Text('${AppLocalizations.of(context).t('dateOfBirth')}: ${_dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : '--'}\n${AppLocalizations.of(context).t('gender')}: ${_gender[0].toUpperCase()}${_gender.substring(1)}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.edit), onPressed: _edit))),
          const SizedBox(height:12),
          // Additional profile fields
          Builder(builder: (ctx) {
            final emailLabel = AppLocalizations.of(ctx).t('email');
            final editLabel = AppLocalizations.of(ctx).t('edit');
            final emptyEmail = AppLocalizations.of(ctx).t('dob_not_set');
            return ListTile(
              leading: const Icon(Icons.email),
              title: Text(emailLabel),
              subtitle: Text(_email.isNotEmpty ? _email : emptyEmail),
              trailing: TextButton(onPressed: _editEmail, child: Text(editLabel)),
            );
          }),
        ]),
      )),
    );
  }
}
