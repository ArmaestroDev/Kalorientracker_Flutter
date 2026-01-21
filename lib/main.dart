import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'logic/providers/main_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const KalorientrackerApp());
}

class KalorientrackerApp extends StatelessWidget {
  const KalorientrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MainProvider(),
      child: Consumer<MainProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'Kalorientracker',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(provider.currentTheme),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
