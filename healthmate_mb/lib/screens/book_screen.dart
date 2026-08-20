import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class BookScreen extends StatelessWidget {
  const BookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('book'))),
      body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(AppLocalizations.of(context).t('booking_coming_soon')))),
    );
  }
}
