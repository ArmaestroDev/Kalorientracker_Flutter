import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/main_provider.dart';
import '../../logic/widget_bridge.dart';
import '../widgets/kit/kit.dart';
import 'assistant_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Root layout with bottom navigation: coach, today, history and profile
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late final MainProvider _provider;
  int _index = 0;
  String? _pendingWidgetAction;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    _provider = context.read<MainProvider>();
    WidgetsBinding.instance.addObserver(this);
    WidgetBridge.setActionHandler(_handleWidgetAction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider.addListener(_onProviderChanged);
      _consumeInitialAction();
    });
  }

  Future<void> _consumeInitialAction() async {
    final action = await WidgetBridge.consumeInitialAction();
    if (action != null && mounted) {
      _handleWidgetAction(action);
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _provider.refreshTodayIfNeeded();
      _provider.refreshModelCatalog();
    }
  }

  void _onProviderChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final error = _provider.errorMessage;
      if (error != null && error != _lastShownError) {
        _lastShownError = error;
        AppFeedback.error(context, error);
        _provider.dismissError();
      } else if (error == null) {
        _lastShownError = null;
      }
      final success = _provider.successMessage;
      if (success != null) {
        AppFeedback.success(context, success);
        _provider.clearSuccess();
      }
    });
  }

  void _handleWidgetAction(String action) {
    if (!mounted) return;
    setState(() {
      _index = 1;
      _pendingWidgetAction = action;
    });
  }

  void _select(int index) => setState(() => _index = index);

  void _openDay(DateTime date) {
    _provider.changeDate(date);
    _select(1);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MainProvider>();

    if (!provider.initialized) {
      return const Scaffold(body: LoadingState(label: 'Lädt…'));
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          AssistantScreen(onOpenProfile: () => _select(3)),
          HomeScreen(
            onOpenHistory: () => _select(2),
            pendingWidgetAction: _pendingWidgetAction,
            onWidgetActionHandled: () {
              if (mounted && _pendingWidgetAction != null) {
                setState(() => _pendingWidgetAction = null);
              }
            },
          ),
          HistoryScreen(onOpenDay: _openDay),
          ProfileScreen(
            initialProfile: provider.userProfile,
            onSave: provider.saveUserProfileAndRecalculateGoals,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Coach',
          ),
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
