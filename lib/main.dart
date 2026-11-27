import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'logic/providers/main_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/app_shell.dart';
import 'data/repositories/log_repository.dart';
import 'data/repositories/user_preferences_repository.dart';
import 'data/repositories/api_service_repository.dart';
import 'data/database/initialize_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);
  initializeDatabase();

  final logRepository = LogRepository();
  final prefsRepository = UserPreferencesRepository();
  final apiServiceRepository = ApiServiceRepository();

  runApp(
    ChangeNotifierProvider(
      create: (_) => MainProvider(
        logRepository: logRepository,
        prefsRepository: prefsRepository,
        apiServiceRepository: apiServiceRepository,
      )..loadInitialData(),
      child: const KalorientrackerApp(),
    ),
  );
}

class KalorientrackerApp extends StatelessWidget {
  const KalorientrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MainProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'Kalorientracker',
          debugShowCheckedModeBanner: false,
          locale: const Locale('de', 'DE'),
          supportedLocales: const [Locale('de', 'DE')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(provider.currentTheme),
          darkTheme: AppTheme.dark(provider.currentTheme),
          themeMode: provider.themeMode,
          home: const AppShell(),
        );
      },
    );
  }
}
