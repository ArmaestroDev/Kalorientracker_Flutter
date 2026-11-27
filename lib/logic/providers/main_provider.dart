import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:intl/intl.dart';
import '../../data/models/ai_model_option.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/activity_entry.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/user_plan.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/calorie_goals.dart';
import '../../data/models/enums.dart';
import '../../data/models/food_item.dart';
import '../../data/models/weight_entry.dart';
import '../../data/repositories/log_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/repositories/api_service_repository.dart';
import '../../data/services/generative_service.dart';
import '../../data/services/gemini_api_service.dart';
import '../../data/services/claude_api_service.dart';
import '../../data/services/openai_compatible_service.dart';
import '../../data/services/food_api_service.dart';
import '../../data/services/model_catalog_service.dart';
import '../../data/services/pdf_plan_extractor.dart';
import '../assistant_context_builder.dart';
import '../coach_tools.dart';
import '../history_data.dart';
import '../nutrition_stats.dart';
import '../goals_calculator.dart';
import '../widget_bridge.dart';
import '../../ui/theme/app_theme.dart';

/// Main state provider for the Kalorientracker app
class MainProvider extends ChangeNotifier {
  final LogRepository _logRepository;
  final UserPreferencesRepository _prefsRepository;
  final ApiServiceRepository _apiServiceRepository;
  final ModelCatalogService _modelCatalogService;

  MainProvider({
    required LogRepository logRepository,
    required UserPreferencesRepository prefsRepository,
    required ApiServiceRepository apiServiceRepository,
    ModelCatalogService? modelCatalogService,
  }) : _logRepository = logRepository,
       _prefsRepository = prefsRepository,
       _apiServiceRepository = apiServiceRepository,
       _modelCatalogService = modelCatalogService ?? ModelCatalogService();

  // State
  DateTime _selectedDate = _today();
  DateTime _lastKnownToday = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<FoodEntry> _foodEntries = [];
  List<ActivityEntry> _activityEntries = [];
  UserProfile _userProfile = const UserProfile();
  CalorieGoals _goals = const CalorieGoals();
  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;
  FoodNutritionInfo? _scannedFoodInfo;
  String _currentTheme = 'amethyst';
  ThemeMode _themeMode = ThemeMode.system;
  Map<AiProvider, List<AiModelOption>> _modelCatalog = {};
  bool _modelsRefreshing = false;
  final Map<AiProvider, String> _modelErrors = {};
  String? _successMessage;
  String? _loadingLabel;
  List<WeightEntry> _weightEntries = [];
  List<FoodEntry> _weekFoodEntries = [];
  List<ActivityEntry> _weekActivityEntries = [];
  List<UserPlan> _plans = [];
  List<ChatMessage> _assistantMessages = [];
  bool _assistantBusy = false;
  String? _assistantStatus;
  int _dataVersion = 0;
  int _dateLoadToken = 0;
  String _entryDraftName = '';
  String _entryDraftDescription = '';

  // Getters
  DateTime get selectedDate => _selectedDate;
  List<FoodEntry> get foodEntries => _foodEntries;
  List<ActivityEntry> get activityEntries => _activityEntries;
  UserProfile get userProfile => _userProfile;
  CalorieGoals get goals => _goals;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  String? get errorMessage => _errorMessage;
  FoodNutritionInfo? get scannedFoodInfo => _scannedFoodInfo;
  String get currentTheme => _currentTheme;
  List<UserPlan> get plans => List.unmodifiable(_plans);
  int get activePlanCount => _plans.where((p) => p.isActive).length;
  List<ChatMessage> get assistantMessages =>
      List.unmodifiable(_assistantMessages);
  bool get assistantBusy => _assistantBusy;
  String? get assistantStatus => _assistantStatus;
  ThemeMode get themeMode => _themeMode;
  bool get modelsRefreshing => _modelsRefreshing;
  String? modelErrorFor(AiProvider provider) => _modelErrors[provider];
  String? get successMessage => _successMessage;
  String? get loadingLabel => _loadingLabel;
  String get entryDraftName => _entryDraftName;
  String get entryDraftDescription => _entryDraftDescription;

  void saveEntryDraft(String name, String description) {
    _entryDraftName = name;
    _entryDraftDescription = description;
  }

  List<AiModelOption> modelsFor(AiProvider provider) {
    final cached = _modelCatalog[provider];
    final options = cached != null && cached.isNotEmpty
        ? List<AiModelOption>.of(cached)
        : List<AiModelOption>.of(ModelCatalogService.fallback[provider]!);
    final selectedId = _userProfile.modelFor(provider);
    if (!options.any((o) => o.id == selectedId)) {
      options.add(
        AiModelOption(
          id: selectedId,
          label: '$selectedId (eigenes)',
          free: !provider.requiresPaidKey,
        ),
      );
    }
    return options;
  }

  /// Increments whenever logged data may have changed, so screens can reload
  int get dataVersion => _dataVersion;

  // Computed values
  int get totalCalories => _foodEntries.fold(0, (sum, e) => sum + e.calories);
  int get totalProtein => _foodEntries.fold(0, (sum, e) => sum + e.protein);
  int get totalCarbs => _foodEntries.fold(0, (sum, e) => sum + e.carbs);
  int get totalFat => _foodEntries.fold(0, (sum, e) => sum + e.fat);
  int get totalBurned =>
      _activityEntries.fold(0, (sum, e) => sum + e.caloriesBurned);

  /// Daily budget. Logged activities are only added when the user opted in,
  /// because the activity level multiplier already includes regular training.
  int get calorieBudget => _budgetFor(totalBurned);

  int _budgetFor(int burned) =>
      _goals.calories + (_userProfile.eatBackActivityCalories ? burned : 0);

  DateTime get weekStart => startOfWeek(_selectedDate);

  static DateTime _daysBefore(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day - days);

  /// Week budget, consumption and what is left for the week of the selected date
  WeekStatus get weekStatus => NutritionStats.weekStatus(
    NutritionStats.daily(
      _weekFoodEntries,
      _weekActivityEntries,
      weekStart,
      _selectedDate,
    ),
    _selectedDate,
    dailyGoal: _goals.calories,
    eatBackActivity: _userProfile.eatBackActivityCalories,
  );

  double? get weightOnSelectedDate {
    final key = dayKey(_selectedDate);
    for (final w in _weightEntries) {
      if (dayKey(w.date) == key) return w.weightKg;
    }
    return null;
  }

  double? get weightAverage7Days => _averageWeight(0);
  double? get weightAveragePrevious7Days => _averageWeight(7);

  double? _averageWeight(int daysBack, {DateTime? anchor}) {
    final end = _daysBefore(anchor ?? _selectedDate, daysBack);
    final start = _daysBefore(end, 6);
    final values = _weightEntries
        .where((w) => !w.date.isBefore(start) && !w.date.isAfter(end))
        .map((w) => w.weightKg)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? get _bodyWeightForEstimates =>
      weightAverage7Days ??
      (_userProfile.weightKg > 0 ? _userProfile.weightKg : null);

  static int _scale(double value, double factor) => (value * factor).round();

  /// Initialize the provider by loading saved data
  Future<void> loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _userProfile = await _prefsRepository.loadUserProfile();
      _goals = await _prefsRepository.loadCalorieGoals();
      if (_userProfile.hasBodyData) {
        _goals = GoalsCalculator.calculateGoals(_userProfile);
        await _prefsRepository.saveCalorieGoals(_goals);
      }
      _currentTheme = await _prefsRepository.loadTheme();
      _themeMode = AppTheme.themeModeFrom(
        await _prefsRepository.loadThemeMode(),
      );
      _modelCatalog = await _prefsRepository.loadModelCatalog();
      _assistantMessages = await _prefsRepository.loadChatHistory();
      _plans = await _logRepository.getPlans();
      _initializeApiService(_userProfile);
      await _loadEntriesForDate(_selectedDate);
      await _syncHomeWidget();
    } catch (e) {
      _errorMessage = _errorText(e);
    }

    _initialized = true;
    _isLoading = false;
    notifyListeners();
    unawaited(refreshModelCatalog());
  }

  /// Advances [_selectedDate] to the new day when the app resumes past midnight
  Future<void> refreshTodayIfNeeded() async {
    final nowToday = _today();
    if (nowToday == _lastKnownToday) return;
    final wasViewingYesterday = _selectedDate == _lastKnownToday;
    _lastKnownToday = nowToday;
    if (wasViewingYesterday) {
      await changeDate(nowToday);
    } else {
      await _syncHomeWidget();
    }
  }

  void _initializeApiService(UserProfile profile) {
    final provider = profile.selectedProvider;
    final key = profile.apiKeyFor(provider).trim();
    final model = profile.modelFor(provider);
    final GenerativeService service = switch (provider) {
      AiProvider.claude => ClaudeApiService(key, model),
      AiProvider.openai => OpenAiCompatibleService.openAi(key, model),
      AiProvider.grok => OpenAiCompatibleService.grok(key, model),
      AiProvider.gemini => GeminiApiService(key, model),
    };
    _apiServiceRepository.updateService(service);
  }

  String? get missingApiKeyMessage {
    final provider = _userProfile.selectedProvider;
    if (_userProfile.apiKeyFor(provider).trim().isNotEmpty) return null;
    return 'Bitte gib zuerst deinen ${provider.label}-API-Schlüssel im Profil ein.';
  }

  bool _isApiKeyMissing() {
    final message = missingApiKeyMessage;
    if (message == null) return false;
    _errorMessage = message;
    notifyListeners();
    return true;
  }

  static String _errorText(Object error) {
    if (error is AiException) return error.message;
    return 'Unerwarteter Fehler: $error';
  }

  /// Runs an AI call behind the loading overlay and reports errors in the banner
  Future<bool> _runAiTask(
    Future<void> Function(DateTime targetDate) task, {
    String label = 'KI schätzt Nährwerte…',
    String? success,
    String? Function()? successBuilder,
  }) async {
    if (_isApiKeyMissing()) return false;
    final targetDate = _selectedDate;
    _isLoading = true;
    _loadingLabel = label;
    _errorMessage = null;
    notifyListeners();
    var ok = false;
    try {
      await task(targetDate);
      await _loadEntriesForDate(_selectedDate);
      await _syncHomeWidget();
      final message = successBuilder != null ? successBuilder() : success;
      if (message != null) _successMessage = message;
      ok = true;
    } catch (e) {
      _errorMessage = _errorText(e);
    }
    _isLoading = false;
    _loadingLabel = null;
    notifyListeners();
    return ok;
  }

  Future<void> _loadEntriesForDate(DateTime date) async {
    final token = ++_dateLoadToken;
    final foods = await _logRepository.getFoodEntriesForDate(date);
    final activities = await _logRepository.getActivityEntriesForDate(date);
    final weekStartDate = startOfWeek(date);
    final weekFoods = await _logRepository.getFoodEntriesForDateRange(
      weekStartDate,
      date,
    );
    final weekActivities = await _logRepository.getActivityEntriesForDateRange(
      weekStartDate,
      date,
    );
    final weights = await _logRepository.getWeightEntriesForDateRange(
      _daysBefore(date, 13),
      date,
    );
    if (token != _dateLoadToken) return;
    _foodEntries = foods;
    _activityEntries = activities;
    _weekFoodEntries = weekFoods;
    _weekActivityEntries = weekActivities;
    _weightEntries = weights;
    _dataVersion++;
  }

  Future<void> _syncHomeWidget() async {
    final today = _today();
    final List<FoodEntry> todayFoods;
    final List<ActivityEntry> todayActivities;
    if (dayKey(_selectedDate) == dayKey(today)) {
      todayFoods = _foodEntries;
      todayActivities = _activityEntries;
    } else {
      todayFoods = await _logRepository.getFoodEntriesForDate(today);
      todayActivities = await _logRepository.getActivityEntriesForDate(today);
    }
    final eaten = todayFoods.fold(0, (s, f) => s + f.calories);
    final burned = todayActivities.fold(0, (s, a) => s + a.caloriesBurned);
    await WidgetBridge.updateSummary(
      eatenKcal: eaten,
      budgetKcal: _budgetFor(burned),
      protein: todayFoods.fold(0, (s, f) => s + f.protein),
      proteinGoal: _goals.proteinGrams,
      carbs: todayFoods.fold(0, (s, f) => s + f.carbs),
      fat: todayFoods.fold(0, (s, f) => s + f.fat),
      hasGoals: _goals.calories > 0,
      dateLabel: DateFormat('EE, d. MMM', 'de_DE').format(today),
    );
  }

  /// Log body weight for the selected date. The profile weight follows the
  /// 7-day average so goals adapt without daily water-weight noise.
  Future<void> saveWeight(double weightKg) async {
    try {
      final date = _selectedDate;
      await _logRepository.saveWeightEntry(
        WeightEntry(date: date, weightKg: weightKg),
      );
      await _loadEntriesForDate(_selectedDate);
      await _syncProfileWeightToAverage(modifiedDate: date);
      await _syncHomeWidget();
      _successMessage = 'Gewicht gespeichert';
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  Future<void> deleteWeight() async {
    try {
      final date = _selectedDate;
      await _logRepository.deleteWeightEntry(date);
      await _loadEntriesForDate(_selectedDate);
      await _syncProfileWeightToAverage(modifiedDate: date);
      await _syncHomeWidget();
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  Future<void> _syncProfileWeightToAverage({DateTime? modifiedDate}) async {
    final today = _today();
    final date = modifiedDate ?? _selectedDate;
    if (date.isAfter(today) || !date.isAfter(_daysBefore(today, 7))) return;
    if (!_userProfile.hasBodyData) return;

    final recentWeights = await _logRepository.getWeightEntriesForDateRange(
      _daysBefore(today, 6),
      today,
    );
    if (recentWeights.isEmpty) return;
    final average =
        recentWeights.fold(0.0, (s, w) => s + w.weightKg) /
        recentWeights.length;
    final rounded = (average * 10).round() / 10;
    if (rounded == _userProfile.weightKg) return;
    final profile = _userProfile.copyWith(weightKg: rounded);
    _goals = GoalsCalculator.calculateGoals(profile);
    _userProfile = profile;
    await _prefsRepository.saveUserProfile(profile);
    await _prefsRepository.saveCalorieGoals(_goals);
  }

  /// Change the selected date and load entries
  Future<void> changeDate(DateTime newDate) async {
    _selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
    _isLoading = true;
    notifyListeners();

    try {
      await _loadEntriesForDate(_selectedDate);
    } catch (e) {
      _errorMessage = _errorText(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String historyIdFor(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

  Future<String> _saveFoodItemToHistory(FoodNutritionInfo info) async {
    final id = historyIdFor(info.name);
    final isWeight = _isWeightUnit(info.unit);
    final hasExplicitPer100 =
        info.caloriesPer100g != null &&
        (info.caloriesPer100g! > 0 || isWeight);
    final amount = info.amount;
    final canComputePer100 =
        !hasExplicitPer100 && isWeight && amount != null && amount > 0;
    final portions = amount != null && amount > 0 && !isWeight ? amount : 1.0;

    final double kcal100;
    final double p100;
    final double c100;
    final double f100;
    final String defaultUnit;

    if (hasExplicitPer100) {
      kcal100 = info.caloriesPer100g!;
      p100 = info.proteinPer100g ?? 0;
      c100 = info.carbsPer100g ?? 0;
      f100 = info.fatPer100g ?? 0;
      defaultUnit = info.unit == 'ml' ? 'ml' : 'g';
    } else if (canComputePer100) {
      final scale = 100.0 / amount;
      kcal100 = info.calories * scale;
      p100 = info.protein * scale;
      c100 = info.carbs * scale;
      f100 = info.fat * scale;
      defaultUnit = info.unit == 'ml' ? 'ml' : 'g';
    } else {
      kcal100 = info.calories / portions;
      p100 = info.protein / portions;
      c100 = info.carbs / portions;
      f100 = info.fat / portions;
      defaultUnit = info.unit == 'Stk' ? 'Stk' : 'Portion';
    }

    final item = FoodItem(
      id: id,
      name: info.name,
      category: info.category ?? 'Allgemein',
      caloriesPer100g: kcal100,
      proteinPer100g: p100,
      carbsPer100g: c100,
      fatPer100g: f100,
      defaultUnit: defaultUnit,
      lastUsed: DateTime.now(),
    );
    await _logRepository.saveFoodItem(item);
    return id;
  }

  static bool _isWeightUnit(String? unit) => unit == 'g' || unit == 'ml';

  Future<void> _addFoodEntryFromInfo(
    FoodNutritionInfo info, {
    DateTime? date,
  }) async {
    final historyId = await _saveFoodItemToHistory(info);
    await _logRepository.addFoodEntry(
      FoodEntry(
        name: info.name,
        calories: info.calories,
        protein: info.protein.round(),
        carbs: info.carbs.round(),
        fat: info.fat.round(),
        date: date ?? _selectedDate,
        amount: info.amount,
        unit: info.amount != null ? (info.unit ?? 'Portion') : null,
        foodItemId: historyId,
      ),
    );
  }

  Future<void> _addActivityEntryFromInfo(
    ActivityInfo info, {
    DateTime? date,
  }) {
    return _logRepository.addActivityEntry(
      ActivityEntry(
        name: info.name,
        caloriesBurned: info.caloriesBurned,
        date: date ?? _selectedDate,
      ),
    );
  }

  /// Fetch food info by barcode
  Future<bool> fetchFoodInfoByBarcode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    var found = false;
    try {
      final nutritionInfo = await _apiServiceRepository.fetchBarCodeNutrition(
        code,
      );

      if (nutritionInfo != null && nutritionInfo.calories >= 0) {
        _scannedFoodInfo = nutritionInfo;
        found = true;
      } else {
        _errorMessage =
            'Produkt nicht gefunden oder keine Nährwertdaten verfügbar.';
      }
    } catch (e) {
      _errorMessage = _errorText(e);
    }

    _isLoading = false;
    notifyListeners();
    return found;
  }

  /// Looks up a barcode without toggling global error state (for photo fallback)
  Future<FoodNutritionInfo?> lookupBarcodeSilently(String code) async {
    try {
      return await _apiServiceRepository.fetchBarCodeNutrition(code);
    } catch (_) {
      return null;
    }
  }

  void setScannedFoodInfo(FoodNutritionInfo info) {
    _scannedFoodInfo = info;
    notifyListeners();
  }

  /// Add scanned food item with gram/ml weight
  Future<void> addScannedFoodItem(FoodNutritionInfo foodInfo, int grams) async {
    final targetDate = _selectedDate;
    try {
      final historyId = await _saveFoodItemToHistory(foodInfo);
      final unit = foodInfo.unit == 'ml' ? 'ml' : 'g';
      final factor = grams / 100.0;
      final newEntry = FoodEntry(
        name: foodInfo.name,
        calories: _scale(
          foodInfo.caloriesPer100g ?? foodInfo.calories.toDouble(),
          factor,
        ),
        protein: _scale(foodInfo.proteinPer100g ?? foodInfo.protein, factor),
        carbs: _scale(foodInfo.carbsPer100g ?? foodInfo.carbs, factor),
        fat: _scale(foodInfo.fatPer100g ?? foodInfo.fat, factor),
        date: targetDate,
        amount: grams.toDouble(),
        unit: unit,
        foodItemId: historyId,
      );

      await _logRepository.addFoodEntry(newEntry);
      await _loadEntriesForDate(_selectedDate);
      await _syncHomeWidget();
      _successMessage = 'Produkt hinzugefügt';
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  /// Add food item from history with specific amount (smart scaling)
  Future<void> addFoodItemFromHistory(FoodItem item, double amount) async {
    final targetDate = _selectedDate;
    try {
      final unit = item.defaultUnit.isEmpty ? 'g' : item.defaultUnit;
      final isPerUnit = unit == 'Portion' || unit == 'Stk';
      final factor = isPerUnit ? amount : amount / 100.0;

      await _logRepository.saveFoodItem(
        item.copyWith(defaultUnit: unit, lastUsed: DateTime.now()),
      );

      await _logRepository.addFoodEntry(
        FoodEntry(
          name: item.name,
          calories: _scale(item.caloriesPer100g, factor),
          protein: _scale(item.proteinPer100g, factor),
          carbs: _scale(item.carbsPer100g, factor),
          fat: _scale(item.fatPer100g, factor),
          date: targetDate,
          amount: amount,
          unit: unit,
          foodItemId: item.id,
        ),
      );
      await _loadEntriesForDate(_selectedDate);
      await _syncHomeWidget();
      _successMessage = 'Mahlzeit hinzugefügt';
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  // --- Food Database Accessors ---

  Future<List<FoodItem>> getRecentFoodItems() {
    return _logRepository.getRecentFoodItems();
  }

  Future<List<FoodItem>> searchFoodItems(String query) {
    return _logRepository.searchFoodItems(query);
  }

  Future<List<String>> getFoodCategories() {
    return _logRepository.getFoodCategories();
  }

  Future<List<FoodItem>> getFoodItemsByCategory(String category) {
    return _logRepository.getFoodItemsByCategory(category);
  }

  Future<void> deleteFoodItemFromHistory(String id) async {
    try {
      await _logRepository.deleteFoodItem(id);
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  void clearScannedFoodInfo() {
    _scannedFoodInfo = null;
    notifyListeners();
  }

  /// Add unified entry - AI classifies as food or activity automatically
  Future<bool> addUnifiedEntry(String input, String description) async {
    saveEntryDraft(input, description);
    var count = 0;
    final ok = await _runAiTask(
      (targetDate) async {
        final entries = await _apiServiceRepository.classifyAndProcessAll(
          input,
          description,
          _bodyWeightForEstimates,
        );
        for (final entry in entries) {
          if (entry.isFood) {
            await _addFoodEntryFromInfo(entry.foodInfo!, date: targetDate);
          } else {
            await _addActivityEntryFromInfo(
              entry.activityInfo!,
              date: targetDate,
            );
          }
          count++;
        }
      },
      label: 'KI analysiert Eintrag…',
      successBuilder: () => count == 1
          ? 'Eintrag hinzugefügt'
          : '$count Einträge hinzugefügt',
    );
    if (ok) saveEntryDraft('', '');
    return ok;
  }

  /// Add food from image using AI estimation
  Future<bool> addFoodFromImage(Uint8List imageBytes, String? description) {
    return _runAiTask(
      (targetDate) async {
        final info = await _apiServiceRepository.estimateFoodFromImage(
          imageBytes,
          description,
        );
        await _addFoodEntryFromInfo(info, date: targetDate);
      },
      label: 'KI analysiert Foto…',
      success: 'Mahlzeit aus Foto hinzugefügt',
    );
  }

  /// Re-estimate a food entry with AI, using the (possibly edited) name and
  /// amount from the edit dialog
  Future<bool> reFetchFoodItem(FoodEntry foodEntry) {
    return _runAiTask(
      (_) async {
        final amount =
            foodEntry.amount != null &&
                foodEntry.unit != null &&
                foodEntry.unit!.isNotEmpty
            ? '${_formatAmount(foodEntry.amount!)} ${foodEntry.unit}'
            : '';
        final info = await _apiServiceRepository.fetchFoodNutrition(
          amount.isEmpty ? foodEntry.name : '$amount ${foodEntry.name}',
          '',
        );
        final historyId = await _saveFoodItemToHistory(info);
        await _logRepository.updateFoodEntry(
          foodEntry.copyWith(
            name: info.name,
            calories: info.calories,
            protein: info.protein.round(),
            carbs: info.carbs.round(),
            fat: info.fat.round(),
            amount: info.amount ?? foodEntry.amount,
            unit: info.amount != null ? info.unit : foodEntry.unit,
            foodItemId: historyId,
          ),
        );
      },
      label: 'KI schätzt neu…',
      success: 'Neu berechnet',
    );
  }

  /// Re-estimate an activity entry with AI, using the edited name
  Future<bool> reFetchActivityItem(ActivityEntry activityEntry) {
    return _runAiTask(
      (_) async {
        final info = await _apiServiceRepository.fetchActivityCalories(
          activityEntry.name,
          _bodyWeightForEstimates,
        );
        await _logRepository.updateActivityEntry(
          activityEntry.copyWith(
            name: info.name,
            caloriesBurned: info.caloriesBurned,
          ),
        );
      },
      label: 'KI schätzt neu…',
      success: 'Neu berechnet',
    );
  }

  static String _formatAmount(double amount) => amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(1);

  /// Update food item manually
  Future<void> updateFoodItemManual(FoodEntry foodEntry) async {
    try {
      await _logRepository.updateFoodEntry(foodEntry);
      await _loadEntriesForDate(_selectedDate);
      await _syncHomeWidget();
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  /// Update activity item manually
  Future<void> updateActivityItemManual(ActivityEntry activityEntry) async {
    try {
      await _logRepository.updateActivityEntry(activityEntry);
      await _loadEntriesForDate(_selectedDate);
      await _syncHomeWidget();
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  /// Delete food item
  Future<void> deleteFoodItem(FoodEntry foodEntry) async {
    try {
      await _logRepository.deleteFoodEntry(foodEntry);
      await _loadEntriesForDate(_selectedDate);
      await _syncHomeWidget();
      _successMessage = 'Eintrag gelöscht';
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  /// Delete activity item
  Future<void> deleteActivityItem(ActivityEntry activityEntry) async {
    try {
      await _logRepository.deleteActivityEntry(activityEntry);
      await _loadEntriesForDate(_selectedDate);
      await _syncHomeWidget();
      _successMessage = 'Eintrag gelöscht';
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  // --- User Plans (Meal & Training PDFs) ---

  Future<String> extractPlanFromPdfBytes(
    Uint8List bytes,
    PlanType type,
    String fileName,
  ) async {
    try {
      final local = PdfPlanExtractor.extractText(bytes);
      if (local.hasMeaningfulText) return local.text;
    } catch (_) {
      // Fall through to AI PDF extraction if local text extraction fails
    }

    if (missingApiKeyMessage != null) {
      throw const AiException(
        'Diese PDF enthält keinen lesbaren Text (evtl. ein Scan). Hinterlege einen Gemini- oder Claude-API-Schlüssel zum Auslesen oder füge den Plan als Text ein.',
      );
    }
    return _apiServiceRepository.extractPlanFromPdf(bytes, type, fileName);
  }

  Future<void> savePlan(UserPlan plan) async {
    try {
      await _logRepository.savePlan(plan.copyWith(updatedAt: DateTime.now()));
      _plans = await _logRepository.getPlans();
      _successMessage = 'Plan gespeichert';
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  Future<void> togglePlanActive(UserPlan plan) async {
    await savePlan(plan.copyWith(isActive: !plan.isActive));
  }

  Future<void> deletePlan(String id) async {
    try {
      await _logRepository.deletePlan(id);
      _plans = await _logRepository.getPlans();
      _successMessage = 'Plan gelöscht';
      notifyListeners();
    } catch (e) {
      _errorMessage = _errorText(e);
      notifyListeners();
    }
  }

  /// Save user profile and recalculate goals
  Future<void> saveUserProfileAndRecalculateGoals(
    UserProfile profile, {
    String successMessage = 'Profil gespeichert',
  }) async {
    final oldProfile = _userProfile;
    final keysChanged =
        oldProfile.geminiApiKey != profile.geminiApiKey ||
        oldProfile.claudeApiKey != profile.claudeApiKey ||
        oldProfile.openaiApiKey != profile.openaiApiKey ||
        oldProfile.grokApiKey != profile.grokApiKey;

    _initializeApiService(profile);
    final newGoals = GoalsCalculator.calculateGoals(profile);

    await _prefsRepository.saveUserProfile(profile);
    await _prefsRepository.saveCalorieGoals(newGoals);

    _userProfile = profile;
    _goals = newGoals;
    if (_errorMessage != null && missingApiKeyMessage == null) {
      _errorMessage = null;
    }
    _successMessage = successMessage;
    await _syncHomeWidget();
    notifyListeners();
    if (keysChanged) unawaited(refreshModelCatalog());
  }

  /// Change app theme
  Future<void> changeTheme(String themeName) async {
    _currentTheme = themeName;
    await _prefsRepository.saveTheme(themeName);
    notifyListeners();
  }

  Future<void> changeThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefsRepository.saveThemeMode(AppTheme.themeModeKey(mode));
    notifyListeners();
  }

  Future<void> selectModel(AiProvider provider, String modelId) async {
    final overrides = Map<AiProvider, String>.of(_userProfile.modelOverrides);
    overrides[provider] = modelId;
    await saveUserProfileAndRecalculateGoals(
      _userProfile.copyWith(modelOverrides: overrides),
      successMessage: 'Modell gewechselt: $modelId',
    );
  }

  Future<void> refreshModelCatalog() async {
    if (_modelsRefreshing) return;
    _modelsRefreshing = true;
    notifyListeners();

    try {
      for (final provider in AiProvider.values) {
        final key = _userProfile.apiKeyFor(provider).trim();
        if (key.isEmpty) continue;
        try {
          _modelCatalog[provider] = await _modelCatalogService.fetch(
            provider,
            key,
          );
          _modelErrors.remove(provider);
        } catch (e) {
          _modelErrors[provider] = _errorText(e);
        }
      }

      _modelCatalog = Map<AiProvider, List<AiModelOption>>.of(_modelCatalog);
      await _prefsRepository.saveModelCatalog(_modelCatalog);

      final provider = _userProfile.selectedProvider;
      final models = _modelCatalog[provider];
      if (models != null &&
          models.isNotEmpty &&
          !models.any((m) => m.id == _userProfile.modelFor(provider))) {
        final overrides = Map<AiProvider, String>.of(
          _userProfile.modelOverrides,
        );
        overrides[provider] = models.first.id;
        final profile = _userProfile.copyWith(modelOverrides: overrides);
        await _prefsRepository.saveUserProfile(profile);
        _userProfile = profile;
        _initializeApiService(_userProfile);
      }
    } catch (e) {
      _modelErrors[_userProfile.selectedProvider] = _errorText(e);
    } finally {
      _modelsRefreshing = false;
      notifyListeners();
    }
  }

  Future<String?> testConnection() async {
    final keyMessage = missingApiKeyMessage;
    if (keyMessage != null) return keyMessage;
    try {
      await _apiServiceRepository.ping();
      return null;
    } catch (e) {
      return _errorText(e);
    }
  }

  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }

  /// Dismiss error message
  void dismissError() {
    _errorMessage = null;
    notifyListeners();
  }

  // --- Personal assistant ---

  static const int _maxMessagesSentToModel = 20;

  /// Sends a message to the personal assistant. The system prompt is rebuilt
  /// on every call so the assistant always sees the latest log, plans and profile.
  Future<void> sendAssistantMessage(String text, {String? displayText}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _assistantBusy) return;

    _assistantMessages = [
      ..._assistantMessages.where((m) => !m.isError),
      ChatMessage(role: ChatRole.user, text: trimmed, displayText: displayText),
    ];
    await _prefsRepository.saveChatHistory(
      _assistantMessages.where((m) => !m.isError).toList(),
    );
    await _requestAssistantReply();
  }

  /// Retries the last user message after an error
  Future<void> retryAssistant() async {
    if (_assistantBusy) return;
    _assistantMessages = _assistantMessages.where((m) => !m.isError).toList();
    if (_assistantMessages.isEmpty || !_assistantMessages.last.isUser) return;
    await _requestAssistantReply();
  }

  Future<void> _requestAssistantReply() async {
    final keyMessage = missingApiKeyMessage;
    if (keyMessage != null) {
      _assistantMessages = [
        ..._assistantMessages,
        ChatMessage(role: ChatRole.assistant, text: keyMessage, isError: true),
      ];
      notifyListeners();
      return;
    }

    _assistantBusy = true;
    notifyListeners();

    var loggedChanges = false;
    try {
      final system = await _buildAssistantContext();
      final history = _assistantMessages.length > _maxMessagesSentToModel
          ? _assistantMessages.sublist(
              _assistantMessages.length - _maxMessagesSentToModel,
            )
          : _assistantMessages;
      final firstUser = history.indexWhere((m) => m.isUser);
      final tools = _coachTools(onMutate: () => loggedChanges = true);
      final reply = await _apiServiceRepository.chat(
        system: system,
        messages: firstUser <= 0 ? history : history.sublist(firstUser),
        tools: CoachTools.definitions,
        onToolCall: tools.execute,
      );
      if (loggedChanges) {
        await _loadEntriesForDate(_selectedDate);
        await _syncHomeWidget();
      }
      _assistantMessages = [
        ..._assistantMessages,
        ChatMessage(role: ChatRole.assistant, text: reply.trim()),
      ];
      await _prefsRepository.saveChatHistory(
        _assistantMessages.where((m) => !m.isError).toList(),
      );
    } catch (e) {
      if (loggedChanges) {
        await _loadEntriesForDate(_selectedDate);
        await _syncHomeWidget();
      }
      _assistantMessages = [
        ..._assistantMessages,
        ChatMessage(
          role: ChatRole.assistant,
          text: _errorText(e),
          isError: true,
        ),
      ];
    } finally {
      _assistantBusy = false;
      _assistantStatus = null;
      notifyListeners();
    }
  }

  CoachTools _coachTools({VoidCallback? onMutate}) => CoachTools(
    loadFoods: _logRepository.getFoodEntriesForDateRange,
    loadActivities: _logRepository.getActivityEntriesForDateRange,
    loadWeights: _logRepository.getWeightEntriesForDateRange,
    loadPlans: () async => _plans,
    onLogFood: (entry) async {
      await _logRepository.addFoodEntry(entry);
      onMutate?.call();
    },
    onLogActivity: (entry) async {
      await _logRepository.addActivityEntry(entry);
      onMutate?.call();
    },
    onLogWeight: (entry) async {
      await _logRepository.saveWeightEntry(entry);
      await _syncProfileWeightToAverage(modifiedDate: entry.date);
      onMutate?.call();
    },
    profile: _userProfile,
    goals: _goals,
    today: _today(),
    onStatus: (status) {
      _assistantStatus = status;
      notifyListeners();
    },
  );

  Future<String> _buildAssistantContext() async {
    final now = DateTime.now();
    final today = dayOnly(now);
    final recentStart = addDays(today, -7);
    final weekStartDate = startOfWeek(today);
    final loadStart = recentStart.isBefore(weekStartDate)
        ? recentStart
        : weekStartDate;

    final foods = await _logRepository.getFoodEntriesForDateRange(
      loadStart,
      today,
    );
    final activities = await _logRepository.getActivityEntriesForDateRange(
      loadStart,
      today,
    );
    final days = NutritionStats.daily(foods, activities, loadStart, today);
    final weights = await _logRepository.getWeightEntriesForDateRange(
      addDays(today, -13),
      today,
    );

    final viewingToday = dayOnly(_selectedDate) == today;
    final todayFoods = viewingToday
        ? _foodEntries
        : foods.where((f) => dayKey(f.date) == dayKey(today)).toList();
    final todayActivities = viewingToday
        ? _activityEntries
        : activities.where((a) => dayKey(a.date) == dayKey(today)).toList();
    final todayBurned = todayActivities.fold(
      0,
      (s, a) => s + a.caloriesBurned,
    );

    return AssistantContextBuilder.build(
      profile: _userProfile,
      goals: _goals,
      now: now,
      selectedDate: _selectedDate,
      dayFoods: todayFoods,
      dayActivities: todayActivities,
      dayBudget: _budgetFor(todayBurned),
      week: NutritionStats.weekStatus(
        days,
        today,
        dailyGoal: _goals.calories,
        eatBackActivity: _userProfile.eatBackActivityCalories,
      ),
      recentDays: days
          .where((d) => !d.date.isBefore(recentStart) && d.date.isBefore(today))
          .toList(),
      recentWeights: weights,
      plans: _plans,
      selectedDayFoods: viewingToday ? null : _foodEntries,
      selectedDayActivities: viewingToday ? null : _activityEntries,
      selectedDayBudget: viewingToday ? null : calorieBudget,
    );
  }

  /// Loads and aggregates logged data for the history screen
  Future<HistoryData> loadHistory(HistoryRange range) async {
    final today = _today();
    final start = range.startFor(today);
    final weekStartDate = startOfWeek(today);
    final loadStart = start.isBefore(weekStartDate) ? start : weekStartDate;
    return HistoryData.build(
      range: range,
      today: today,
      goals: _goals,
      eatBackActivity: _userProfile.eatBackActivityCalories,
      foods: await _logRepository.getFoodEntriesForDateRange(loadStart, today),
      activities: await _logRepository.getActivityEntriesForDateRange(
        loadStart,
        today,
      ),
      weights: await _logRepository.getWeightEntriesForDateRange(
        addDays(start, -6),
        today,
      ),
    );
  }

  Future<void> clearAssistantChat() async {
    _assistantMessages = [];
    await _prefsRepository.saveChatHistory(_assistantMessages);
    notifyListeners();
  }

  @override
  void dispose() {
    _modelCatalogService.close();
    super.dispose();
  }
}
