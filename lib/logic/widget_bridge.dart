import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WidgetLaunchAction {
  static const String addText = 'add_text';
  static const String addVoice = 'add_voice';
  static const String addPhoto = 'add_photo';
}

class WidgetBridge {
  static const MethodChannel _channel = MethodChannel(
    'de.armando.kalorientracker_flutter/widget',
  );

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void setActionHandler(void Function(String action) onAction) {
    if (!_isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction' && call.arguments is String) {
        onAction(call.arguments as String);
      }
    });
  }

  static Future<String?> consumeInitialAction() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('consumeInitialAction');
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateSummary({
    required int eatenKcal,
    required int budgetKcal,
    required int protein,
    required int proteinGoal,
    required int carbs,
    required int fat,
    required bool hasGoals,
    required String dateLabel,
  }) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('updateWidgetData', {
        'eatenKcal': eatenKcal,
        'budgetKcal': budgetKcal,
        'protein': protein,
        'proteinGoal': proteinGoal,
        'carbs': carbs,
        'fat': fat,
        'hasGoals': hasGoals,
        'dateLabel': dateLabel,
      });
    } catch (_) {}
  }
}
