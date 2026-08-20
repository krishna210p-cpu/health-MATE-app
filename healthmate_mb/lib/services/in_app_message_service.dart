import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppMessageService {
  // A list of possible package names this app may use; admin can target any of these
  static const List<String> _knownPackageIds = [
    'com.example.finalhealthmate_mb',
    'com.example.healthmate',
    'com.example.healthmate_plus',
    'com.example.finalhealthmateMb',
    'com.example.healthmate',
    'com.example.healthmate_mb'
  ];

  /// Checks Firestore for active in-app messages matching the given trigger
  /// (e.g. 'first_open' or 'app_start') and shows them in-app using dialogs.
  /// Messages are marked shown per device (via SharedPreferences) so they won't
  /// repeat unless the document changes its `show_always` flag.
  static Future<void> checkAndShowMessages(BuildContext context, String trigger) async {
    try {
      if (Firebase.apps.isEmpty) return; // Firebase not initialized
      final prefs = await SharedPreferences.getInstance();
      final col = FirebaseFirestore.instance.collection('in_app_messages');
      final query = await col.where('active', isEqualTo: true).where('trigger', isEqualTo: trigger).get();
      for (final doc in query.docs) {
        try {
          final data = doc.data();
          // Targeting
          final bool targetAll = data['targetAll'] == true;
          final List<dynamic> targetApps = (data['targetApps'] is List) ? data['targetApps'] as List<dynamic> : [];
          final bool matchesTarget = targetAll || targetApps.any((t) => _knownPackageIds.contains(t.toString()));
          if (!matchesTarget) continue;

          // Scheduling
          final now = DateTime.now().toUtc();
          if (data['start_at'] != null) {
            final start = DateTime.tryParse(data['start_at'].toString());
            if (start != null && now.isBefore(start.toUtc())) continue;
          }
          if (data['end_at'] != null) {
            final end = DateTime.tryParse(data['end_at'].toString());
            if (end != null && now.isAfter(end.toUtc())) continue;
          }

          final idKey = 'in_app_msg_shown_${doc.id}';
          final alreadyShown = prefs.getBool(idKey) ?? false;
          final showAlways = data['show_always'] == true;
          if (alreadyShown && !showAlways) continue;

          // Show dialog
          if (!context.mounted) return;
          final title = data['title']?.toString() ?? 'Message';
          final body = data['body']?.toString() ?? '';
          final actionUrl = data['action_url']?.toString();
          await showDialog<void>(context: context, builder: (ctx) {
            return AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                if (actionUrl != null && actionUrl.isNotEmpty)
                  TextButton(onPressed: () async { Navigator.of(ctx).pop(); try { final uri = Uri.parse(actionUrl); if (await canLaunchUrl(uri)) await launchUrl(uri); } catch (_) {} }, child: Text(data['action_text']?.toString() ?? 'Open')),
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              ],
            );
          });

          // mark shown
          await prefs.setBool(idKey, true);
        } catch (_) {
          continue; // ignore message-specific errors and proceed
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('InAppMessageService failed: $e');
    }
  }
}
