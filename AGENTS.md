# AGENTS.md — Kalorientracker Flutter

## Project Overview

A cross-platform daily calorie/macro tracker with AI-powered food recognition, barcode scanning, exercise logging, and dietary analysis. Built with Flutter, targeting Android, iOS, Web, Windows, Linux, and macOS.

## Architecture

**Clean Architecture Lite** — 3 layers: `data/`, `logic/`, `ui/`.

- **State Management**: Single `ChangeNotifier` (`MainProvider`) via `provider` package
- **Database**: SQLite via `sqflite` (native) / `sqflite_common_ffi` (desktop/web) — 3 tables
- **AI**: Strategy pattern — `GenerativeService` abstract class with 4 implementations (Gemini, Claude, OpenAI, Grok)
- **Navigation**: Navigator 1.0 (push/pop + showDialog), no routing package
- **Theming**: 4 Material 3 themes, user-selectable, stored in SharedPreferences

Full architecture details in `ARCHITECTURE.md`.

## Key Commands

```bash
# Analyze (lint)
flutter analyze

# Run app
flutter run

# Build
flutter build apk / ios / web / windows

# Tests (currently none active — skeleton only)
flutter test

# Generate app icons
flutter pub run flutter_launcher_icons
```

## Code Style & Conventions

- **No comments in code** unless absolutely necessary for complex logic
- **Immutable models**: `final` fields + `copyWith` — no code generation (no freezed/json_serializable)
- **IDs**: Use `uuid` v4 for entities. `FoodItem.id` = `name.toLowerCase().replaceAll(' ', '_')`
- **German locale**: All UI strings hardcoded in German, date format `de_DE`
- **AI prompts**: German language, strict JSON output instruction, markdown fences stripped after parsing
- **Error handling**: Prefix exceptions with service name (`GeminiError:`, `ClaudeError:`)
- **Material 3**: All widgets use `useMaterial3: true`, `colorScheme.primary`, `FilledButton`, `OutlinedInputBorder`
- **No assets folder**: Only Material icons (`uses-material-design: true`) and generated launcher icons

## Important Rules

1. **Never add `build_runner` or code generation** — all serialization is handwritten
2. **No Firebase** — app is entirely local-first (SQLite + SharedPreferences + direct AI API calls)
3. **No Cupertino/Platform-specific widgets** — single codebase with Material Design everywhere
4. **Provider only** — do not introduce Bloc, Riverpod, GetX, or other state management
5. **MainProvider is the single source of truth** — all state changes go through `notifyListeners()`
6. **Database migrations** — use `onUpgrade` in `AppDatabase` with version bump; never drop tables
7. **Platform-specific DB init** — use conditional exports pattern in `initialize_database.dart`

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
| `userProfile` | `UserProfile` | User data + API keys |
| `goals` | `CalorieGoals` | Calculated daily targets |
| `isLoading` | `bool` | Loading indicator |
| `errorMessage` | `String?` | Error to display |
| `scannedFoodInfo` | `FoodNutritionInfo?` | Barcode scan result |
| `currentTheme` | `String` | Active theme name |

Computed: `totalCalories`, `totalProtein`, `totalCarbs`, `totalFat`, `totalBurned`, `netCalories`

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
- **No automated tests**
- **No deployment pipeline**
- All configs (signing, Firebase, Fastlane) need to be set up from scratch

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready, protected |
| `feat/*` | Feature branches |
| `release/v*` | Release candidates |
| `hotfix/*` | Urgent fixes |
