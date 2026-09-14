import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/main_provider.dart';
import 'assistant_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// Root layout with bottom navigation: today, history and the coach
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MainProvider>().loadInitialData();
    });
  }

  void _select(int index) => setState(() => _index = index);

  void _openDay(DateTime date) {
    context.read<MainProvider>().changeDate(date);
    _select(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenHistory: () => _select(1)),
          HistoryScreen(onOpenDay: _openDay),
          const AssistantScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Heute',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Verlauf',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Coach',
          ),
        ],
      ),
    );
  }
}
