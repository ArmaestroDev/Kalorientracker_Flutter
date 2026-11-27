import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_palettes.dart';
import 'tokens.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color success;
  final Color warning;
  final Color danger;

  const AppColors({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith({
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppColors(
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      success: success ?? this.success,
      warning: warning ?? this.warning,
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
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light(String paletteKey) =>
      _build(AppPalettes.byKey(paletteKey), Brightness.light);

  static ThemeData dark(String paletteKey) =>
      _build(AppPalettes.byKey(paletteKey), Brightness.dark);

  static ThemeMode themeModeFrom(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeKey(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final scheme = brightness == Brightness.dark ? palette.dark : palette.light;
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    final base = typography.englishLike
        .merge(
          brightness == Brightness.light ? typography.black : typography.white,
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final textTheme = base.copyWith(
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );

    final double stroke = palette.monochrome ? Stroke.selectable : 0;
    final BorderSide side = palette.monochrome
        ? BorderSide(color: scheme.onSurface, width: Stroke.selectable)
        : BorderSide.none;
    final Color success = brightness == Brightness.dark
        ? palette.successDark
        : palette.successLight;
    final Color warning = brightness == Brightness.dark
        ? palette.warningDark
        : palette.warningLight;

    final inputRadius = BorderRadius.circular(Corner.md);
    final BorderSide neutralSide = palette.monochrome
        ? side
        : BorderSide.none;
    final BorderSide focusedSide = BorderSide(
      color: scheme.primary,
      width: Stroke.emphasis,
    );
    final BorderSide errorSide = BorderSide(
      color: scheme.error,
      width: Stroke.hairline,
    );
    final BorderSide focusedErrorSide = BorderSide(
      color: scheme.error,
      width: Stroke.emphasis,
    );
    final InputDecorationTheme inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: palette.monochrome
          ? OutlineInputBorder(
              borderRadius: inputRadius,
              borderSide: neutralSide,
            )
          : UnderlineInputBorder(
              borderRadius: inputRadius,
              borderSide: neutralSide,
            ),
      enabledBorder: palette.monochrome
          ? OutlineInputBorder(
              borderRadius: inputRadius,
              borderSide: neutralSide,
            )
          : UnderlineInputBorder(
              borderRadius: inputRadius,
              borderSide: neutralSide,
            ),
      disabledBorder: palette.monochrome
          ? OutlineInputBorder(
              borderRadius: inputRadius,
              borderSide: neutralSide,
            )
          : UnderlineInputBorder(
              borderRadius: inputRadius,
              borderSide: neutralSide,
            ),
      focusedBorder: palette.monochrome
          ? OutlineInputBorder(
              borderRadius: inputRadius,
              borderSide: focusedSide,
            )
          : UnderlineInputBorder(
              borderRadius: inputRadius,
              borderSide: focusedSide,
            ),
      errorBorder: palette.monochrome
          ? OutlineInputBorder(
              borderRadius: inputRadius,
              borderSide: errorSide,
            )
          : UnderlineInputBorder(
              borderRadius: inputRadius,
              borderSide: errorSide,
            ),
      focusedErrorBorder: palette.monochrome
          ? OutlineInputBorder(
              borderRadius: inputRadius,
              borderSide: focusedErrorSide,
            )
          : UnderlineInputBorder(
              borderRadius: inputRadius,
              borderSide: focusedErrorSide,
            ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: [
        AppColors(
          protein: palette.monochrome ? scheme.onSurface : scheme.primary,
          carbs: palette.monochrome ? scheme.onSurface : scheme.tertiary,
          fat: palette.monochrome ? scheme.onSurface : warning,
          success: success,
          warning: warning,
          danger: scheme.error,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corner.md),
          side: side,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          side: BorderSide(
            color: scheme.outline,
            width: palette.monochrome ? Stroke.selectable : Stroke.hairline,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        ),
      ),
      inputDecorationTheme: inputTheme,
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: inputTheme,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            scheme.surfaceContainerLowest,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.md)),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corner.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corner.xxl),
          side: side,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(Corner.xxl),
            topRight: Radius.circular(Corner.xxl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corner.md),
        ),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.secondaryContainer,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: palette.monochrome ? stroke : Stroke.hairline,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corner.md),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: palette.monochrome
            ? scheme.onSurface.withValues(alpha: 0.15)
            : scheme.surfaceContainerHighest,
        circularTrackColor: palette.monochrome
            ? scheme.onSurface.withValues(alpha: 0.15)
            : scheme.surfaceContainerHighest,
      ),
    );
  }
}
