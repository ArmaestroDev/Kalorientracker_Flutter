# AGENTS.md — Kalorientracker Flutter

## Project Overview

A local, single-user daily calorie/macro tracker with an AI coach, AI-powered food recognition, barcode scanning, exercise logging and dietary analysis. Built with Flutter, targeting Android, iOS, Web, Windows, Linux and macOS.

## Architecture

**Clean Architecture Lite** — 3 layers: `data/`, `logic/`, `ui/`.

- **State Management**: Single `ChangeNotifier` (`MainProvider`) via `provider` package
- **Database**: SQLite via `sqflite` (native) / `sqflite_common_ffi` (desktop) / `sqflite_common_ffi_web` (web) — 5 tables (`food_entries`, `activity_entries`, `food_items`, `weight_entries`, `user_plans`), schema version 4
- **AI**: Strategy pattern — `GenerativeService` abstract class with 3 implementations (`GeminiApiService`, `ClaudeApiService`, `OpenAiCompatibleService`, the last one serving both OpenAI and Grok). `AiProvider` has 4 values. The available model list is fetched live by `ModelCatalogService`.
- **Navigation**: Navigator 1.0 (push/pop + showDialog), no routing package. `AppShell` holds 4 tabs in an `IndexedStack`: Coach, Heute, Verlauf, Profil
- **Theming**: 5 palettes (Amethyst, Saphir, Smaragd, Schwarz & Weiß, Pink) × light/dark/system, from the UNI-fied design system; colours only via colorScheme/AppColors, spacing/radius via Space/Corner tokens, UI composed from lib/ui/widgets/kit

Full architecture details in `ARCHITECTURE.md`.

## Key Commands

```bash
# Analyze (lint)
flutter analyze

# Run app
flutter run

# Build
flutter build apk / ios / web / windows / linux / macos

# Tests (7 test files under test/)
flutter test

# Generate app icons
flutter pub run flutter_launcher_icons
```

## Code Style & Conventions

- **No comments in code** unless absolutely necessary for complex logic
- **Immutable models**: `final` fields + `copyWith` — no code generation (no freezed/json_serializable)
- **IDs**: Use `uuid` v4 for entities. `FoodItem.id` = `name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_')`
- **German locale**: All UI strings hardcoded in German, date format `de_DE`
- **AI prompts**: German language, strict JSON output instruction, markdown fences stripped after parsing
- **Error handling**: Throw `AiException` with a readable German message; prefix service-specific failures with the service name
- **Material 3**: All widgets use `useMaterial3: true`, `colorScheme.primary`, `FilledButton`, outlined/filled inputs from the theme
- **Design system**: Compose screens from `lib/ui/widgets/kit/` (`AppCard`, `SectionHeader`, `StatusPill`, `Notice`, `EmptyState`, `LoadingState`, `AppFeedback`). Colours only via `Theme.of(context).colorScheme.<role>` or `AppColors.of(context)`; spacing/radius only via `Space.*`, `Corner.*`, `Stroke.*` from `lib/ui/theme/tokens.dart`. No `Colors.red`, no `Color(0x...)`, no `withOpacity`.
- **No assets folder**: Only Material icons (`uses-material-design: true`) and generated launcher icons

## Important Rules

1. **Never add `build_runner` or code generation** — all serialization is handwritten
2. **No Firebase** — app is entirely local-first (SQLite + SharedPreferences + direct AI API calls)
3. **No Cupertino/Platform-specific widgets** — single codebase with Material Design everywhere
4. **Provider only** — do not introduce Bloc, Riverpod, GetX, or other state management
5. **MainProvider is the single source of truth** — all state changes go through `notifyListeners()`
6. **Database migrations** — use `onUpgrade` in `AppDatabase` with version bump; never drop tables
7. **Platform-specific DB init** — use conditional exports pattern in `initialize_database.dart`
8. **Flutter SDK on this machine**: `~/development/flutter/bin/flutter` (Flutter is not on PATH)
9. **Errors must always reach the user**: set `MainProvider.errorMessage` (shown as SnackBar by AppShell) or call `AppFeedback.error` for local errors. Screens never show their own error banner for provider errors.

## File Naming

- `snake_case` for files and directories
- `PascalCase` for classes and widgets
- `camelCase` for methods, fields, variables
- Dart files match the single class they contain

## State Shape (MainProvider)

| Field | Type | Description |
|-------|------|-------------|
| `selectedDate` | `DateTime` | Currently viewed day |
| `foodEntries` | `List<FoodEntry>` | Food for selected date |
| `activityEntries` | `List<ActivityEntry>` | Activities for selected date |
| `userProfile` | `UserProfile` | User data + API keys + model overrides |
| `goals` | `CalorieGoals` | Calculated daily targets |
| `plans` | `List<UserPlan>` | Meal/training plans (read-only view) |
| `activePlanCount` | `int` | Number of active plans |
| `assistantMessages` | `List<ChatMessage>` | Coach chat history |
| `assistantBusy` | `bool` | Coach is waiting for a reply |
| `assistantStatus` | `String?` | Status line while the coach calls tools |
| `isLoading` | `bool` | Loading indicator |
| `loadingLabel` | `String?` | Text shown next to the progress bar |
| `errorMessage` | `String?` | Error, shown as SnackBar by AppShell |
| `successMessage` | `String?` | Confirmation, shown as SnackBar by AppShell |
| `scannedFoodInfo` | `FoodNutritionInfo?` | Barcode scan result |
| `currentTheme` | `String` | Active palette key (`amethyst`, `sapphire`, `smaragd`, `black_white`, `pink`) |
| `themeMode` | `ThemeMode` | light / dark / system |
| `modelsRefreshing` | `bool` | Model catalogue is being refreshed |

Computed: `totalCalories`, `totalProtein`, `totalCarbs`, `totalFat`, `totalBurned`, `calorieBudget`, `weekStatus`, `weightOnSelectedDate`, `weightAverage7Days`, `dataVersion`

## Tests

`test/` contains 7 files, all runnable with `flutter test`: AI service HTTP payloads (mocked `http.Client`), JSON parsing, goals calculation, nutrition/history statistics, coach tools, `ModelCatalogService` and widget/dialog behaviour. Keep them green; update them when behaviour changes intentionally.

## DevOps & CI/CD

Full deployment strategy in `ARCHITECTURE.md` (DevOps section).

### Recommended CI Pipeline (GitHub Actions)

| Trigger | Jobs |
|---------|------|
| PR to `main`/`develop` | `flutter analyze` → `flutter test` |
| Push to `main` | analyze + test + build all platforms |
| Tag `v*` | analyze + test + build + deploy |

### Build Commands by Platform

| Platform | Command | Output |
|----------|---------|--------|
| Android APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android AAB | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` |
| iOS | `flutter build ios --release --no-codesign` | `build/ios/ipa/` |
| Web | `flutter build web --release` | `build/web/` |
| Windows | `flutter build windows --release` | `build/windows/runner/Release/` |
| macOS | `flutter build macos --release` | `build/macos/Build/Products/Release/` |
| Linux | `flutter build linux --release` | `build/linux/x64/release/bundle/` |

### Versioning

```
pubspec.yaml:  version: MAJOR.MINOR.PATCH+BUILD
CI bumps BUILD via --build-number=${{ github.run_number }}
Tagged releases follow semver (v1.2.3).
```

### Current Status
- **No CI/CD configured** — all builds manual
- **Automated tests exist** — 7 files, run with `flutter test`
- **No deployment pipeline**
- All deploy configs (signing, Fastlane, store accounts) need to be set up from scratch

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready, protected |
| `develop` | Integration |
| `feat/*` | Feature branches |
| `release/v*` | Release candidates |
| `hotfix/*` | Urgent fixes |
