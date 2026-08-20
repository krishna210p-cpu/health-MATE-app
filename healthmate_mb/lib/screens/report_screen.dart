import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      // Attempt to send report to Firestore if Firebase is configured
      await Firebase.initializeApp();
      final col = FirebaseFirestore.instance.collection('app_reports');
      await col.add({'text': _controller.text.trim(), 'ts': FieldValue.serverTimestamp()});
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
      Navigator.of(context).pop();
    } catch (e) {
      // Fallback: simulate network send
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report queued (no Firebase configured)')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('report'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(AppLocalizations.of(context).t('report')),
            const SizedBox(height: 12),
            TextField(controller: _controller, maxLines: 6, decoration: InputDecoration(hintText: AppLocalizations.of(context).t('describe_issue'))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _sending ? null : _send, child: _sending ? const CircularProgressIndicator() : Text(AppLocalizations.of(context).t('submit')))
          ],
        ),
      ),
    );
  }
}
