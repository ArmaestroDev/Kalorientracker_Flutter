# Kalorientracker Flutter — Architecture

Lokaler, single-user Kalorien- und Makro-Tracker mit KI-Coach. Kein Backend, keine Accounts, keine Cloud.

## Directory Structure

```
lib/
├── main.dart                       # DI, MaterialApp (de_DE), ChangeNotifierProvider
├── data/
│   ├── database/
│   │   ├── app_database.dart       # Singleton SQLite wrapper (5 Tabellen, version 4)
│   │   ├── initialize_database.dart / _native.dart / _web.dart   # conditional export
│   │   └── dao/
│   │       ├── log_dao.dart        # food_entries, activity_entries
│   │       ├── food_item_dao.dart  # food_items (Verlauf, pro 100 g)
│   │       └── plan_dao.dart       # user_plans
│   ├── models/                     # immutable, handgeschriebenes JSON + copyWith
│   │   ├── food_entry.dart, activity_entry.dart, food_item.dart, weight_entry.dart
│   │   ├── user_profile.dart, calorie_goals.dart, user_plan.dart, chat_message.dart
│   │   ├── ai_model_option.dart
│   │   └── enums.dart              # AiProvider, Gender, ActivityLevel, FitnessGoal, PlanType, ...
│   ├── repositories/
│   │   ├── log_repository.dart              # DAOs → Provider
│   │   ├── user_preferences_repository.dart # SharedPreferences: Profil, Keys, Theme, Modelle, Chat
│   │   └── api_service_repository.dart      # KI-Orchestrierung + Barcode
│   └── services/
│       ├── generative_service.dart          # abstrakte Schnittstelle, AiRequest, AiTool, AiException
│       ├── gemini_api_service.dart          # Gemini REST
│       ├── claude_api_service.dart          # Anthropic Messages API
│       ├── openai_compatible_service.dart   # OpenAI und Grok (xAI)
│       ├── model_catalog_service.dart       # Live-Modellliste pro Anbieter
│       ├── food_api_service.dart            # OpenFoodFacts Barcode-Lookup
│       └── pdf_plan_extractor.dart          # lokale PDF-Textextraktion
├── logic/
│   ├── providers/main_provider.dart  # einziger ChangeNotifier (State + Aktionen)
│   ├── goals_calculator.dart         # BMR (Mifflin-St Jeor) → TDEE → Makros
│   ├── nutrition_stats.dart          # Tages-/Wochenstatistik, WeekStatus
│   ├── history_data.dart             # Aggregation für den Verlauf (HistoryRange)
│   ├── assistant_context_builder.dart # System-Prompt des Coaches
│   ├── coach_tools.dart              # Function-Calling-Werkzeuge des Coaches
│   ├── number_format.dart
│   ├── voice_input_service.dart      # speech_to_text
│   └── widget_bridge.dart            # MethodChannel zum Android-Widget
└── ui/
    ├── theme/
    │   ├── tokens.dart         # Space, Corner, Stroke, Theme-Mode-Helfer
    │   ├── app_palettes.dart   # 5 Paletten, je helles und dunkles ColorScheme
    │   └── app_theme.dart      # AppTheme.light/dark + AppColors ThemeExtension
    ├── screens/
    │   ├── app_shell.dart      # NavigationBar: Coach, Heute, Verlauf, Profil
    │   ├── assistant_screen.dart
    │   ├── home_screen.dart
    │   ├── history_screen.dart
    │   ├── profile_screen.dart
    │   ├── plans_screen.dart
    │   ├── photo_input_screen.dart
    │   └── barcode_scanner_screen.dart
    └── widgets/
        ├── kit/                # AppCard, SectionHeader, StatusPill, Notice,
        │                       # EmptyState, LoadingState, AppFeedback
        ├── goals_summary_card.dart, food_item_row.dart, activity_item_row.dart
        ├── weight_card.dart, app_text_field.dart
        └── dialogs/            # add_entry, unified_input, food_recall, edit_food,
                                # edit_activity, delete_confirmation, barcode_scanner
```

## Architecture Style: Clean Architecture Lite (Layer-based)

```
ui/ (Screens, Widgets, Dialogs)
        │  context.watch / Consumer / read
        ▼
logic/ (MainProvider = einziger State, reine Funktionen für Ziele und Statistik)
        │
        ▼
data/ (Repositories → DAOs → SQLite, sowie Services → KI-APIs / OpenFoodFacts)
```

- Eine Richtung: `ui` → `logic` → `data`. Keine Rückimporte aus `data` nach `ui`.
- `MainProvider` ist die einzige Quelle der Wahrheit; jede Änderung endet in `notifyListeners()`.
- Rechenlogik (Ziele, Wochenbudget, Verlaufsaggregation) liegt in reinen Funktionen ohne Flutter-Abhängigkeit und ist dadurch testbar.

## Data Flow

```
Nutzeraktion (Text, Foto, Barcode, Sprache, Dialog)
        │
        ▼
MainProvider-Methode
        ├──► saveUserProfileAndRecalculateGoals() ──► GoalsCalculator ──► CalorieGoals
        ├──► addUnifiedEntry / addFoodFromImage / addScannedFoodItem / addFoodItemFromHistory
        │        └──► ApiServiceRepository ──► GenerativeService (Gemini/Claude/OpenAI/Grok)
        │                                   bzw. FoodApiService (OpenFoodFacts)
        │             └──► LogRepository ──► DAOs ──► SQLite
        ├──► reFetchFoodItem / reFetchActivityItem ──► KI-Schätzung neu
        ├──► sendAssistantMessage / retryAssistant ──► chat() mit CoachTools (Function Calling)
        ├──► saveWeight / deleteWeight ──► weight_entries + 7-Tage-Durchschnitt im Profil
        ├──► savePlan / togglePlanActive / deletePlan ──► user_plans
        └──► changeDate / changeTheme / changeThemeMode / selectModel
        │
        ▼
notifyListeners() ──► Consumer/select baut die UI neu
        │
        ▼
AppShell zeigt errorMessage und successMessage als SnackBar
```

## Key Design Decisions

### State Management
- `provider` mit genau einem `ChangeNotifier`: `MainProvider`.
- State: `selectedDate`, `foodEntries`, `activityEntries`, `userProfile`, `goals`, `plans`, `assistantMessages`, `weightEntries` (13 Tage), Wochendaten, `currentTheme`, `themeMode`, `isLoading`/`loadingLabel`, `errorMessage`, `successMessage`, Modellkatalog.
- Abgeleitet: `totalCalories`, `totalProtein`, `totalCarbs`, `totalFat`, `totalBurned`, `calorieBudget`, `weekStatus`, Gewichts-Durchschnitte, `dataVersion`.

### Database (SQLite)
- `sqflite` auf Android/iOS, `sqflite_common_ffi` auf Desktop, `sqflite_common_ffi_web` im Web.
- Bedingter Export in `initialize_database.dart`.
- **5 Tabellen**: `food_entries`, `activity_entries`, `food_items`, `weight_entries`, `user_plans`; Schema-Version **4**.
- Migrationen in `onUpgrade` (v2: `amount`/`unit`/`food_item_id` + `food_items`; v3: `weight_entries`; v4: `user_plans` + Indizes). Es wird nie eine Tabelle verworfen.
- DAO-Muster: `LogDao`, `FoodItemDao`, `PlanDao` kapseln alle SQL-Strings.

### AI Integration (Strategy Pattern)
- Abstrakte Klasse `GenerativeService` mit **drei** Implementierungen: `GeminiApiService`, `ClaudeApiService`, `OpenAiCompatibleService`.
- `AiProvider` hat vier Werte (Gemini, Claude, OpenAI, Grok); OpenAI und Grok teilen sich `OpenAiCompatibleService`.
- Anbieter und Modell wählt der Nutzer im Profil; `MainProvider._initializeApiService` baut den Service und reicht ihn an `ApiServiceRepository.updateService` weiter.
- `ModelCatalogService` lädt bei jedem App-Start die verfügbare Modellliste des Anbieters (mit lokalem Cache und Fallback-Liste).
- Prompts auf Deutsch mit strikter JSON-Vorgabe; Markdown-Fences werden vor dem Parsen entfernt.
- Der Coach nutzt Function Calling (`CoachTools`) und kann darüber Einträge schreiben.

### Goals Calculation
- Mifflin-St Jeor BMR: `10w + 6.25h - 5a + {5 | -161}`
- TDEE = BMR × Aktivitätsfaktor, Ziel = TDEE + Ziel-Modifikator (mit Sicherheitsuntergrenze)
- Makroaufteilung nach Ziel (Protein 1,5–2,0 g/kg, Fett 25–30 %, Kohlenhydrate füllen auf)
- Optional wird der Aktivitätsverbrauch dem Tagesbudget zugerechnet (`eatBackActivityCalories`).

### Navigation
- Navigator 1.0 (push/pop + `showDialog`), kein Routing-Paket.
- `AppShell` hält die vier Tabs in einem `IndexedStack`: **Coach, Heute, Verlauf, Profil** (Coach ist Tab 0).
- Eigene Routen nur für `PlansScreen`, `PhotoInputScreen` und `BarcodeScannerScreen`; alles andere sind Dialoge.

### Theming & Design System
- Fünf Paletten (`amethyst`, `sapphire`, `smaragd`, `black_white`, `pink`), jede mit hellem und dunklem `ColorScheme`; Modus hell/dunkel/system getrennt in SharedPreferences gespeichert.
- `AppTheme.light/dark(paletteKey)` baut das Theme inklusive `AppColors` ThemeExtension (protein, carbs, fat, success, warning, danger) und Komponenten-Themes.
- Abstände und Radien ausschließlich über `Space`/`Corner`/`Stroke` aus `lib/ui/theme/tokens.dart`.
- Oberflächen werden aus `lib/ui/widgets/kit/` komponiert (`AppCard`, `SectionHeader`, `StatusPill`, `Notice`, `EmptyState`, `LoadingState`, `AppFeedback`), nicht in Screens nachgebaut.
- Farbe nur über `colorScheme`-Rollen oder `AppColors`; kein `Colors.red`, kein `Color(0x...)` in UI-Code.

### Feedback
- `MainProvider.errorMessage` / `successMessage` werden vom `AppShell` als SnackBar gezeigt; Screens zeigen für Provider-Fehler kein eigenes Banner.
- Lokale Fehler (Kamera-Berechtigung, Validierung) über `AppFeedback.error`.
- Während einer KI-Anfrage: `LinearProgressIndicator` plus `loadingLabel`, keine blockierende Vollbild-Überlagerung.

### Android Home-Screen Widget
- `WidgetBridge` (Dart) ↔ `MainActivity` + `KalorientrackerWidgetProvider` (Kotlin) über einen `MethodChannel`.
- Actions `add_text` / `add_voice` / `add_photo` werden beim Start an den „Heute“-Tab weitergereicht.

## Conventions

### Immutability
- Alle Modelle: `final` Felder + `copyWith`, handgeschriebenes `toMap`/`fromMap` bzw. `toJson`/`fromJson`.
- Keine Code-Generierung (kein `build_runner`, kein freezed, kein json_serializable).

### IDs
- Entitäten nutzen `uuid` v4.
- `FoodItem.id` wird aus dem Namen abgeleitet: `name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_')`.

### Error Handling
- KI-Services werfen `AiException` mit lesbarer deutscher Meldung.
- `MainProvider` fängt und setzt `errorMessage`, das der `AppShell` als SnackBar anzeigt.

### Testing
- `flutter test` — 7 Testdateien unter `test/`:
  `ai_services_test.dart`, `app_text_field_test.dart`, `assistant_and_edit_test.dart`, `goals_calculator_test.dart`, `model_catalog_service_test.dart`, `new_features_test.dart`, `stats_and_coach_tools_test.dart`.
- Abgedeckt sind KI-Service-Requests (mit gemocktem `http.Client`), JSON-Parsing, Zielberechnung, Statistik/Aggregation, Coach-Tools, `ModelCatalogService` und Widget-Dialoge.

---

## DevOps & Deployment Strategy

### Build Commands

| Platform | Command | Output |
|----------|---------|--------|
| Android APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android AAB | `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` |
| iOS | `flutter build ios --release --no-codesign` | `build/ios/ipa/` |
| Web | `flutter build web --release` | `build/web/` |
| Windows | `flutter build windows --release` | `build/windows/runner/Release/` |
| macOS | `flutter build macos --release` | `build/macos/Build/Products/Release/` |
| Linux | `flutter build linux --release` | `build/linux/x64/release/bundle/` |

### Recommended CI Pipeline (GitHub Actions)

| Trigger | Jobs |
|---------|------|
| PR to `main`/`develop` | `flutter analyze` → `flutter test` |
| Push to `main` | analyze + test + build all platforms |
| Tag `v*` | analyze + test + build + deploy |

### Versioning

```
pubspec.yaml:  version: MAJOR.MINOR.PATCH+BUILD
CI bumps BUILD via --build-number=${{ github.run_number }}
Tagged releases follow semver (v1.2.3).
```

### Environment

Da die App vollständig lokal läuft (kein Backend), gibt es keine getrennten Umgebungen. API-Schlüssel gibt der Nutzer in der App ein; sie liegen in SharedPreferences.

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready, protected |
| `develop` | Integration |
| `feat/*` | Feature branches |
| `release/v*` | Release candidates |
| `hotfix/*` | Urgent fixes |

### Current Status
- **No CI/CD configured** — alle Builds laufen manuell über `flutter build`.
- **Tests vorhanden** — 7 Dateien, laufen mit `flutter test`.
- **No deployment pipeline** — APK/IPA/Web-Builds entstehen lokal.
- **No code signing setup** — Signierung wird lokal im IDE/Keystore erledigt.
