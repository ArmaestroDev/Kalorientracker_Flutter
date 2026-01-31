import 'package:flutter/foundation.dart';
import '../../data/models/food_entry.dart';
import '../../data/models/activity_entry.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/calorie_goals.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/log_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/repositories/api_service_repository.dart';
import '../../data/services/generative_service.dart';
import '../../data/services/gemini_api_service.dart';
import '../../data/services/claude_api_service.dart';
import '../../data/services/openai_api_service.dart';
import '../../data/services/grok_api_service.dart';
import '../../data/services/food_api_service.dart';
import '../../data/models/food_item.dart';
import '../../data/models/ai_analysis_type.dart';
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
  DateTime _selectedDate = DateTime.now();
  List<FoodEntry> _foodEntries = [];
  List<ActivityEntry> _activityEntries = [];
  UserProfile _userProfile = const UserProfile();
  CalorieGoals _goals = const CalorieGoals();
  bool _isLoading = false;
  String? _errorMessage;
  FoodNutritionInfo? _scannedFoodInfo;
  String _currentTheme = 'Default';

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

  // Computed values
  int get totalCalories => _foodEntries.fold(0, (sum, e) => sum + e.calories);
  int get totalProtein => _foodEntries.fold(0, (sum, e) => sum + e.protein);
  int get totalCarbs => _foodEntries.fold(0, (sum, e) => sum + e.carbs);
  int get totalFat => _foodEntries.fold(0, (sum, e) => sum + e.fat);
  int get totalBurned =>
      _activityEntries.fold(0, (sum, e) => sum + e.caloriesBurned);
  int get netCalories => totalCalories - totalBurned;

  /// Initialize the provider by loading saved data
  Future<void> loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _userProfile = await _prefsRepository.loadUserProfile();
      _goals = await _prefsRepository.loadCalorieGoals();
      _currentTheme = await _prefsRepository.loadTheme();
      _initializeApiService(_userProfile);
      await _loadEntriesForDate(_selectedDate);
    } catch (e) {
      _errorMessage = 'Fehler beim Laden der Daten: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  void _initializeApiService(UserProfile profile) {
    GenerativeService service;
    switch (profile.selectedProvider) {
      case AiProvider.claude:
        service = ClaudeApiService(profile.claudeApiKey);
        break;
      case AiProvider.openai:
        service = OpenAiApiService(profile.openaiApiKey);
        break;
      case AiProvider.grok:
        service = GrokApiService(profile.grokApiKey);
        break;
      case AiProvider.gemini:
        service = GeminiApiService(profile.geminiApiKey);
        break;
    }
    _apiServiceRepository.updateService(service);
  }

  bool _isApiKeyMissing() {
    bool isMissing = false;
    switch (_userProfile.selectedProvider) {
      case AiProvider.gemini:
        isMissing = _userProfile.geminiApiKey.isEmpty;
        break;
      case AiProvider.claude:
        isMissing = _userProfile.claudeApiKey.isEmpty;
        break;
      case AiProvider.openai:
        isMissing = _userProfile.openaiApiKey.isEmpty;
        break;
      case AiProvider.grok:
        isMissing = _userProfile.grokApiKey.isEmpty;
        break;
    }

    if (isMissing) {
      _errorMessage =
          'Bitte gib zuerst deinen ${_userProfile.selectedProvider.name.toUpperCase()} API-Schlüssel im Profil ein.';
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> _loadEntriesForDate(DateTime date) async {
    _foodEntries = await _logRepository.getFoodEntriesForDate(date);
    _activityEntries = await _logRepository.getActivityEntriesForDate(date);
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

  /// Add a food item using AI to estimate nutrition
  Future<void> addFoodItem(String foodName, String description) async {
    if (_isApiKeyMissing()) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nutritionInfo = await _apiServiceRepository.fetchFoodNutrition(
        foodName,
        description,
      );

      if (nutritionInfo != null && nutritionInfo.calories > 0) {
        // Save to DB History
        await _saveFoodItemToHistory(nutritionInfo);

        final newEntry = FoodEntry(
          name: nutritionInfo.name,
          calories: nutritionInfo.calories,
          protein: nutritionInfo.protein.toInt(),
          carbs: nutritionInfo.carbs.toInt(),
          fat: nutritionInfo.fat.toInt(),
          date: _selectedDate,
          // Assuming AI gives us the total values, we might not always know exact gram amount
          // unless parsed from name. But we stored normalized values for next time.
        );
        await _logRepository.addFoodEntry(newEntry);
        await _loadEntriesForDate(_selectedDate);
      } else {
        _errorMessage = 'Nährwertdaten konnten nicht abgerufen werden.';
      }
    } catch (e) {
      // Show the actual error message to the user for debugging
      _errorMessage = 'Fehler: ${e.toString().replaceAll('Exception: ', '')}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveFoodItemToHistory(FoodNutritionInfo info) async {
    // Generate ID
    final id = info.name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

    // Determine values to save
    double c100, p100, cb100, f100;
    String unit;

    if (info.caloriesPer100g != null) {
      c100 = info.caloriesPer100g!;
      p100 = info.proteinPer100g ?? 0;
      cb100 = info.carbsPer100g ?? 0;
      f100 = info.fatPer100g ?? 0;
      unit = 'g';
    } else {
      // Fallback: Save as "1 Portion" using the total values
      c100 = info.calories.toDouble();
      p100 = info.protein;
      cb100 = info.carbs;
      f100 = info.fat;
      unit = 'Portion';
    }

    final item = FoodItem(
      id: id,
      name: info.name,
      category: info.category ?? 'Allgemein',
      caloriesPer100g:
          c100, // Represents per 100g OR per Portion depending on unit
      proteinPer100g: p100,
      carbsPer100g: cb100,
      fatPer100g: f100,
      defaultUnit: unit,
      lastUsed: DateTime.now(),
    );
    await _logRepository.saveFoodItem(item);
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
    // Save to history (will save as 100g based since barcode usually has it)
    await _saveFoodItemToHistory(foodInfo);

    final factor = grams / 100.0;
    final newEntry = FoodEntry(
      name: '${foodInfo.name} (${grams}g)',
      calories: (foodInfo.calories * factor).toInt(),
      protein: (foodInfo.protein * factor).toInt(),
      carbs: (foodInfo.carbs * factor).toInt(),
      fat: (foodInfo.fat * factor).toInt(),
      date: _selectedDate,
      amount: grams.toDouble(),
      unit: 'g',
    );

    await _logRepository.addFoodEntry(newEntry);
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
  }

  /// Add food item from history with specific amount (smart scaling)
  Future<void> addFoodItemFromHistory(
    FoodItem item,
    double amount,
    String unit,
  ) async {
    // Update last used timestamp
    final updatedItem = FoodItem(
      id: item.id,
      name: item.name,
      category: item.category,
      caloriesPer100g: item.caloriesPer100g,
      proteinPer100g: item.proteinPer100g,
      carbsPer100g: item.carbsPer100g,
      fatPer100g: item.fatPer100g,
      defaultUnit:
          unit, // Remember last used unit? Maybe keep original default.
      lastUsed: DateTime.now(),
    );
    await _logRepository.saveFoodItem(updatedItem);

    // Calculate values
    double factor;
    if (item.defaultUnit == 'Portion' || unit == 'Portion' || unit == 'Stk') {
      // If stored as portion, amount is number of portions
      factor = amount;
    } else {
      // Grams / ml
      factor = amount / 100.0;
    }

    // Build display name with amount
    final displayName = (unit == 'Portion' || unit == 'Stk')
        ? '${item.name} (${amount.toInt()} $unit)'
        : '${item.name} (${amount.toInt()}$unit)';

    final newEntry = FoodEntry(
      name: displayName,
      calories: (item.caloriesPer100g * factor).toInt(),
      protein: (item.proteinPer100g * factor).toInt(),
      carbs: (item.carbsPer100g * factor).toInt(),
      fat: (item.fatPer100g * factor).toInt(),
      date: _selectedDate,
      amount: amount,
      unit: unit,
      foodItemId: item.id,
    );

    await _logRepository.addFoodEntry(newEntry);
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
  Future<void> addActivityItem(String activityName) async {
    if (_isApiKeyMissing()) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final activityInfo = await _apiServiceRepository.fetchActivityCalories(
        activityName,
      );

      if (activityInfo != null && activityInfo.caloriesBurned > 0) {
        final newEntry = ActivityEntry(
          name: activityInfo.name,
          caloriesBurned: activityInfo.caloriesBurned,
          date: _selectedDate,
        );
        await _logRepository.addActivityEntry(newEntry);
        await _loadEntriesForDate(_selectedDate);
      } else {
        _errorMessage = 'Verbrannte Kalorien konnten nicht geschätzt werden.';
      }
    } catch (e) {
      _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add unified entry - AI classifies as food or activity automatically
  Future<void> addUnifiedEntry(String input, String description) async {
    if (_isApiKeyMissing()) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final unifiedEntry = await _apiServiceRepository.classifyAndProcess(
        input,
        description,
      );

      if (unifiedEntry == null) {
        _errorMessage = 'Eintrag konnte nicht klassifiziert werden.';
      } else if (unifiedEntry.isFood && unifiedEntry.foodInfo != null) {
        final foodInfo = unifiedEntry.foodInfo!;
        if (foodInfo.calories > 0) {
          await _saveFoodItemToHistory(foodInfo);

          final newEntry = FoodEntry(
            name: foodInfo.name,
            calories: foodInfo.calories,
            protein: foodInfo.protein.toInt(),
            carbs: foodInfo.carbs.toInt(),
            fat: foodInfo.fat.toInt(),
            date: _selectedDate,
          );
          await _logRepository.addFoodEntry(newEntry);
          await _loadEntriesForDate(_selectedDate);
        } else {
          _errorMessage = 'Nährwertdaten konnten nicht abgerufen werden.';
        }
      } else if (!unifiedEntry.isFood && unifiedEntry.activityInfo != null) {
        final activityInfo = unifiedEntry.activityInfo!;
        if (activityInfo.caloriesBurned > 0) {
          final newEntry = ActivityEntry(
            name: activityInfo.name,
            caloriesBurned: activityInfo.caloriesBurned,
            date: _selectedDate,
          );
          await _logRepository.addActivityEntry(newEntry);
          await _loadEntriesForDate(_selectedDate);
        } else {
          _errorMessage = 'Verbrannte Kalorien konnten nicht geschätzt werden.';
        }
      } else {
        _errorMessage = 'Eintrag konnte nicht verarbeitet werden.';
      }
    } catch (e) {
      _errorMessage = 'Fehler: ${e.toString().replaceAll('Exception: ', '')}';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add food from image using AI estimation
  Future<void> addFoodFromImage(
    Uint8List imageBytes,
    String? description,
  ) async {
    if (_isApiKeyMissing()) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final foodInfo = await _apiServiceRepository.estimateFoodFromImage(
        imageBytes,
        description,
      );

      if (foodInfo != null && foodInfo.calories > 0) {
        await _saveFoodItemToHistory(foodInfo);

        final newEntry = FoodEntry(
          name: foodInfo.name,
          calories: foodInfo.calories,
          protein: foodInfo.protein.toInt(),
          carbs: foodInfo.carbs.toInt(),
          fat: foodInfo.fat.toInt(),
          date: _selectedDate,
        );
        await _logRepository.addFoodEntry(newEntry);
        await _loadEntriesForDate(_selectedDate);
      } else {
        _errorMessage =
            'Nährwertdaten konnten aus dem Bild nicht geschätzt werden.';
      }
    } catch (e) {
      _errorMessage = 'Fehler: ${e.toString().replaceAll('Exception: ', '')}';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Re-fetch food item with AI
  Future<void> reFetchFoodItem(FoodEntry foodEntry) async {
    if (_isApiKeyMissing()) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nutritionInfo = await _apiServiceRepository.fetchFoodNutrition(
        foodEntry.name,
        '',
      );

      if (nutritionInfo != null && nutritionInfo.calories > 0) {
        final updatedEntry = foodEntry.copyWith(
          name: nutritionInfo.name,
          calories: nutritionInfo.calories,
          protein: nutritionInfo.protein.toInt(),
          carbs: nutritionInfo.carbs.toInt(),
          fat: nutritionInfo.fat.toInt(),
        );
        await _logRepository.updateFoodEntry(updatedEntry);
        await _loadEntriesForDate(_selectedDate);
      } else {
        _errorMessage = 'Nährwertdaten konnten nicht abgerufen werden.';
      }
    } catch (e) {
      _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Re-fetch activity item with AI
  Future<void> reFetchActivityItem(ActivityEntry activityEntry) async {
    if (_isApiKeyMissing()) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final activityInfo = await _apiServiceRepository.fetchActivityCalories(
        activityEntry.name,
      );

      if (activityInfo != null && activityInfo.caloriesBurned > 0) {
        final updatedEntry = activityEntry.copyWith(
          name: activityInfo.name,
          caloriesBurned: activityInfo.caloriesBurned,
        );
        await _logRepository.updateActivityEntry(updatedEntry);
        await _loadEntriesForDate(_selectedDate);
      } else {
        _errorMessage = 'Kaloriendaten konnten nicht abgerufen werden.';
      }
    } catch (e) {
      _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

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

  /// Perform AI Analysis based on selected type
  Future<String?> performAiAnalysis(AiAnalysisType type) async {
    if (_isApiKeyMissing()) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      DateTime start;
      DateTime end;
      String analysisContext;

      // Determine date range and context
      final now = DateTime.now();
      switch (type) {
        case AiAnalysisType.dayReview:
        case AiAnalysisType.nextMeal:
          start = DateTime(now.year, now.month, now.day);
          end = start;
          analysisContext = type == AiAnalysisType.dayReview
              ? "Daily Review: Summarize the day's nutrition and activity."
              : "Next Meal Suggestion: Suggest a healthy next meal based on remaining calories and macros.";
          break;
        case AiAnalysisType.weekReview:
          start = now.subtract(const Duration(days: 7));
          end = now;
          analysisContext =
              "Weekly Review: Analyze the nutrition and activity trends over the last week.";
          break;
        case AiAnalysisType.monthReview:
          start = now.subtract(const Duration(days: 30));
          end = now;
          analysisContext =
              "Monthly Review: Analyze the nutrition and activity trends over the last month.";
          break;
        case AiAnalysisType.yearReview:
          start = now.subtract(const Duration(days: 365));
          end = now;
          analysisContext =
              "Yearly Review: Analyze the nutrition and activity trends over the last year.";
          break;
      }

      // Fetch data
      List<FoodEntry> foods;
      List<ActivityEntry> activities;

      if (start == end) {
        // Optimization for single day (though range would work efficiently too)
        foods = await _logRepository.getFoodEntriesForDate(start);
        activities = await _logRepository.getActivityEntriesForDate(start);
      } else {
        foods = await _logRepository.getFoodEntriesForDateRange(start, end);
        activities = await _logRepository.getActivityEntriesForDateRange(
          start,
          end,
        );
      }

      // Build prompt
      final sb = StringBuffer();
      sb.writeln(analysisContext);
      sb.writeln(
        "User Profile: $_userProfile",
      ); // Ensure toString() is meaningful
      sb.writeln("Goals: $_goals");
      sb.writeln(
        "Data Period: ${start.toIso8601String()} to ${end.toIso8601String()}",
      );
      sb.writeln("\nFood Entires:");
      if (foods.isEmpty) {
        sb.writeln("No food entries recorded.");
      } else {
        for (var f in foods) {
          sb.writeln(
            "- ${f.date.toIso8601String().split('T')[0]}: ${f.name} (${f.calories} kcal, P:${f.protein}g, C:${f.carbs}g, F:${f.fat}g)",
          );
        }
      }

      sb.writeln("\nActivity Entries:");
      if (activities.isEmpty) {
        sb.writeln("No activity entries recorded.");
      } else {
        for (var a in activities) {
          sb.writeln(
            "- ${a.date.toIso8601String().split('T')[0]}: ${a.name} (${a.caloriesBurned} kcal)",
          );
        }
      }

      sb.writeln("\nInstructions:");
      sb.writeln("1. Be encouraging and helpful.");
      sb.writeln("2. Highlight positives and suggest improvements.");
      sb.writeln("3. Keep it concise but informative.");
      sb.writeln("4. Use Markdown formatting.");
      sb.writeln("5. Respond in German.");

      final prompt = sb.toString();

      final result = await _apiServiceRepository.analyzeDiet(prompt);

      if (result == null) {
        _errorMessage = "Die Analyse konnte nicht erstellt werden.";
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Fehler bei der Analyse: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
