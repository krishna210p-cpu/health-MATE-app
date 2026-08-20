import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      setState(() => _pos = p);
    } catch (e) {
      // Could not get location (permission denied or unavailable)
    }
  }
  

  Future<void> _openMaps() async {
    final q = 'hospital near me';
    final uri = _pos != null
        ? Uri.parse('https://www.google.com/maps/search/$q/@${_pos!.latitude},${_pos!.longitude},14z')
        : Uri.parse('https://www.google.com/maps/search/$q');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('nearby'))),
      body: Center(
        child: ElevatedButton.icon(onPressed: _openMaps, icon: const Icon(Icons.map), label: Text(AppLocalizations.of(context).t('find_hospitals'))),
      ),
    );
  }
}
