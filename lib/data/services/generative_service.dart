import 'dart:convert';
import 'dart:typed_data';
import '../models/chat_message.dart';

/// A provider-independent request to a generative AI model
class AiRequest {
  final String system;
  final List<ChatMessage> messages;
  final bool jsonOutput;
  final Uint8List? imageBytes;
  final int maxTokens;

  const AiRequest({
    required this.system,
    required this.messages,
    this.jsonOutput = false,
    this.imageBytes,
    this.maxTokens = 16000,
  });

  AiRequest.single({
    required this.system,
    required String prompt,
    this.jsonOutput = false,
    this.imageBytes,
    this.maxTokens = 16000,
  }) : messages = [ChatMessage(role: ChatRole.user, text: prompt)];
}

/// Error with a user-facing German message
class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}

abstract class GenerativeService {
  String get providerName;
  String get model;

  Future<String> generate(AiRequest request);

  static const textTimeout = Duration(seconds: 120);
  static const imageTimeout = Duration(seconds: 180);

  /// Turns an HTTP error response into a message the user can act on
  static AiException httpError(
    String provider,
    String model,
    int status,
    String body,
  ) {
    String? detail;
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final error = json['error'];
        if (error is Map) {
          detail = error['message'] as String?;
        } else if (error is String) {
          detail = error;
        }
      } else if (json is List && json.isNotEmpty && json.first is Map) {
        detail = ((json.first as Map)['error'] as Map?)?['message'] as String?;
      }
    } catch (_) {}
    detail ??= body.length > 200 ? '${body.substring(0, 200)}…' : body;

    final lower = detail.toLowerCase();
    final hint = switch (status) {
      400 when lower.contains('api key') || lower.contains('api_key') =>
        'API-Schlüssel ungültig. Bitte im Profil prüfen.',
      400 when lower.contains('model') =>
        'Modell "$model" wird nicht unterstützt. Trage im Profil ein aktuelles Modell ein.',
      400 => 'Anfrage abgelehnt.',
      401 || 403 =>
        'API-Schlüssel ungültig oder ohne Berechtigung. Bitte im Profil prüfen.',
      402 => 'Kein Guthaben beim Anbieter.',
      404 =>
        'Modell "$model" nicht gefunden. Trage im Profil ein aktuelles Modell ein.',
      429 =>
        'Zu viele Anfragen oder Kontingent aufgebraucht. Bitte kurz warten.',
      >= 500 =>
        'Der Dienst ist gerade überlastet. Bitte später erneut versuchen.',
      _ => 'Unerwarteter Fehler.',
    };
    return AiException('$provider: $hint\n($status) $detail');
  }

  static AiException networkError(String provider, Object error) {
    return AiException(
      '$provider: Keine Verbindung oder Zeitüberschreitung. Bitte Internet prüfen und erneut versuchen.\n$error',
    );
  }
}
