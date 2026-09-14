import 'package:flutter/material.dart';

/// Colors with a fixed meaning that must not change with the theme hue.
/// Macro colors are the first three slots of a colorblind-validated
/// categorical palette; success/danger are text-safe on both surfaces.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color success;
  final Color danger;

  const AppColors({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.success,
    required this.danger,
  });

  static const light = AppColors(
    protein: Color(0xFF2A78D6),
    carbs: Color(0xFFEB6834),
    fat: Color(0xFF1BAF7A),
    success: Color(0xFF006300),
    danger: Color(0xFFBA1A1A),
  );

  static const dark = AppColors(
    protein: Color(0xFF3987E5),
    carbs: Color(0xFFD95926),
    fat: Color(0xFF199E70),
    success: Color(0xFF4CC24C),
    danger: Color(0xFFFFB4AB),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? success,
    Color? danger,
  }) {
    return AppColors(
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      protein: Color.lerp(protein, other.protein, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

class AppThemeOption {
  final String key;
  final String label;
  final Color seed;
  final ThemeMode mode;

  const AppThemeOption(this.key, this.label, this.seed, this.mode);
}

class AppTheme {
  static const options = [
    AppThemeOption(
      'Default',
      'Grün · System',
      Color(0xFF2F7D5B),
      ThemeMode.system,
    ),
    AppThemeOption(
      'Light Green',
      'Grün · Hell',
      Color(0xFF2F7D5B),
      ThemeMode.light,
    ),
    AppThemeOption('Ocean', 'Ozean · Hell', Color(0xFF1F6FB2), ThemeMode.light),
    AppThemeOption(
      'Dark Forest',
      'Wald · Dunkel',
      Color(0xFF3F7D4F),
      ThemeMode.dark,
    ),
    AppThemeOption(
      'Dark Purple',
      'Violett · Dunkel',
      Color(0xFF6750A4),
      ThemeMode.dark,
    ),
  ];

  static AppThemeOption option(String key) =>
      options.firstWhere((o) => o.key == key, orElse: () => options.first);

  static ThemeData light(String key) =>
      _build(option(key).seed, Brightness.light);

  static ThemeData dark(String key) =>
      _build(option(key).seed, Brightness.dark);

  static ThemeData _build(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [isDark ? AppColors.dark : AppColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
