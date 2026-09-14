import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/calorie_goals.dart';
import '../models/chat_message.dart';

/// Repository for storing user preferences in SharedPreferences
class UserPreferencesRepository {
  static const String _profileKey = 'user_profile';
  static const String _goalsKey = 'calorie_goals';
  static const String _themeKey = 'app_theme';
  static const String _chatKey = 'assistant_chat';
  static const int _maxStoredMessages = 60;

  Future<UserProfile> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profileKey);

    if (jsonString == null) {
      return const UserProfile();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } catch (e) {
      return const UserProfile();
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(profile.toJson());
    await prefs.setString(_profileKey, jsonString);
  }

  Future<CalorieGoals> loadCalorieGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_goalsKey);

    if (jsonString == null) {
      return const CalorieGoals();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return CalorieGoals.fromJson(json);
    } catch (e) {
      return const CalorieGoals();
    }
  }

  Future<void> saveCalorieGoals(CalorieGoals goals) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(goals.toJson());
    await prefs.setString(_goalsKey, jsonString);
  }

  Future<String> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'Default';
  }

  Future<void> saveTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
  }

  Future<List<ChatMessage>> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_chatKey);
    if (jsonString == null) return [];
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = messages.length > _maxStoredMessages
        ? messages.sublist(messages.length - _maxStoredMessages)
        : messages;
    await prefs.setString(
      _chatKey,
      jsonEncode(recent.map((m) => m.toJson()).toList()),
    );
  }
}
