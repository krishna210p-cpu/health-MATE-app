import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _email = prefs.getString('account_email') ?? '';
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _editEmail() async {
    final controller = TextEditingController(text: _email);
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(AppLocalizations.of(context).t('email')),
      content: TextField(controller: controller, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: 'you@example.com')),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context).t('cancel'))), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(AppLocalizations.of(context).t('save')))],
    ));
    if (result == true) {
      _email = controller.text.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('account_email', _email);
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final nw = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(AppLocalizations.of(context).t('change')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: current, obscureText: true, decoration: InputDecoration(hintText: AppLocalizations.of(context).t('currentPassword'))), const SizedBox(height:8), TextField(controller: nw, obscureText: true, decoration: InputDecoration(hintText: AppLocalizations.of(context).t('newPassword')))]),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context).t('cancel'))), ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(AppLocalizations.of(context).t('save')))],
    ));
    if (ok == true) {
      // For this free app we won't implement a secure backend; persist a local flag to indicate password saved.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('account_password', nw.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('saved'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('account'))),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(leading: const Icon(Icons.email), title: Text(AppLocalizations.of(context).t('email')), subtitle: Text(_email.isNotEmpty ? _email : AppLocalizations.of(context).t('not_set')), trailing: TextButton(onPressed: _editEmail, child: Text(AppLocalizations.of(context).t('edit')))),
          ListTile(leading: const Icon(Icons.lock), title: Text(AppLocalizations.of(context).t('password')), subtitle: Text('••••••••'), trailing: TextButton(onPressed: _changePassword, child: Text(AppLocalizations.of(context).t('change')))),
        ]),
      ),
    );
  }
}
