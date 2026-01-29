import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'logic/providers/main_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
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
      ),
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
          theme: AppTheme.getTheme(provider.currentTheme),
          home: const HomeScreen(),
        );
      },
    );
  }
}
