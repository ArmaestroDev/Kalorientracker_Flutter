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
import '../../data/services/food_api_service.dart';
import '../goals_calculator.dart';

/// Main state provider for the Kalorientracker app
class MainProvider extends ChangeNotifier {
  final LogRepository _logRepository = LogRepository();
  final UserPreferencesRepository _prefsRepository =
      UserPreferencesRepository();

  ApiServiceRepository? _apiServiceRepository;

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
    if (profile.selectedProvider == AiProvider.claude) {
      service = ClaudeApiService(profile.claudeApiKey);
    } else {
      service = GeminiApiService(profile.geminiApiKey);
    }
    _apiServiceRepository = ApiServiceRepository(service);
  }

  bool _isApiKeyMissing() {
    final isMissing = _userProfile.selectedProvider == AiProvider.gemini
        ? _userProfile.geminiApiKey.isEmpty
        : _userProfile.claudeApiKey.isEmpty;

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
      final nutritionInfo = await _apiServiceRepository!.fetchFoodNutrition(
        foodName,
        description,
      );

      if (nutritionInfo != null && nutritionInfo.calories > 0) {
        final newEntry = FoodEntry(
          name: nutritionInfo.name,
          calories: nutritionInfo.calories,
          protein: nutritionInfo.protein.toInt(),
          carbs: nutritionInfo.carbs.toInt(),
          fat: nutritionInfo.fat.toInt(),
          date: _selectedDate,
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

  /// Fetch food info by barcode
  Future<void> fetchFoodInfoByBarcode(String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nutritionInfo = await _apiServiceRepository!.fetchBarCodeNutrition(
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
    final factor = grams / 100.0;
    final newEntry = FoodEntry(
      name: '${foodInfo.name} (${grams}g)',
      calories: (foodInfo.calories * factor).toInt(),
      protein: (foodInfo.protein * factor).toInt(),
      carbs: (foodInfo.carbs * factor).toInt(),
      fat: (foodInfo.fat * factor).toInt(),
      date: _selectedDate,
    );

    await _logRepository.addFoodEntry(newEntry);
    await _loadEntriesForDate(_selectedDate);
    notifyListeners();
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
      final activityInfo = await _apiServiceRepository!.fetchActivityCalories(
        activityName,
      );

      if (activityInfo != null && activityInfo.caloriesBurned > 0) {
        final newEntry = ActivityEntry(
          name: activityName,
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

  /// Re-fetch food item with AI
  Future<void> reFetchFoodItem(FoodEntry foodEntry) async {
    if (_isApiKeyMissing()) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nutritionInfo = await _apiServiceRepository!.fetchFoodNutrition(
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
      final activityInfo = await _apiServiceRepository!.fetchActivityCalories(
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
}
