import 'package:flutter/foundation.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/activity_entry.dart';
import '../../data/models/chat_message.dart';
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
import '../assistant_context_builder.dart';
import '../coach_tools.dart';
import '../history_data.dart';
import '../nutrition_stats.dart';
import '../goals_calculator.dart';

/// Main state provider for the Kalorientracker app
class MainProvider extends ChangeNotifier {
  final LogRepository _logRepository;
  final UserPreferencesRepository _prefsRepository;
  final ApiServiceRepository _apiServiceRepository;

  MainProvider({
    required LogRepository logRepository,
    required UserPreferencesRepository prefsRepository,
    required ApiServiceRepository apiServiceRepository,
  }) : _logRepository = logRepository,
       _prefsRepository = prefsRepository,
       _apiServiceRepository = apiServiceRepository;

  // State
  DateTime _selectedDate = _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<FoodEntry> _foodEntries = [];
  List<ActivityEntry> _activityEntries = [];
  UserProfile _userProfile = const UserProfile();
  CalorieGoals _goals = const CalorieGoals();
  bool _isLoading = false;
  String? _errorMessage;
  FoodNutritionInfo? _scannedFoodInfo;
  String _currentTheme = 'Default';
  List<WeightEntry> _weightEntries = [];
  List<FoodEntry> _weekFoodEntries = [];
  List<ActivityEntry> _weekActivityEntries = [];
  List<ChatMessage> _assistantMessages = [];
  bool _assistantBusy = false;
  String? _assistantStatus;
  int _dataVersion = 0;

  // Getters
  DateTime get selectedDate => _selectedDate;
  List<FoodEntry> get foodEntries => _foodEntries;
  List<ActivityEntry> get activityEntries => _activityEntries;
  UserProfile get userProfile => _userProfile;
  CalorieGoals get goals => _goals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  FoodNutritionInfo? get scannedFoodInfo => _scannedFoodInfo;
  String get currentTheme => _currentTheme;
  List<ChatMessage> get assistantMessages =>
      List.unmodifiable(_assistantMessages);
  bool get assistantBusy => _assistantBusy;
  String? get assistantStatus => _assistantStatus;

  /// Increments whenever logged data may have changed, so screens can reload
  int get dataVersion => _dataVersion;

  // Computed values
  int get totalCalories => _foodEntries.fold(0, (sum, e) => sum + e.calories);
  int get totalProtein => _foodEntries.fold(0, (sum, e) => sum + e.protein);
  int get totalCarbs => _foodEntries.fold(0, (sum, e) => sum + e.carbs);
  int get totalFat => _foodEntries.fold(0, (sum, e) => sum + e.fat);
  int get totalBurned =>
      _activityEntries.fold(0, (sum, e) => sum + e.caloriesBurned);
  int get netCalories => totalCalories - totalBurned;

  /// Daily budget. Logged activities are only added when the user opted in,
  /// because the activity level multiplier already includes regular training.
  int get calorieBudget =>
      _goals.calories +
      (_userProfile.eatBackActivityCalories ? totalBurned : 0);
  int get remainingCalories => calorieBudget - totalCalories;

  DateTime get weekStart =>
      _daysBefore(_selectedDate, _selectedDate.weekday - DateTime.monday);

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
    final key = _dayKey(_selectedDate);
    for (final w in _weightEntries) {
      if (_dayKey(w.date) == key) return w.weightKg;
    }
    return null;
  }

  double? get weightAverage7Days => _averageWeight(0);
  double? get weightAveragePrevious7Days => _averageWeight(7);

  double? _averageWeight(int daysBack) {
    final end = _daysBefore(_selectedDate, daysBack);
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

  static String _dayKey(DateTime d) => d.toIso8601String().split('T')[0];

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
      _assistantMessages = await _prefsRepository.loadChatHistory();
      _initializeApiService(_userProfile);
      await _loadEntriesForDate(_selectedDate);
    } catch (e) {
      _errorMessage = 'Fehler beim Laden der Daten: $e';
    }

    _isLoading = false;
    notifyListeners();
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
  Future<void> _runAiTask(Future<void> Function() task) async {
    if (_isApiKeyMissing()) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await task();
      await _loadEntriesForDate(_selectedDate);
    } catch (e) {
      _errorMessage = _errorText(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadEntriesForDate(DateTime date) async {
    _foodEntries = await _logRepository.getFoodEntriesForDate(date);
    _activityEntries = await _logRepository.getActivityEntriesForDate(date);
    _weekFoodEntries = await _logRepository.getFoodEntriesForDateRange(
      weekStart,
      date,
    );
    _weekActivityEntries = await _logRepository.getActivityEntriesForDateRange(
      weekStart,
      date,
    );
    _weightEntries = await _logRepository.getWeightEntriesForDateRange(
      _daysBefore(date, 13),
      date,
    );
    _dataVersion++;
  }

  /// Log body weight for the selected date. The profile weight follows the
  /// 7-day average so goals adapt without daily water-weight noise.
  Future<void> saveWeight(double weightKg) async {
    await _logRepository.saveWeightEntry(
      WeightEntry(date: _selectedDate, weightKg: weightKg),
    );
    await _loadEntriesForDate(_selectedDate);
    await _syncProfileWeightToAverage();
    notifyListeners();
  }

  Future<void> deleteWeight() async {
    await _logRepository.deleteWeightEntry(_selectedDate);
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
  }

  Future<void> _syncProfileWeightToAverage() async {
    if (_dayKey(_selectedDate) != _dayKey(_today())) return;
    final average = weightAverage7Days;
    if (average == null || !_userProfile.hasBodyData) return;
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

    await _loadEntriesForDate(_selectedDate);

    _isLoading = false;
    notifyListeners();
  }

  static String historyIdFor(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

  Future<String> _saveFoodItemToHistory(FoodNutritionInfo info) async {
    final id = historyIdFor(info.name);
    final hasPer100 = info.caloriesPer100g != null && info.caloriesPer100g! > 0;
    final amount = info.amount;
    final portions = amount != null && amount > 0 && !_isWeightUnit(info.unit)
        ? amount
        : 1.0;

    final item = FoodItem(
      id: id,
      name: info.name,
      category: info.category ?? 'Allgemein',
      caloriesPer100g: hasPer100
          ? info.caloriesPer100g!
          : info.calories / portions,
      proteinPer100g: hasPer100
          ? (info.proteinPer100g ?? 0)
          : info.protein / portions,
      carbsPer100g: hasPer100
          ? (info.carbsPer100g ?? 0)
          : info.carbs / portions,
      fatPer100g: hasPer100 ? (info.fatPer100g ?? 0) : info.fat / portions,
      defaultUnit: hasPer100
          ? (info.unit == 'ml' ? 'ml' : 'g')
          : (info.unit == 'Stk' ? 'Stk' : 'Portion'),
      lastUsed: DateTime.now(),
    );
    await _logRepository.saveFoodItem(item);
    return id;
  }

  static bool _isWeightUnit(String? unit) => unit == 'g' || unit == 'ml';

  Future<void> _addFoodEntryFromInfo(FoodNutritionInfo info) async {
    final historyId = await _saveFoodItemToHistory(info);
    await _logRepository.addFoodEntry(
      FoodEntry(
        name: info.name,
        calories: info.calories,
        protein: info.protein.round(),
        carbs: info.carbs.round(),
        fat: info.fat.round(),
        date: _selectedDate,
        amount: info.amount,
        unit: info.amount != null ? (info.unit ?? 'Portion') : null,
        foodItemId: historyId,
      ),
    );
  }

  Future<void> _addActivityEntryFromInfo(ActivityInfo info) {
    return _logRepository.addActivityEntry(
      ActivityEntry(
        name: info.name,
        caloriesBurned: info.caloriesBurned,
        date: _selectedDate,
      ),
    );
  }

  /// Add a food item using AI to estimate nutrition
  Future<void> addFoodItem(String foodName, String description) {
    return _runAiTask(() async {
      final info = await _apiServiceRepository.fetchFoodNutrition(
        foodName,
        description,
      );
      await _addFoodEntryFromInfo(info);
    });
  }

  /// Fetch food info by barcode
  Future<void> fetchFoodInfoByBarcode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nutritionInfo = await _apiServiceRepository.fetchBarCodeNutrition(
        code,
      );

      if (nutritionInfo != null && nutritionInfo.calories >= 0) {
        _scannedFoodInfo = nutritionInfo;
      } else {
        _errorMessage =
            'Produkt nicht gefunden oder keine Nährwertdaten verfügbar.';
      }
    } catch (e) {
      _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add scanned food item with gram weight
  Future<void> addScannedFoodItem(FoodNutritionInfo foodInfo, int grams) async {
    final historyId = await _saveFoodItemToHistory(foodInfo);

    final factor = grams / 100.0;
    final newEntry = FoodEntry(
      name: foodInfo.name,
      calories: _scale(
        foodInfo.caloriesPer100g ?? foodInfo.calories.toDouble(),
        factor,
      ),
      protein: _scale(foodInfo.protein, factor),
      carbs: _scale(foodInfo.carbs, factor),
      fat: _scale(foodInfo.fat, factor),
      date: _selectedDate,
      amount: grams.toDouble(),
      unit: 'g',
      foodItemId: historyId,
    );

    await _logRepository.addFoodEntry(newEntry);
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
  }

  /// Add food item from history with specific amount (smart scaling)
  Future<void> addFoodItemFromHistory(FoodItem item, double amount) async {
    final unit = item.defaultUnit.isEmpty ? 'g' : item.defaultUnit;
    final isPerUnit = unit == 'Portion' || unit == 'Stk';
    final factor = isPerUnit ? amount : amount / 100.0;

    await _logRepository.saveFoodItem(
      FoodItem(
        id: item.id,
        name: item.name,
        category: item.category,
        caloriesPer100g: item.caloriesPer100g,
        proteinPer100g: item.proteinPer100g,
        carbsPer100g: item.carbsPer100g,
        fatPer100g: item.fatPer100g,
        defaultUnit: unit,
        lastUsed: DateTime.now(),
      ),
    );

    await _logRepository.addFoodEntry(
      FoodEntry(
        name: item.name,
        calories: _scale(item.caloriesPer100g, factor),
        protein: _scale(item.proteinPer100g, factor),
        carbs: _scale(item.carbsPer100g, factor),
        fat: _scale(item.fatPer100g, factor),
        date: _selectedDate,
        amount: amount,
        unit: unit,
        foodItemId: item.id,
      ),
    );
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
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

  void clearScannedFoodInfo() {
    _scannedFoodInfo = null;
    notifyListeners();
  }

  /// Add an activity using AI to estimate calories burned
  Future<void> addActivityItem(String activityName) {
    return _runAiTask(() async {
      final info = await _apiServiceRepository.fetchActivityCalories(
        activityName,
        _bodyWeightForEstimates,
      );
      await _addActivityEntryFromInfo(info);
    });
  }

  /// Add unified entry - AI classifies as food or activity automatically
  Future<void> addUnifiedEntry(String input, String description) {
    return _runAiTask(() async {
      final entry = await _apiServiceRepository.classifyAndProcess(
        input,
        description,
        _bodyWeightForEstimates,
      );
      if (entry.isFood) {
        await _addFoodEntryFromInfo(entry.foodInfo!);
      } else {
        await _addActivityEntryFromInfo(entry.activityInfo!);
      }
    });
  }

  /// Add food from image using AI estimation
  Future<void> addFoodFromImage(Uint8List imageBytes, String? description) {
    return _runAiTask(() async {
      final info = await _apiServiceRepository.estimateFoodFromImage(
        imageBytes,
        description,
      );
      await _addFoodEntryFromInfo(info);
    });
  }

  /// Re-estimate a food entry with AI, using the (possibly edited) name and
  /// amount from the edit dialog
  Future<void> reFetchFoodItem(FoodEntry foodEntry) {
    return _runAiTask(() async {
      final amount = foodEntry.amount != null && foodEntry.unit != null
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
    });
  }

  /// Re-estimate an activity entry with AI, using the edited name
  Future<void> reFetchActivityItem(ActivityEntry activityEntry) {
    return _runAiTask(() async {
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
    });
  }

  static String _formatAmount(double amount) => amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(1);

  /// Update food item manually
  Future<void> updateFoodItemManual(FoodEntry foodEntry) async {
    await _logRepository.updateFoodEntry(foodEntry);
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
  }

  /// Update activity item manually
  Future<void> updateActivityItemManual(ActivityEntry activityEntry) async {
    await _logRepository.updateActivityEntry(activityEntry);
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
  }

  /// Delete food item
  Future<void> deleteFoodItem(FoodEntry foodEntry) async {
    await _logRepository.deleteFoodEntry(foodEntry);
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
  }

  /// Delete activity item
  Future<void> deleteActivityItem(ActivityEntry activityEntry) async {
    await _logRepository.deleteActivityEntry(activityEntry);
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
  }

  /// Save user profile and recalculate goals
  Future<void> saveUserProfileAndRecalculateGoals(UserProfile profile) async {
    _initializeApiService(profile);
    final newGoals = GoalsCalculator.calculateGoals(profile);

    await _prefsRepository.saveUserProfile(profile);
    await _prefsRepository.saveCalorieGoals(newGoals);

    _userProfile = profile;
    _goals = newGoals;
    if (_errorMessage != null && missingApiKeyMessage == null) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  /// Change app theme
  Future<void> changeTheme(String themeName) async {
    _currentTheme = themeName;
    await _prefsRepository.saveTheme(themeName);
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
  /// on every call so the assistant always sees the latest log and profile.
  Future<void> sendAssistantMessage(String text, {String? displayText}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _assistantBusy) return;

    _assistantMessages = [
      ..._assistantMessages.where((m) => !m.isError),
      ChatMessage(role: ChatRole.user, text: trimmed, displayText: displayText),
    ];
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

    try {
      final system = await _buildAssistantContext();
      final history = _assistantMessages.length > _maxMessagesSentToModel
          ? _assistantMessages.sublist(
              _assistantMessages.length - _maxMessagesSentToModel,
            )
          : _assistantMessages;
      final firstUser = history.indexWhere((m) => m.isUser);
      final tools = _coachTools();
      final reply = await _apiServiceRepository.chat(
        system: system,
        messages: firstUser <= 0 ? history : history.sublist(firstUser),
        tools: CoachTools.definitions,
        onToolCall: tools.execute,
      );
      _assistantMessages = [
        ..._assistantMessages,
        ChatMessage(role: ChatRole.assistant, text: reply.trim()),
      ];
      await _prefsRepository.saveChatHistory(_assistantMessages);
    } catch (e) {
      _assistantMessages = [
        ..._assistantMessages,
        ChatMessage(
          role: ChatRole.assistant,
          text: _errorText(e),
          isError: true,
        ),
      ];
    }

    _assistantBusy = false;
    _assistantStatus = null;
    notifyListeners();
  }

  CoachTools _coachTools() => CoachTools(
    loadFoods: _logRepository.getFoodEntriesForDateRange,
    loadActivities: _logRepository.getActivityEntriesForDateRange,
    loadWeights: _logRepository.getWeightEntriesForDateRange,
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
    final weekStartDate = startOfWeek(_selectedDate);
    final loadStart = recentStart.isBefore(weekStartDate)
        ? recentStart
        : weekStartDate;
    final loadEnd = _selectedDate.isAfter(today) ? _selectedDate : today;

    final foods = await _logRepository.getFoodEntriesForDateRange(
      loadStart,
      loadEnd,
    );
    final activities = await _logRepository.getActivityEntriesForDateRange(
      loadStart,
      loadEnd,
    );
    final days = NutritionStats.daily(foods, activities, loadStart, loadEnd);
    final weights = await _logRepository.getWeightEntriesForDateRange(
      addDays(today, -13),
      today,
    );

    return AssistantContextBuilder.build(
      profile: _userProfile,
      goals: _goals,
      now: now,
      selectedDate: _selectedDate,
      dayFoods: _foodEntries,
      dayActivities: _activityEntries,
      dayBudget: calorieBudget,
      week: NutritionStats.weekStatus(
        days,
        _selectedDate,
        dailyGoal: _goals.calories,
        eatBackActivity: _userProfile.eatBackActivityCalories,
      ),
      recentDays: days
          .where((d) => !d.date.isBefore(recentStart) && d.date.isBefore(today))
          .toList(),
      recentWeights: weights,
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
}
