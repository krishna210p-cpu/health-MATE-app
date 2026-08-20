import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'vaccine_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'package:healthmate_mb/l10n/app_localizations.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  final List<Widget> _pages = const [HomeScreen(), VaccineScreen(), SettingsScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        showUnselectedLabels: true,
        currentIndex: _index,
        onTap: (i) => setState(()=>_index = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: AppLocalizations.of(context).t('appTitle')),
          BottomNavigationBarItem(icon: const Icon(Icons.vaccines), label: AppLocalizations.of(context).t('vaccine_info')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: AppLocalizations.of(context).t('settings_title')),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: AppLocalizations.of(context).t('profile')),
        ],
      ),
    );
  }
}
