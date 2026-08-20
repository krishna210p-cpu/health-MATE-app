import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class TodayTipScreen extends StatelessWidget {
  const TodayTipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('todayTip'))),
      body: Padding(padding: const EdgeInsets.all(16.0), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).t('todayTip'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height:12),
          Text(AppLocalizations.of(context).t('health_tip_example'), style: const TextStyle(fontSize:16)),
          const SizedBox(height:12),
          const Divider(),
          const SizedBox(height:12),
          Text(AppLocalizations.of(context).t('more_tips_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height:8),
          Text(AppLocalizations.of(context).t('more_tip_1')),
          Text(AppLocalizations.of(context).t('more_tip_2')),
          Text(AppLocalizations.of(context).t('more_tip_3')),
          const SizedBox(height:16),
          ElevatedButton(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('tip_saved')))); }, child: Text(AppLocalizations.of(context).t('save_tip')))
        ],
      )),
    );
  }
}
