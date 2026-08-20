import 'dart:convert';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'language_provider.dart';
import 'services/translate_service.dart';

class HealthCampaignsScreen extends StatefulWidget {
  const HealthCampaignsScreen({Key? key}) : super(key: key);

  @override
  State<HealthCampaignsScreen> createState() => _HealthCampaignsScreenState();
}

class _HealthCampaignsScreenState extends State<HealthCampaignsScreen> {
  List<dynamic> _campaigns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _isLoading = true);
    try {
      final jsonString = await rootBundle.loadString('assets/campaigns.json');
      final data = json.decode(jsonString) as List<dynamic>;
      // Capture language before translation awaits to avoid context across async gaps
      final lang = Provider.of<LanguageProvider>(context, listen: false).languageCode;
      if (lang == 'en' || lang.isEmpty) {
        setState(() {
          _campaigns = data;
          _isLoading = false;
        });
        return;
      }

      final translated = <dynamic>[];
      for (final c in data) {
        try {
          final tTitle = await TranslateService.translate(c['title'] ?? '', lang);
          final tDetails = await TranslateService.translate(c['details'] ?? '', lang);
          final tLocation = await TranslateService.translate(c['location'] ?? '', lang);
          translated.add({...c, 'title': tTitle ?? (c['title'] ?? ''), 'details': tDetails ?? (c['details'] ?? ''), 'location': tLocation ?? (c['location'] ?? '')});
        } catch (e) {
          translated.add(c);
        }
      }
      if (!mounted) return;
      setState(() { _campaigns = translated; _isLoading = false; });
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load campaigns: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload campaigns when language changes
    Provider.of<LanguageProvider>(context);
    _loadCampaigns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('upcoming_campaigns')),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _campaigns.isEmpty
              ? Center(child: Text(AppLocalizations.of(context).t('no_upcoming_campaigns')))
              : ListView.builder(
                  itemCount: _campaigns.length,
                  itemBuilder: (context, index) {
                    final c = _campaigns[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['title'] ?? '',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            Text('📍 Location: ${c['location'] ?? ''}'),
                            Text('🗓 Date: ${c['date'] ?? ''}'),
                            Text('🏙 City: ${c['city'] ?? ''}'),
                            const SizedBox(height: 8),
                            Text(
                              c['details'] ?? '',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
